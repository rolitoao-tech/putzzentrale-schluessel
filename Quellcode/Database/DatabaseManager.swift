import SQLite3
import Foundation

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
        migrateIfNeeded()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Datenbankpfad (iCloud Drive mit lokalem Fallback)

    private func dbPfad() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloud = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            .appendingPathComponent("Putzzentrale")

        if FileManager.default.fileExists(atPath:
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path) {
            try? FileManager.default.createDirectory(at: iCloud, withIntermediateDirectories: true)
            return iCloud.appendingPathComponent("schluessel.sqlite")
        }

        let lokal = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ch.putzzentrale.schluessel")
        try? FileManager.default.createDirectory(at: lokal, withIntermediateDirectories: true)
        return lokal.appendingPathComponent("schluessel.sqlite")
    }

    private func openDatabase() {
        let pfad = dbPfad()
        guard sqlite3_open(pfad.path, &db) == SQLITE_OK else {
            print("DB-Fehler: \(pfad.path)")
            return
        }
        sqlite3_busy_timeout(db, 3000)   // 3 Sek. warten bei gleichzeitigem Schreibzugriff
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA journal_mode = WAL;")
    }

    private func createTables() {
        exec("""
        CREATE TABLE IF NOT EXISTS kunden (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            kundennummer         TEXT NOT NULL,
            name                 TEXT NOT NULL,
            wohnort              TEXT DEFAULT '',
            zugeteilt_rk_id      INTEGER NOT NULL DEFAULT 0,
            standort_typ         TEXT NOT NULL DEFAULT 'safe',
            standort_detail      TEXT DEFAULT '',
            aktiv                INTEGER NOT NULL DEFAULT 1,
            notizen              TEXT DEFAULT ''
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS reinigungskraefte (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            name    TEXT NOT NULL,
            aktiv   INTEGER NOT NULL DEFAULT 1,
            notizen TEXT DEFAULT ''
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS bewegungen (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            kunden_id            INTEGER NOT NULL,
            datum_abgang         TEXT NOT NULL,
            grund                TEXT NOT NULL,
            stellvertretung_rk_id INTEGER,
            erwartete_rueckgabe  TEXT,
            datum_rueckgabe      TEXT,
            pool_eingetragen     INTEGER NOT NULL DEFAULT 0,
            notizen              TEXT DEFAULT '',
            FOREIGN KEY (kunden_id) REFERENCES kunden(id)
        );
        """)
    }

    // Migration: neue Spalten hinzufügen (schlägt still fehl wenn bereits vorhanden)
    private func migrateIfNeeded() {
        exec("ALTER TABLE kunden ADD COLUMN zugeteilt_rk_id INTEGER NOT NULL DEFAULT 0;")
        exec("ALTER TABLE bewegungen ADD COLUMN stellvertretung_rk_id INTEGER;")
    }

    // MARK: - Helpers

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK, let e = err { print("SQL: \(String(cString: e))") }
        return rc == SQLITE_OK
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    private func col(_ s: OpaquePointer?, _ i: Int32) -> String {
        sqlite3_column_text(s, i).map { String(cString: $0) } ?? ""
    }
    private func colDate(_ s: OpaquePointer?, _ i: Int32) -> Date? {
        guard let t = sqlite3_column_text(s, i).map({ String(cString: $0) }), !t.isEmpty
        else { return nil }
        return DateFormatter.iso8601Date.date(from: t)
    }
    private func colDateReq(_ s: OpaquePointer?, _ i: Int32) -> Date {
        colDate(s, i) ?? Date()
    }
    private func bind(_ s: OpaquePointer?, _ i: Int32, _ v: String) {
        sqlite3_bind_text(s, i, v, -1, SQLITE_TRANSIENT)
    }
    private func bindDate(_ s: OpaquePointer?, _ i: Int32, _ v: Date?) {
        if let d = v { bind(s, i, DateFormatter.iso8601Date.string(from: d)) }
        else { sqlite3_bind_null(s, i) }
    }

    // MARK: - Kunden
    // Spalten: 0=id, 1=kundennummer, 2=name, 3=wohnort, 4=zugeteilt_rk_id,
    //          5=standort_typ, 6=standort_detail, 7=aktiv, 8=notizen

    func fetchKunden(nurAktive: Bool = false) -> [Kunde] {
        let where_ = nurAktive ? " WHERE aktiv = 1" : ""
        guard let s = prepare(
            "SELECT id,kundennummer,name,wohnort,zugeteilt_rk_id,standort_typ,standort_detail,aktiv,notizen FROM kunden\(where_) ORDER BY name"
        ) else { return [] }
        defer { sqlite3_finalize(s) }
        var list: [Kunde] = []
        while sqlite3_step(s) == SQLITE_ROW {
            list.append(Kunde(
                id:                          sqlite3_column_int64(s, 0),
                kundennummer:                col(s, 1),
                name:                        col(s, 2),
                wohnort:                     col(s, 3),
                zugeteilteReinigungskraftId: sqlite3_column_int64(s, 4),
                standortTyp:                 StandortTyp(rawValue: col(s, 5)) ?? .safe,
                standortDetail:              col(s, 6),
                aktiv:                       sqlite3_column_int(s, 7) != 0,
                notizen:                     col(s, 8)
            ))
        }
        return list
    }

    @discardableResult
    func insertKunde(_ k: Kunde) -> Int64 {
        guard let s = prepare(
            "INSERT INTO kunden (kundennummer,name,wohnort,zugeteilt_rk_id,standort_typ,standort_detail,aktiv,notizen) VALUES (?,?,?,?,?,?,?,?)"
        ) else { return -1 }
        defer { sqlite3_finalize(s) }
        bind(s,1,k.kundennummer); bind(s,2,k.name); bind(s,3,k.wohnort)
        sqlite3_bind_int64(s,4,k.zugeteilteReinigungskraftId)
        bind(s,5,k.standortTyp.rawValue); bind(s,6,k.standortDetail)
        sqlite3_bind_int(s,7,k.aktiv ? 1 : 0); bind(s,8,k.notizen)
        sqlite3_step(s)
        return sqlite3_last_insert_rowid(db)
    }

    func updateKunde(_ k: Kunde) {
        guard let s = prepare(
            "UPDATE kunden SET kundennummer=?,name=?,wohnort=?,zugeteilt_rk_id=?,standort_typ=?,standort_detail=?,aktiv=?,notizen=? WHERE id=?"
        ) else { return }
        defer { sqlite3_finalize(s) }
        bind(s,1,k.kundennummer); bind(s,2,k.name); bind(s,3,k.wohnort)
        sqlite3_bind_int64(s,4,k.zugeteilteReinigungskraftId)
        bind(s,5,k.standortTyp.rawValue); bind(s,6,k.standortDetail)
        sqlite3_bind_int(s,7,k.aktiv ? 1 : 0); bind(s,8,k.notizen)
        sqlite3_bind_int64(s,9,k.id)
        sqlite3_step(s)
    }

    func deleteKunde(id: Int64) { exec("DELETE FROM kunden WHERE id=\(id)") }

    // MARK: - Reinigungskräfte

    func fetchReinigungskraefte(nurAktive: Bool = false) -> [Reinigungskraft] {
        let where_ = nurAktive ? " WHERE aktiv = 1" : ""
        guard let s = prepare(
            "SELECT id,name,aktiv,notizen FROM reinigungskraefte\(where_) ORDER BY name"
        ) else { return [] }
        defer { sqlite3_finalize(s) }
        var list: [Reinigungskraft] = []
        while sqlite3_step(s) == SQLITE_ROW {
            list.append(Reinigungskraft(
                id:      sqlite3_column_int64(s, 0),
                name:    col(s, 1),
                aktiv:   sqlite3_column_int(s, 2) != 0,
                notizen: col(s, 3)
            ))
        }
        return list
    }

    @discardableResult
    func insertReinigungskraft(_ r: Reinigungskraft) -> Int64 {
        guard let s = prepare(
            "INSERT INTO reinigungskraefte (name,aktiv,notizen) VALUES (?,?,?)"
        ) else { return -1 }
        defer { sqlite3_finalize(s) }
        bind(s,1,r.name); sqlite3_bind_int(s,2,r.aktiv ? 1 : 0); bind(s,3,r.notizen)
        sqlite3_step(s)
        return sqlite3_last_insert_rowid(db)
    }

    func updateReinigungskraft(_ r: Reinigungskraft) {
        guard let s = prepare(
            "UPDATE reinigungskraefte SET name=?,aktiv=?,notizen=? WHERE id=?"
        ) else { return }
        defer { sqlite3_finalize(s) }
        bind(s,1,r.name); sqlite3_bind_int(s,2,r.aktiv ? 1 : 0); bind(s,3,r.notizen)
        sqlite3_bind_int64(s,4,r.id)
        sqlite3_step(s)
    }

    func deleteReinigungskraft(id: Int64) { exec("DELETE FROM reinigungskraefte WHERE id=\(id)") }

    // MARK: - Bewegungen
    // Spalten: 0=id, 1=kunden_id, 2=datum_abgang, 3=grund,
    //          4=stellvertretung_rk_id, 5=erwartete_rueckgabe,
    //          6=datum_rueckgabe, 7=pool_eingetragen, 8=notizen

    private let bSelect = """
        SELECT id,kunden_id,datum_abgang,grund,
               stellvertretung_rk_id,erwartete_rueckgabe,datum_rueckgabe,pool_eingetragen,notizen
        FROM bewegungen
        """

    private func bRow(_ s: OpaquePointer?) -> Bewegung {
        let stvId = sqlite3_column_type(s, 4) != SQLITE_NULL
            ? sqlite3_column_int64(s, 4) as Int64?
            : nil
        return Bewegung(
            id:                   sqlite3_column_int64(s, 0),
            kundenId:             sqlite3_column_int64(s, 1),
            datumAbgang:          colDateReq(s, 2),
            grund:                BewegungGrund(rawValue: col(s, 3)) ?? .einzelTermin,
            stellvertretungRKId:  stvId,
            erwarteteRueckgabe:   colDate(s, 5),
            datumRueckgabe:       colDate(s, 6),
            poolEingetragen:      sqlite3_column_int(s, 7) != 0,
            notizen:              col(s, 8)
        )
    }

    func fetchBewegungen(kundenId: Int64? = nil) -> [Bewegung] {
        let sql = kundenId.map { bSelect + " WHERE kunden_id=\($0) ORDER BY datum_abgang DESC" }
                  ?? bSelect + " ORDER BY datum_abgang DESC"
        guard let s = prepare(sql) else { return [] }
        defer { sqlite3_finalize(s) }
        var list: [Bewegung] = []
        while sqlite3_step(s) == SQLITE_ROW { list.append(bRow(s)) }
        return list
    }

    func fetchOffeneBewegungen() -> [Bewegung] {
        let sql = bSelect + " WHERE (datum_rueckgabe IS NULL OR datum_rueckgabe='') ORDER BY erwartete_rueckgabe ASC"
        guard let s = prepare(sql) else { return [] }
        defer { sqlite3_finalize(s) }
        var list: [Bewegung] = []
        while sqlite3_step(s) == SQLITE_ROW { list.append(bRow(s)) }
        return list
    }

    func fetchAktiveBewegung(kundenId: Int64) -> Bewegung? {
        let sql = bSelect + " WHERE kunden_id=\(kundenId) AND (datum_rueckgabe IS NULL OR datum_rueckgabe='') ORDER BY datum_abgang DESC LIMIT 1"
        guard let s = prepare(sql) else { return nil }
        defer { sqlite3_finalize(s) }
        return sqlite3_step(s) == SQLITE_ROW ? bRow(s) : nil
    }

    func fetchBewegungen(stellvertretungRKId rkId: Int64, nurOffen: Bool = false) -> [Bewegung] {
        var sql = bSelect + " WHERE stellvertretung_rk_id=\(rkId)"
        if nurOffen { sql += " AND (datum_rueckgabe IS NULL OR datum_rueckgabe='')" }
        sql += " ORDER BY datum_abgang DESC"
        guard let s = prepare(sql) else { return [] }
        defer { sqlite3_finalize(s) }
        var list: [Bewegung] = []
        while sqlite3_step(s) == SQLITE_ROW { list.append(bRow(s)) }
        return list
    }

    @discardableResult
    func insertBewegung(_ b: Bewegung) -> Int64 {
        guard let s = prepare("""
            INSERT INTO bewegungen
            (kunden_id,datum_abgang,grund,stellvertretung_rk_id,erwartete_rueckgabe,datum_rueckgabe,pool_eingetragen,notizen)
            VALUES (?,?,?,?,?,?,?,?)
            """) else { return -1 }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_int64(s,1,b.kundenId)
        bind(s,2,DateFormatter.iso8601Date.string(from:b.datumAbgang))
        bind(s,3,b.grund.rawValue)
        if let stvId = b.stellvertretungRKId { sqlite3_bind_int64(s,4,stvId) }
        else { sqlite3_bind_null(s,4) }
        bindDate(s,5,b.erwarteteRueckgabe); bindDate(s,6,b.datumRueckgabe)
        sqlite3_bind_int(s,7,b.poolEingetragen ? 1 : 0)
        bind(s,8,b.notizen)
        sqlite3_step(s)
        return sqlite3_last_insert_rowid(db)
    }

    func updateBewegung(_ b: Bewegung) {
        guard let s = prepare("""
            UPDATE bewegungen SET kunden_id=?,datum_abgang=?,grund=?,
            stellvertretung_rk_id=?,erwartete_rueckgabe=?,datum_rueckgabe=?,pool_eingetragen=?,notizen=? WHERE id=?
            """) else { return }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_int64(s,1,b.kundenId)
        bind(s,2,DateFormatter.iso8601Date.string(from:b.datumAbgang))
        bind(s,3,b.grund.rawValue)
        if let stvId = b.stellvertretungRKId { sqlite3_bind_int64(s,4,stvId) }
        else { sqlite3_bind_null(s,4) }
        bindDate(s,5,b.erwarteteRueckgabe); bindDate(s,6,b.datumRueckgabe)
        sqlite3_bind_int(s,7,b.poolEingetragen ? 1 : 0)
        bind(s,8,b.notizen); sqlite3_bind_int64(s,9,b.id)
        sqlite3_step(s)
    }

    func rueckgabeEintragen(bewegungId: Int64, datum: Date = Date()) {
        let ds = DateFormatter.iso8601Date.string(from: datum)
        exec("UPDATE bewegungen SET datum_rueckgabe='\(ds)' WHERE id=\(bewegungId)")
    }

    func deleteBewegung(id: Int64) { exec("DELETE FROM bewegungen WHERE id=\(id)") }
}
