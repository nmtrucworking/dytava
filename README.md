<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="web/assets/dytava-reversed-horizontal.svg">
    <source media="(prefers-color-scheme: light)" srcset="web/assets/dytava-primary-horizontal.svg">
    <img alt="Dytava / ExcelCompare Logo" src="web/assets/dytava-primary-horizontal.svg" width="560">
  </picture>
</p>

<p align="center">
  <strong>Understand every difference.</strong><br>
  Privacy-first, multi-platform spreadsheet comparison and semantic difference engine.
</p>

<p align="center">
  <a href="https://github.com/nmtrucworking/dytava/actions"><img src="https://img.shields.io/badge/CI-Passing-22c55e?style=for-the-badge&logo=github-actions&logoColor=white" alt="CI Status"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-24%2B-339933?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js"></a>
  <a href="#-privacy-first-architecture"><img src="https://img.shields.io/badge/Privacy-100%25%20Client--Side-blueviolet?style=for-the-badge&logo=shield" alt="Privacy First"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License"></a>
</p>

---

## 📌 Tổng Quan / Overview

**Dytava** (còn được biết đến qua bộ giải pháp **ExcelCompare**) là nền tảng so sánh bảng tính và dữ liệu phân tích sai khác ngữ nghĩa (semantic diff) đa nền tảng hiện đại. Dự án được thiết kế theo mô hình **Monorepo** bao gồm ứng dụng di động Flutter, ứng dụng Web bảo mật cao và API dịch vụ quản trị.

Unlike traditional line-by-line diff tools, **Dytava** operates at the **cell and data-type level**:
- Hiểu cấu trúc dòng/cột, bảng tính nhiều sheet (XLSX, XLS, CSV, TSV).
- Phân biệt giá trị tính toán (*calculated value*) và công thức (*formula*).
- Sai số số học (*numeric tolerance*), làm tròn ngày giờ, và chuẩn hóa văn bản.
- **100% Client-Side Privacy**: Toàn bộ dữ liệu bảng tính được xử lý trực tiếp trên thiết bị/trình duyệt người dùng qua Web Workers và bộ nhớ cục bộ, **không tải nội dung bảng tính lên server**.

---

## 📸 Giao Diện & Visual Concept

<p align="center">
  <img src="web/assets/visual-concept.png" alt="Dytava Visual Concept" width="850">
</p>

---

## 🚀 Các Tính Năng Nổi Bật (Key Features)

| Tính Năng | Mô Tả Chi Tiết |
| :--- | :--- |
| **🔒 100% Client-Side Privacy** | Không gửi file dữ liệu qua Internet. Tận dụng Web Worker & Engine nội bộ để phân tích hoàn toàn trên máy khách. |
| **🔍 Semantic Diff Engine** | So sánh ngữ nghĩa: Phát hiện thêm/xóa dòng, sửa ô, đổi kiểu dữ liệu (String sang Number/Date), và chênh lệch công thức. |
| **📐 Numeric & Precision Tolerance** | Thiết lập ngưỡng sai số cho phép ($10^{-2}$, $10^{-6}$, hoặc theo phần trăm %) để tránh cảnh báo sai do sai số dấu phẩy động. |
| **📱 Flutter Mobile App** | Ứng dụng di động (`mobile/`) đa nền tảng (Android & iOS) gọn nhẹ, tra cứu và so sánh nhanh bảng tính ngoại tuyến. |
| **🌐 Web App & Admin Portal** | Giao diện web hoàn chỉnh (`web/`), tích hợp công cụ so sánh trực quan, quản trị phát hành, KPI metrics và kiểm thử chấp nhận (Acceptance Tests). |
| **📑 Đa Định Dạng & Xuất Báo Cáo** | Đọc ghi XLSX, XLS, CSV, TSV. Xuất báo cáo sai khác dạng bảng trực quan, CSV hoặc file Excel có highlight màu. |

---

## 📂 Cấu Trúc Monorepo (Workspace Architecture)

