# Kiểu dữ liệu nguồn và provenance

> **ADR status 11/11/2026:** [INP-ADR-001..009 đã chốt](../../decisions/ADR_REGISTER_P0_2026-11-11.md) cho Android P0, gồm OCR có review. Các câu “OPEN”, “OCR P2” hoặc “chưa quyết định” của baseline 0.1.0 khi xung đột là lịch sử; schema và test implementation vẫn DRAFT/PLANNED.

Document ID: INP-005\
Version: 0.1.1 (documentation; wire schemas vẫn 0.1.0)\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 12/11/2026

## 1. Mục đích và phạm vi

Nguồn chuẩn của physical source types và địa chỉ gốc. Parsed Input là Canonical Table Model ở tầng cấu trúc, chưa phải semantic CanonicalValue. Normalization, tolerance và kết luận EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED thuộc Core.

## 2. Thuật ngữ và định nghĩa

| Tầng | Ví dụ | Ai chịu trách nhiệm |
| --- | --- | --- |
| Physical | xlsxNumber, csvText, jsonNull | Adapter giữ bằng chứng nguồn |
| Logical | text, arbitrary precision decimal/integer, bool, date-only | Parse strict có profile; gợi ý chưa thay raw |
| Semantic | IDENTIFIER, MONEY, DATE | Comparison policy xác nhận |

Date-like XLSX có thể là số serial + style; OOXML cũng có kiểu ngày ISO (`xlsxDateISO`). Không coi style là bằng chứng đủ về ý nghĩa nghiệp vụ. EXCEL_ERROR không phải null thông thường. Text sentinel như `N/A` vẫn là raw text, chỉ được policy diễn giải về sau.

## 3. Các thành phần dữ liệu

| Field | Contract |
| --- | --- |
| `raw_kind` | xlsxNumber/xlsxString/xlsxSharedString/xlsxBoolean/xlsxDateISO, csvText, jsonNumber/jsonString/jsonBoolean/jsonNull, formula/error/blank/missing, ocrText |
| `lexical_status` | PRESERVED có raw_lexeme; UNAVAILABLE không có raw_lexeme và phải ghi losses; NOT_APPLICABLE cho null/blank/missing |
| `raw_lexeme` | Nội dung nguồn theo định nghĩa từng adapter, không lấy display_text làm thay thế |
| `display_text`, `format_code` | Tùy nguồn; bỏ thuộc tính nếu không có, không tạo giá trị giả |
| `formula`, `cached_value` | Biểu thức tách cached physical value; không tự evaluate |
| `formula_cache_status` | NOT_FORMULA / PRESENT_UNVERIFIED / MISSING / KNOWN_STALE |
| `excel_date_system` | 1900/1904 nếu số serial được diễn giải thành ngày |
| `null_kind` | NONE / MISSING / BLANK / EMPTY_STRING / JSON_NULL / EXCEL_ERROR |
| `source_ref`, `losses` | Địa chỉ gốc và danh sách thông tin không bảo toàn được |
| `review_state` | NOT_REQUIRED; OCR dùng PENDING/CONFIRMED, confidence có thể null |

CSV raw_lexeme là field text sau unquote/unescape, giữ khoảng trắng và line ending bên trong field; không phải byte slice có dấu quote. JSON string là decoded Unicode text; JSON number giữ numeric token trước cast. Shared string là resolved source text; index shared-string không phải nội dung cell. Formula raw_lexeme nếu có là biểu thức gốc, không chứa cached value. Bản bytes + SHA-256 cho phép truy lại cách mã hóa/escape; contract cell không hứa bảo toàn từng byte XML/JSON string.

## 4. Quy tắc và ràng buộc

- **INP-RULE-021:** Giữ raw, display và semantic riêng; không sửa raw sau suy luận hoặc xác nhận người dùng.
- **INP-RULE-022:** UNAVAILABLE phải ghi loss cụ thể (ví dụ RAW_LEXEME_UNAVAILABLE); thiếu precision cần review hoặc từ chối mode yêu cầu exactness. Không render float đã làm tròn rồi gọi đó là raw.
- **INP-RULE-023:** MISSING khác BLANK, EMPTY_STRING, JSON_NULL, EXCEL_ERROR, 0 và false; chỉ Core/policy được gộp có chủ đích.
- **INP-RULE-024:** Mọi cell có source_ref thật; không giả địa chỉ Excel cho CSV/JSON/OCR.
- **INP-RULE-025:** Công thức/cache tách biệt; cache tồn tại không chứng minh còn mới. Cache thiếu/stale không thành 0/rỗng.

