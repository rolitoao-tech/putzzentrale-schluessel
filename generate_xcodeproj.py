#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Generiert das Xcode-Projekt für Putzzentrale Schlüsselverwaltung

import uuid, os

BASE_DIR          = "/Users/roli/Desktop/Claude Code/Putzzentrale - Schlüsselverwaltung"
APP_NAME          = "Schlüsselverwaltung"
BUNDLE_ID         = "ch.putzzentrale.schluessel"
DEPLOYMENT_TARGET = "13.0"
XCODEPROJ_DIR     = os.path.join(BASE_DIR, f"{APP_NAME}.xcodeproj")

def new_id():
    return uuid.uuid4().hex[:24].upper()

# Alle Quelldateien (Name, Pfad relativ zu Quellcode-Gruppe)
SOURCE_FILES = [
    ("PutzentraleApp",           "PutzentraleApp.swift"),
    ("ContentView",              "ContentView.swift"),
    ("DateFormatters",           "Utilities/DateFormatters.swift"),
    ("Kunde",                    "Models/Kunde.swift"),
    ("Reinigungskraft",          "Models/Reinigungskraft.swift"),
    ("Bewegung",                 "Models/Bewegung.swift"),
    ("DatabaseManager",          "Database/DatabaseManager.swift"),
    ("AppViewModel",             "ViewModels/AppViewModel.swift"),
    ("DashboardView",            "Views/DashboardView.swift"),
    ("SchluesselUebersichtView", "Views/SchluesselUebersichtView.swift"),
    ("BewegungErfassenView",     "Views/BewegungErfassenView.swift"),
    ("EinstellungenView",        "Views/EinstellungenView.swift"),
    ("ReinigungskraefteView",    "Views/Stammdaten/ReinigungskraefteView.swift"),
    ("ErinnerungsService",       "Services/ErinnerungsService.swift"),
]

# UUIDs erzeugen
P   = {n: new_id() for n in [
    "proj", "target", "main_grp", "quellcode_grp", "products_grp", "frameworks_grp",
    "models_grp", "utilities_grp", "database_grp", "viewmodels_grp",
    "views_grp", "stammdaten_grp", "services_grp",
    "app_ref", "infoplist_ref", "entitlements_ref",
    "eventkit_ref", "eventkit_build",
    "assets_ref", "assets_build",
    "sources_phase", "frameworks_phase", "resources_phase",
    "proj_debug", "proj_release", "tgt_debug", "tgt_release",
    "proj_cfglist", "tgt_cfglist",
]}
F = {name: (new_id(), new_id()) for name, _ in SOURCE_FILES}  # name -> (fileref, buildfile)

src_dict = dict(SOURCE_FILES)

