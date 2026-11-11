# 01. Product Brief và quyết định phạm vi

**Mã dự án:** EXC; **tên làm việc:** ExcelCompare; **bản tài liệu:** 1.0-DESIGN; **ngày:** 22/10/2026; **nền tảng mục tiêu:** Android/Kotlin; **trạng thái:** baseline thiết kế, chưa chứng nhận production.

## 1.1. Tuyên bố vấn đề

Nhiều hệ thống xuất báo cáo dạng bảng tính nhưng cùng dữ liệu có thể khác tên cột, thứ tự hàng, kiểu lưu trữ, cách viết ngày/số, công thức và metadata. So sánh hai tệp bằng cách nhìn trực tiếp hoặc so từng tọa độ ô gây báo sai khác giả và bỏ sót sai khác nghiệp vụ. Ảnh chụp là nguồn đầu vào khó hơn vì chỉ giữ lại biểu diễn trực quan và không thể truy cập các thuộc tính ẩn trong workbook.

## 1.2. Giá trị sản phẩm

Ứng dụng tiếp nhận hai nguồn dạng bảng, ánh xạ schema, xác định định danh hàng, chuẩn hóa theo **quy tắc công khai**, đưa ra kết luận có thể truy vết (*exact / equivalent / different / unresolved*), xem chi tiết ô/bản ghi khác biệt và xuất báo cáo kiểm toán. Không thay đổi dữ liệu nguồn.

## 1.3. Người dùng mục tiêu và các trường hợp sử dụng

| Người dùng | Nhu cầu | Ưu tiên |
|---|---|---|
| Sinh viên/kế toán/nhân sự | So danh sách, điểm số, công nợ, kiểm kê giữa hai lần xuất | P0 |
| Nhân viên kiểm thử dữ liệu | So đầu ra của hai hệ thống sau migrate | P0 |
| Quản trị dữ liệu | Ánh xạ schema, audit, quy tắc chuẩn hóa | P1 |
| Người dùng chỉ có ảnh chụp | OCR bảng đơn giản, hiệu chỉnh rồi so | P2 |

## 1.4. In scope / out of scope

**P0 - MVP:** Android offline; import XLSX/CSV/TSV/JSON dạng bản ghi theo adapter; xem preview, chọn sheet/table, header row; mapping cột thủ công; xác định key đơn/ghép; chuẩn hóa text/decimal/date/boolean/identifier/percentage; đối chiếu record; xuất CSV/XLSX báo cáo đơn giản an toàn; lưu cấu hình và lịch sử so sánh có kiểm soát.

**P1:** XLS legacy theo proof-of-concept, xlsm chỉ đọc dữ liệu và không chạy macro, ODS adapter riêng, metadata/công thức ở chế độ báo cáo, gợi ý mapping an toàn, xử lý dữ liệu lớn streaming, quy tắc tái sử dụng.

**P2:** OCR ML Kit với xác nhận ô; cloud layout OCR opt-in; XLSB/PDF/XML/HTML/JSONL; tích hợp hệ thống ngoài; sync đa thiết bị.

**Không cam kết:** mọi công thức Excel tái tính được; suy luận đúng 100% schema/locale; khôi phục macro; ảnh OCR có metadata Excel; tự động sửa file gốc; phát hiện gian lận doanh nghiệp chỉ bằng sự khác biệt.

## 1.5. Chỉ số thành công và ranh giới trách nhiệm

| Nhóm | Chỉ số đề xuất (chưa đo) | Điều kiện nghiệm thu |
|---|---|---|
| An toàn dữ liệu | 0 lần ghi vào nguồn; 0 nội dung ô trong telemetry | kiểm thử có chứng cứ |
| Độ đúng | 100% các quy tắc chuẩn hóa có unit test và golden fixture | không tự tương đương khi ambiguous |
| Truy vết | 100% difference có source coordinate + rule version hoặc lý do missing | review report |
| Ổn định | Không crash/OOM trên bộ stress đã chốt cho thiết bị tham chiếu | benchmark thực nghiệm |
| Định lượng | Có precision, recall, unresolved rate, elapsed time, peak memory | công bố số đo kèm dữ liệu và cấu hình |

**Quyết định sản phẩm:** ‘production-grade specification’ khác ‘production-qualified product’. Các SLO sẽ chỉ được cam kết sau khi đo trên thiết bị và corpus thực tế.
