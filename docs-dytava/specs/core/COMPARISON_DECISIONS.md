---
document_id: DYT-CORE-DEC-001
version: 1.0.0
status: DRAFT
owner: Core semantic contract role
reviewer: Semantic review role; assignee pending
updated: 2026-11-13
---

# Typed comparison decision tables — L7

Extension của [Core spec §5.6](../../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md). Bốn kết luận cell và mẫu số không thay đổi. Physical raw/null/formula refs thuộc INP-005; wire result ở [ER-1](../engine/04_result_runtime.md). P0 types theo PRD: IDENTIFIER/FREE_TEXT/DECIMAL/BOOLEAN/PERCENTAGE; các tables DATE/formula bên dưới đặc tả extension, không tự enable P0.

## 1. Precedence và evidence

| Thứ tự | Điều kiện | Kết quả |
| --- | --- | --- |
| 0 | Không có confirmed row/field pairing | Structural/unresolved ownership event; không fabricated matched-cell pair |
| 1 | Pair có nhưng thiếu policy/capability, parse fail, OCR receipt stale hoặc evidence thiếu | UNRESOLVED + reason/remediation; systemic invalid snapshot phải fail job thay vì hàng loạt semantic verdict giả |
| 2 | Cùng physical kind, preserved lexical value, null-kind và valid typed value; metadata yêu cầu bởi selected mode đầy đủ | EXACT; identity rule/version và evidence refs |
| 3 | Raw khác nhưng canonical exact equality hoặc permitted field tolerance satisfied | EQUIVALENT; rule/version, canonical A/B và trace refs bắt buộc |
| 4 | Hai canonical successes và valid inequality theo comparison rules | DIFFERENT + reason/evidence |

EXACT không dùng display_text thay raw_lexeme; lexical UNAVAILABLE không được EXACT. `TYPE_CHANGED`, `FORMULA_CHANGED`, `STYLE_CHANGED`, `OCR_REVIEWED`, `COORDINATE_SHIFTED` là orthogonal flags/kinds, không cell verdicts. `UNDETERMINED` của v3 gốc là alias đọc cũ→UNRESOLVED, không được phát ra trong ER-1.

## 2. Decision cases theo dtype

| Case | Required evidence/policy | Expected |
| --- | --- | --- |
| Identifier text00123 vs text123 | Strict identifier, lexical preserved | DIFFERENT; không numeric cast |
| Identifier text00123 vs XLSX numeric123/display00123 | Không đủ original identifier lexical evidence | UNRESOLVED IDENTIFIER_LEXICAL_LOSS; không tái tạo leading zeros |
| Missing/blank/empty/null/0/false | Typed null-kind + confirmed null mapping | Distinct mặc định; explicit null collapse có trace→EQUIVALENT nếu eligible |
| Invalid numeric separators / unknown locale | Explicit source parse profile absent/conflicting | UNRESOLVED LOCALE_AMBIGUOUS/PARSE_INVALID; không fallback string |
| Decimal8.5 vs text8,5 | A/B separators explicit, DECIMAL parse exact | EQUIVALENT + parse trace; physical flags khác |
| Decimal8.50 vs8.5 | ignore_scale=true/false theo CE-1 | true→EQUIVALENT nếu raw khác; false→DIFFERENT khi scales khác |
| Decimal delta = tolerance_abs | Absolute decimal delta ≤ configured nonnegative epsilon | EQUIVALENT; tolerance không key/MULTISET |
| Huge integer/decimal/exponent | Exact parser, digit/token bounds | Within profile→exact numeric behavior; vượt bound→structured limit, không round/double |
| NaN/infinity/Excel error | Typed EXCEL_ERROR hoặc unsupported numeric token | Error policy cụ thể; mặc định UNRESOLVED, không numeric zero/null |
| Percentage0.1 vs10% | percent_sign_is_scale=true, defined source profiles | EQUIVALENT ratio0.1; number10 không tự là10% |
| Booleanfalse vs“Không” | Versioned alias map collision-free | EQUIVALENT; alias chưa confirm→UNRESOLVED |
| Text NFC/NFD / case/whitespace | Chỉ operations bật trong policy | EQUIVALENT khi transform eligible và trace đủ; tắt→DIFFERENT |
| OCR recognized text sửa bởi user | Original+reviewed text và current receipt | Compare reviewed_text; OCR_REVIEWED flag, original/correction trace giữ nguyên |

