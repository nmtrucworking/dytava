# ExcelCompare — DataType, Semantic Normalization & Policy Engine (Flutter/Dart)

> Ranh giới sau khi tách Input: physical types/provenance/raw lexical thuộc [Input 0.1.0 DRAFT](../../specs/input/README.md); tài liệu này giữ canonicalization, policy compiler, key matching và comparison. Ví dụ policy v2 chuẩn: [project policy](../comparison_policy.v2.example.json). Dart PoC hiện tại chưa triển khai đầy đủ wire contract này.

**Trạng thái:** 2.2.0-FLUTTER-ANDROID-IOS-DESIGN | **Ngày cập nhật:** 11/11/2026 | **Nền tảng phát hành:** Flutter mobile — Android P0 (APK/AAB) rồi iPhone/iOS P1 (IPA); web/desktop ngoài phạm vi | **Policy JSON:** schema 2 (giữ tương thích)

> Đây là tài liệu thiết kế Flutter/Dart. Không phải bằng chứng ứng dụng Flutter hoặc bộ quy tắc đã đạt chuẩn production. Giai đoạn đầu ưu tiên học Flutter/Dart; các adapter và OCR triển khai theo gate ở giai đoạn tiếp theo.

## 5.1. Mục tiêu và các invariant

Mọi `matched cell pair` trả đúng một trạng thái `EXACT`, `EQUIVALENT`, `DIFFERENT`, `UNRESOLVED`. Structural differences, added/removed rows và unmatched fields **không** cộng vào mẫu số matched cell pairs. Không sửa tệp nguồn; không tự dùng inference confidence để kết luận; không auto-cast identifier; không tự đoán locale, đơn vị, tỷ giá hay múi giờ. `EQUIVALENT` yêu cầu `rule_id`, `rule_version`, canonical left/right, transformation trace và policy digest. Mơ hồ/trục trặc parse thành `UNRESOLVED` có reason_code, không tự fallback so chuỗi.

## 5.2. Hợp đồng kiểu dữ liệu (Dart)

| Tầng | Loại dữ liệu | Trách nhiệm |
|---|---|---|
| Physical | [INP-005](../../specs/input/05_data_types_provenance.md) và [SourceCell schema](../../specs/input/schemas/source_cell.schema.json) | Contract source types, raw/null/formula/provenance thuộc Input; Core không định nghĩa lại wire shape. |
| Logical | `String`, `BigInt`, `Decimal`, `bool`, date-only ISO string, instant/offset-typed datetime, array/object tagged structure | Dùng BigInt và Decimal; `DateTime` của Dart dùng cho instant có timezone đã giải quyết, không coi là thay thế cho `LocalDate` hoặc zone ID. |
| Semantic | `IDENTIFIER`, `POSTAL_CODE`, `FREE_TEXT`, `PERSON_NAME`, `INTEGER`, `DECIMAL`, `MONEY`, `PERCENTAGE`, `BOOLEAN`, `DATE`, `DATETIME`, `PHONE`, `EMAIL`, `ENUM`, `UNIT_QUANTITY` | Field rule xác nhận nghĩa; dtype inference chỉ là gợi ý. |
| Normalization | Unicode NFC; trim; case; alias; decimal/grouping separators; date patterns; timezone; unit/currency; null policy; tolerance | Versioned, strict, có trace. Dart core **không cung cấp API NFC phổ dụng**: chọn thư viện đã kiểm chứng hoặc adapter verified; không tự khẳng định đã chuẩn hóa NFC. |

SourceCell wire contract được định nghĩa duy nhất tại [INP-005](../../specs/input/05_data_types_provenance.md). `CanonicalValue` vẫn thuộc Core: TextValue, IntegerValue(BigInt), DecimalValue(Decimal), BoolValue, DateValue, InstantValue, ZonedLocalDateTimeValue, MoneyValue, PercentageValue, QuantityValue, EnumValue, NullValue và ComplexValue theo capability. Core mapping phải bảo toàn source_ref và losses, không thay SourceCell bằng canonical value.

