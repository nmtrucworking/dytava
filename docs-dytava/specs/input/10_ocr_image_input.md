# Input ảnh và OCR — phạm vi Android P0 tối thiểu

Document ID: INP-010\
Version: 0.1.1 (documentation; wire schemas vẫn 0.1.0)\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 12/11/2026

## 1. Mục đích và phạm vi

Theo [INP-ADR-002 đã chốt](../../decisions/ADR_REGISTER_P0_2026-11-11.md), Android P0 nhận tối đa một nguồn ảnh PNG/JPEG trong hai nguồn A/B (một ảnh, một bảng), dùng model nhận dạng chữ bundled on-device, và yêu cầu manual table/text review trước handoff. **PDF input**, multi-page, cloud OCR, ảnh-ảnh và bố cục bảng phức tạp không thuộc P0. Quyết định chưa chứng minh đã có adapter/SDK chạy; mức OCR tối thiểu còn cần giảng viên xác nhận.

## 2. Thuật ngữ và định nghĩa

OCR text recognition chỉ nhận chữ; table reconstruction suy ra hàng/cột từ geometry. Confidence đo độ tin cậy model nếu SDK cung cấp, không là xác suất đúng nghiệp vụ. Manual review xác nhận/correct extraction, không phục hồi công thức/hidden rows từ ảnh.

## 3. Các thành phần dữ liệu

Nguồn ảnh/camera giữ artifact hash, kích thước/orientation, page, crop/rotation transform và engine/model version trong extraction manifest. Geometry xuất ra source_ref ở hệ oriented_image_pixels: gốc trên trái, x sang phải, y xuống; polygon phải nằm trong image dimensions. Nếu deskew/crop, lưu transform ngược tới hệ ảnh định hướng gốc. PDF page có page number riêng; pipeline PDF text cần contract riêng trước khi bật support.

SourceCell ocrText: raw_lexeme là recognized text không sửa; confidence [0,1] hoặc null nếu không có; review_state PENDING/CONFIRMED. reviewed_text chỉ có sau xác nhận, kể cả giữ nguyên recognized text. Review receipt lưu reviewer action/time + artifact hash + config revision + extraction revision + cell ref + correction, tách khỏi raw data.

## 4. Quy tắc và ràng buộc

- **INP-RULE-037:** OCR luôn review trước handoff; confidence cao không bypass review.
- **INP-RULE-038:** Giữ text gốc, geometry và correction riêng; sửa ảnh/extraction/layout invalidate review receipts.
- **INP-RULE-039:** Không tạo workbook formula, format code, physical number hoặc dữ liệu che khuất từ OCR. 00123 nhận diện là text, semantic type do policy.

Nếu không nhận diện được lưới bảng, chuyển NEEDS_REVIEW hoặc báo unsupported layout; không ép text lines thành bảng mà không cho người dùng xác nhận. Nhiều trang/bảng chưa được suy ra là scope P0.

## 5. Input / Output Contract

image/camera → decode/limits → orientation/crop/deskew có transform → text blocks + polygons → table reconstruction → SourceTable + ocrText cells PENDING → manual review + receipts → validated extraction snapshot. Adapter capability OCR_REVIEW_REQUIRED vẫn giữ nguyên sau review; trạng thái cells thay thành CONFIRMED. Schema Input 0.1.0 có source_ref/cell OCR nhưng ImportConfig **chưa nhận image**. Trước khi bật Android P0 OCR phải có schema migration/version mới, extraction manifest, review receipt contract và integration tests; không dùng schema OCR đã mô tả làm chứng cứ tính năng đang chạy.

## 6. Luồng xử lý

File picker/camera explicit consent → local recognition nếu capability đã kiểm thử → preview overlay ảnh và cells → sửa layout/text → xác nhận từng cell hoặc batch được liệt kê rõ → freeze extraction revision → kiểm tra toàn bộ selected scope → gate READY. Cloud OCR nằm ngoài P0, chỉ nghiên cứu ở giai đoạn sau với opt-in/service contract riêng; không tự fallback khi offline recognition thất bại.

## 7. Edge Cases và Error Handling

Ảnh mờ, nghiêng, không lưới, bảng chồng, chữ viết tay, merged cells và ảnh cắt mất hàng: 012 REVIEW hoặc 013/008 ERROR nếu không có cách an toàn. Confidence không có dùng null; không đặt 1.0. Polygon ngoài ảnh: 014. Image decompression/pixel limit: 004; không decode vô hạn. File HEIC icon không chứng minh codec/model hỗ trợ. Trần source 1 GB của scope mở rộng không bỏ pixel/decode limits hoặc manual review; NFR sở hữu profile lớn. PDF export có thể trình bày kết quả từ OCR đã review theo Report spec, không trở thành PDF/OCR importer.

## 8. Security & Privacy

Ảnh có thể chứa PII, EXIF/vị trí; không gửi lên cloud hoặc telemetry mặc định. Camera quyền chỉ xin khi dùng camera. File gốc read-only; preview/crop là derivative có lifecycle riêng. Receipts không được chứa access token; việc xuất ảnh/evidence cần lựa chọn rõ của người dùng.

## 9. Acceptance Criteria

INP-TC-039: confidence cao/thấp/null đều cần review, giữ recognized/corrected text và geometry đúng; sửa crop/layout invalidate receipts. INP-TC-040: không gọi cloud khi chưa opt-in; không fabricate formulas/metadata; ảnh vượt pixel limit bị dừng. Đây là planned integration tests, chưa chạy OCR SDK.

## 10. Open Questions

INP-ADR-002 đã chốt OCR vào Android P0; INP-ADR-004 đặt bootstrap ceiling một ảnh tối đa 12MP, một bảng/page, chưa benchmark. Model/plugin PoC, corpus layout accuracy, review UX, schema migration và xác nhận giảng viên còn là implementation/acceptance gates, không phải ADR OPEN. Cần extraction manifest/receipt schema riêng khi bật P2.

## 11. References

[INP-005](05_data_types_provenance.md), [INP-008](08_import_state_machine.md), [Project Description](../../project/Project%20Description.md), [baseline OCR note](../../project/Optical%20Character%20Recognition%20%28OCR%29.md).
