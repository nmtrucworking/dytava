import 'package:excelcompare_core/excelcompare_core.dart';

// AUTO-GENERATED & SEMANTICALLY EXTENDED — Dytava Illustration Library 4K v1.0
// Render SVG in Flutter via flutter_svg; 4K PNG intended for promotional/export use.
abstract final class DytavaIllustrations {
  /// Chưa có phiên so sánh
  static const emptyComparisons =
      'assets/dytava/illustrations/svg/square/empty-comparisons.svg';

  /// Chưa có tệp dữ liệu
  static const emptyFiles =
      'assets/dytava/illustrations/svg/square/empty-files.svg';

  /// Chưa có hình ảnh để nhận dạng
  static const emptyOcr =
      'assets/dytava/illustrations/svg/square/empty-ocr.svg';

  /// Chưa ánh xạ cột
  static const emptyMapping =
      'assets/dytava/illustrations/svg/square/empty-mapping.svg';

  /// Bộ lọc không có kết quả
  static const emptyFilter =
      'assets/dytava/illustrations/svg/square/empty-filter.svg';

  /// So sánh hoàn tất
  static const successCompare =
      'assets/dytava/illustrations/svg/square/success-compare.svg';

  /// Nhập tệp thành công
  static const successImport =
      'assets/dytava/illustrations/svg/square/success-import.svg';

  /// Trùng khớp tuyệt đối
  static const statusExact =
      'assets/dytava/illustrations/svg/square/status-exact.svg';

  /// Tương đương theo quy tắc
  static const statusEquivalent =
      'assets/dytava/illustrations/svg/square/status-equivalent.svg';

  /// Phát hiện sai khác
  static const statusDifferent =
      'assets/dytava/illustrations/svg/square/status-different.svg';

  /// Chưa thể kết luận
  static const statusUnresolved =
      'assets/dytava/illustrations/svg/square/status-unresolved.svg';

  /// Cảnh báo dữ liệu
  static const statusWarning =
      'assets/dytava/illustrations/svg/square/status-warning.svg';

  /// Không thể hoàn thành
  static const statusError =
      'assets/dytava/illustrations/svg/square/status-error.svg';

  /// Không có quyền truy cập tệp
  static const statusNoPermission =
      'assets/dytava/illustrations/svg/square/status-no-permission.svg';

  /// Tệp bị lỗi
  static const statusFileCorrupt =
      'assets/dytava/illustrations/svg/square/status-file-corrupt.svg';

  /// Định dạng chưa hỗ trợ
  static const statusUnsupportedFormat =
      'assets/dytava/illustrations/svg/square/status-unsupported-format.svg';

  /// Vượt giới hạn bộ nhớ
  static const statusMemoryLimit =
      'assets/dytava/illustrations/svg/square/status-memory-limit.svg';

  /// Đã hủy thao tác
  static const statusCancelled =
      'assets/dytava/illustrations/svg/square/status-cancelled.svg';

  /// Xử lý tại thiết bị
  static const securityLocal =
      'assets/dytava/illustrations/svg/square/security-local.svg';

  /// Chọn hai tệp dữ liệu
  static const onboardingImport =
      'assets/dytava/illustrations/svg/wide/onboarding-import.svg';

  /// Ánh xạ cột và xác định khóa
  static const onboardingMapping =
      'assets/dytava/illustrations/svg/wide/onboarding-mapping.svg';

  /// Thiết lập chính sách so sánh
  static const onboardingPolicy =
      'assets/dytava/illustrations/svg/wide/onboarding-policy.svg';

  /// Xem bốn trạng thái sai khác
  static const onboardingCompare =
      'assets/dytava/illustrations/svg/wide/onboarding-compare.svg';

  /// Xuất báo cáo có thể truy vết
  static const onboardingReport =
      'assets/dytava/illustrations/svg/wide/onboarding-report.svg';

  /// Bắt đầu so sánh dữ liệu
  static const heroGetStarted =
      'assets/dytava/illustrations/svg/wide/hero-get-started.svg';

  /// Không gian làm việc mới
  static const heroEmptyWorkspace =
      'assets/dytava/illustrations/svg/wide/hero-empty-workspace.svg';

  /// Kiểm tra illustration có tỷ lệ khung hình ngang 16:9 (`wide`) hay vuông 1:1 (`square`)
  static bool isWide(String asset) => asset.contains('/wide/');

  /// Trả về illustration tương ứng với 4 trạng thái quyết định của Core Engine
  static String forVerdict(DecisionStatus status) => switch (status) {
    DecisionStatus.exact => statusExact,
    DecisionStatus.equivalent => statusEquivalent,
    DecisionStatus.different => statusDifferent,
    DecisionStatus.unresolved => statusUnresolved,
  };

  /// Trả về illustration phản ánh đúng mã lỗi hoặc trạng thái cảnh báo
  static String forIssueCode(String code) {
    final normalized = code.toUpperCase();
    if (normalized.contains('PERM') || normalized.contains('ACCESS')) {
      return statusNoPermission;
    }
    if (normalized.contains('CORRUPT') ||
        normalized.contains('PARSE') ||
        normalized.contains('ENCODING')) {
      return statusFileCorrupt;
    }
    if (normalized.contains('FORMAT') || normalized.contains('UNSUPPORTED')) {
      return statusUnsupportedFormat;
    }
    if (normalized.contains('MEM') || normalized.contains('LIMIT')) {
      return statusMemoryLimit;
    }
    if (normalized.contains('CANCEL')) {
      return statusCancelled;
    }
    if (normalized.contains('OCR') ||
        normalized.contains('REVIEW') ||
        normalized.contains('WARN')) {
      return statusWarning;
    }
    return statusError;
  }

  /// Danh sách các illustration đang sử dụng dùng cho kiểm thử tự động (Asset QA)
  static const List<String> allAssets = [
    emptyComparisons,
    emptyFiles,
    emptyOcr,
    emptyMapping,
    emptyFilter,
    successCompare,
    successImport,
    statusExact,
    statusEquivalent,
    statusDifferent,
    statusUnresolved,
    statusWarning,
    statusError,
    statusNoPermission,
    statusFileCorrupt,
    statusUnsupportedFormat,
    statusMemoryLimit,
    statusCancelled,
    securityLocal,
    onboardingImport,
    onboardingMapping,
    onboardingPolicy,
    onboardingCompare,
    onboardingReport,
    heroGetStarted,
    heroEmptyWorkspace,
  ];
}
