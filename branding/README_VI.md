# DYTAVA BRANDING & UI ASSET VAULT (PRECISION WORKSPACE v3.2)

Đây là kho lưu trữ tài nguyên thiết kế và nhận diện thương hiệu **chính thức** của **Dytava** (dự án `excelcompare`), chuẩn hóa theo hệ thống ngôn ngữ thiết kế:
**DYTAVA — Precision Workspace (Editorial Minimalism × Data Instrument × Native Interaction)**.

Tagline: `PRECISION WORKSPACE`
Slogan: "Đối chiếu dữ liệu chính xác, nhanh chóng và rõ ràng."

---

## 1. Thành phần kho tài nguyên

- **Thương hiệu & Biểu trưng (Brand & Logos):**
  - Wordmark `dytava.` có dấu chấm tròn, font Manrope hình học hiện đại.
  - Tagline đi kèm: `PRECISION WORKSPACE`.
  - Logo chính ngang (`dytava-horizontal.svg`, PNG 4K).
  - Biến thể Logo đơn sắc trắng trên nền Graphite (`dytava-horizontal-white.svg`).
  - Biến thể Logo dạng Pill Badge (`dytava-pill-blue.svg`).
  - Biểu tượng ứng dụng đa nền tảng (`dytava-app.svg`, `dytava-app-light.svg`, `dytava-app-dark.svg`, `dytava-app-circle.svg`, `dytava-app-purple.svg`, `dytava-ios-fullbleed.svg`).
  - Biểu tượng Android Adaptive (`android-adaptive-foreground.svg`).
- **116 Biểu tượng chức năng (Functional Icons):** Đầy đủ 3 biến thể SVG (`color`, `outline`, `glyph`) và các mức độ phân giải PNG (`png_4k`, `png_512`, `png_128`).
- **18 Biểu tượng định dạng tệp:** XLSX, XLS, CSV, TSV, JSON, JSONL, ODS, PDF, XML, HTML, TXT, PNG, JPG, WEBP, HEIC, XLSM, XLSB, MD.
- **Hệ thống Design System:**
  - Typography: **Manrope** (Tiêu đề, điểm nhấn), **Inter** (Giao diện, nội dung & số liệu Tabular).
  - Signature Components: Nút chính Pill Lime `#C8FF4A`, Nút phụ Pill `#EDEBE4`, Thẻ tệp File Card, Status Pill `● Đang tiến hành`, Difference Fingerprint & Donut ring.
- **Brand Showcase HTML tương tác:**
  - `branding/index.html`: Trang tài liệu thương hiệu trực quan, tương tác trực tiếp với toàn bộ bảng màu, logo, nhóm tính năng và linh kiện UI.
  - `branding/catalog/index.html`: Thư viện tra cứu và tìm kiếm offline 116+ icons và định dạng tệp.

---

## 2. Bảng màu chuẩn · Precision Workspace

| Vai trò | Mã HEX | Mô tả |
|---|---|---|
| **Lime Primary** | `#C8FF4A` | Màu nhận diện thương hiệu chính, nút CTA dạng Pill, switch active, tiến trình |
| **Lime-600** | `#86E63A` | Điểm nhấn viền active, hover state, chỉ báo tiến trình |
| **Off-white** | `#F7F6F2` | Nền canvas mặc định của ứng dụng và website, thanh nhã |
| **Warm Surface** | `#EDEBE4` | Bề mặt container thẻ, vùng tải tệp và ô nhập dữ liệu |
| **Graphite** | `#0F1A1C` | Màu chữ chính, nút phụ tương phản cao, header kỹ thuật |
| **Graphite-800** | `#1B2426` | Bề mặt tối cho Dark Mode, container Focus Diff, status pill nền đen |
| **Difference Coral** | `#E97965` | Sai khác dữ liệu (`DIFFERENT`), mật độ sai lệch trên Difference Fingerprint |
| **Emerald Green** | `#10B981` | Trạng thái `EXACT` (trùng khớp hoàn toàn 100%), icon Excel xanh lá |
| **Amber Warning** | `#F59E0B` | Cảnh báo đối soát, trạng thái `UNRESOLVED` |
| **Crimson Danger**| `#EF4444` | Nút xóa, cảnh báo lỗi nghiêm trọng |
| **Subtle Divider** | `#D8D5CC` | Đường viền các thẻ, phân cách bảng tính |

---

## 3. Cấu trúc thư mục

```text
branding/
├── index.html                   # Trang trưng bày nhận diện thương hiệu chính thức (Brand Showcase)
├── README_VI.md                 # Tài liệu hướng dẫn này
├── SHA256SUMS.txt               # Mã băm kiểm tra toàn vẹn file
├── catalog/
│   ├── index.html               # Trình tra cứu và tìm kiếm Icon Vault
│   └── *_catalog_4k.png         # Poster danh mục độ phân giải cao
├── documentation/
│   ├── BRAND_VERSION.md         # Lịch sử và thông số phiên bản nhận diện
│   └── STATUS_SEMANTICS.md      # Quy chuẩn 4 trạng thái so sánh dữ liệu
└── mobile/
    ├── pubspec_assets_snippet.yaml
    ├── lib/design_system/       # Bộ mã nguồn Flutter Design System
    │   ├── design_system.dart
    │   ├── dytava_colors.dart
    │   ├── dytava_typography.dart
    │   ├── dytava_icons.dart
    │   ├── dytava_theme.dart
    │   └── dytava_components.dart
    └── assets/dytava/           # Toàn bộ tài nguyên SVG, PNG, Tokens
        ├── brand/               # Logo và App Icon
        ├── icons/               # 116 functional icons (color, outline, glyph)
        ├── formats/             # 18 file format icons
        ├── adaptive/            # Android & iOS icons
        └── design_tokens.json   # Token JSON chuẩn
```

---

## 4. Tích hợp vào ứng dụng Flutter

1. Khai báo tài nguyên trong `mobile/pubspec.yaml` theo mẫu tại `branding/mobile/pubspec_assets_snippet.yaml`.
2. Sao chép thư mục `mobile/lib/design_system` vào ứng dụng:
   ```dart
   import 'package:mobile/design_system/design_system.dart';

   // Áp dụng Theme
   MaterialApp(
     theme: DytavaTheme.lightTheme,
     home: const HomeScreen(),
   );

   // Sử dụng Icon
   SvgPicture.asset(DytavaIcons.compare, width: 24, height: 24);

   // Sử dụng màu chuẩn
   Container(color: DytavaColors.primary);
   ```
