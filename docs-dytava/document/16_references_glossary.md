# 16. Nguồn kỹ thuật, thuật ngữ, giới hạn xác minh

## 16.1. Nguồn tài liệu kỹ thuật chính thức (kiểm tra ngày 22/10/2026)

[R1] Android App architecture recommendations, https://developer.android.com/topic/architecture/recommendations . Separation of concerns, UI/data/domain layers, coroutines, Compose, testing.

[R2] Android Storage Access Framework, https://developer.android.com/guide/topics/providers/document-provider . User-selected document access and persistable URI permissions.

[R3] Apache POI HSSF/XSSF/SXSSF overview, https://poi.apache.org/components/spreadsheet/ . Event reader và memory trade-off.

[R4] Apache POI limitations, https://poi.apache.org/components/spreadsheet/limitations.html . Giới hạn workbook và bộ nhớ.

[R5] Apache POI configuration / ZipSecureFile, https://poi.apache.org/components/configuration.html . Zipbomb guardrails.

[R6] Apache Tika supported formats, https://tika.apache.org/docs/4.0.x/formats.html . OOXML, ODF, legacy Office extraction background; không suy ra Android compatibility từ đây.

[R7] Google ML Kit Text Recognition Android, https://developers.google.com/ml-kit/vision/text-recognition/v2/android . OCR models và dependencies.

[R8] ML Kit supported languages, https://developers.google.com/ml-kit/vision/text-recognition/v2/languages . Tiếng Việt Latin.

[R9] Microsoft Azure Document Intelligence Layout, https://learn.microsoft.com/azure/ai-services/document-intelligence/prebuilt/layout . Table extraction, file and size constraints.

[R10] Google Document AI Layout Parser, https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk . Layout and supported formats; cloud feature is optional.

[R11] OWASP MASVS, https://mas.owasp.org/MASVS/ . Security controls for mobile apps.

[R12] OWASP CSV injection, https://owasp.org/www-community/attacks/CSV_Injection . Protection of spreadsheet export.

[R13] Room migrations, https://developer.android.com/training/data-storage/room/migrating-db-versions . Schema/migration tests.

[R14] RFC 4180, https://www.rfc-editor.org/rfc/rfc4180 . CSV formats / MIME type.

## 16.2. Thuật ngữ

`Workbook`: tệp bảng tính; `Worksheet`: sheet; `Schema`: cột và các thuộc tính; `Field`: trường/cột logic; `Record`: bản ghi/hàng logic; `Physical dtype`: kiểu lưu trữ; `Semantic dtype`: loại ý nghĩa nghiệp vụ; `Canonicalization`: quy về biểu diễn có quy tắc; `Provenance`: truy nguồn chính xác; `Unresolved`: không đủ căn cứ để kết luận; `OCR`: nhận dạng chữ trong ảnh; `Layout parsing`: xác định cấu trúc tài liệu; `PoC`: thử nghiệm khả thi kỹ thuật; `SLO`: mục tiêu mức độ dịch vụ; `RACI`: phân vai chịu trách nhiệm/phê duyệt/tham vấn/nhận tin.

## 16.3. Căn cứ và giả định

Nguồn ban đầu là yêu cầu đề tài số 3 do người dùng cung cấp: so sánh hai file Excel, thống kê giống/khác, chỉ rõ sai khác, đọc ảnh chụp, đóng gói file cài đặt. Các chức năng mở rộng dtype, chuẩn hóa ngữ nghĩa, kiến trúc và vận hành là **đề xuất thiết kế của tài liệu này**, không phải yêu cầu đã được khách hàng/giảng viên duyệt. Không phải tất cả công nghệ đề cập đã được POC, đo hiệu năng, xác nhận giá dịch vụ hay tích hợp thực tế.