**Precision:** Không dùng `double` để so sánh/parse tiền, phần trăm, số chính xác. Dùng `package:decimal` ở Dart, `BigInt` cho số nguyên; serialize canonical decimal thành chuỗi. Không dùng `num.parse` để biến đổi dữ liệu tài chính. Strict typed compare chỉ chạy sau validation.

## 5.3. Bảng quy tắc chuẩn hóa

| Semantic dtype | Canonical | Chính sách bắt buộc / mặc định |
|---|---|---|
| IDENTIFIER, POSTAL_CODE | NFC text | Không bỏ zero đầu; không numeric cast; case-sensitive mặc định; giữ lexical representation. |
| FREE_TEXT, PERSON_NAME | NFC text | Trim theo field; không bỏ dấu / phiên âm / fuzzy match. Tên pháp lý không tự đồng nhất `Nguyen` với `Nguyễn`. |
| INTEGER | BigInt | Parse locale/nhóm số strict, cấm truncate số thập phân. |
| DECIMAL | Decimal | Decimal/grouping separators theo từng nguồn; `ignore_scale`, `tolerance_abs` theo field, không dùng cho keys. |
| MONEY | `{currency, amount: Decimal}` | Chỉ so khi cùng currency; FX yêu cầu snapshot/rate/time/source rõ ràng, không mặc định. |
| PERCENTAGE | Decimal ratio | `10%` -> `0.1` chỉ khi `percent_sign_is_scale=true`; số `10` không mặc định là 10%. |
| BOOLEAN | bool | `1/0`, `Có/Không` chỉ qua alias có phiên bản, tránh alias collision. |
| DATE | ISO date-only string | Format/pivot năm 2 chữ số explicit; serial 1900/1904 cần adapter khai báo, Excel serial 60 unresolved. |
| DATETIME | UTC instant hoặc zoned-local tagged | Offset/zone ID; DST overlap/gap phải xử lý explicit; khác ngày lịch địa phương không tự triệt tiêu. |
| PHONE | E.164 khi đủ region, hoặc tagged raw | Không mặc định bỏ `0` đầu; region missing -> unresolved. |
| EMAIL | local-part nguyên dạng + domain IDNA | Domain lowercase theo IDNA; không lowercase toàn email, không xóa plus/dots. |
| ENUM | stable code | Dictionary versioned; many-to-one alias phải được duyệt, không mơ hồ. |
| UNIT_QUANTITY | Decimal + dimension + unit | Chỉ đổi cùng dimension bằng bảng rule/version; affine conversion (độ C/F) cần công thức riêng. |
| NULL kinds | `MISSING`, `BLANK`, `EMPTY_STRING`, `JSON_NULL`, `EXCEL_ERROR`, `TEXT_SENTINEL` | Tách `0`, `false`, null và string rỗng; chỉ gộp bằng mapping được xác nhận. |

## 5.4. Pipeline chuẩn hóa

```text
Input source adapters (read-only)
    -> preview/profile + explicit field mapping
    -> compile/validate policy v2 (fail-closed)
    -> consume validated physical kind + provenance from Input
    -> resolve null kind / OCR review gate
    -> strict source-specific parse
    -> semantic transform
    -> immutable CanonicalValue + TraceStep[]
    -> record alignment (strict keys) + typed comparison
    -> EXACT | EQUIVALENT | DIFFERENT | UNRESOLVED
    -> report manifest + audit provenance
```

`NormalizeResult = Success(CanonicalValue, TraceStep[]) | Unresolved(reasonCode, remediation, evidenceMetadata)`. A/B raw values và canonical values chỉ xuất vào report khi người dùng lựa chọn; không đưa vào analytics/telemetry. `TraceStep = {ruleId, ruleVersion, operation, inputKind, outputKind, parametersDigest}`.

## 5.5. Policy schema v2 — vẫn độc lập nền tảng

Top-level fields: `schema_version`, `policy_id`, `policy_version`, `canonical_serializer_version`, `defaults`, `alignment`, `source_profiles`, `fields`, `unresolved_handling`, `auto_cast_all_fields`.

