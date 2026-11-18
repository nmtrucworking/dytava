# Nhận diện thương hiệu Dytava — Precision Workspace

![[system-branding.png]]

> **Thông tin phiên bản:** Chuẩn nhận diện thiết kế **DYTAVA — UI MOCKUP SET (Precision Workspace v3.2 Official Baseline)**.
>
> **Định hướng thiết kế:** **Editorial Minimalism × Data Instrument × Native Interaction**
>
> **Triết lý:** Dytava sở hữu **ngôn ngữ thiết kế riêng đủ mạnh để người dùng nhận diện sản phẩm mà không cần nhìn logo**. Material 3 và Material 3 Expressive là nền tảng về hành vi và accessibility, không phải toàn bộ bản sắc. Dytava là một ứng dụng đối chiếu dữ liệu mang thẩm mỹ của công cụ phân tích chuyên nghiệp (data instrument), nhưng trải nghiệm thao tác mượt mà, tối giản tương tự ứng dụng mobile hiện đại.
>
> **Tagline:** `PRECISION WORKSPACE`
> **Slogan:** "Đối chiếu dữ liệu chính xác, nhanh chóng và rõ ràng." / "Thiết lập quá trình đối chiếu dữ liệu một cách chính xác, linh hoạt và hiệu quả."

---

## 1. Bản sắc thị giác cốt lõi (Precision Visual Identity)

Bản sắc thị giác của Dytava loại bỏ phong cách neon/AI dashboard trang trí rườm rà. Màu nổi bật chỉ xuất hiện khi mang ý nghĩa nghiệp vụ: hành động chính, dữ liệu thay đổi hoặc tình trạng cần chú ý. Toàn bộ phần còn lại sử dụng nền trung tính thanh nhã, typography sắc nét và bố cục có nhịp điệu (editorial rhythm).

### Bộ Logo chính thức · `dytava-svg-logo-pack`

Hệ thống nhận diện thương hiệu sử dụng trọn bộ vector SVG chuẩn từ gói `dytava-svg-logo-pack`:
- **Biểu tượng Monogram D (Spreadsheet Mark):** Chữ D cách điệu từ bảng tính 3D isometric với 2 vạch nhấn so sánh đối chiếu: Vạch trên màu Lime (`#D8F36A`) đại diện cho dữ liệu trùng khớp/tiến trình; Vạch dưới màu Coral (`#E97965`) đại diện cho phát hiện sai lệch.
- **Logotype DYTAVA:** Kiểu chữ hình học đậm nét kết hợp dấu chấm tròn Lime (`#D8F36A`).
- **Tagline tiếng Việt:** "SO SÁNH DỮ LIỆU CHÍNH XÁC" định vị rõ ràng giải pháp đối chiếu chuyên nghiệp.

| Tên tệp SVG | Loại logo | Nền áp dụng | Mục đích sử dụng |
|---|---|---|---|
| `dytava-logo-primary.svg` | Bản đầy đủ (Primary) | Nền sáng (`#F7F6F2`, `#FFFFFF`) | Header Web, Báo cáo PDF/In ấn, Màn hình Splash sáng |
| `dytava-logo-reverse.svg` | Bản đảo ngược (Reverse) | Nền tối (`#0F1A1C`, `#1B2426`) | Dark mode, Footer Web, Thẻ Focus Diff tối |
| `dytava-symbol.svg` | Monogram Mark (Color) | Linh hoạt | Favicon Web, AppBar Mobile, Tab icon, Avatar |
| `dytava-symbol-monochrome.svg` | Monogram Mark (Đơn sắc) | Nền đơn sắc | Watermark, Tài liệu xuất Word/Excel đơn sắc |
| `dytava-app-icon.svg` | App Launcher Icon (Dark) | Nền Graphite | Launcher icon Mobile Android/iOS, PWA App icon |
| `dytava-app-icon-light.svg` | App Launcher Icon (Light) | Nền Off-white | Launcher icon phiên bản sáng tùy chọn |

