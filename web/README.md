# Dytava (ExcelCompare) — Web & Admin Portal

Hệ thống website giới thiệu sản phẩm và trang quản trị sản phẩm tập trung cho công cụ so sánh bảng tính **Dytava (ExcelCompare)**, tham chiếu giao diện và trải nghiệm người dùng hiện đại từ [ExcelCompare.org](https://excelcompare.org/).

---

## 🌟 Tính Năng Nổi Bật

### 1. Website Giới Thiệu Sản Phẩm & Công Cụ So Sánh Trực Tuyến (`#/`)
- **Giao diện hiện đại & Thân thiện:** Thiết kế theo quy chuẩn nhận diện thương hiệu Dytava v2.0 (Màu xanh Navy `#0F172A`, Brand Blue `#2563EB`, Canvas `#F3F4F6` và Dark Mode).
- **100% Client-Side Privacy:** Toàn bộ quá trình tính toán, chuẩn hóa và so sánh dữ liệu diễn ra cục bộ trong trình duyệt người dùng. Không tải file hay dữ liệu nhạy cảm lên bất kỳ máy chủ nào.
- **Công cụ So Sánh Bảng Tính Trực Tiếp (Spreadsheet Diff Tool):**
  - Hỗ trợ kéo thả hoặc chọn tệp `.xlsx`, `.csv`, `.tsv`, `.txt`, `.json`.
  - Tích hợp sẵn 3 bộ dữ liệu mẫu thực tế:
    1. *Bảng điểm & Hồ sơ học tập (Academic Records)*: Kiểm tra dấu phẩy thập phân kiểu Việt Nam (`8.5` vs `8,5`), mã SV, điểm số.
    2. *Báo cáo Doanh thu & Chi phí Q3 vs Q4 (Finance & P&L)*: Kiểm tra dung sai tiền tệ, tỷ lệ chiết khấu (`5%` vs `0.05`), ngày ghi nhận ISO.
    3. *Kiểm kê Kho vận & SKU Vật tư (Supply Chain)*: Kiểm tra bảo toàn số 0 đứng trước ở mã định danh (`00492 ≠ 492`).
  - **Tự động Căn Chỉnh theo Cột Khóa (Key-based Alignment):** Không phụ thuộc vào thứ tự hàng, tự động ghép dòng theo khóa chính (ID, Mã SV, SKU, Mã đơn).
  - **Lưới Đối Chiếu Song Song Đồng Bộ (Side-by-Side Dual Grid):**
    - Tự động đồng bộ cuộn trang (Synchronized scrolling) giữa 2 bảng.
    - Tô màu trực quan 4 trạng thái theo chuẩn PRD:
      - 🟢 **EXACT** (`#10B981`): Giống tuyệt đối.
      - 🔵 **EQUIVALENT** (`#2563EB`): Khác format/scale nhưng tương đương ngữ nghĩa.
      - 🔴 **DIFFERENT** (`#EF4444`): Khác biệt nghiệp vụ thực tế.
      - 🟡 **UNRESOLVED** (`#F59E0B`): Mơ hồ, cần người dùng thẩm định.
  - **Cửa sổ Thẩm Tra Ô (Cell Inspector Modal):** Bấm vào ô bất kỳ để xem giá trị thô, giá trị chuẩn hóa, mã quy tắc (Rule ID) và lý do chi tiết.
  - **Xuất Báo Cáo:** Xuất tệp CSV khác biệt và biên bản kiểm toán JSON chuẩn theo hồ sơ thiết kế EXC.

---

### 2. Trang Quản Trị Sản Phẩm Tập Trung (`#/admin`)
- **📊 Tổng Quan & KPIs (Overview):**
  - Theo dõi tổng số phiên so sánh, tỷ lệ tương đương ngữ nghĩa, tỷ lệ unresolved, thời gian xử lý trung bình (38ms).
  - Biểu đồ phân bố định dạng tệp (XLSX, CSV, JSON, OCR Scan).
  - Luồng hoạt động kiểm toán gần nhất.
- **🚀 Quản Lý Bản Phát Hành (Releases & Builds):**
  - Danh sách bản phát hành các nền tảng: Android Native (APK/AAB), Web WASM Client, CLI Daemon, Python SDK.
  - Quản lý mã băm SHA256, dung lượng, ghi chú thay đổi (Changelog).
  - Modal tạo bản phát hành mới.
- **⚙️ Bộ Quy Tắc & Chính Sách DType (Policies & Rules):**
  - Quản lý các cấu hình policy: `academic-records-v1`, `financial-audit-v2`, `inventory-sku-v1`.
  - **Trình Thẩm Định Quy Tắc Trực Tiếp (Policy Tester):** Nhập 2 giá trị và kiểu dữ liệu để engine phân loại ngay lập tức.
- **🧪 Kiểm Thử Chấp Nhận (Acceptance Test Suite):**
  - Chạy toàn bộ 10 kịch bản kiểm thử Golden Fixtures (TC-01 đến TC-10) từ tài liệu EXC.
  - Tỷ lệ đạt chuẩn: **10/10 Passed (100%)**.
- **📜 Nhật Ký Kiểm Toán (Zero-PII Audit Trail):**
  - Danh sách biên bản kiểm toán có mã băm SHA256 và thông số phiên mà không vi phạm dữ liệu cá nhân (Zero-PII).
- **🚩 Cờ Tính Năng (Feature Flags):**
  - Bật/tắt các tính năng theo lộ trình P0 (MVP), P1 và P2.

---

## 🚀 Hướng Dẫn Khởi Chạy

### Cách 1: Sử dụng máy chủ Node.js tích hợp (Khuyên dùng)
```bash
# Khởi chạy máy chủ nội bộ (Zero-dependency)
node web/server.js
```
Truy cập:
- **Website & Tool So sánh:** `http://localhost:3000`
- **Trang Quản trị Admin:** `http://localhost:3000/#/admin/overview`

### Cách 2: Mở trực tiếp trong trình duyệt
Bạn có thể mở tệp `web/index.html` trực tiếp bằng bất kỳ trình duyệt nào (Chrome, Safari, Firefox, Edge).
Hoặc dùng Python:
```bash
python3 -m http.server 3000 -d web
```

---

## 📁 Cấu Trúc Thư Mục `web/`

```
web/
├── index.html            # Giao diện chính kết hợp Website giới thiệu và Admin Portal
├── server.js             # Máy chủ HTTP Node.js gọn nhẹ, zero-dependency
├── css/
│   └── style.css         # Hệ thống thiết kế Dytava v2.0 Tokens & Responsive Styles
├── js/
│   ├── app.js            # Controller chính, điều hướng routing và sự kiện
│   ├── compare-engine.js # Core Semantic Comparison & Alignment Engine
│   ├── admin-portal.js   # Quản lý KPI, Releases, Policies & Acceptance Suite
│   └── sample-data.js    # 3 bộ dữ liệu mẫu thực tế (Academic, Finance, Inventory)
└── assets/               # Brand assets gốc: SVG logos, app icons, design tokens
```

## Đồng bộ branding

Kho chính thức: `branding/mobile/assets/dytava/` và
`branding/DYTAVA_Illustration_Library_v1/mobile/assets/dytava/illustrations/`.
Chạy `npm run branding:sync` tại gốc dự án để đồng bộ SVG cho web và mobile.
`npm run build` tự đồng bộ tài nguyên web và sinh `css/brand-tokens.css` từ palette đã duyệt.
Không chỉnh các bản SVG đã sao chép trong `web/assets/dytava/`; sửa nguồn trong `branding/` rồi đồng bộ lại.

Web dùng logo sáng/tối, functional icons, illustration cho hero, xử lý, lỗi,
lịch sử trống, bộ lọc trống và trang hướng dẫn/quyền riêng tư. Chỉ đóng gói SVG,
không tải PNG 4K vào giao diện. Màu chính xanh dương, nhập tệp xanh lá, xuất báo cáo tím.
