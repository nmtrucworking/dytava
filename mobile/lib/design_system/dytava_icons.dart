/// Định nghĩa đường dẫn tài nguyên Icons và Logos chính thức của Dytava
class DytavaIcons {
  DytavaIcons._();

  static const String assetPrefix = 'assets/dytava';

  // Brand Symbols & Logos
  static const String symbol = '$assetPrefix/brand/svg/dytava-symbol.svg';
  static const String horizontal = '$assetPrefix/brand/svg/dytava-horizontal.svg';
  static const String horizontalCompact = '$assetPrefix/brand/svg/dytava-horizontal-compact.svg';
  static const String horizontalWhite = '$assetPrefix/brand/svg/dytava-horizontal-white.svg';
  static const String pillBlue = '$assetPrefix/brand/svg/dytava-pill-blue.svg';
  static const String app = '$assetPrefix/brand/svg/dytava-app.svg';
  static const String appLight = '$assetPrefix/brand/svg/dytava-app-light.svg';
  static const String appDark = '$assetPrefix/brand/svg/dytava-app-dark.svg';
  static const String appCircle = '$assetPrefix/brand/svg/dytava-app-circle.svg';
  static const String appPurple = '$assetPrefix/brand/svg/dytava-app-purple.svg';
  static const String mono = '$assetPrefix/brand/svg/dytava-mono.svg';
  static const String iosFullbleed = '$assetPrefix/brand/svg/dytava-ios-fullbleed.svg';

  // 11 Core Functional Features (Nhóm tính năng chính)
  static const String compare = '$assetPrefix/icons/svg/color/compare.svg'; // So sánh Excel
  static const String ocr = '$assetPrefix/icons/svg/color/ocr.svg'; // OCR (Ảnh -> Bảng)
  static const String importData = '$assetPrefix/icons/svg/color/import.svg'; // Nhập dữ liệu
  static const String mapping = '$assetPrefix/icons/svg/color/mapping.svg'; // Ánh xạ cột
  static const String normalize = '$assetPrefix/icons/svg/color/normalize.svg'; // Quy tắc chuẩn hóa
  static const String report = '$assetPrefix/icons/svg/color/report.svg'; // Báo cáo
  static const String history = '$assetPrefix/icons/svg/color/history.svg'; // Lịch sử
  static const String saveRule = '$assetPrefix/icons/svg/color/save-rule.svg'; // Mẫu quy tắc
  static const String learn = '$assetPrefix/icons/svg/color/learn.svg'; // Học tập
  static const String info = '$assetPrefix/icons/svg/color/info.svg'; // Giới thiệu
  static const String settings = '$assetPrefix/icons/svg/color/settings.svg'; // Cài đặt

  // Bottom Navigation
  static const String navHome = '$assetPrefix/icons/svg/color/home.svg';
  static const String navCompare = '$assetPrefix/icons/svg/color/compare.svg';
  static const String navHistory = '$assetPrefix/icons/svg/color/history.svg';
  static const String navLearn = '$assetPrefix/icons/svg/color/learn.svg';
  static const String navSettings = '$assetPrefix/icons/svg/color/settings.svg';

  // Actions
  static const String play = '$assetPrefix/icons/svg/color/play.svg';
  static const String upload = '$assetPrefix/icons/svg/color/upload.svg';
  static const String export = '$assetPrefix/icons/svg/color/export.svg';
  static const String delete = '$assetPrefix/icons/svg/color/delete.svg';
  static const String close = '$assetPrefix/icons/svg/color/close.svg';
  static const String check = '$assetPrefix/icons/svg/color/check.svg';
  static const String plus = '$assetPrefix/icons/svg/color/plus.svg';
  static const String search = '$assetPrefix/icons/svg/color/search.svg';
  static const String filter = '$assetPrefix/icons/svg/color/filter.svg';
  static const String camera = '$assetPrefix/icons/svg/color/camera.svg';
  static const String calendar = '$assetPrefix/icons/svg/color/calendar.svg';

  // Status & Semantic
  static const String exact = '$assetPrefix/icons/svg/color/exact.svg';
  static const String equivalent = '$assetPrefix/icons/svg/color/equivalent.svg';
  static const String different = '$assetPrefix/icons/svg/color/different.svg';
  static const String unresolved = '$assetPrefix/icons/svg/color/unresolved.svg';
  static const String loading = '$assetPrefix/icons/svg/color/loading.svg';
  static const String empty = '$assetPrefix/icons/svg/color/empty.svg';
  static const String warning = '$assetPrefix/icons/svg/color/warning.svg';
  static const String success = '$assetPrefix/icons/svg/color/success.svg';
  static const String error = '$assetPrefix/icons/svg/color/error.svg';

  // File Formats
  static const String fileXlsx = '$assetPrefix/formats/svg/file-xlsx.svg';
  static const String fileCsv = '$assetPrefix/formats/svg/file-csv.svg';
  static const String fileXls = '$assetPrefix/formats/svg/file-xls.svg';
  static const String filePdf = '$assetPrefix/formats/svg/file-pdf.svg';
  static const String fileJson = '$assetPrefix/formats/svg/file-json.svg';

  // Helpers
  static String colorIcon(String name) => '$assetPrefix/icons/svg/color/$name.svg';
  static String outlineIcon(String name) => '$assetPrefix/icons/svg/outline/$name.svg';
  static String glyphIcon(String name) => '$assetPrefix/icons/svg/glyph/$name.svg';
  static String formatIcon(String ext) => '$assetPrefix/formats/svg/file-${ext.toLowerCase().replaceAll('.', '')}.svg';
  static String png512(String name) => '$assetPrefix/icons/png_512/$name.png';
}