```
   dytava.
   PRECISION WORKSPACE
   
   [ LIME PRIMARY ]    #C8FF4A   (Lime Primary — hành động chính, active switch, tiến trình nổi bật)
   [ LIME-600 ]        #86E63A   (Lime-600 — viền active, hover state, điểm nhấn sắc nét)
   [ OFF-WHITE ]       #F7F6F2   (Off-white — nền canvas sáng mặc định, bảo vệ thị giác)
   [ WARM SURFACE ]    #EDEBE4   (Warm Surface — bề mặt thẻ card, container nhập liệu)
   [ GRAPHITE ]        #0F1A1C   (Graphite Dark — khối tiêu điểm, chữ chính, header kỹ thuật)
   [ GRAPHITE-800 ]    #1B2426   (Graphite-800 — bề mặt tối cho dark mode, status pill nền tối)
```

### Bảng màu chuẩn · Precision Workspace

| Mã HEX | Token Code | Tên gọi | Vai trò trong hệ thống Precision Workspace |
|---|---|---|---|
| `#C8FF4A` | `limePrimary` | **Lime Primary** | Hành động chính (CTA Pill, "Bắt đầu đối chiếu", "Tiếp tục"), toggle switch active, vòng tròn tiến trình |
| `#86E63A` | `lime600` | **Lime-600** | Điểm nhấn viền active, hover state, chỉ báo tiến trình chạy nền |
| `#F7F6F2` | `offWhite` | **Off-white** | Nền canvas mặc định của ứng dụng và website, thanh nhã và tương phản cao |
| `#EDEBE4` | `warmSurface` | **Warm Surface** | Bề mặt card, container phụ, vùng tải tệp và ô nhập dữ liệu |
| `#0F1A1C` | `graphite` | **Deep Graphite** | Màu văn bản chính, nút phụ tương phản cao, header kỹ thuật |
| `#1B2426` | `graphite800` | **Graphite-800** | Bề mặt container dark mode, nền thẻ Focus Diff, status pill nền đen |
| `#E97965` | `differenceCoral` | **Difference Coral** | Dữ liệu sai khác (`DIFFERENT`), mật độ sai lệch trên fingerprint, cảnh báo giá trị |
| `#10B981` | `coreGreen` | **Emerald Green** | Trạng thái `EXACT` (trùng khớp tuyệt đối 100%), icon Excel xanh lá |
| `#F59E0B` | `coreAmber` | **Amber Warning** | Trạng thái `UNRESOLVED` (cần rà soát thủ công, độ tin cậy OCR thấp) |
| `#38BDF8` | `sourceBlue` | **Source Blue** | Phân định luồng dữ liệu Nguồn B |
| `#D8D5CC` | `borderSubtle` | **Subtle Divider** | Đường kẻ hairline, phân chia ô dữ liệu và biên giới card |

> **Nguyên tắc nền sáng / tối:** Giao diện sáng thanh nhã (`#F7F6F2`) kết hợp bề mặt ấm (`#EDEBE4`) là mặc định cho vùng đọc bảng để đảm bảo tương phản văn bản cao nhất mà không gây lóa mắt. Nền graphite (`#0F1A1C` / `#1B2426`) được sử dụng ở các thành phần trọng điểm (hero card, container Focus Diff) hoặc qua chế độ tối toàn diện khi người dùng kích hoạt.

---

## 2. Hệ thống Typography chuẩn

Theo UI Mockup Set của Precision Workspace:

| Phân cấp | Phông chữ | Trọng số (Weight) | Vai trò |
|---|---|---|---|
| **Display / Tiêu đề** | **Manrope** | Bold (700), ExtraBold (850) | Tiêu đề chính (H1, H2, H3), tên thương hiệu, điểm nhấn chính |
| **Interface / Nội dung** | **Inter (System)** | Regular (400), Medium (500), SemiBold (600) | Nội dung mô tả, nhãn nút, hướng dẫn thao tác |
| **Data / Số liệu & Mã** | **Inter (Tabular)** | Regular (400), Bold (700) | Bảng tính, số dòng, mã định danh, số liệu tài chính (`tabular-nums lining-nums`) |

