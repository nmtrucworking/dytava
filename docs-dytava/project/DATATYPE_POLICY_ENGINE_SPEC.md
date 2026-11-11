# ExcelCompare — DataType, Semantic Normalization & Policy Engine

Bản đặc tả đề xuất 2.0.0. Chưa có bằng chứng engine được triển khai.

05. DataType, chuẩn hóa ngữ nghĩa và policy engine

Bản hoàn thiện đặc tả — EXCELCOMPARE / Kotlin-JVM / policy schema 2.0.0. Đây là normative design, không phải bằng chứng triển khai hoặc kiểm thử production.

## 5.1. Mục tiêu, phạm vi và nguyên tắc bất biến

Semantic comparison trả EXACT, EQUIVALENT, DIFFERENT hoặc UNRESOLVED trên từng matched cell pair. Structural differences và unmatched rows được thống kê tách riêng. Không viết vào nguồn, không suy luận locale/đơn vị/mã định danh bất chấp mơ hồ, không coi confidence inference là bằng chứng đồng nhất.

Mỗi EQUIVALENT phải có rule_id, rule_version, canonical(left/right), trace, policy_digest. Parse error hoặc thiếu ngữ cảnh trọng yếu là UNRESOLVED với reason_code; không được fallback về so sánh chuỗi và tuyên bố DIFFERENT nếu đã có yêu cầu semantic cast chưa giải quyết.

## 5.2. Hợp đồng dữ liệu và hệ thống kiểu

SourceCell = {raw_kind, raw_lexeme?, display_text?, format_code?, formula?, formula_cache_status?, excel_date_system?, provenance, review_state}. raw_lexeme là chuỗi biểu diễn gốc được adapter lưu nếu khả dụng; không trộn cached formula value với biểu thức. Missing cell là trạng thái riêng, không phải JSON null.

CanonicalValue là tagged union: Text(value), Integer(value), Decimal(value), Boolean(value), Date(ISO), Instant(UTC), LocalDateTime(value, zone_context), Money(amount,currency), Percentage(ratio), Quantity(amount,unit,dimension), Enum(code), NullKind(tag), Complex(canonical_structure). Chỉ so hai canonical values cùng type và cùng dimension/units sau chuyển đổi được phê duyệt.

## 5.3. Quy tắc chuẩn hóa theo semantic dtype

## 5.4. Pipeline canonicalization và trace

Preflight file/provenance → field alignment + key profile → compile/validate policy → classify source raw kind → null-kind resolution → strict parse với source-specific locale/format → semantic transformation → canonical serialization → typed compare → decision/trace → report. Không đổi thứ tự transform tùy runtime.

NormalizedResult = Success(value, steps, effective_rule_ids) | Unresolved(reason_code, evidence, remediation). Trace step = {rule_id, rule_version, operation, before_kind, after_kind, parameters_digest}; trace không ghi dữ liệu nhạy cảm vào telemetry. User-facing report có thể chứa raw/canonical với quyền xuất riêng.

## 5.5. Policy schema, inheritance và precedence

Policy schema_version=2, policy_id, policy_version, defaults, source_profiles, alignment, fields, unresolved_handling. Merge theo thứ tự: engine conservative defaults < policy.defaults < field rule < source-specific field overrides. Overrides chỉ tác động tới parse input; semantic comparison rule của field phải chung và rõ ràng. Không hỗ trợ arbitrary code/scripts hoặc rule tùy ý thực thi trong JSON.

Mandatory validation: schema/version supported; unique logical names; mapping 1:1; keys mapped and of IDENTIFIER-compatible type; no key tolerance/fuzzy matching; source locale/pattern explicit for potentially ambiguous text; tolerance_abs >= 0; alias dictionaries non-conflicting; units/currencies compatible; null mapping legal; unknown fields and unknown operations rejected (fail-closed); no circular aliases; engine capabilities satisfied.

Policy digest = SHA-256 của canonical policy JSON theo một serializer có version, UTF-8, Unicode NFC cho keys do schema định nghĩa, stable ordering và decimal dưới dạng string. Digest tính trên effective resolved policy kèm parser/normalizer dictionary versions; thay đổi input hashes/engine/config_revision/policy digest invalidates comparison cache. generated_at nằm ngoài semantic digest.

## 5.6. Thuật toán quyết định và thứ tự ưu tiên

