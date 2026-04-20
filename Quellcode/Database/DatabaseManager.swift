import SQLite3
import Foundation

// Swift-kompatibler Ersatz für das C-Makro SQLITE_TRANSIENT
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
        runMigrations()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    private func openDatabase() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ch.putzzentrale.schluessel")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let path = dir.appendingPathComponent("schluessel.sqlite")
        guard sqlite3_open(path.path, &db) == SQLITE_OK else {
            print("DB-Fehler: Öffnen fehlgeschlagen – \(path.path)")
            return
        }
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA journal_mode = WAL;")
    }

    private func createTables() {
        exec("""
        CREATE TABLE IF NOT EXISTS kunden (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT NOT NULL,
            adresse  TEXT DEFAULT '',
            objekt   TEXT DEFAULT '',
            status   TEXT NOT NULL DEFAULT 'aktiv',
            notizen  TEXT DEFAULT ''
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS putzfrauen (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT NOT NULL,
            telefon  TEXT DEFAULT '',
            email    TEXT DEFAULT '',
            status   TEXT NOT NULL DEFAULT 'aktiv',
            notizen  TEXT DEFAULT ''
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS schluessel (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            bezeichnung    TEXT NOT NULL,
            kunde_id       INTEGER NOT NULL,
            anzahl_kopien  INTEGER NOT NULL DEFAULT 1,
            notizen        TEXT DEFAULT '',
            verloren       INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (kunde_id) REFERENCES kunden(id)
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS bewegungen (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            schluessel_id        INTEGER NOT NULL,
            datum_abgang         TEXT NOT NULL,
            putzfrau_id          INTEGER NOT NULL,
            grund                TEXT NOT NULL,
            erwartete_rueckgabe  TEXT,
            datum_rueckgabe      TEXT,
            notizen              TEXT DEFAULT '',
            FOREIGN KEY (schluessel_id) REFERENCES schluessel(id),
            FOREIGN KEY (putzfrau_id)  REFERENCES putzfrauen(id)
        );
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY
        );
        """)
    }

    private func runMigrations() {
        // Platz für spätere Schema-Migrationen
    }

    // MARK: - Helpers

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK, let msg = errmsg {
            print("SQL-Fehler: \(String(cString: msg))\n→ \(sql.prefix(80))")
        }
        return rc == SQLITE_OK
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("Prepare-Fehler: \(sql.prefix(80))")
            return nil
        }
        return stmt
    }

    private func col(_ stmt: OpaquePointer?, _ idx: Int32) -> String {
        sqlite3_column_text(stmt, idx).map { String(cString: $0) } ?? ""
    }

    private func colDate(_ stmt: OpaquePointer?, _ idx: Int32) -> Date? {
        guard let t = sqlite3_column_text(stmt, idx).map({ String(cString: $0) }),
              !t.isEmpty else { return nil }
        return DateFormatter.iso8601Date.date(from: t)
    }

    private func colDateReq(_ stmt: OpaquePointer?, _ idx: Int32) -> Date {
        colDate(stmt, idx) ?? Date()
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
    }

    private func bindOptDate(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Date?) {
        if let d = value {
            bindText(stmt, idx, DateFormatter.iso8601Date.string(from: d))
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    // MARK: - Kunden

    func fetchKunden() -> [Kunde] {
        guard let stmt = prepare(
            "SELECT id, name, adresse, objekt, status, notizen FROM kunden ORDER BY name"
        ) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Kunde] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append(Kunde(
                id:      sqlite3_column_int64(stmt, 0),
                name:    col(stmt, 1),
                adresse: col(stmt, 2),
                objekt:  col(stmt, 3),
                status:  KundeStatus(rawValue: col(stmt, 4)) ?? .aktiv,
                notizen: col(stmt, 5)
            ))
        }
        return list
    }

    @discardableResult
    func insertKunde(_ k: Kunde) -> Int64 {
        guard let stmt = prepare(
            "INSERT INTO kunden (name, adresse, objekt, status, notizen) VALUES (?,?,?,?,?)"
        ) else { return -1 }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, k.name)
        bindText(stmt, 2, k.adresse)
        bindText(stmt, 3, k.objekt)
        bindText(stmt, 4, k.status.rawValue)
        bindText(stmt, 5, k.notizen)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func updateKunde(_ k: Kunde) {
        guard let stmt = prepare(
            "UPDATE kunden SET name=?, adresse=?, objekt=?, status=?, notizen=? WHERE id=?"
        ) else { return }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, k.name)
        bindText(stmt, 2, k.adresse)
        bindText(stmt, 3, k.objekt)
        bindText(stmt, 4, k.status.rawValue)
        bindText(stmt, 5, k.notizen)
        sqlite3_bind_int64(stmt, 6, k.id)
        sqlite3_step(stmt)
    }

    func deleteKunde(id: Int64) {
        exec("DELETE FROM kunden WHERE id = \(id)")
    }

    // MARK: - Putzfrauen

    func fetchPutzfrauen() -> [Putzfrau] {
        guard let stmt = prepare(
            "SELECT id, name, telefon, email, status, notizen FROM putzfrauen ORDER BY name"
        ) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Putzfrau] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append(Putzfrau(
                id:      sqlite3_column_int64(stmt, 0),
                name:    col(stmt, 1),
                telefon: col(stmt, 2),
                email:   col(stmt, 3),
                status:  PutzfrauStatus(rawValue: col(stmt, 4)) ?? .aktiv,
                notizen: col(stmt, 5)
            ))
        }
        return list
    }

    @discardableResult
    func insertPutzfrau(_ p: Putzfrau) -> Int64 {
        guard let stmt = prepare(
            "INSERT INTO putzfrauen (name, telefon, email, status, notizen) VALUES (?,?,?,?,?)"
        ) else { return -1 }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, p.name)
        bindText(stmt, 2, p.telefon)
        bindText(stmt, 3, p.email)
        bindText(stmt, 4, p.status.rawValue)
        bindText(stmt, 5, p.notizen)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func updatePutzfrau(_ p: Putzfrau) {
        guard let stmt = prepare(
            "UPDATE putzfrauen SET name=?, telefon=?, email=?, status=?, notizen=? WHERE id=?"
        ) else { return }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, p.name)
        bindText(stmt, 2, p.telefon)
        bindText(stmt, 3, p.email)
        bindText(stmt, 4, p.status.rawValue)
        bindText(stmt, 5, p.notizen)
        sqlite3_bind_int64(stmt, 6, p.id)
        sqlite3_step(stmt)
    }

    func deletePutzfrau(id: Int64) {
        exec("DELETE FROM putzfrauen WHERE id = \(id)")
    }

    // MARK: - Schlüssel

    func fetchSchluessel(kundeId: Int64? = nil) -> [Schluessel] {
        let sql: String
        if let kid = kundeId {
            sql = """
            SELECT id, bezeichnung, kunde_id, anzahl_kopien, notizen, verloren
            FROM schluessel WHERE kunde_id = \(kid) ORDER BY bezeichnung
            """
        } else {
            sql = """
            SELECT id, bezeichnung, kunde_id, anzahl_kopien, notizen, verloren
            FROM schluessel ORDER BY bezeichnung
            """
        }
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Schluessel] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append(Schluessel(
                id:           sqlite3_column_int64(stmt, 0),
                bezeichnung:  col(stmt, 1),
                kundeId:      sqlite3_column_int64(stmt, 2),
                anzahlKopien: Int(sqlite3_column_int(stmt, 3)),
                notizen:      col(stmt, 4),
                verloren:     sqlite3_column_int(stmt, 5) != 0
            ))
        }
        return list
    }

    @discardableResult
    func insertSchluessel(_ s: Schluessel) -> Int64 {
        guard let stmt = prepare(
            "INSERT INTO schluessel (bezeichnung, kunde_id, anzahl_kopien, notizen, verloren) VALUES (?,?,?,?,?)"
        ) else { return -1 }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, s.bezeichnung)
        sqlite3_bind_int64(stmt, 2, s.kundeId)
        sqlite3_bind_int(stmt, 3, Int32(s.anzahlKopien))
        bindText(stmt, 4, s.notizen)
        sqlite3_bind_int(stmt, 5, s.verloren ? 1 : 0)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func updateSchluessel(_ s: Schluessel) {
        guard let stmt = prepare(
            "UPDATE schluessel SET bezeichnung=?, kunde_id=?, anzahl_kopien=?, notizen=?, verloren=? WHERE id=?"
        ) else { return }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, s.bezeichnung)
        sqlite3_bind_int64(stmt, 2, s.kundeId)
        sqlite3_bind_int(stmt, 3, Int32(s.anzahlKopien))
        bindText(stmt, 4, s.notizen)
        sqlite3_bind_int(stmt, 5, s.verloren ? 1 : 0)
        sqlite3_bind_int64(stmt, 6, s.id)
        sqlite3_step(stmt)
    }

    func deleteSchluessel(id: Int64) {
        exec("DELETE FROM schluessel WHERE id = \(id)")
    }

    // MARK: - Bewegungen

    private func bewegungRow(_ stmt: OpaquePointer?) -> Bewegung {
        Bewegung(
            id:                  sqlite3_column_int64(stmt, 0),
            schluesselId:        sqlite3_column_int64(stmt, 1),
            datumAbgang:         colDateReq(stmt, 2),
            putzfrauId:          sqlite3_column_int64(stmt, 3),
            grund:               BewegungGrund(rawValue: col(stmt, 4)) ?? .sonstiges,
            erwarteteRueckgabe:  colDate(stmt, 5),
            datumRueckgabe:      colDate(stmt, 6),
            notizen:             col(stmt, 7)
        )
    }

    private let bewegungSelect = """
        SELECT id, schluessel_id, datum_abgang, putzfrau_id,
               grund, erwartete_rueckgabe, datum_rueckgabe, notizen
        FROM bewegungen
        """

    func fetchBewegungen(schluesselId: Int64? = nil) -> [Bewegung] {
        let sql: String
        if let sid = schluesselId {
            sql = bewegungSelect + " WHERE schluessel_id = \(sid) ORDER BY datum_abgang DESC"
        } else {
            sql = bewegungSelect + " ORDER BY datum_abgang DESC"
        }
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Bewegung] = []
        while sqlite3_step(stmt) == SQLITE_ROW { list.append(bewegungRow(stmt)) }
        return list
    }

    func fetchOffeneBewegungen() -> [Bewegung] {
        let sql = bewegungSelect + """
             WHERE (datum_rueckgabe IS NULL OR datum_rueckgabe = '')
             ORDER BY erwartete_rueckgabe ASC
            """
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Bewegung] = []
        while sqlite3_step(stmt) == SQLITE_ROW { list.append(bewegungRow(stmt)) }
        return list
    }

    func fetchAktiveBewegung(schluesselId: Int64) -> Bewegung? {
        let sql = bewegungSelect + """
             WHERE schluessel_id = \(schluesselId)
               AND (datum_rueckgabe IS NULL OR datum_rueckgabe = '')
             ORDER BY datum_abgang DESC LIMIT 1
            """
        guard let stmt = prepare(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? bewegungRow(stmt) : nil
    }

    func fetchBewegungen(putzfrauId: Int64, nurOffen: Bool = false) -> [Bewegung] {
        var sql = bewegungSelect + " WHERE putzfrau_id = \(putzfrauId)"
        if nurOffen { sql += " AND (datum_rueckgabe IS NULL OR datum_rueckgabe = '')" }
        sql += " ORDER BY datum_abgang DESC"
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var list: [Bewegung] = []
        while sqlite3_step(stmt) == SQLITE_ROW { list.append(bewegungRow(stmt)) }
        return list
    }

    @discardableResult
    func insertBewegung(_ b: Bewegung) -> Int64 {
        guard let stmt = prepare("""
            INSERT INTO bewegungen
            (schluessel_id, datum_abgang, putzfrau_id, grund,
             erwartete_rueckgabe, datum_rueckgabe, notizen)
            VALUES (?,?,?,?,?,?,?)
            """) else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, b.schluesselId)
        bindText(stmt, 2, DateFormatter.iso8601Date.string(from: b.datumAbgang))
        sqlite3_bind_int64(stmt, 3, b.putzfrauId)
        bindText(stmt, 4, b.grund.rawValue)
        bindOptDate(stmt, 5, b.erwarteteRueckgabe)
        bindOptDate(stmt, 6, b.datumRueckgabe)
        bindText(stmt, 7, b.notizen)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func updateBewegung(_ b: Bewegung) {
        guard let stmt = prepare("""
            UPDATE bewegungen SET
              schluessel_id=?, datum_abgang=?, putzfrau_id=?, grund=?,
              erwartete_rueckgabe=?, datum_rueckgabe=?, notizen=?
            WHERE id=?
            """) else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, b.schluesselId)
        bindText(stmt, 2, DateFormatter.iso8601Date.string(from: b.datumAbgang))
        sqlite3_bind_int64(stmt, 3, b.putzfrauId)
        bindText(stmt, 4, b.grund.rawValue)
        bindOptDate(stmt, 5, b.erwarteteRueckgabe)
        bindOptDate(stmt, 6, b.datumRueckgabe)
        bindText(stmt, 7, b.notizen)
        sqlite3_bind_int64(stmt, 8, b.id)
        sqlite3_step(stmt)
    }

    func rueckgabeEintragen(bewegungId: Int64, datum: Date = Date()) {
        let ds = DateFormatter.iso8601Date.string(from: datum)
        exec("UPDATE bewegungen SET datum_rueckgabe = '\(ds)' WHERE id = \(bewegungId)")
    }

    func deleteBewegung(id: Int64) {
        exec("DELETE FROM bewegungen WHERE id = \(id)")
    }

    // MARK: - Statistiken

    func anzahlOffeneBewegungen() -> Int {
        guard let stmt = prepare(
            "SELECT COUNT(*) FROM bewegungen WHERE datum_rueckgabe IS NULL OR datum_rueckgabe = ''"
        ) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }
}