*Fallback offline an toàn:* `Plus Jakarta Sans` cho Display, `Be Vietnam Pro` cho Interface, `IBM Plex Mono` cho Mono code.

---

## 3. Signature Components (Linh kiện nhận diện cốt lõi)

1. **Nút chính (Primary Action):**
   - Hình khối: Bo góc tròn hoàn toàn dạng viên con nhộng (**Pill**, `border-radius: 9999px`).
   - Nền: **Lime Primary (`#C8FF4A`)**.
   - Văn bản: **Graphite (`#0F1A1C`)**, font Manrope Bold.
   - Đi kèm biểu tượng điều hướng: mũi tên phải `→` hoặc dấu kiểm `✓`.
2. **Nút phụ (Secondary Action):**
   - Hình khối: Pill bo tròn.
   - Nền: **Warm Surface (`#EDEBE4`)** hoặc viền mảnh Graphite.
   - Văn bản: **Graphite (`#0F1A1C`)**.
3. **Thẻ trạng thái (Status Pill):**
   - Nền tối Graphite-800 (`#1B2426`) với chữ và chấm tròn phát sáng Lime Primary (`#C8FF4A`): `● Đang tiến hành`.
4. **Thẻ tệp (File Card):**
   - Bo góc 16px, nền Warm Surface (`#EDEBE4`) hoặc Graphite-800.
   - Huy hiệu icon Excel xanh lá nổi bật (với chữ `X`), tên tệp (vd: `DanhSach_A.xlsx`), số dòng và kích thước.
5. **Biểu đồ dữ liệu trực quan (Data Viz):**
   - **Difference Fingerprint:** Bản đồ ma trận phân bổ sai khác theo sheet và cột với phân vùng màu sắc: Trùng khớp, Khác biệt (`#E97965`), Chỉ có ở A (`#C8FF4A`), Chỉ có ở B (`#38BDF8`).
   - **Vòng tròn tiến trình (Donut Ring):** Vòng cung Lime rực rỡ thể hiện tỷ lệ trùng khớp (vd: `96,8% Trùng khớp`) hoặc tiến trình xử lý (`68% Đang so sánh...`).
6. **Cụm chọn nguồn đầu vào (Core Entry):**
   - 3 lựa chọn trực quan: (1) Tải tệp từ thiết bị, (2) Quét từ ảnh (OCR), (3) Dùng dữ liệu mẫu.

---

## 4. Kiến trúc màn hình 4 Boards (UI Mockup Set Architecture)

### Board 01 · Core Entry & Input
1. **Trang chủ:** Tổng quan và truy cập nhanh phiên đang thực hiện, danh sách phiên gần đây, bottom bar (Trang chủ, Lịch sử, Cài đặt).
2. **Tạo phiên đối chiếu:** Chọn cách thêm dữ liệu: Tải tệp từ thiết bị, Quét từ ảnh (OCR) hoặc Dùng dữ liệu mẫu.
3. **Chọn nguồn dữ liệu:** Thiết lập Nguồn A và Nguồn B với các định dạng linh hoạt (.xlsx, .csv, v.v.).
4. **Xem trước dữ liệu:** Kiểm tra thông tin tệp và xem trước bảng dữ liệu (10 dòng đầu) trước khi chạy so sánh.
5. **Tiếp tục phiên:** Quản lý và tiếp tục các phiên đối chiếu gần đây kèm chỉ báo tiến độ %.