Precedence: alignment unresolved > parsing/policy unresolved > exact typed comparison > semantic equivalence > substantive difference. Flags TYPE_CHANGED/FORMULA_CHANGED/STYLE_CHANGED/OCR_REVIEWED độc lập; không ép formula flag thay đổi cell semantic status. Tolerance có thể không bắc cầu (a≈b, b≈c nhưng a≉c): không dùng fuzzy/tolerance equality để tạo key hoặc fingerprint multiset.

## 5.7. Matching keys, multiset và scale

KEY: canonical key strict (identifier, tagged tuple có length-prefix) + uniqueness trước join. Duplicate hoặc invalid keys tạo unresolved bucket. POSITION chỉ so theo tọa độ đã align. MULTISET dùng exact canonical typed fingerprints và xác nhận equality khi hash trùng; không dùng tolerance/fuzzy để fingerprint. ORDERED_SEQUENCE yêu cầu memory/time cap. Streaming, indexed SQLite/sort-merge cho dữ liệu lớn; SHA-256 chỉ index, không thay proof equality.

## 5.8. Reason codes và mức độ xử lý

## 5.9. Acceptance, properties và release gate

Golden cases bắt buộc: 00123 vs 123 identifier DIFFERENT; 8.5 vs 8,5 vi-VN decimal EQUIVALENT; 1,234 khi không có locale UNRESOLVED; false vs Không chỉ EQUIVALENT khi alias; 0 vs blank DIFFERENT; 10% vs 0.1 theo percent field EQUIVALENT; Nguyen An vs Nguyễn An DIFFERENT; date serial 1900/1904; timezone equivalence; duplicate keys; OCR review; policy digest reproducibility.

Property tests: determinism với nguồn/policy/engine cố định, idempotent canonicalization (trong miền đã định), symmetry khi đảo A/B và đảo mapping, không silent lossy cast, failure becomes UNRESOLVED. Branch-coverage mục tiêu >=90% cho core critical rules; golden fixtures 100%; benchmark device thực tế; security tests ngăn input injection. Đây là tiêu chí đề xuất, chưa có test evidence.

## 5.10. Android/Kotlin module contract và bảo vệ dữ liệu

core/model: sealed interfaces PhysicalCell, CanonicalValue, NormalizationResult, ComparisonDecision; core/policy: PolicyParser, PolicyValidator, PolicyCompiler, RuleRegistry; core/compare: Canonicalizer, StrictKeyMatcher, SemanticComparator. Domain thuần Kotlin/JVM; adapters không tự chuẩn hóa; UI chỉ hiển thị policy review/evidence. BigInteger/BigDecimal + java.time; xử lý cancellation tại job layer.

Không ghi raw/canonical cell data, email/phone, đường dẫn, OCR content vào telemetry. Original input read-only. Snapshot policy + digest + versions gắn report; export escaped CSV/XLSX text để tránh formula injection.

| Tầng | Các loại | Bảo toàn / ràng buộc |
|---|---|---|
| Physical | XLSX NUMBER/STRING/BOOLEAN/ERROR/FORMULA/BLANK; CSV TEXT; JSON STRING/NUMBER/BOOL/NULL; OCR TEXT | Giữ raw lexical, storage dtype, display, number format, date system, origin, OCR review state; không tự coi style là dtype. |
| Logical | TEXT, INTEGER, DECIMAL, BOOLEAN, DATE, LOCAL_DATETIME, OFFSET_DATETIME, INSTANT, ARRAY, OBJECT; NULL-like tagged union | INTEGER dùng BigInteger; DECIMAL BigDecimal; không dùng Double để so tiền/decimal; array/object phải có comparator explicit. |
| Semantic | IDENTIFIER, FREE_TEXT, PERSON_NAME, POSTAL_CODE, PHONE, EMAIL, ENUM, MONEY, PERCENTAGE, UNIT_QUANTITY, DATE, DATETIME, BOOLEAN | Chính sách field-specific quyết định semantic_type, parse rule, canonical type và equality. |
| Normalization | unicode, trim, whitespace, case, locale, date patterns, time zone, aliases, currency, units, null mapping, tolerance | Tất cả có version và audit trail; default bảo toàn thông tin, không tự bỏ dấu/leading zero. |

