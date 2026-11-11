# DYTAVA BRANDING & UI ASSET VAULT v2.0 (CHÍNH THỨC)

Đây là kho lưu trữ tài nguyên thiết kế và nhận diện thương hiệu **chính thức** của **Dytava** (dự án `excelcompare`), được xây dựng chuẩn theo bản thiết kế **Design System & UI Assets (Flutter / Material)** đã được phê duyệt.

---

## 1. Thành phần kho tài nguyên

- **Thương hiệu & Biểu trưng (Brand & Logos):**
  - Logo chính ngang (`dytava-horizontal.svg`, PNG 4K).
  - Biến thể Logo dạng Pill Badge nền xanh (`dytava-pill-blue.svg`).
  - Biểu tượng ứng dụng đa nền tảng (`dytava-app.svg`, `dytava-app-light.svg`, `dytava-app-dark.svg`, `dytava-app-circle.svg`, `dytava-app-purple.svg`, `dytava-ios-fullbleed.svg`).
  - Biểu tượng Android Adaptive (`android-adaptive-foreground.svg`).
- **116 Biểu tượng chức năng (Functional Icons):** Đầy đủ 3 biến thể SVG (`color`, `outline`, `glyph`) và các mức độ phân giải PNG (`png_4k`, `png_512`, `png_128`).
- **18 Biểu tượng định dạng tệp:** XLSX, XLS, CSV, TSV, JSON, JSONL, ODS, PDF, XML, HTML, TXT, PNG, JPG, WEBP, HEIC, XLSM, XLSB, MD.
- **Hệ thống Flutter Dart Design System (`mobile/lib/design_system/`):**
  - `dytava_colors.dart`: Bảng màu chuẩn 10 màu và trạng thái so sánh.
  - `dytava_typography.dart`: Chuẩn typography Inter / Roboto.
  - `dytava_icons.dart`: Hằng số định danh và ánh xạ icon toàn hệ thống.
  - `dytava_theme.dart`: ThemeData Material 3 chuẩn cho ứng dụng Flutter.
  - `dytava_components.dart`: Các widget UI mẫu (Result Card, Policy Card, Status Badge, Empty State...).
- **Brand Showcase HTML tương tác:**
  - `branding/index.html`: Trang tài liệu thương hiệu trực quan, tương tác trực tiếp với toàn bộ bảng màu, logo, nhóm tính năng và linh kiện UI.
  - `branding/catalog/index.html`: Thư viện tra cứu và tìm kiếm offline 116+ icons và định dạng tệp.

---

## 2. Bảng màu chính thức (Official Palette)

| Vai trò | Mã HEX | Mô tả |
|---|---|---|
| **Primary Blue** | `#2563EB` | Màu thương hiệu chính, nút so sánh chính, trạng thái EQUIVALENT |
| **Sky Blue** | `#3B82F6` | Màu nhấn, điểm sáng gradient |
| **Purple Accent** | `#8B5CF6` | Nút xuất báo cáo, module ánh xạ cột, học tập |
| **Cyan Accent** | `#06B6D4` | Điểm nhấn trích xuất OCR, bảng tính nền |
| **Emerald Green** | `#10B981` | Nút nhập tệp, Excel, trạng thái EXACT, Hoàn thành |
| **Amber Warning** | `#F59E0B` | Trạng thái UNRESOLVED, cảnh báo đối soát |
| **Crimson Danger**| `#EF4444` | Nút xóa, cảnh báo lỗi, trạng thái DIFFERENT |
| **Background** | `#F3F4F6` | Nền ứng dụng trung tính |
| **Border** | `#E5E7EB` | Đường viền các thẻ, phân cách bảng |
| **White** | `#FFFFFF` | Nền thẻ bề mặt, chữ nổi trên nền màu |

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