### Board 02 · Setup & Processing
1. **Ánh xạ cột (Bước 1/5):** Ghép các cột tương ứng giữa hai nguồn dữ liệu và kiểm tra các cột cần xác minh.
2. **Chọn khóa đối chiếu (Bước 2/5):** Chọn cột khóa (hoặc tổ hợp khóa) để định danh và ghép bản ghi chính xác (kèm dự kiến tỷ lệ ghép thành công).
3. **Quy tắc chuẩn hóa (Bước 3/5):** Thiết lập các quy tắc xử lý dữ liệu trước khi so sánh: Bỏ khoảng trắng thừa, Không phân biệt hoa/thường, Chuẩn hóa ngày tháng, Làm tròn số thập phân, Bỏ dấu tiếng Việt, So sánh theo kiểu dữ liệu.
4. **Phạm vi & xác nhận (Bước 4/5):** Chọn phạm vi dữ liệu cần xử lý (toàn bộ, chọn sheet, chọn cột) và kiểm tra lại toàn bộ tóm tắt cấu hình.
5. **Đang xử lý (Bước 5/5):** Thực hiện đối chiếu theo cấu hình và hiển thị tiến trình chi tiết (checklist từng bước: Đọc nguồn A, Đọc nguồn B, Chuẩn hóa dữ liệu, Ánh xạ & ghép bản ghi, Tổng hợp kết quả).

### Board 03 · Results & Difference Analysis
1. **Kết quả tổng quan:** Tổng hợp kết quả so sánh, tỷ lệ trùng khớp (Donut chart), tổng dòng, tổng cột, số lượng sai khác và cần xem xét.
2. **Bản đồ sai khác:** Trực quan hóa phân bổ sai khác theo từng sheet (Difference Fingerprint matrix).
3. **Focus Diff:** Xem chi tiết và so sánh giá trị cũ (A) và giá trị mới (B) của từng bản ghi với thao tác vuốt mượt mà.
4. **Danh sách sai khác:** Danh sách các bản ghi sai khác, phân loại theo tabs (Tất cả, Giá trị, Thiếu dòng, Thêm dòng, Định dạng).
5. **Chi tiết sai khác:** Thông tin đầy đủ về một sai khác cụ thể, gợi ý kiểm tra và nút thao tác nhanh (Đánh dấu đã xem, Xem ngữ cảnh).

### Board 04 · OCR, Export, History & Settings
1. **OCR chụp ảnh:** Nhận diện dữ liệu bảng từ ảnh bằng camera, tự động phát hiện vùng bảng.
2. **Điều chỉnh vùng:** Tinh chỉnh vùng nhận diện bảng, xoay hoặc cắt lại để tăng độ chính xác.
3. **Kiểm tra OCR:** Xem, chỉnh sửa kết quả nhận dạng và xử lý các ô có độ tin cậy thấp trước khi sử dụng.
4. **Xuất báo cáo:** Xuất kết quả đối chiếu dưới nhiều định dạng (PDF báo cáo, Excel kết quả, CSV sai khác) hoặc chia sẻ liên kết.
5. **Lịch sử phiên:** Quản lý và xem lại các phiên đối chiếu đã thực hiện theo trạng thái và thống kê nhanh.
6. **Cài đặt:** Tùy chỉnh quy tắc mặc định, OCR, định dạng số, xuất báo cáo, thông báo, chế độ tối và màu nhấn Lime.

---

## 5. Hệ thống biểu trưng và Wordmark

- **Wordmark:** `dytava.` — chữ thường, nét đậm hình học, dấu chấm dứt khoát mang tính biểu thị công cụ dữ liệu chính xác.
- **Biểu trưng độc lập (Symbol):** Thẻ kép Cyan/Purple với biểu đồ 3 cột và huy hiệu kiểm định, đại diện cho bản quyền công nghệ lõi.
- **Biến thể nhận diện:**
  - `dytava-horizontal.svg`: Logo trên nền sáng Off-white.
  - `dytava-horizontal-white.svg`: Logo đơn sắc trắng trên nền Graphite.
  - `dytava-pill-blue.svg`: Huy hiệu container cho xuất bản.