def pbxproj():
    L = []
    def w(*args): L.append("\t\t" + " ".join(str(a) for a in args))

    L.append("// !$*UTF8*$!")
    L.append("{")
    L.append("\tarchiveVersion = 1;")
    L.append("\tclasses = {")
    L.append("\t};")
    L.append("\tobjectVersion = 56;")
    L.append("\tobjects = {")
    L.append("")

    # --- PBXBuildFile ---
    L.append("/* Begin PBXBuildFile section */")
    w(P["eventkit_build"], "/* EventKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef =", P["eventkit_ref"], "/* EventKit.framework */; };")
    w(P["assets_build"], "/* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef =", P["assets_ref"], "/* Assets.xcassets */; };")
    for name, path in SOURCE_FILES:
        fname = os.path.basename(path)
        fref, fbuild = F[name]
        w(fbuild, f"/* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef =", fref, f"/* {fname} */; }};")
    L.append("/* End PBXBuildFile section */")
    L.append("")

    # --- PBXFileReference ---
    L.append("/* Begin PBXFileReference section */")
    w(P["app_ref"], f'/* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "{APP_NAME}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w(P["eventkit_ref"], "/* EventKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = EventKit.framework; path = System/Library/Frameworks/EventKit.framework; sourceTree = SDKROOT; };")
    w(P["assets_ref"], '/* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };')
    w(P["infoplist_ref"], '/* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };')
    w(P["entitlements_ref"], f'/* {APP_NAME}.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "{APP_NAME}.entitlements"; sourceTree = "<group>"; }};')
    for name, path in SOURCE_FILES:
        fname = os.path.basename(path)
        fref, _ = F[name]
        w(fref, f'/* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};')
    L.append("/* End PBXFileReference section */")
    L.append("")

    # --- PBXFrameworksBuildPhase ---
    L.append("/* Begin PBXFrameworksBuildPhase section */")
    L.append(f"\t\t{P['frameworks_phase']} /* Frameworks */ = {{")
    L.append("\t\t\tisa = PBXFrameworksBuildPhase; buildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    L.append(f"\t\t\t\t{P['eventkit_build']} /* EventKit.framework in Frameworks */,")
    L.append("\t\t\t); runOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXFrameworksBuildPhase section */")
    L.append("")

    # --- PBXGroup ---
    L.append("/* Begin PBXGroup section */")

    def group(gid, name, path, children_lines):
        L.append(f"\t\t{gid} /* {name} */ = {{")
        L.append("\t\t\tisa = PBXGroup;")
        L.append("\t\t\tchildren = (")
        for c in children_lines: L.append(f"\t\t\t\t{c}")
        L.append("\t\t\t);")
        if name: L.append(f'\t\t\tname = "{name}";')
        if path: L.append(f'\t\t\tpath = "{path}";')
        L.append('\t\t\tsourceTree = "<group>";')
        L.append("\t\t};")

    group(P["main_grp"], "", "",
          [f'{P["quellcode_grp"]} /* Quellcode */,',
           f'{P["frameworks_grp"]} /* Frameworks */,',
           f'{P["products_grp"]} /* Products */,'])

    group(P["products_grp"], "Products", "",
          [f'{P["app_ref"]} /* {APP_NAME}.app */,'])

    group(P["frameworks_grp"], "Frameworks", "",
          [f'{P["eventkit_ref"]} /* EventKit.framework */,'])

    root_files = [f'{F[n][0]} /* {os.path.basename(src_dict[n])} */,' for n in ["PutzentraleApp","ContentView"]]
    group(P["quellcode_grp"], "Quellcode", "Quellcode",
          root_files + [
              f'{P["models_grp"]} /* Models */,',
              f'{P["utilities_grp"]} /* Utilities */,',
              f'{P["database_grp"]} /* Database */,',
              f'{P["viewmodels_grp"]} /* ViewModels */,',
              f'{P["views_grp"]} /* Views */,',
              f'{P["services_grp"]} /* Services */,',
              f'{P["assets_ref"]} /* Assets.xcassets */,',
              f'{P["infoplist_ref"]} /* Info.plist */,',
              f'{P["entitlements_ref"]} /* {APP_NAME}.entitlements */,',
          ])

    group(P["models_grp"], "Models", "Models",
          [f'{F[n][0]} /* {os.path.basename(src_dict[n])} */,' for n in ["Kunde","Reinigungskraft","Bewegung"]])

    group(P["utilities_grp"], "Utilities", "Utilities",
          [f'{F["DateFormatters"][0]} /* DateFormatters.swift */,'])

    group(P["database_grp"], "Database", "Database",
          [f'{F["DatabaseManager"][0]} /* DatabaseManager.swift */,'])

    group(P["viewmodels_grp"], "ViewModels", "ViewModels",
          [f'{F["AppViewModel"][0]} /* AppViewModel.swift */,'])

    view_names = ["DashboardView","SchluesselUebersichtView","BewegungErfassenView","EinstellungenView"]
    group(P["views_grp"], "Views", "Views",
          [f'{F[n][0]} /* {os.path.basename(src_dict[n])} */,' for n in view_names] +
          [f'{P["stammdaten_grp"]} /* Stammdaten */,'])

    group(P["stammdaten_grp"], "Stammdaten", "Stammdaten",
          [f'{F[n][0]} /* {os.path.basename(src_dict[n])} */,' for n in ["ReinigungskraefteView"]])

    group(P["services_grp"], "Services", "Services",
          [f'{F["ErinnerungsService"][0]} /* ErinnerungsService.swift */,'])

    L.append("/* End PBXGroup section */")
    L.append("")

    # --- PBXNativeTarget ---
    L.append("/* Begin PBXNativeTarget section */")
    L.append(f'\t\t{P["target"]} /* {APP_NAME} */ = {{')
    L.append(f'\t\t\tisa = PBXNativeTarget;')
    L.append(f'\t\t\tbuildConfigurationList = {P["tgt_cfglist"]} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */;')
    L.append(f'\t\t\tbuildPhases = ({P["sources_phase"]} /* Sources */, {P["frameworks_phase"]} /* Frameworks */, {P["resources_phase"]} /* Resources */,);')
    L.append(f'\t\t\tbuildRules = (); dependencies = ();')
    L.append(f'\t\t\tname = "{APP_NAME}"; productName = "{APP_NAME}";')
    L.append(f'\t\t\tproductReference = {P["app_ref"]} /* {APP_NAME}.app */;')
    L.append(f'\t\t\tproductType = "com.apple.product-type.application";')
    L.append("\t\t};")
    L.append("/* End PBXNativeTarget section */")
    L.append("")

    # --- PBXProject ---
    L.append("/* Begin PBXProject section */")
    L.append(f'\t\t{P["proj"]} /* Project object */ = {{')
    L.append(f'\t\t\tisa = PBXProject;')
    L.append(f'\t\t\tattributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; TargetAttributes = {{ {P["target"]} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }};')
    L.append(f'\t\t\tbuildConfigurationList = {P["proj_cfglist"]} /* Build configuration list for PBXProject "{APP_NAME}" */;')
    L.append(f'\t\t\tcompatibilityVersion = "Xcode 15.0";')
    L.append(f'\t\t\tdevelopmentRegion = de;')
    L.append(f'\t\t\thasScannedForEncodings = 0;')
    L.append(f'\t\t\tknownRegions = (de, Base,);')
    L.append(f'\t\t\tmainGroup = {P["main_grp"]};')
    L.append(f'\t\t\tproductRefGroup = {P["products_grp"]} /* Products */;')
    L.append(f'\t\t\tprojectDirPath = ""; projectRoot = "";')
    L.append(f'\t\t\ttargets = ({P["target"]} /* {APP_NAME} */,);')
    L.append("\t\t};")
    L.append("/* End PBXProject section */")
    L.append("")

    # --- PBXResourcesBuildPhase ---
    L.append("/* Begin PBXResourcesBuildPhase section */")
    L.append(f'\t\t{P["resources_phase"]} /* Resources */ = {{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({P["assets_build"]} /* Assets.xcassets in Resources */,); runOnlyForDeploymentPostprocessing = 0; }};')
    L.append("/* End PBXResourcesBuildPhase section */")
    L.append("")

    # --- PBXSourcesBuildPhase ---
    L.append("/* Begin PBXSourcesBuildPhase section */")
    L.append(f'\t\t{P["sources_phase"]} /* Sources */ = {{')
    L.append("\t\t\tisa = PBXSourcesBuildPhase; buildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    for name, path in SOURCE_FILES:
        _, fbuild = F[name]
        fname = os.path.basename(path)
        L.append(f"\t\t\t\t{fbuild} /* {fname} in Sources */,")
    L.append("\t\t\t); runOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXSourcesBuildPhase section */")
    L.append("")

    # --- XCBuildConfiguration ---
    L.append("/* Begin XCBuildConfiguration section */")

    def cfg(cfg_id, name, settings):
        L.append(f"\t\t{cfg_id} /* {name} */ = {{")
        L.append("\t\t\tisa = XCBuildConfiguration;")
        L.append("\t\t\tbuildSettings = {")
        for k, v in settings.items():
            L.append(f"\t\t\t\t{k} = {v};")
        L.append("\t\t\t};")
        L.append(f"\t\t\tname = {name};")
        L.append("\t\t};")

    base = {"MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET, "SWIFT_VERSION": "5.0", "ALWAYS_SEARCH_USER_PATHS": "NO"}

    cfg(P["proj_debug"],   "Debug",   {**base})
    cfg(P["proj_release"], "Release", {**base})

    tgt_settings = {
        **base,
        "CODE_SIGN_ENTITLEMENTS":   f'"Quellcode/{APP_NAME}.entitlements"',
        "CODE_SIGN_STYLE":          "Automatic",
        "COMBINE_HIDPI_IMAGES":     "YES",
        "INFOPLIST_FILE":           '"Quellcode/Info.plist"',
        "PRODUCT_BUNDLE_IDENTIFIER": f'"{BUNDLE_ID}"',
        "PRODUCT_NAME":             f'"{APP_NAME}"',
        "SWIFT_EMIT_LOC_STRINGS":   "YES",
        "ASSETCATALOG_COMPILER_APPICON_NAME": '"AppIcon"',
    }
    cfg(P["tgt_debug"],   "Debug",   {**tgt_settings, "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"', "DEBUG_INFORMATION_FORMAT": "dwarf"})
    cfg(P["tgt_release"], "Release", {**tgt_settings})

    L.append("/* End XCBuildConfiguration section */")
    L.append("")

    # --- XCConfigurationList ---
    L.append("/* Begin XCConfigurationList section */")
    L.append(f'\t\t{P["proj_cfglist"]} /* Build configuration list for PBXProject "{APP_NAME}" */ = {{ isa = XCConfigurationList; buildConfigurations = ({P["proj_debug"]} /* Debug */, {P["proj_release"]} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
    L.append(f'\t\t{P["tgt_cfglist"]} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */ = {{ isa = XCConfigurationList; buildConfigurations = ({P["tgt_debug"]} /* Debug */, {P["tgt_release"]} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
    L.append("/* End XCConfigurationList section */")
    L.append("")

    L.append("\t};")
    L.append(f'\trootObject = {P["proj"]} /* Project object */;')
    L.append("}")
    return "\n".join(L)


def main():
    os.makedirs(XCODEPROJ_DIR, exist_ok=True)

    pbx_path = os.path.join(XCODEPROJ_DIR, "project.pbxproj")
    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(pbxproj())
    print(f"✓ project.pbxproj")

    ws_dir = os.path.join(XCODEPROJ_DIR, "project.xcworkspace")
    os.makedirs(ws_dir, exist_ok=True)
    with open(os.path.join(ws_dir, "contents.xcworkspacedata"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version = "1.0"><FileRef location = "self:"></FileRef></Workspace>')
    print(f"✓ xcworkspace")

    print(f"\n✓ Projekt bereit: {XCODEPROJ_DIR}")


if __name__ == "__main__":
    main()
