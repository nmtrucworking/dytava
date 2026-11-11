# 10. Threat model, bảo mật và quản trị dữ liệu

## 10.1. Tài sản cần bảo vệ

Bảng điểm/danh sách nhân sự, mã khách hàng, dữ liệu kế toán, ảnh chụp, policy và report, phiên so sánh. Input tệp được xem là **untrusted content** ngay cả khi người dùng chọn trực tiếp.

## 10.2. Threat model (STRIDE rút gọn)

| Rủi ro | Biện pháp |
|---|---|
| Zip bomb/OOXML oversize | giới hạn extract/entry count/compression ratio, parse streaming, fail closed |
| XML entity expansion/XXE | secure parser, disable external DTD/entities, no outbound references |
| Spreadsheet formula injection lúc export | mọi user-controlled raw text viết thành string cell và escape CSV, test bằng Excel/LibreOffice |
| Macro/external link execution | read-only, never run VBA/active content; no external formula resolution |
| Lộ file trên máy | SAF user grant, app-internal private cache, TTL, no world-readable exports |
| Lộ thông tin qua logs/crash | redact by design, telemetry opt-in, aggregate-only metrics |
| API key leak | none in APK, server-side secret manager (nếu bật cloud) |
| Man-in-the-middle | TLS, standard cert validation, no trust-all certificates |
| Cloud vendor disclosure | explicit consent, visible recipient/purpose, retention control, data minimization |
| Report tampering | manifest hash/signature optional; compare hash before audit |
| Stale cache/confusing old report | bind input sha, config revision, engine/report version |
| Local DB sensitive data at rest | Room is not encryption by default; assess SQLCipher/Keystore-backed protection or no raw data persistence |

## 10.3. Privacy by design

Default không gửi file lên server; không yêu cầu danh bạ, vị trí, quyền quản lý mọi file, không thu thập raw dữ liệu cho phân tích. Xóa tệp tạm sau session hoặc thời gian ngắn được cấu hình; cho người dùng xóa toàn bộ lịch sử. Export public phải do người dùng chủ động chọn nơi lưu.

**Chính sách lưu trữ baseline:** Original copy tạm xóa khi hoàn tất hoặc 24 giờ nếu người dùng cần tiếp tục; parsed content và report cached lưu chỉ khi opt-in, mặc định tối thiểu; chỉ số tổng hợp có thể giữ 30 ngày. Đây là đề xuất sản phẩm, phải được thực hiện và công bố rõ, không phải một cam kết hiện có.

## 10.4. Security testing gates

SAST/dependency audit, SBOM, malformed workbook fuzzing, zipbomb tests, CSV injection tests, URI lifecycle tests, Android backup inspection, logs inspection, MASVS storage/platform/privacy checks, cloud key exposure tests nếu có cloud.

## 10.5. Tuân thủ và pháp lý

Đánh giá quy định bảo vệ dữ liệu áp dụng theo thị trường triển khai trước khi xử lý tài liệu có dữ liệu cá nhân và trước khi truyền cloud. Không tuyên bố ISO/SOC2/GDPR/VN-law compliance nếu chưa có đánh giá, bằng chứng và quy trình tương ứng.
