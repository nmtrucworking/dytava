# Nhận diện thương hiệu chính thức Dytava (Official Brand Identity v2.0)

![[system-branding.png]]

> **Thông tin phiên bản:** Phiên bản nhận diện thương hiệu v2.0 được phê duyệt chính thức cho dự án Dytava (ExcelCompare Mobile / Flutter).

---

## 1. Tổng quan và triết lý thiết kế

Logo Dytava kết hợp các thành phần cốt lõi:
- **Hai lớp thẻ dữ liệu xếp chồng:**
  - Lớp thẻ sau (Cyan gradient `#06B6D4`): Tượng trưng cho dữ liệu gốc và bảng tính nguồn.
  - Lớp thẻ trước (Purple gradient `#8B5CF6`): Tượng trưng cho dữ liệu đã chuẩn hóa và phân tích thông minh, với đồ thị 3 cột tăng dần màu trắng.
- **Huy hiệu dấu kiểm xác thực (Verification Badge):** Vòng tròn xanh `#2563EB` với dấu tick trắng ở góc dưới, thể hiện sự chính xác tuyệt đối và tin cậy của thuật toán so sánh.
- **Wordmark "dytava":** Chữ thường, nét đậm hiện đại, bo tròn góc, phông chữ Inter / Roboto.

---

## 2. Bảng màu thương hiệu (Official Color Palette)

| Mã HEX | Tên gọi | Vai trò trong hệ thống |
|---|---|---|
| `#2563EB` | **Primary Royal Blue** | Nút chính ("So sánh ngay", "Xác nhận"), trạng thái `EQUIVALENT`, màu nhận diện chính |
| `#3B82F6` | **Sky Blue** | Màu phụ, điểm sáng gradient, icon điều hướng |
| `#8B5CF6` | **Purple Accent** | Nút "Xuất báo cáo", nhóm "Ánh xạ cột", "Học tập", "Cài đặt" |
| `#06B6D4` | **Cyan Accent** | Điểm nhấn trích xuất OCR, bảng tính nền |
| `#10B981` | **Emerald Green** | Nút "Nhập tệp", tính năng "So sánh Excel", trạng thái `EXACT`, badge "Hoàn thành" |
| `#F59E0B` | **Amber Warning** | Trạng thái `UNRESOLVED`, cảnh báo đối soát cần xác nhận |
| `#EF4444` | **Crimson Danger** | Nút "Xóa", cảnh báo lỗi, trạng thái `DIFFERENT` |
| `#F3F4F6` | **Neutral Background**| Nền giao diện, khối container thẻ, vùng nhập rỗng |
| `#E5E7EB` | **Divider / Border** | Đường phân cách, viền thẻ và bảng tính |
| `#FFFFFF` | **Pure White** | Nền thẻ bề mặt, chữ nổi trên nền màu |

---

## 3. Hệ thống biểu tượng và App Icon

### Biến thể Logo
- **Logo chính (Full-color on light):** `branding/mobile/assets/dytava/brand/svg/dytava-horizontal.svg`
- **Biến thể Nút Xanh (Pill Badge):** `branding/mobile/assets/dytava/brand/svg/dytava-pill-blue.svg`
- **Biến thể Nền tối (Dark Mode):** `branding/mobile/assets/dytava/brand/svg/dytava-horizontal-white.svg`
- **Biểu trưng độc lập (Symbol):** `branding/mobile/assets/dytava/brand/svg/dytava-symbol.svg`

### Biểu tượng ứng dụng (App Icon Suite)
- **Squircle Gradient Xanh:** `dytava-app.svg`
- **Squircle Tím Tinh tế:** `dytava-app-purple.svg`
- **Tròn Xanh Hoàng Gia:** `dytava-app-circle.svg`
- **iOS 1024 Fullbleed:** `dytava-ios-fullbleed.svg`
- **Android Adaptive:** `android-adaptive-foreground.svg`

---

## 4. Danh mục 11 nhóm tính năng chính (Core Features)

1. **So sánh Excel:** Đối soát dữ liệu bảng tính tự động.
2. **OCR (Ảnh -> Bảng):** Quét hình ảnh, hóa đơn và chuyển thành bảng dữ liệu.
3. **Nhập dữ liệu:** Tải tệp XLSX, XLS, CSV, TSV, JSON, XML...
4. **Ánh xạ cột:** Ghép nối các trường tương đương giữa hai nguồn dữ liệu.
5. **Quy tắc chuẩn hóa:** Xây dựng và áp dụng bộ chuẩn hóa dữ liệu tự động.
6. **Báo cáo:** Xuất báo cáo kết quả đối soát.
7. **Lịch sử:** Tra cứu các phiên làm việc và đối soát gần nhất.
8. **Mẫu quy tắc:** Lưu trữ và tái sử dụng bộ chính sách (Policy).
9. **Học tập:** Hướng dẫn sử dụng và tài liệu hỗ trợ.
10. **Giới thiệu:** Thông tin ứng dụng và điều khoản bảo mật offline.
11. **Cài đặt:** Tùy chọn cấu hình, ngôn ngữ và giao diện.

---

## 5. Quy chuẩn 4 trạng thái so sánh (Comparison Semantics)

- **EXACT (`#10B981`):** Hai ô trùng khớp chính xác 100%.
- **EQUIVALENT (`#2563EB`):** Hai ô khác biểu diễn chữ nhưng tương đương giá trị theo quy tắc chuẩn hóa.
- **DIFFERENT (`#EF4444`):** Hai ô khác biệt rõ rệt về dữ liệu.
- **UNRESOLVED (`#F59E0B`):** Chưa đủ cơ sở kết luận (cần người dùng kiểm tra thủ công).

---

## 6. Trang trưng bày HTML và tra cứu

- **Brand Showcase chính thức:** Mở tệp `branding/index.html` trên trình duyệt để xem toàn diện bảng màu, kiểu chữ, logo và các linh kiện UI trực quan có thể tương tác.
- **Icon Vault 4K:** Mở `branding/catalog/index.html` để tìm kiếm và tải về 116+ icons và 18 định dạng tệp.
