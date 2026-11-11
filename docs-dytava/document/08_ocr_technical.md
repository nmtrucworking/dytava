# 08. Đặc tả OCR: API, kiểm soát lỗi và privacy

## 8.1. Chế độ OCR

**Local default:** ML Kit v2 Text Recognition (script Latin, hỗ trợ tiếng Việt), chạy on-device. Trả text + geometry; **không đảm bảo table cell structure**. ML Kit bundled tránh tải mô hình lúc chạy, APK tăng dung lượng; unbundled giảm APK nhưng phải chuẩn bị download model.

**Cloud option:** Document AI/Layout APIs trả table structure đối với input hỗ trợ; nhưng vẫn có lỗi OCR, hạn mức/trả phí, yêu cầu internet và vấn đề chuyển dữ liệu cho bên thứ ba. Dùng backend proxy có quota/budget/expiry/auth; KHÔNG nhúng cloud secret trong APK.

## 8.2. OCR workflow

1. Chọn ảnh → rotate EXIF/crop/perspective/deskew/contrast (giữ original bất biến). 2. OCR text blocks. 3. Tái dựng bảng: line grouping Y; tìm cột bằng geometry + table borders + grid consistency; xử lý merged cell bằng flag uncertainty. 4. Preview editable grid đối chiếu overlay ảnh. 5. Manual confirmation. 6. Infer datatype / mapping; không cho OCR bỏ qua xác nhận ở field khóa hoặc số tiền. 7. Compare và annotate source reference `image/page/polygon`.

## 8.3. Giới hạn kỹ thuật không được che giấu

- Ảnh không chứa workbook metadata, công thức chưa hiển thị, font structural internals, hidden sheet/row, original logical type.
- ML Kit không tự xác định merged cells/headers; bảng nghiêng/chồng lớp/không lưới có thể không phục hồi được.
- OCR probability/confidence: không phải provider nào cũng trả confidence per cell; không được lấy `confidence=1` làm mặc định.
- Không tự đưa OCR text qua AI cloud nếu chưa có opt-in và minh bạch nơi lưu trú dữ liệu.

## 8.4. Metrics OCR

- `CER/WER` kiểm thử nhận dạng ký tự/từ; `cell_exact_accuracy` sau reconstruction; `table_structure_F1` khi có ground truth bounding boxes; `critical_field_error_rate` cho key/money/date; `manual_review_time`; `end_to_end_difference_precision_recall`.
- Bộ kiểm thử tối thiểu đề xuất: nhiều loại ảnh, ánh sáng, lóa, độ nghiêng, số lượng cột, tiếng Việt, ngày/số, merged cells; giá trị chấp nhận phải suy ra từ pilot không tự tuyên bố trước.

## 8.5. API contract cloud optional

`POST /v1/ocr/jobs` nhận ảnh encrypted transit, metadata consent/idempotency; trả `job_id` và TTL. `GET /v1/ocr/jobs/{id}` trả PENDING/PROCESSING/REVIEW_REQUIRED/FAILED, token coords, table geometry, result schema. `DELETE /v1/ocr/jobs/{id}` xóa nội dung theo retention. Hạn mức per-user + max page/byte + backoff, timeout, circuit breaker, tenant isolation. Không cung cấp chức năng này trong offline-only build.