Null mappings phải closed, không capture arbitrary parse errors thành null. Unsupported requested dtype/operation chặn policy compile trước RUNNING; runtime evidence-specific failure trả unresolved. Normalization không âm thầm thay semantic dtype để cứu parse.

## 3. Date/formula/style extensions

DATE serial conversion: adapter khai date_system; serial60 hệ1900→UNRESOLVED EXCEL_SERIAL_60; date system thiếu→UNRESOLVED DATE_SYSTEM_MISSING. 1900/1904 conversion chỉ khi full valid serial/calendar rule, không dựa display locale. Date-only không gán timezone. DATETIME thiếu offset/zone hoặc DST gap/overlap không có resolution rule→UNRESOLVED; không tự đổi qua UTC.

| Formula mode | Conditions | Outcome |
| --- | --- | --- |
| EXPRESSION | Expression present cả hai, expression comparison raw token/codepoint exact; không relative-reference rewriting | Same→EXACT/EQUIVALENT theo full mode evidence; different→DIFFERENT + FORMULA_CHANGED |
| CACHED_VALUE | Cache PRESENT_UNVERIFIED | Compare stored caches nếu user chọn “stored cache only”; warning CACHE_NOT_RECALCULATED, không tuyên bố live formula equivalence |
| CACHED_VALUE | Cache MISSING/KNOWN_STALE | UNRESOLVED FORMULA_CACHE_MISSING/STALE |
| EXPRESSION_AND_CACHE | Hai components có verdict | Một component unresolved→UNRESOLVED; ngược lại component khác→DIFFERENT; tất cả exact→EXACT; còn lại equivalent→EQUIVALENT |
| Formula vs literal | Mode không cho structural/type conversion | DIFFERENT nếu đủ metadata, flag FORMULA_CHANGED; thiếu metadata→UNRESOLVED |

Không chạy functions/macros/network links; cache same không chứng minh formulas same; expression same không chứng minh cache fresh. Unsupported function không cản EXPRESSION raw-text compare nếu metadata đủ, nhưng không bao giờ evaluate. V3 tự gợi relative formula equivalence không enabled nếu chưa có separate parser/normalizer rule.

Style comparison riêng extension với declared style facets và format events; default value-only không trộn style score vào semantic verdict. Missing requested style evidence→UNRESOLVED cho style facet, không giả style unchanged.

## 4. Long text và highlight

Exact/canonical text compare stream theo bounded chunks và bytes length; đến cuối mới kết luận equality. Semantic processing vượt hard input/normalization budget không được truncate→EQUIVALENT. Highlight là output phụ, state `NOT_REQUESTED | COMPLETE | OMITTED_BUDGET | UNAVAILABLE`; không thuộc cell verdict.

Highlight tokenization versioned, optional token-level LCS chỉ trong highlight-cell/token/DP limits RP-1. Quá budget thì trả omission reason và raw evidence refs, không mất DIFFERENT verdict. Lazy highlight khi mở detail có attempt/version và result_id binding riêng, không sửa immutable semantic snapshot. Token offsets là Unicode scalar positions trong declared display text version, không giả source byte offsets.

## 5. Acceptance

Planned [UDG-TC-014](../../testing/UDG_CONTRACT_ACCEPTANCE.md), Core TC-01..10 phù hợp từng type, INP-TC-021/022/024/039/040 và v3 F06–F09/F19/F23. Every verdict có rule/reason và SourceRefs; no-match không tăng denominator. Formula/date/style cases báo extension status riêng.
