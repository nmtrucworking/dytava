# Input ảnh và OCR — phạm vi P2

Document ID: INP-010\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## 1. Mục đích và phạm vi

OCR/PDF-image là P2 theo baseline Flutter 2.2, chưa là tính năng đã triển khai. Yêu cầu học phần “đọc từ file hình ảnh chụp” vẫn bắt buộc trong đề bài; mâu thuẫn ưu tiên với P0 phải giải quyết tại INP-ADR-002, không âm thầm bỏ yêu cầu.

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

image/camera → decode/limits → orientation/crop/deskew có transform → text blocks + polygons → table reconstruction → SourceTable + ocrText cells PENDING → manual review + receipts → validated extraction snapshot. Adapter capability OCR_REVIEW_REQUIRED vẫn giữ nguyên sau review; trạng thái cells thay thành CONFIRMED. Schema 0.1.0 có source_ref/cell cho thiết kế P2; ImportConfig P0 không nhận image, nên schema support không đồng nghĩa ingestion enabled.

## 6. Luồng xử lý

File picker/camera explicit consent → local recognition nếu capability đã kiểm thử → preview overlay ảnh và cells → sửa layout/text → xác nhận từng cell hoặc batch được liệt kê rõ → freeze extraction revision → kiểm tra toàn bộ selected scope → gate READY. Cloud OCR chỉ sau opt-in riêng với service/backend contract; không tự fallback khi offline recognition thất bại.

## 7. Edge Cases và Error Handling

Ảnh mờ, nghiêng, không lưới, bảng chồng, chữ viết tay, merged cells và ảnh cắt mất hàng: 012 REVIEW hoặc 013/008 ERROR nếu không có cách an toàn. Confidence không có dùng null; không đặt 1.0. Polygon ngoài ảnh: 014. Image decompression/pixel limit: 004; không decode vô hạn. File HEIC icon không chứng minh codec/model hỗ trợ.

## 8. Security & Privacy

Ảnh có thể chứa PII, EXIF/vị trí; không gửi lên cloud hoặc telemetry mặc định. Camera quyền chỉ xin khi dùng camera. File gốc read-only; preview/crop là derivative có lifecycle riêng. Receipts không được chứa access token; việc xuất ảnh/evidence cần lựa chọn rõ của người dùng.

## 9. Acceptance Criteria

INP-TC-039: confidence cao/thấp/null đều cần review, giữ recognized/corrected text và geometry đúng; sửa crop/layout invalidate receipts. INP-TC-040: không gọi cloud khi chưa opt-in; không fabricate formulas/metadata; ảnh vượt pixel limit bị dừng. Đây là planned integration tests, chưa chạy OCR SDK.

## 10. Open Questions

INP-ADR-002 về lịch giao học phần; INP-ADR-004 về pixel/page limits; model/plugin PoC, layout accuracy corpus và review UX còn chờ. Cần extraction manifest/receipt schema riêng khi bật P2.

## 11. References

[INP-005](05_data_types_provenance.md), [INP-008](08_import_state_machine.md), [Project Description](../../project/Project%20Description.md), [baseline OCR note](../../project/Optical%20Character%20Recognition%20%28OCR%29.md).
