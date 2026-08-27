# PRIMALIS Asset Performance Intake Gate

> **[TESTING]** These budgets are provisional planning limits for catching obviously pathological assets. They are not universal industry rules or immutable game-design decisions. Actual Godot gameplay profiling is authoritative.

## Purpose and usage

The intake gate performs a read-only static inspection before production art multiplies across the project. It never decimates, compresses, resizes, strips, edits, re-exports, or rewrites an asset or its Godot import settings.

Run the project model scan:

```powershell
powershell -ExecutionPolicy Bypass -File tools\asset_audit.ps1 -All
```

Run one asset with an explicit category:

```powershell
powershell -ExecutionPolicy Bypass -File tools\asset_audit.ps1 -Asset "assets\path\example.glb" -Category HERO_BUILDING
```

Use `-Summary` for compact automation output. The latest detailed human and machine-readable reports overwrite `captures/audit/latest_asset_audit.txt` and `captures/audit/latest_asset_audit.json`; generated reports are ignored by Git.

## Development target

The development machine uses Intel Iris Xe integrated graphics at 1920×1080. Normal gameplay should approach 60 FPS where practical and remain at least 30 FPS under heavy gameplay. A static pass only indicates that an individual asset is within the initial planning envelope. Scene density, instances, draw calls, shader cost, transparency, lights, animation, physics, and other runtime systems still require measurement in the actual game.

## Category budgets

The source data is `tools/asset_budgets.json`. `target` means PASS at or below that value. Values above target are WARN unless they exceed the listed `fail` threshold. A blank fail threshold means the metric remains a warning and needs human approval rather than becoming an automatic technical failure.

| Category | LOD0 target | LOD0 fail above | LOD1 target | LOD2 target | Material target | Texture target | Disk target | Disk fail above |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GENERIC_BUILDING | 30,000 | 75,000 | 12,000 | 3,000 | 3 | 2K | 20 MiB | 60 MiB |
| HERO_BUILDING | 60,000 | 150,000 | 25,000 | 6,000 | 5 | 2K; 4K warns | 35 MiB | 100 MiB |
| VILLAGER | 20,000 | 50,000 | 8,000 | 2,500 | 2 | 2K | 20 MiB | 60 MiB |
| PRIMALIS | 80,000 | 200,000 | 35,000 | 10,000 | 6 | 2K preferred; 4K selective | 50 MiB | 150 MiB |
| TREE | 8,000 | 30,000 | 3,000 | 800 | 2 | 2K | 10 MiB | 30 MiB |
| VEGETATION | 2,000 | 10,000 | 800 | 200 | 1 | 2K | 5 MiB | 20 MiB |
| ROCK | 10,000 | 40,000 | 4,000 | 1,000 | 2 | 2K | 10 MiB | 40 MiB |
| PROP | 5,000 | 25,000 | 2,000 | 500 | 2 | 2K | 10 MiB | 40 MiB |
| ENEMY | 25,000 | 60,000 | 10,000 | 3,000 | 3 | 2K | 25 MiB | 75 MiB |
| BOSS | 100,000 | 250,000 | 45,000 | 12,000 | 8 | 4K | 60 MiB | 180 MiB |
| UNKNOWN | no numeric assumption | — | — | — | — | — | — | — |

`UNKNOWN` is deliberately valid. It receives general file, Git LFS, ledger, license, parser, naming, and path checks, plus a warning to assign an explicit configured category. The tool does not translate an unrecognized ledger word into a more specific performance category.

## Geometry and LOD expectations

The GLB parser reads glTF structure directly without launching Blender or importing the asset into Godot. Indexed triangle primitives use index count; non-indexed primitives use position-vertex count. `TRIANGLES`, `TRIANGLE_STRIP`, and `TRIANGLE_FAN` modes are handled according to glTF topology. Other primitive modes remain `UNKNOWN` rather than receiving an invented triangle count.

Repeated environment assets, characters, hero assets, enemies, and bosses normally need an authored LOD chain. Detection is conservative and uses explicit `LOD0`, `LOD1`, and `LOD2` patterns in mesh or node names. One label alone is not assumed to prove a complete chain. Tiny props may reasonably omit LODs. Missing collision names inside a GLB are informational because collision may live in a separate Godot scene.

## Textures and materials

The audit reads PNG, JPEG, WebP, and KTX2 headers without fully decoding images. It reports embedded/external byte size, dimensions, format, major PBR slots, and an **approximate uncompressed RGBA8 memory** value (`width × height × 4`). That estimate is intentionally not presented as exact runtime memory: mipmaps, GPU formats, compression, reuse, and import settings change the real cost.

2K is the normal texture target. Blanket 4K use is discouraged. A selective 4K texture on Primalis, a boss, or a hero building is a warning/approval case—not an automatic failure. Material targets are kept low because material count often increases draw-call and state-change pressure.

## Technical result versus shipping status

Each model receives `PASS`, `PASS WITH WARNINGS`, or `FAIL`. Objective corruption, severe configured-budget excess, or a required production binary missing Git LFS may fail the technical gate. Missing or unresolved license metadata normally warns and displays `BLOCK SHIPPING`; it does not pretend to be a legal conclusion.

`AI_PROCESSING_ALLOWED = UNKNOWN` means the asset must not be uploaded to an external AI service until permission is verified. The gate surfaces the recorded value and never infers permission.

The 14 existing `.tres` programmer-art materials reported by the broader project audit are not treated as 3D production models by this intake scan. Whether they eventually need ledger entries is a separate production-policy decision.

## Repository hygiene note

`art_source/.gdignore` is currently absent. Adding one is likely useful before Blender source files appear because it would prevent Godot from scanning non-runtime source art. This task leaves the structure unchanged; add the marker only as an explicit repository-policy decision.
