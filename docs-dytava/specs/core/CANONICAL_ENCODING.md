---
document_id: DYT-CORE-ENC-001
version: 1.0.0
status: DRAFT
owner: Core semantic contract role
reviewer: Cross-runtime review role; assignee pending
updated: 2026-11-13
contract_version: CE-1
---

# Canonical encoding, signatures và cache — L4

Extension của [Core semantic spec](../../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md). Semantic transform/parse vẫn theo confirmed policy; byte encoding không cấp phép coercion. CE-1 thay signatures ad-hoc trong v3; cached/indexed data cũ phải rebuild. Không thay policy schema_version=2 bằng engine version.

## 1. Primitive byte grammar

Tất cả text là valid Unicode scalar sequence → UTF-8 không BOM. Reject unpaired surrogates/invalid UTF-8; không replace bằng U+FFFD. Không implicit trim/NFC/casefold tại serializer. Normalization chỉ chạy ở Core theo policy; dùng [UAX #15](https://www.unicode.org/reports/tr15/tr15-58.html) và implementation/version ghi trong manifest nếu bật NFC.

`U64(n)`: unsigned 64-bit big-endian, 0≤n<2^64; `B(x)=U64(byteLength(x)) || x`; `S(t)=B(UTF8(t))`. Length là bytes, không codepoints/UTF-16 units. `SEQ(xs)=U64(count)||B(x1)||...||B(xn)`. Overflow/không đủ byte/budget phải reject trước cấp phát; không parse length thành double. Opaque IDs được serialize như S, không đoán numeric.

| Value | Encoding |
| --- | --- |
| Boolean | byte `01` cho false, `02` cho true |
| Text | byte `03` + S(text) |
| Integer | byte `04` + S(minimal base-10 signed integer); 0 là `0`, không `+`/leading zeros/-0 |
| Decimal | byte `05` + S(normalized decimal) + S(scale facet) |
| Null kind | byte `06` + S(MISSING/BLANK/EMPTY_STRING/JSON_NULL/EXCEL_ERROR/TEXT_SENTINEL) + S(error/sentinel code hoặc chuỗi rỗng) |
| Typed compound | byte `07` + S(type_id) + SEQ(named component encodings) |

Normalized decimal: finite coefficient `c` base10 minimal và signed exponent `e`, payload text `c@e`; remove coefficient trailing zeros, adjust exponent; zero=`0@0`, không negative zero. Ví dụ `8.50`→`85@-1`, `0.1`→`1@-1`, `1000`→`1@3`. Số không parse/NaN/infinity không có DECIMAL canonical success; trả unresolved/error typed theo policy.

Scale facet=`*` khi policy ignore_scale=true; nếu ignore_scale=false là decimal integer số chữ số fractional trong **effective parsed representation sau transforms có scale rõ**. Không có defined effective scale thì unresolved, không tự chọn `*`. Raw source representation vẫn lưu ở evidence riêng. DECIMAL và PERCENTAGE cùng numeric ratio vẫn có semantic dtype tag trong field envelope nên không tự trở thành cùng type.

`CanonicalFieldBytes = S(logical_field_id)||S(dtype)||B(valueEncoding)`. `CanonicalRecordBytes = S("CE-1")||S(schema_digest)||SEQ(fields theo confirmed mapping order)`. Mapped/unmapped structures có schema riêng; content compare không trộn field order của hai snapshots chưa map. Unknown dtype/compound component order reject; chỉ enable các dtypes có registered semantic encoder.

## 2. Configuration canonical serializer

Effective policy/config digests dùng `CFG-1`, không hash arbitrary JSON pretty-print. Input là parsed JSON AST strict, reject duplicate keys, nonfinite numbers và invalid Unicode. RFC8259 là format nền, không quy định byte canonicalization ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)). Quy tắc Dytava:

- Null=`N`; boolean=`T`/`F`; string=`S||S(text)`; number=`D||S(normalized decimal c@e)` từ exact numeric token, không qua double.
- Array=`A||SEQ(encoded items)` theo thứ tự; object=`O||U64(count)||S(key1)||B(value1)...`, keys sorted lexicographically theo unsigned UTF-8 bytes, không Unicode normalize keys.
- Defaults được resolve và unknown operations reject **trước** serialization; array order chỉ normalize nếu owner contract khai đó là set và đưa thứ tự canonical. Policy object không chứa chính digest của nó, timestamps, UI state hoặc access refs.

`H(domain,payload)=SHA-256(S("DYTAVA")||S(domain)||B(payload))`. Text output digest=`sha256:` + 64 lowercase hex; hash input giữ binary digest khi đóng frame. Domain/version là một phần hash; không reuse cùng digest giữa source và key/content.