Precedence: `engine conservative defaults < policy.defaults < field-level semantic/comparison rules < A/B source_overrides (parse only)`. Cấm arbitrary scripts/code trong JSON. `schema_version=2` mô tả cấu trúc policy, **không tự tăng schema version chỉ vì đổi framework**; các thay đổi quy tắc phải tăng `policy_version` và `engine_version`.

Policy compiler trong Dart phải kiểm tra: unknown schema keys/unknown rule operations => reject; mapping 1:1 & logical names unique; keys exist, strict identifier, không tolerance/fuzzy; `tolerance_abs >= 0`; nguồn `decimal_separator` khác `grouping_separator`; grouping không được bật im lặng; aliases không trùng; locale/date/year pivot explicit; zone/FX/unit phù hợp; OCR critical cell bắt buộc confirmed; engine capabilities cho các dtype hiện dùng. Trong bản demo lõi Dart đi kèm chỉ có 5 semantic types đã triển khai: IDENTIFIER, FREE_TEXT, DECIMAL, BOOLEAN, PERCENTAGE; còn lại fail-closed, không tuyên bố hỗ trợ runtime.

**Digest**: `SHA-256(canonicalSerialize(effectivePolicy + dictionaryVersions + parserVersions))`, UTF-8, deterministic key ordering, explicit canonical serializer version; đưa `policy_digest`, `engine_version`, adapter versions và source SHA-256 vào report manifest. Generated-at không thuộc semantic digest. Phải xác nhận parity digest giữa các runtime bằng golden fixtures.

## 5.6. Quy tắc phân loại và matching

Thứ tự: 1) structural/mapping/row alignment unresolved → 2) policy/parse/OCR unresolved → 3) strict same physical+lexical+typed value ⇒ `EXACT` → 4) canonical semantic equality (hoặc tolerance đã được phê duyệt) ⇒ `EQUIVALENT` + evidence → 5) valid canonical inequality ⇒ `DIFFERENT`. Exact storage mode và semantic mode phải được mô tả trên UI để tránh nhầm lẫn. `TYPE_CHANGED`, `FORMULA_CHANGED`, `STYLE_CHANGED`, `OCR_REVIEWED` là flags riêng.

`KEY`: canonical identifier theo tagged tuple, đảm bảo uniqueness; duplicate/null/ambiguous key thành bucket unresolved; không arbitrary first-match. `POSITION`: theo tọa độ đã align; `MULTISET`: typed canonical fingerprint + verify equality khi trùng hash; `ORDERED_SEQUENCE`: có time/memory caps. Tolerance có thể không bắc cầu, tuyệt đối không dùng cho key join hoặc multiset fingerprints.

## 5.7. Reason codes

| Code | Điều kiện | Hướng xử lý |
|---|---|---|
| LOCALE_AMBIGUOUS | Số `1,234` không rõ cách đọc | Chọn định dạng nguồn. |
| PARSE_FAILED | Không parse theo rule strict | Xem raw/display và sửa field rule. |
| MISSING_POLICY | Field chưa được gán dtype | Confirm mapping và dtype. |
| INVALID_POLICY | Rule xung đột / unknown key | Chỉnh cấu hình; fail-closed. |
| NULL_KIND_CONFLICT | Không thể ánh xạ null kinds | Review null policy. |
| KEY_DUPLICATE / KEY_INVALID | Trùng/thiếu key | Đổi key hoặc xử lý dữ liệu nguồn. |
| CURRENCY_MISMATCH / UNIT_INCOMPATIBLE | Khác đơn vị chưa phê duyệt | Xác nhận conversion. |
| ZONE_AMBIGUOUS | DST hoặc zone chưa đủ | Chọn zone / offset. |
| OCR_REVIEW_REQUIRED | OCR chưa xác nhận | Review ô/field. |
| EXCEL_DATE_SERIAL_60 | Lỗi lịch Excel 1900 | Cần xác nhận riêng. |
| UNSUPPORTED_SEMANTIC_TYPE | Engine Dart chưa triển khai dtype | Chặn so sánh, hiện capability. |

## 5.8. Kiến trúc Flutter/Dart

