# Extended Leasing

Extended Leasing is a Farming Simulator 25 mod that adjusts lease behavior to support longer terms, softer payment pressure, and more flexible contract logic.

## Features

- Softens lease financing by applying configurable payment and duration modifiers
- Caps longer lease terms to keep games readable and predictable
- Adds a small amount of runtime logging for debugging lease contracts
- Keeps the mod compatible with a standard FS25 mod structure and build pipeline

## Project structure

- `FS25_Src/` — source files bundled into the final zip
- `docs/` — implementation notes and planning
- `build.ps1` / `build.sh` — local zip build scripts

## Build

Windows:

```powershell
.\build.ps1 build
```

Linux/macOS:

```bash
./build.sh build
```

The build script creates a distributable zip under the `dist/` folder.

## Notes

This mod is intentionally written as a clean extension point for future gameplay tuning. The lease logic is implemented through patchable hooks so it can be adapted to later game updates without a large rewrite.
