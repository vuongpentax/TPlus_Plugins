# VGD_Cabinet

Read CODEX_HANDOFF.md before editing. Current source is cabinet_work; tests/generator/package/deploy are cabinet_dev.
- Communicate in Vietnamese. Keep the extension name VGD_Cabinet, namespace VGD_Cabinet, loader vgd_cabinet.rb.
- Preserve construction rules inherited from T+ Cabinet; the old handoff is an archive, not active runtime.
- Only deploy this Cabinet into SketchUp 2022. Explicit own-file whitelist; back up/retire only tplus_cabinet.rb. Do not modify other plugins, their data, or other SketchUp versions.
- Preserve read compatibility with TPlus_Cabinet model dictionaries. Write new cabinets/updates to VGD_Cabinet; do not migrate unrelated model objects.
- Presets belong in APPDATA/VGD/SketchUp/VGD_Cabinet/presets_v1.json. Atomic temporary file, backup, file lock; no preset JSON in installation/Preferences. Read T+ Preferences once when no new store exists.
- Create, update and rename are distinct. Reject collisions, including case-insensitive names. Do not reset saved presets on reload/reinstall.
- New defaults: ceiling strip 20; door perimeter/between/top gaps 0; drawer front perimeter gaps 0; drawer tier gap 25; cabinet tier gap 25.
- front_bevel/bevel_lip now affect doors only. drawer_bevel/drawer_bevel_lip are independent. Migrate legacy shared handles only if handle_split_v1 is absent.
- Pano khung gỗ models separate stiles, rails, real straight grooves and flat floating panels. No CNC/BOM scope. Panel dimensions include groove capture minus expansion clearance. Validate tiny openings and groove/frame thickness.
- Change UI through redesign_ui.cjs/menu.js/menu.css, regenerate HTML before packaging. ui_beta1 is a reference only.
- Run meaningful geometry/preset/DOM/payload/UI/deployment tests. Distinguish WASM/stubs from native SketchUp; file locking is simulated in WASI.
- Deliver RBZ and source ZIP with updated version/validation. Never claim native manifold, Undo or restart unless actually tested in SketchUp.