```text
Flutter Material 3 Screens (Import / Preview / Mapping / Policy / Results / OCR Review)
  -> Feature ViewModels (Riverpod đề xuất; không để normalize trong Widgets)
  -> Application UseCases (Import / Map / CompilePolicy / Compare / Export)
  -> Pure Dart domain package `excelcompare_core`
       model/ (sealed SourceCell, CanonicalValue, Provenance)
       policy/ (parser, validator, compiler, rule registry)
       normalization/ (strict parsing + TraceStep)
       compare/ (strict matcher, comparator, summary)
  <- Repository interfaces (source adapters, report repository)
       adapter/xlsx, adapter/csv, adapter/json  [format-specific PoCs]
       storage/drift (SQLite; cache & sessions)
       platform/file_picker (Android SAF, iOS file providers)
       ocr/ml_kit (opt-in feature, Android/iOS only)
```

Codebase đề xuất:

```text
excelcompare/
  apps/mobile/                  # Flutter Android-first app
    lib/app/                    # Router, theme, dependencies
    lib/features/import/        # Views + ViewModels
    lib/features/mapping/
    lib/features/policy/
    lib/features/compare/
    lib/features/results/
    lib/features/ocr/           # P2
    lib/infrastructure/         # file adapters, Drift, permissions
  packages/excelcompare_core/   # Pure Dart; no flutter/material.dart, android.*, Java POI
    lib/src/model/
    lib/src/policy/
    lib/src/normalization/
    lib/src/compare/
    test/
  docs/                         # ADRs, policy schemas, test fixtures
```

**Công nghệ gợi ý (cần khóa version khi bắt đầu dự án):** Flutter SDK + Dart 3; `decimal` cho số chính xác, `file_picker` cho nguồn do người dùng chọn, `drift`/`drift_flutter` cho SQLite; Riverpod cho state (quyết định kiến trúc, không bắt buộc); `google_mlkit_text_recognition` ở P2 (chỉ Android/iOS, không tự có OCR web). Không áp đặt Apache POI Java vào Flutter: thử nghiệm package XLSX Dart trên device real với merged cells, formula caches, high cardinality shared strings và zip-bomb constraints; khi không đạt, dùng adapter native/platform channel có PoC hoặc giới hạn định dạng. Không tuyên bố CSV/XLSX streaming khi chưa benchmark.

Flutter job dài: chạy parser/compare CPU intensive ngoài UI isolate bằng `Isolate.run`/long-lived Isolate khi phù hợp, giới hạn memory/bytes, progress/cancellation/checkpoint. Flutter Web không có isolate cùng mô hình; tính năng Web là out-of-scope ban đầu. Plugin calls/OCR phải đặt ngoài pure Dart domain. Platform-specific permissions và SAF URI lifecycle cần integration tests.

## 5.9. Data contracts, safety và vận hành

`ComparisonReport` gồm `source_a`, `source_b`, `mapping`, `policy_snapshot`, `policy_digest`, `engine_version`, `adapter_versions`, `summary`, `record_differences`, `cell_differences`, `structural_differences`, `unresolved`, `warnings`. `SourceRef` tagged union `{type: excel, sheet, address}`, `{type: csv, line, field}`, `{type: json, pointer}`, `{type: ocr, imageId, polygon}`; không giả Sheet1 cho CSV/ảnh.

UI không log raw/canonical, file URI, email, phone, OCR images vào telemetry. Cache Drift chứa dữ liệu nhạy cảm nếu persist: Drift/SQLite **không tự mã hóa**; áp dụng TTL và chọn SQLite encryption có PoC hoặc không lưu raw data. Export XLSX giữ user text như string cell, CSV chống formula injection, không mở external links/macros. Đổi policy/engine/source hash phải invalidate semantic comparison cache và tăng `config_revision`.

## 5.10. Acceptance tests và release gates

