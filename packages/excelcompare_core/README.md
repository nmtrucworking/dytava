# excelcompare_core — Pure Dart proof of concept

This is a **training prototype**, not the complete Flutter app. It implements *matched-cell* semantic comparison for only `IDENTIFIER`, `FREE_TEXT`, `DECIMAL`, `BOOLEAN`, `PERCENTAGE`, plus null kinds and the OCR review gate. It **does not** implement policy JSON compilation, Unicode NFC, date/time, money, unit quantity, key matching, Excel/CSV/JSON adapters, reports, encryption or Flutter UI. Do not report it as production validated.

## Setup

Requires a local Dart 3 SDK (Flutter includes Dart):

```sh
cd excelcompare_flutter_core
dart pub get
dart test
```

The current artifact has **not** been executed because this file-generation runtime has neither `dart` nor `flutter` installed; inspect and run tests locally before merging. Dependencies are declared in `pubspec.yaml` and should be locked on first successful `dart pub get`.

## Scope and behavior

- No numeric cast for identifiers; `00123` != `123` as strings, while numeric source `123` is unresolved when semantic identifier is required.
- Decimal input from a physical number uses `.` as its *storage lexeme*, while CSV text requires a per-source explicit separator; ambiguous text => unresolved.
- `10%` -> exact ratio `0.10` only with `percentSignIsScale: true`.
- Money/amounts use `Decimal`, not binary `double`.
- `EQUIVALENT` requires rule label, but the full policy digest / audit trace is not implemented in this PoC.
- SourceCell provenance fields are intentionally omitted here; production work must implement them before report generation.

Full semantic design: [Core spec](../../docs-dytava/project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md). Source wire contract: [Input 0.1.0 DRAFT](../../docs-dytava/specs/input/README.md); the PoC does not implement this complete contract.