```text
excelcompare/
├── mobile/                  # 📱 Ứng dụng di động đa nền tảng Flutter (Android & iOS)
│   ├── lib/main.dart        # Entrypoint ứng dụng Flutter
│   └── pubspec.yaml         # Cấu hình dependencies Flutter
│
├── web/                     # 🌐 Giao diện Web Client & Admin Portal
│   ├── assets/              # Logo SVG, PNG, Design tokens & App icons
│   ├── css/                 # Modern Responsive UI stylesheet
│   ├── js/                  # Compare Engine, File Parser & Web Worker
│   └── index.html           # Trang chủ ứng dụng so sánh bảng tính
│
├── server/                  # ⚡ Backend Express & Quản trị dịch vụ
│   ├── app.js               # Khởi tạo Express app & middleware bảo mật
│   ├── index.js             # Entrypoint server (Watch / Production)
│   └── migrations/          # SQLite database migrations
│
├── docs/                    # 📚 Toàn bộ tài liệu kỹ thuật & Brand
│   ├── document/            # PRD, SRS, Non-functional, Data Contracts
│   ├── diagrams/            # Sơ đồ kiến trúc (DOT & PNG)
│   └── dytava_brand/        # Bộ nhận diện thương hiệu Dytava Brand Identity v1.0
│
├── legacy-android/          # 📦 Bản Android Native cũ (Kotlin + Jetpack Compose) lưu tham khảo
│   └── app/                 # Lưu trữ UI components & design system Kotlin
│
├── tests/                   # 🧪 Bộ kiểm thử tự động (26 acceptance test cases)
├── .github/workflows/ci.yml # 🤖 GitHub Actions CI tự động kiểm tra Web & Flutter
└── package.json             # Quản lý scripts Node.js & dependencies
```

---

## 🛠️ Hướng Dẫn Cài Đặt & Khởi Chạy (Getting Started)

### Yêu Cầu Môi Trường (Prerequisites)
- **Node.js**: v20+ (Khuyên dùng v24+)
- **Flutter SDK**: 3.x+ (cho phân hệ `mobile/`)
- **Trình duyệt**: Chrome, Firefox, Safari hoặc Edge phiên bản mới

---

### 1. Phân Hệ Web & Server

```bash
# Cài đặt dependencies Node.js
npm install

# Khởi chạy server development (tự động build web assets và watch backend)
npm run dev

# Mở trình duyệt tại:
# -> Web so sánh: http://localhost:3000
# -> Admin Portal: http://localhost:3000/admin (nếu kích hoạt)
```

**Chạy kiểm thử tự động Web Engine:**
```bash
npm test
# Chạy 26 kịch bản kiểm thử ngữ nghĩa golden fixtures
```

---

### 2. Phân Hệ Di Động Flutter (`mobile/`)

```bash
# Di chuyển vào thư mục mobile
cd mobile

# Cài đặt các gói phụ thuộc Flutter
flutter pub get

# Kiểm tra code & chạy smoke tests
flutter test

# Khởi chạy trên thiết bị giả lập hoặc máy thật kết nối
flutter run
```

---

## 🧩 Kiến Trúc So Sánh Ngữ Nghĩa (Diff Engine)

```mermaid
flowchart LR
    A["File Bảng Tính A\n(XLSX, CSV)"] --> C["Bộ Phân Tích Cục Bộ\n(File Parser / Worker)"]
    B["File Bảng Tính B\n(XLSX, CSV)"] --> C
    
    C --> D{"Semantic Diff Engine"}
    
    subgraph Engine ["Quy Tắc So Sánh (Policy Engine)"]
        D1["Kiểm tra Cấu trúc\n(Sheet, Hàng, Cột)"]
        D2["Đối soát Kiểu Dữ Liệu\n(Number, Text, Date)"]
        D3["Áp dụng Sai Số\n(Tolerance Matrix)"]
    end
    
    D --> Engine
    Engine --> E["Báo Cáo Phân Tích Sai Khác\n(Interactive Visual Diff / Export)"]
```

---

## 🎨 Bộ Nhận Diện Thương Hiệu (Brand Identity)

Dự án áp dụng quy chuẩn **Dytava Brand Identity v1.0**:
- **Primary Color**: `#2663EB` (Dytava Royal Blue)
- **Accent Palette**: 
  - Text/Diff Added: `#16A585` (Emerald Teal)
  - Diff Changed: `#F2A642` (Amber Warmth)
  - Data Type Shift: `#A48BFA` (Soft Purple)
- Logo và design tokens đầy đủ tại: [`docs/dytava_brand/`](docs/dytava_brand/) hoặc [`web/assets/`](web/assets/).

---

## 📄 Bản Quyền & Tác Giả (License & Author)

Dự án được phân phối dưới giấy phép **[MIT License](LICENSE)**.

Được phát triển và duy trì bởi **[nmtrucworking](https://github.com/nmtrucworking)**.
Mọi đóng góp (Pull Request, Issue) đều được hoan nghênh!