## 3. Ba loại signatures

| Signature | Definition / dùng cho | Không được suy ra |
| --- | --- | --- |
| Source fingerprint | SHA-256 bytes nguồn đúng EOF; không CE framing | Không đồng nhất hai artifact slots cùng bytes |
| Key signature | H(`key/CE-1`, S(key_policy_digest)\|\|SEQ(CanonicalFieldBytes của ordered strict identifier keys)) | Không hash cả record để join; không tolerance/fuzzy/null key |
| Exact canonical content | H(`content/CE-1`, S(content_policy_digest)\|\|CanonicalRecordBytes) | Không suy EXACT storage hoặc same entity chỉ từ hash |
| Policy digest | H(`policy/CFG-1`, CFG-1(effectivePolicy + dictionary/normalizer/parser versions)) | Không dùng generated_at/app label thay semantic version |

Key equality luôn compare complete key bytes khi signatures bằng nhau; content hash hit luôn verify complete canonical record bytes. Không hash-equal shortcut cell verdict. Source-specific parse overrides nằm trong effective policy; A/B dùng cùng compiled policy/schema envelope, không mang side tag vào key/content bytes để tránh ngăn equal cross-side.

Nếu field normalization unresolved thì record không có complete canonical content signature; key có thể vẫn hợp lệ nếu các key fields đủ evidence. Record đó vẫn được pair theo key, L7 phát unresolved cho affected fields. Numeric-source identifier thiếu lexical evidence invalid key; không zero-pad từ format/display.

## 4. Equality và tolerance

`CanonicalExact` là equality bytes sau các transforms tạo quan hệ tương đương đã confirm. `SemanticComparison` có thể thêm absolute tolerance, nhưng không dùng kết quả tolerance để partition/key/MULTISET. P0 hỗ trợ tolerance_abs nonnegative đã confirm ở field; relative tolerance chưa có trong policy compiler contract hiện hành nên reject operation, không ngầm thêm từ v3 prose.

`0~0.09`, `0.09~0.18`, `0!~0.18` với epsilon0.1 minh họa không bắc cầu. MULTISET extension chỉ cho fields có exact canonical equivalence; policy có tolerance hoặc unresolved thì mode không eligible, không round/bucket để giả equivalence. Key field transforms phải đúng strict identifier rules và uniqueness global sau transform.

## 5. Cache binding và invalidation

Canonical cache key gồm snapshot_id/source hash, Input schema/adapter/config/extraction revision, scope/view/map digest, logical field ID, normalization/encoding version, field-effective policy digest và engine semantic version. Raw value giống nhau nhưng locale/source profile khác không share entry. Cache values là success+trace hoặc unresolved+reason; không cache transient access errors thành semantic truth.

Key/content indexes thêm schema/key order/mode lineage; match cache thêm both snapshot IDs, direction, mode/extension parameters, profile-sensitive search configuration và mapping confirmation revision. Export cache thêm result_id/filter/order/template/layout/locale/timezone/fonts versions. Không reuse partial search như full match cache; stale generation/encoding invalidates whole dependent partition.

Trace payload giữ transformation operations/input/output kinds/parameters digest và source refs; không cần duplicate full policy trong mỗi cell. Evidence/raw store leases phải còn sống để replay. Không có lease/evidence thì entry không dùng để publish result.

## 6. Golden vectors và error behavior

| Input | Expected encoding relation / outcome |
| --- | --- |
| Key tuple `("ab","c")` vs `("a","bc")` | Different framed bytes, không delimiter collision |
| Text `""` vs MISSING vs integer0 vs false | Different tags/frames; policy null collapse chỉ sau explicit transform |
| `8.50` vs `8.5`, ignore_scale=true | Same decimal payload/facet; raw khác nên verdict có thể EQUIVALENT, không EXACT |
| `8.50` vs `8.5`, ignore_scale=false | Same numeric payload nhưng facets2/1 khác, semantic decision theo scale policy |
| `é` UTF-8 vs `e`+combining accent, NFC bật | Same normalized text bytes; NFC tắt thì khác |
| Mock digest collision, key bytes khác | Not equal, separate key groups |
| Key `SV001`, value `8.5→8.7` | Same key bytes, different content bytes, one pair + changed cell |

Malformed frame/unknown tag/version/overflow=blocking encoding error; unresolved semantic values không được serialize như valid null. Input bytes không sửa để “sửa encoding”. Planned acceptance: [UDG-TC-009/010/011](../../testing/UDG_CONTRACT_ACCEPTANCE.md); byte-level fixture runner/parity chưa được tạo.