| Type | Canonical | Ràng buộc / đặc điểm |
|---|---|---|
| IDENTIFIER / POSTAL_CODE | NFC string | Giữ zero đầu, không cast numeric, case-sensitive mặc định; numeric source là string từ raw representation đã xác nhận; nếu thiếu leading zeros không được tái tạo. |
| FREE_TEXT / PERSON_NAME | NFC string | Trim/collapse whitespace tùy policy; không bỏ dấu, bỏ punctuation hoặc transliterate mặc định; với tên pháp lý giữ dấu. |
| INTEGER | BigInteger | Không truncate phần thập phân; grouping/decimal locale rõ; giới hạn độ dài đầu vào. |
| DECIMAL | BigDecimal | Parse strict theo từng nguồn; ignore_scale tùy policy; tolerance_abs không âm; phép toán chính xác. |
| MONEY | (ISO 4217 code, BigDecimal) | Không quy đổi FX mặc định; currency phải xác định; FX chỉ khi rate snapshot/date/source được explicit; tolerance theo cùng currency. |
| PERCENTAGE | BigDecimal ratio | 10% = 0.10 khi percent_sign_is_scale cho phép; 10 trần không được tự hiểu là 10%. |
| BOOLEAN | true/false | Không tự ép 1/0 hoặc Có/Không nếu thiếu alias; alias tránh trùng/ambiguous. |
| DATE | ISO LocalDate | Chỉ parse format được khai báo; 2-digit-year cần pivot explicit; Excel serial cần hệ 1900/1904 và xử lý serial 60. |
| DATETIME | Instant hoặc local-with-zone | Chỉ so instants nếu đủ offset/zone; DST overlap/gap không tự chọn; local calendar equality là mode khác. |
| PHONE | E.164 hoặc string tagged | Cần region mặc định khi số thiếu prefix; không cắt zero đầu máy móc; giữ original. |
| EMAIL | local part nguyên dạng + domain IDNA | Domain case-insensitive; không lowercase local part mặc định; không bỏ dấu chấm/plus alias tùy nhà cung cấp. |
| ENUM | stable code | Dictionary phiên bản cố định; map many-to-one phải được người dùng duyệt; alias collision -> invalid policy. |
| UNIT_QUANTITY | (BigDecimal, canonical unit, dimension) | Chuyển đổi theo bảng tỷ lệ chính xác, cùng chiều đo; nhiệt độ affine conversion cần rule riêng. |
| NULL-LIKE | MISSING/BLANK/EMPTY_STRING/JSON_NULL/EXCEL_ERROR/TEXT_SENTINEL | Tách 0 và false; chỉ gộp khi null policy explicit; lỗi Excel không phải null mặc định. |

| Điều kiện | Kết quả | Ghi chú |
|---|---|---|
| Không có matched row/field | STRUCTURAL / RECORD DIFF | Không đếm như matched cell pair. |
| Key duplicate / null / ambiguous | UNRESOLVED alignment | Không first-match; nhóm bucket để review. |
| OCR chưa confirm ở trường trọng yếu | UNRESOLVED | Không dùng confidence để tự hợp thức hóa. |
| Thiếu policy, parse error, unit/zone/currency ambiguity | UNRESOLVED | Lý do mã hóa; không coi là DIFFERENT. |
| Raw stored typed + semantic meaning đúng bằng theo exact policy | EXACT | Exact mode có định nghĩa typed equality và null kind; flags độc lập. |
| Không EXACT; canonical typed bằng theo rule được duyệt | EQUIVALENT | Phải có transformation trace; kể cả tolerance nếu bật. |
| Canonical parsed hợp lệ, nhưng không bằng | DIFFERENT | reason = VALUE_CHANGED hoặc NULL_MISMATCH. |

| Reason code | Khi nào xuất hiện | User action |
|---|---|---|
| LOCALE_AMBIGUOUS | 1,234 hoặc ngày hai cách hiểu | Chọn locale/format nguồn. |
| PARSE_FAILED | Không parse được theo rule | Sửa rule hoặc dữ liệu. |
| MISSING_POLICY | Field chưa khai báo semantic dtype | Xác nhận dtype. |
| NULL_KIND_CONFLICT | null/missing/blank không map | Duyệt null mapping. |
| KEY_DUPLICATE | Khóa lặp ở A hoặc B | Chọn key khác / xử lý. |
| KEY_INVALID | Key missing/null/ambiguous | Chỉnh key/field rule. |
| CURRENCY_MISMATCH | Mã tiền khác | Bổ sung FX snapshot nếu cần. |
| UNIT_INCOMPATIBLE | Khác dimension hoặc unit chưa biết | Chọn unit đúng. |
| ZONE_AMBIGUOUS | DST / timezone thiếu | Xác nhận zone, offset. |
| OCR_REVIEW_REQUIRED | OCR chưa xác nhận | Duyệt ô OCR. |
| EXCEL_DATE_SERIAL_60 | Ngày không tồn tại do Excel 1900 | Review hoặc special handling. |
