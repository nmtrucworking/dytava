---
version: 0.1.0
status: draft
platform: Flutter — Android P0 / iOS P1
---
# INP-001 — Input Scope Specification

## 1. Mục đích

Đặc tả phạm vi dữ liệu đầu vào của Dytava (ExcelCompare), làm cơ sở thiết kế File Import, Data Parsing, Validation và Comparison Engine.

## 2. Định nghĩa Input

Input là tập hợp dữ liệu nguồn và cấu hình cần thiết để hệ thống thực hiện một phiên so sánh.

Một phiên so sánh tiếp nhận hai nguồn dữ liệu:

- **Source A:** Nguồn dữ liệu thứ nhất.
    
- **Source B:** Nguồn dữ liệu thứ hai.
    

Vai trò nguồn gốc/bản cập nhật của A và B sẽ được xác định trong cấu hình phiên so sánh.

## 3. Các thành phần Input

|Thành phần|Mô tả|
|---|---|
|Input Artifact|Tệp dữ liệu được người dùng lựa chọn|
|File Metadata|Tên, dung lượng, định dạng và thông tin nhận diện tệp|
|Source Structure|Sheet, bảng, hàng, cột và ô dữ liệu|
|Raw Data|Giá trị và kiểu dữ liệu thực tế từ nguồn|
|Provenance|Thông tin xác định vị trí và nguồn gốc dữ liệu|
|Import Configuration|Cấu hình đọc và diễn giải cấu trúc nguồn|
|Comparison Configuration|Mapping, khóa và chính sách so sánh do người dùng xác nhận|

## 4. Phạm vi định dạng

Theo baseline thiết kế Flutter 2.2:

**P0 — Android MVP**

- XLSX
    
- CSV
    
- TSV
    
- JSON dạng bản ghi
    

**P1 — Mở rộng**

- JSONL / NDJSON
    
- XLS
    
- XLSM
    
- ODS
    

**P2 — Mở rộng nâng cao**

- PDF
    
- Hình ảnh thông qua OCR
    
- XML
    
- HTML Table
    
- XLSB
    

Danh sách trên là phạm vi dự kiến, không đồng nghĩa tất cả adapter đã được triển khai hoặc kiểm thử.

## 5. Ranh giới xử lý

**Input Subsystem chịu trách nhiệm:**

- Tiếp nhận tệp.
    
- Kiểm tra định dạng và tính hợp lệ.
    
- Trích xuất cấu trúc và dữ liệu gốc.
    
- Bảo toàn provenance.
    
- Cung cấp dữ liệu có cấu trúc cho Comparison Engine.
    

**Input Subsystem không chịu trách nhiệm:**

- Kết luận hai giá trị có tương đương hay không.
    
- Xác định các hàng được thêm, xóa hoặc thay đổi.
    
- Tính toán thống kê sai khác.
    
- Tạo báo cáo so sánh cuối cùng.
    

## 6. Nguyên tắc bắt buộc

1. Không thay đổi nội dung tệp nguồn.
    
2. Không tự động chuyển đổi kiểu dữ liệu gây mất thông tin.
    
3. Phân biệt giá trị gốc, giá trị hiển thị và giá trị đã chuẩn hóa.
    
4. Không suy đoán khi định dạng hoặc kiểu dữ liệu không rõ ràng.
    
5. Bảo toàn khả năng truy vết về dữ liệu nguồn.
    

## 7. Vấn đề chưa quyết định

- Source A có mặc định là bản gốc và Source B là bản cập nhật không?
    
- Mỗi nguồn được phép chọn bao nhiêu sheet trong một phiên?
    
- OCR có bắt buộc ngay trong P0 theo yêu cầu học phần hay được triển khai ở P2?
    

**Trạng thái:** Đang biên soạn, chưa phê duyệt.