| ID | A vs B | Field policy | Kết quả |
|---|---|---|---|
| TC-01 | numeric `8.5` vs string `8,5` | DECIMAL, separators A/B explicit | EQUIVALENT |
| TC-02 | string `00123` vs string `123` | IDENTIFIER (preserve zeros) | DIFFERENT |
| TC-03 | `0` vs BLANK | NULL kinds distinct | DIFFERENT |
| TC-04 | `false` vs `Không` | BOOLEAN, explicit alias | EQUIVALENT |
| TC-05 | `01/02/26` vs `2026-02-01` | DATE missing year pivot/locale | UNRESOLVED |
| TC-06 | `0.1` vs `10%` | PERCENTAGE sign-scale on | EQUIVALENT |
| TC-07 | `100000` vs `100001` | MONEY zero tolerance | DIFFERENT (sau khi MONEY implemented) |
| TC-08 | `Nguyễn An` vs `Nguyen An` | PERSON_NAME, preserve accents | DIFFERENT (sau khi NFC implementation verified) |
| TC-09 | `1,234` vs `1.234` | DECIMAL, unspecified locale | UNRESOLVED |
| TC-10 | duplicate keys | KEY matching | UNRESOLVED alignment |
| TC-11 | unaudited OCR numeric field | OCR review gate | UNRESOLVED |
| TC-12 | policy changed, same inputs | version/digest | distinct comparison revision |

Release gates: validator & golden cases 100% pass trong scope implemented; property tests (symmetry, determinism, fail closed); targeted core branch coverage ≥90% là mục tiêu, không phải bảo chứng; XLSX parser PoC Android real; large-file OOM/DoS; permission lifecycle; export CSV injection; no PII logs; benchmark trước cam kết SLO.

## 5.11. Kế hoạch chuyển đổi theo giai đoạn

- **G0 / Nền tảng học:** học Dart 3 (records, sealed, async/await, isolates), Flutter widgets/state/navigation, unit tests; chạy thử package `excelcompare_core` độc lập với app.
- **G1 / Lõi ngữ nghĩa:** implement & test toàn bộ semantic dtypes; policy compiler/validator; stable digest; key alignment; golden fixtures.
- **G2 / Android MVP:** Flutter Import/Preview/Mapping/Policy/Results; CSV/JSON + XLSX theo PoC; Drift local sessions, safe export.
- **G3 / Mở rộng:** OCR ML Kit + manual review, các format khác, thiết bị/OS matrix, optional iOS/desktop.

## Nguồn tham khảo đối chiếu (truy cập 11/11/2026)

- Flutter app architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter/Dart isolates: https://docs.flutter.dev/perf/isolates
- `decimal`: https://pub.dev/packages/decimal
- `file_picker`: https://pub.dev/packages/file_picker
- `drift`: https://pub.dev/packages/drift
- ML Kit Flutter plugin/platform constraints: https://pub.dev/packages/google_mlkit_text_recognition

**Các giả định cần xác nhận khi triển khai:** giới hạn file/device, nền tảng thứ hai sau Android, cấu trúc XLSX cần hỗ trợ (formulas/merged/style), có lưu dữ liệu thô ở máy hay không, chính sách OCR/consent, chỉ tiêu hiệu năng trên corpus đại diện.


## 5.12. Cross-platform contract và release parity — Android P0 / iOS P1

- Policy JSON schema 2 giữ **platform-independent**: cùng input, effective policy, engine version và canonical serializer phải cho kết quả semantic giống trên Android/iOS.
- Android/iOS chỉ triển khai platform ports về `file_picker`, local persistence, sharing/export và OCR; các phép so dtype/normalize/compare chạy bằng Pure Dart package.
- Không đưa Android URI, iOS security-scoped URL, đường dẫn file, device locale/zone mặc định vào canonical value; các giá trị đó phải là tham số nguồn tường minh.
- I/O không được sửa nguồn; quyền trên iOS có thể phụ thuộc document provider và phạm vi sandbox. Sử dụng stream/copy tạm với quota, TTL và dọn dẹp.
- `report.json` trên cả hai nền tảng phải vượt qua bộ golden fixtures parity; không khẳng định parity nếu mới có kiểm thử trên một OS.
- Chỉ iOS release gate khi shared core pass và plugin dependencies kiểm chứng bằng simulator lẫn iPhone thực. Binaries: APK/AAB signed cho Android; IPA signed/provisioned cho iPhone.
