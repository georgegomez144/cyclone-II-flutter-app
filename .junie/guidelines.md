# Project Guidelines

## Versioning and pubspec.yaml updates

Every change to this repository must be accompanied by a version update in pubspec.yaml.

Rules:
- Update only the semantic version portion before the plus sign (x.y.z), never the build metadata after the plus (+).
- Follow semantic versioning semantics:
    - Major (X.y.z): Increase when introducing significant or potentially backward-incompatible changes.
    - Minor (x.Y.z): Increase when adding new, backward-compatible features or a set of smaller features.
    - Patch (x.y.Z): Increase for bug fixes, small improvements, or internal changes that don’t add features.

Checklist before merging any change:
- [ ] Decide the impact level: breaking change (Major), feature (Minor), fix/chore (Patch).
- [ ] Edit pubspec.yaml version: bump x.y.z accordingly; do not modify the number after "+".
- [ ] Ensure changelog/commit message reflects the chosen version bump.

## Code organization
- Create small file sizes; prefer splitting large files into smaller, focused modules.
- Use widgets as separate files and import them rather than defining many widgets in a single file.
- file imports should use the package: syntax and not relative imports

## Structure
- use clean architecture
- look for bottle-necks and fix for faster app loads and runtimes
- keep all content centered for tablet and web