XLSX raw number `123`, format `00000`, display `00123`: giữ đủ ba thuộc tính; không kết luận mã gốc từng là `00123`. Khi policy yêu cầu identifier từ numeric source, chuyển thông tin loss/ambiguity cho Core; không phục hồi số 0 bằng suy đoán. Serial 60 hệ 1900 và ngày thiếu date system không được ép thành ngày hợp lệ. JSON number lớn phải giữ token; adapter không đáp ứng thì công bố loss/capability và chặn chế độ yêu cầu precision.

## 5. Input / Output Contract

[source_cell schema](schemas/source_cell.schema.json) tham chiếu [source_ref schema](schemas/source_ref.schema.json). SourceRef là union đóng:

| type | Bắt buộc ngoài artifact_id, exists |
| --- | --- |
| excel | sheet, address (A1, 1-based) |
| csv | line/end_line (physical, 1-based, inclusive), record (logical, 1-based gồm header), field (1-based) |
| json | pointer RFC 6901; root `""`, array index 0-based |
| ocr | page (1-based), polygon ≥3 points, image dimensions, coordinate_space=oriented_image_pixels |

Missing JSON property dùng pointer tới vị trí dự kiến và exists=false; đó là địa chỉ kỳ vọng, không tuyên bố value tồn tại. Pointer escape `~` → `~0`, `/` → `~1`. XLSX missing cell có địa chỉ worksheet, exists=false. OCR không được dùng exists=false để phát minh chữ không nhận diện được.

JSON Schema kiểm tra shape/tag/required fields; runtime kiểm tra số dòng, cell count, Excel bounds, artifact ID, pointer resolution/absence, polygon trong ảnh, raw/null-kind phù hợp nội dung và loss declaration.

## 6. Luồng xử lý

Đọc token/type → ghi SourceRef → lấy metadata khả dụng → ghi losses → kiểm tra schema + invariants → preview. Parse logical candidates lưu riêng ở tầng profile; không thêm semantic rules vào SourceCell. Handoff truyền immutable cells và evidence; adapter không tự canonicalize.

## 7. Edge Cases và Error Handling

JSON null: raw_kind=jsonNull, lexical_status=NOT_APPLICABLE, null_kind=JSON_NULL, không raw_lexeme. CSV field `""`: raw_kind=csvText, raw_lexeme="", null_kind=EMPTY_STRING. Missing: không raw_lexeme, exists=false. Mất provenance: INP-ERR-014; thiếu precision/metadata cần thiết: INP-ERR-013. JSON nested arrays/objects bị reject ở P0 flat profile; không JSON.stringify rồi gọi là text nguồn.

## 8. Security & Privacy

SourceRef chứa vị trí, không chứa URI/token truy cập. Không dùng raw/display/formula/cached values cho telemetry. Mask preview theo UX; việc người dùng sửa OCR phải giữ recognized text gốc, reviewed_text riêng và review record gắn snapshot (xem INP-010).

## 9. Acceptance Criteria

INP-TC-021 numeric 123/style 00000; INP-TC-022 null taxonomy; INP-TC-023 JSON number precision + pointer escaping; INP-TC-024 missing/stale formula cache; INP-TC-025 loại ref đúng nguồn. Schema positive/negative samples kiểm tra bằng validator độc lập.

## 10. Open Questions

INP-ADR-006 đã chốt: numeric identifier thiếu lexical evidence → UNRESOLVED, không khôi phục leading zeros. INP-ADR-007 đã chốt chiến lược XlsxFormatAdapter; parser PoC và fidelity evidence vẫn phải thực hiện. Cần quyết định serializer logical preview và extension metadata trước khi mở rộng schema.

## 11. References

[JSON RFC 8259](https://www.rfc-editor.org/rfc/rfc8259), [JSON Pointer RFC 6901](https://www.rfc-editor.org/rfc/rfc6901), [Core semantic spec](../../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md), [INP-010](10_ocr_image_input.md).
