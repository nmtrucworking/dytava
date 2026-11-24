import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Comprehensive Localization class for Dytava (English & Vietnamese).
/// Supports reactive locale switching and fallback resolution.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? _current;
  static AppLocalizations get current => _current ?? AppLocalizations(const Locale('en'));
  static set current(AppLocalizations loc) => _current = loc;
  static Locale get currentLocale => current.locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('vi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final explicit = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (explicit != null) return explicit;

    bool isOcrOrDemo = false;
    context.visitAncestorElements((element) {
      final name = element.widget.runtimeType.toString();
      if (name.contains('PreviewScreen') ||
          name.contains('Ocr') ||
          name.contains('CompareDemo') ||
          name.contains('DifferenceFingerprint') ||
          name.contains('FocusDiff') ||
          name.contains('TextDifferenceEvidence')) {
        isOcrOrDemo = true;
        return false;
      }
      return true;
    });

    final selfName = context.widget.runtimeType.toString();
    if (selfName.contains('PreviewScreen') ||
        selfName.contains('Ocr') ||
        selfName.contains('CompareDemo') ||
        selfName.contains('DifferenceFingerprint') ||
        selfName.contains('FocusDiff') ||
        selfName.contains('TextDifferenceEvidence')) {
      isOcrOrDemo = true;
    }

    if (isOcrOrDemo) {
      return AppLocalizations(const Locale('vi'));
    }

    return _current ?? AppLocalizations(const Locale('en'));
  }

  bool get isVietnamese => locale.languageCode == 'vi';

  // ===========================================================================
  // App & Branding
  // ===========================================================================
  String get appTitle => 'Dytava — Excel Compare';
  String get appName => 'Dytava';
  String get appSubtitle => isVietnamese ? 'So sánh Excel' : 'Excel Compare';
  String get appTagline => isVietnamese
      ? 'Hai bảng tính. Một góc nhìn rõ ràng.'
      : 'Two spreadsheets. One clear view.';
  String get compareWithClarity => isVietnamese ? 'ĐỐI SOÁT CHUẨN XÁC' : 'COMPARE WITH CLARITY';
  String get spotTheDifference => isVietnamese ? 'Nhận diện\nsai khác.' : 'Spot the\ndifference.';
  String get spotTheDifferenceInline => isVietnamese ? 'Nhận diện sai khác.' : 'Spot the difference.';
  String get readyForAClearView => isVietnamese ? 'Sẵn sàng góc nhìn rõ ràng.' : 'Ready for a clear view.';
  String get openingWorkspace => isVietnamese ? 'Đang mở không gian làm việc' : 'Opening your workspace';
  String get workspaceReady => isVietnamese ? 'Không gian đã sẵn sàng' : 'Workspace ready';

  // ===========================================================================
  // Common Actions
  // ===========================================================================
  String get back => isVietnamese ? 'Quay lại' : 'Back';
  String get cancel => isVietnamese ? 'Hủy' : 'Cancel';
  String get done => isVietnamese ? 'Xong' : 'Done';
  String get close => isVietnamese ? 'Đóng' : 'Close';
  String get save => isVietnamese ? 'Lưu' : 'Save';
  String get delete => isVietnamese ? 'Xóa' : 'Delete';
  String get clearAll => isVietnamese ? 'Xóa tất cả' : 'Clear all';
  String get tryAgain => isVietnamese ? 'Thử lại' : 'Try again';
  String get retry => isVietnamese ? 'Thử lại' : 'Retry';
  String get all => isVietnamese ? 'Tất cả' : 'All';
  String get fullscreen => isVietnamese ? 'Toàn màn hình' : 'Fullscreen';
  String get minimize => isVietnamese ? 'Thu nhỏ' : 'Minimize';
  String get cellDetails => isVietnamese ? 'Chi tiết ô' : 'Cell details';
  String get viewAll => isVietnamese ? 'Xem tất cả ›' : 'View all ›';
  String get viewRulePresetsAction => isVietnamese ? 'Xem ›' : 'View ›';
  String get configureAction => isVietnamese ? 'Cấu hình ›' : 'Configure ›';
  String get confirm => isVietnamese ? 'Xác nhận' : 'Confirm';
  String get edit => isVietnamese ? 'Chỉnh sửa' : 'Edit';
  String get share => isVietnamese ? 'Chia sẻ' : 'Share';

  // ===========================================================================
  // Navigation Bar Titles
  // ===========================================================================
  String get titleHome => 'Dytava';
  String get titleImport => isVietnamese ? 'Nhập tệp' : 'Import files';
  String get titlePreview => isVietnamese ? 'Xem trước tệp' : 'File preview';
  String get titleOcr => isVietnamese ? 'Kiểm tra OCR' : 'OCR review';
  String get titleMapping => isVietnamese ? 'Ánh xạ cột' : 'Column mapping';
  String get titleReview => isVietnamese ? 'Xem xét đối chiếu' : 'Review comparison';
  String get titleComparing => isVietnamese ? 'Đang đối chiếu tệp' : 'Comparing files';
  String get titleResults => isVietnamese ? 'Kết quả đối chiếu' : 'Comparison results';
  String get titleDetail => isVietnamese ? 'Chi tiết sai khác' : 'Change details';
  String get titleExport => isVietnamese ? 'Xuất báo cáo' : 'Export report';
  String get titleHistory => isVietnamese ? 'Đối chiếu gần đây' : 'Recent comparisons';
  String get titlePresets => isVietnamese ? 'Mẫu quy tắc' : 'Rule presets';
  String get titleSettings => isVietnamese ? 'Cài đặt ứng dụng' : 'App settings';
  String get comparisonSettingsTooltip => isVietnamese ? 'Cài đặt đối chiếu' : 'Comparison settings';
  String get helpAndSupport => isVietnamese ? 'Trợ giúp & hỗ trợ' : 'Help & support';
  String get localStorageSetting => isVietnamese ? 'Lưu trữ cục bộ' : 'Local storage';
  String get localStorageDesc => isVietnamese
      ? 'Lưu lịch sử trong 30 ngày · Xóa dữ liệu đã lưu'
      : 'Keep history for 30 days · Clear saved data';
  String get quickBadge => isVietnamese ? 'Nhanh' : 'Quick';
  String get privacyShortDesc => isVietnamese
      ? 'Tệp được lưu cục bộ trừ khi bạn chọn chia sẻ.'
      : 'Files stay local unless you choose to share.';
  String get comparisonRulesSummary => isVietnamese
      ? 'Chỉ giá trị · Phân biệt hoa/thường · Không dung sai'
      : 'Values only · Case sensitive · No tolerance';

  // OCR stages
  String get ocrStagePreprocess => isVietnamese ? 'Chọn vùng bảng' : 'Select table region';
  String get ocrStageRecognizing => isVietnamese ? 'Đang quét bảng' : 'Scanning table';
  String get ocrStageReview => isVietnamese ? 'Kiểm tra bảng' : 'Review table';

  // ===========================================================================
  // Home Screen
  // ===========================================================================
  String get recentComparisons => isVietnamese ? 'Đối chiếu gần đây' : 'Recent comparisons';
  String get noComparisonsYet => isVietnamese ? 'Chưa có đối chiếu nào' : 'No comparisons yet';
  String get noComparisonsSubtitle => isVietnamese
      ? 'Đối chiếu hai bảng tính để tìm sai khác,\nkiểm tra thay đổi và lưu kết quả tại đây.'
      : 'Compare two spreadsheets to find changes,\nreview differences, and save your results here.';
  String get noComparisonsHomeHint => isVietnamese
      ? 'Chưa có đối chiếu nào.\nĐối chiếu hiện tại sẽ xuất hiện ở đây.'
      : 'No comparisons yet.\nYour current comparison will appear here.';
  String get newComparison => isVietnamese ? '+ Đối chiếu mới' : '+ New Comparison';
  String get spreadsheetComparison => isVietnamese ? 'Đối chiếu bảng tính' : 'Spreadsheet comparison';
  String get savedComparison => isVietnamese ? 'Đối chiếu đã lưu' : 'Saved comparison';
  String completedWorkbooks(int count) => isVietnamese ? 'Đã hoàn tất · $count bảng tính' : 'Completed · $count workbooks';
  String inProgressWorkbooks(int count) => isVietnamese ? 'Đang tiến hành · $count bảng tính' : 'In progress · $count workbooks';
  String cellsAndDiffs(int cells, int diffs) => isVietnamese
      ? '$cells ô · $diffs sai khác'
      : '$cells cells · $diffs diffs';

  // ===========================================================================
  // Source Selection Screen
  // ===========================================================================
  String get chooseFileA => isVietnamese ? 'Chọn tệp A' : 'Choose file A';
  String get chooseFileB => isVietnamese ? 'Chọn tệp B' : 'Choose file B';
  String get compareSpreadsheets => isVietnamese ? 'Đối chiếu bảng tính' : 'Compare spreadsheets';
  String get compareFiles => isVietnamese ? 'So sánh tệp' : 'Compare files';
  String get matchingSettings => isVietnamese ? 'Cài đặt so khớp' : 'Matching settings';
  String get advancedColumnMapping => isVietnamese ? 'Ánh xạ cột nâng cao ›' : 'Advanced column mapping ›';
  String get sourceA => isVietnamese ? 'Nguồn A' : 'Source A';
  String get sourceB => isVietnamese ? 'Nguồn B' : 'Source B';
  String get fileA => isVietnamese ? 'Tệp A' : 'File A';
  String get fileB => isVietnamese ? 'Tệp B' : 'File B';
  String get tapToUploadOrReplace => isVietnamese ? 'Chạm để tải lên hoặc thay thế' : 'Tap to upload or replace';
  String get dragDropOrTap => isVietnamese ? 'Kéo thả hoặc chạm để chọn' : 'Drag & drop or tap to choose';
  String get formatSupportedHint => isVietnamese ? 'CSV, XLSX hoặc ảnh bảng' : 'CSV, XLSX or Image table';
  String get selectingAndReadingFile => isVietnamese ? 'Đang chọn và đọc tệp…' : 'Selecting and reading file…';
  String get emptyFile => isVietnamese ? 'Tệp trống' : 'Empty file';
  String get ready => isVietnamese ? 'Sẵn sàng' : 'Ready';
  String get activeComparison => isVietnamese ? 'ĐỐI SOÁT ĐANG MỞ' : 'ACTIVE COMPARISON';
  String get preparingData => isVietnamese ? 'Đang chuẩn bị' : 'Preparing';
  String get needDataVerification => isVietnamese ? 'Cần xác minh dữ liệu' : 'Needs verification';
  String get selectSourceB => isVietnamese ? 'Chọn nguồn B' : 'Select Source B';
  String get noDataYet => isVietnamese ? 'Chưa có dữ liệu' : 'No data yet';
  String get continueSetup => isVietnamese ? 'Tiếp tục thiết lập' : 'Continue setup';
  String get clearSelection => isVietnamese ? 'Hủy chọn' : 'Clear';
  String get switchDirection => isVietnamese ? 'Đổi chiều A ↔ B' : 'Switch A ↔ B';
  String get sourcesChangedRevalidate => isVietnamese
      ? 'Nguồn đã thay đổi; cần xác thực lại trước khi cấu hình.'
      : 'Sources changed; re-validation required before configuring.';
  String get backToSources => isVietnamese ? 'Về nguồn A/B' : 'Back to Sources A/B';

  // ===========================================================================
  // Preview & OCR Screen
  // ===========================================================================
  String get sheet => isVietnamese ? 'Trang tính' : 'Sheet';
  String allSheetsCount(int count) => isVietnamese ? 'Tất cả sheet ($count)' : 'All sheets ($count)';
  String get inspectTable => isVietnamese ? 'Kiểm tra bảng' : 'Review table';
  String get viewSourceImage => isVietnamese ? 'Xem ảnh nguồn' : 'View source image';
  String get noTableDetected => isVietnamese ? 'Chưa phát hiện bảng dữ liệu' : 'No table detected';
  String get noTableDetectedDesc => isVietnamese
      ? 'Không thể tự động nhận diện lưới bảng từ ảnh này.'
      : 'Could not automatically detect table grid from this image.';
  String get chooseAnotherImage => isVietnamese ? 'Chọn ảnh khác' : 'Choose another image';
  String get createManualTable => isVietnamese ? 'Tạo bảng thủ công' : 'Create table manually';
  String get reselectArea => isVietnamese ? 'Khoanh lại' : 'Reselect';
  String get reselectAreaLong => isVietnamese ? 'Khoanh lại vùng bảng' : 'Reselect table area';
  String get scanTable => isVietnamese ? 'Quét bảng' : 'Scan table';
  String get scanningTableWait => isVietnamese ? 'Đang quét bảng…' : 'Scanning table…';
  String get tableStructure => isVietnamese ? 'Cấu trúc' : 'Structure';
  String get tableStructureTitle => isVietnamese ? 'Cấu trúc bảng' : 'Table structure';
  String get columnCountLabel => isVietnamese ? 'Số cột' : 'Columns';
  String get firstRowIsHeader => isVietnamese ? 'Hàng đầu là tiêu đề' : 'First row is header';
  String get addRow => isVietnamese ? 'Thêm hàng' : 'Add row';
  String get addColumn => isVietnamese ? 'Thêm cột' : 'Add column';
  String get mergeLastTwoCols => isVietnamese ? 'Gộp 2 cột cuối' : 'Merge last 2 columns';
  String get useThisTable => isVietnamese ? 'Dùng bảng này' : 'Use this table';
  String columnNumber(int index) => isVietnamese ? 'Cột $index' : 'Column $index';
  String get headerLabel => isVietnamese ? 'Tiêu đề' : 'Header';
  String rowColFormat(int r, int c) => isVietnamese ? '$r hàng × $c cột' : '$r rows × $c columns';
  String cellCoordinates(int r, int c) => isVietnamese ? 'Hàng $r, Cột $c' : 'Row $r, Column $c';
  String headerColumnCoordinates(int c) => isVietnamese ? 'Tiêu đề Cột $c' : 'Header Column $c';
  String get splitColumn => isVietnamese ? 'Tách cột' : 'Split column';
  String get enterValueHint => isVietnamese ? 'Nhập giá trị' : 'Enter value';
  String get cannotLoadOcrTable => isVietnamese ? 'Không thể nạp bảng OCR' : 'Cannot load OCR table';
  String get cannotRecognizeImage => isVietnamese ? 'Không thể nhận diện ảnh này' : 'Cannot recognize this image';
  String get cannotRecognizeImageDesc => isVietnamese
      ? 'Hãy thử khoanh lại vùng bảng hoặc chọn ảnh khác.'
      : 'Try reselecting the table area or choosing another image.';
  String get cancelImport => isVietnamese ? 'Hủy nhập' : 'Cancel import';
  String get quickCompareTitle => isVietnamese ? 'Đối chiếu nhanh' : 'Quick Compare';
  String get checkOcrTitle => isVietnamese ? 'Kiểm tra OCR' : 'OCR inspection';
  String get checkYourWorkbooks => isVietnamese ? 'Kiểm tra bảng tính' : 'Check your workbooks';
  String get previewValuesAndTypes => isVietnamese
      ? 'Xem trước giá trị và kiểu dữ liệu trước khi đối chiếu.'
      : 'Preview values and types before comparing.';
  String get noFileSelected => isVietnamese ? 'Chưa chọn tệp' : 'No file selected';
  String get awaitingImport => isVietnamese ? 'Đang chờ nạp' : 'Awaiting import';
  String get rows => isVietnamese ? 'hàng' : 'rows';
  String get columns => isVietnamese ? 'cột' : 'columns';
  String rowsAndColumns(int r, int c) => isVietnamese ? '$r hàng · $c cột' : '$r rows · $c columns';
  String get checkBeforeImporting => isVietnamese ? 'Kiểm tra trước khi nạp.' : 'Check before importing.';
  String get imageSpreadsheet => isVietnamese ? 'Bảng tính ảnh' : 'Image spreadsheet';
  String get reviewOcrHint => isVietnamese
      ? 'Xác nhận các ô cần kiểm tra trước khi tiến hành so sánh.'
      : 'Confirm cells that need review before comparing.';
  String cellsNeedReviewCount(int count) => isVietnamese
      ? '$count ô cần kiểm tra'
      : '$count cells need review';
  String recognizedTextLabel(String text) => isVietnamese
      ? 'Văn bản nhận diện: $text'
      : 'Recognized text: $text';
  String get confirmThisValue => isVietnamese ? 'Xác nhận giá trị này' : 'Confirm this value';
  String get uncertainCellsNotice => isVietnamese
      ? 'Các ô chưa chắc chắn cần được xác nhận trước khi nạp.'
      : 'Uncertain cells must be confirmed before import.';
  String get importReviewedValues => isVietnamese ? 'Nạp các giá trị đã kiểm tra' : 'Import reviewed values';
  String confirmCellsToContinue(int count) => isVietnamese
      ? 'Xác nhận $count ô để tiếp tục'
      : 'Confirm $count cells to continue';
  String previewRowsCount(int shown, int total) => isVietnamese
      ? 'Xem trước $shown trên $total hàng.'
      : 'Previewing $shown of $total rows.';
  String get autoDetectSheetsColumns => isVietnamese
      ? 'Tự động nhận diện cặp sheet, cột và khóa hàng.'
      : 'Auto-detects sheet pairs, columns and row keys.';
  String get confirmRangeAndHeader => isVietnamese ? 'Xác nhận phạm vi và tiêu đề' : 'Confirm range and header';
  String get reviewRecognition => isVietnamese ? 'Kiểm tra nhận diện' : 'Review recognition';
  String get backToImportFiles => isVietnamese ? 'Quay lại chọn tệp' : 'Back to import files';
  String get noTableFoundDesc => isVietnamese
      ? 'Không tìm thấy cấu trúc hàng và cột trong vùng ảnh đã chọn.'
      : 'No row and column structure found in the selected image area.';
  String get textFoundNoTableDesc => isVietnamese
      ? 'Đã nhận diện văn bản nhưng chưa xác định được hàng và cột.'
      : 'Text recognized but rows and columns could not be determined.';

  // ===========================================================================
  // Column Mapping & Policy
  // ===========================================================================
  String get matchYourColumns => isVietnamese ? 'Ghép cặp các cột' : 'Match your columns';
  String get autoMatchColumns => isVietnamese ? 'Tự động ghép cột →' : 'Auto match columns →';
  String get editColumnMapping => isVietnamese ? 'Chỉnh sửa ánh xạ cột →' : 'Edit column mapping →';
  String get unpaired => isVietnamese ? 'Chưa ghép' : 'Unpaired';
  String get compareColumns => isVietnamese ? 'So sánh cột' : 'Compare columns';
  String get reconcileById => isVietnamese ? 'Đối chiếu theo mã' : 'Reconcile by ID';
  String get byPosition => isVietnamese ? 'Theo vị trí' : 'By position';
  String get byKeyColumn => isVietnamese ? 'Theo cột khóa' : 'By key column';
  String get sequenceAlignment => isVietnamese ? 'Khớp tuần tự' : 'Sequence alignment';
  String get confirmSettingsToStart => isVietnamese
      ? 'Xác nhận các thiết lập này để bắt đầu đối chiếu.'
      : 'Confirm these settings to start your comparison.';
  String get startComparison => isVietnamese ? 'Bắt đầu đối chiếu' : 'Start comparison';
  String get dotDecimal => isVietnamese ? 'Dấu chấm (1.25)' : 'Dot (1.25)';
  String get commaDecimal => isVietnamese ? 'Dấu phẩy (1,25)' : 'Comma (1,25)';
  String get ignoreWhitespace => isVietnamese ? 'Bỏ qua khoảng trắng' : 'Ignore whitespace';
  String get ignoreCase => isVietnamese ? 'Bỏ qua chữ hoa/thường' : 'Ignore case';
  String get toleranceLabel => isVietnamese ? 'Độ lệch cho phép (Tolerance)' : 'Tolerance';
  String get matchingModeLabel => isVietnamese ? 'Chế độ so khớp' : 'Matching mode';
  String get rowAlignmentLabel => isVietnamese ? 'Căn chỉnh hàng' : 'Row alignment';
  String get keyColumnTuple => isVietnamese ? 'Cột khóa' : 'Key column';
  String get valueRules => isVietnamese ? 'Quy tắc giá trị' : 'Value rules';

  // ===========================================================================
  // Progress Screen
  // ===========================================================================
  String get comparingYourData => isVietnamese ? 'Đang đối chiếu dữ liệu' : 'Comparing your data';
  String get comparisonFailed => isVietnamese ? 'Đối chiếu thất bại' : 'Comparison failed';
  String get comparisonCancelled => isVietnamese ? 'Đối chiếu đã bị hủy' : 'Comparison cancelled';
  String get matchingSheetsColumnsKeys => isVietnamese
      ? 'Đang ghép sheet, cột, khóa và giá trị.'
      : 'Matching sheets, columns, keys and values.';
  String get checkingSheetsRecords => isVietnamese
      ? 'Đang kiểm tra sheet và bản ghi'
      : 'Checking sheets and records';
  String get working => isVietnamese ? 'Đang xử lý…' : 'Working…';
  String get inProgressUpper => isVietnamese ? 'ĐANG TIẾN HÀNH' : 'IN PROGRESS';
  String get stageReadFiles => isVietnamese ? 'Đọc và xác thực tệp' : 'Read and validate files';
  String get stageReadFilesDesc => isVietnamese
      ? 'Đã nhận diện các bảng tính nguồn'
      : 'Source workbooks recognized';
  String get stageMatchRecords => isVietnamese ? 'Ghép và đối chiếu bản ghi' : 'Match and compare records';
  String get stageMatchRecordsDesc => isVietnamese
      ? 'Đang kiểm tra cấu trúc và giá trị ô'
      : 'Checking structure and cell values';
  String get stagePrepareResults => isVietnamese ? 'Chuẩn bị kết quả' : 'Prepare results';
  String get upNext => isVietnamese ? 'Tiếp theo' : 'Up next';
  String get cancelComparison => isVietnamese ? 'Hủy đối chiếu' : 'Cancel comparison';
  String get cancelling => isVietnamese ? 'Đang hủy…' : 'Cancelling…';
  String get backToSetup => isVietnamese ? 'Quay lại thiết lập' : 'Back to setup';

  // ===========================================================================
  // Results & Detail Screen
  // ===========================================================================
  String get resultsReadyUpper => isVietnamese ? 'KẾT QUẢ ĐÃ SẴN SÀNG' : 'RESULTS READY';
  String get reportReady => isVietnamese ? 'Báo cáo đã sẵn sàng' : 'Report ready';
  String get exportReport => isVietnamese ? 'Xuất báo cáo' : 'Export report';
  String get downloadCsv => isVietnamese ? 'Xuất CSV' : 'Export CSV';
  String get downloadJson => isVietnamese ? 'Xuất JSON' : 'Export JSON';
  String get differenceFingerprint => isVietnamese
      ? 'BẢN ĐỒ SAI KHÁC (FINGERPRINT)'
      : 'DIFFERENCE FINGERPRINT';
  String get matchingVerdict => isVietnamese ? 'Trùng khớp' : 'Matching';
  String get differentVerdict => isVietnamese ? 'Sai khác' : 'Different';
  String get needsReviewVerdict => isVietnamese ? 'Cần xem xét' : 'Needs review';
  String get differenceDensity => isVietnamese ? 'mật độ sai lệch' : 'difference density';
  String get jumpToDifference => isVietnamese ? 'Nhảy tới sai khác' : 'Jump to difference';
  String get previousDifference => isVietnamese ? 'Sai khác trước' : 'Previous difference';
  String get nextDifference => isVietnamese ? 'Sai khác tiếp theo' : 'Next difference';
  String diffIndexRatio(int current, int total) => isVietnamese
      ? 'Sai khác $current / $total'
      : 'Difference $current / $total';
  String get showMoreChanges => isVietnamese ? 'Xem thêm thay đổi' : 'Show more changes';
  String get comparisonDetails => isVietnamese ? 'Chi tiết đối chiếu' : 'Comparison details';
  String get ruleReference => isVietnamese ? 'Quy tắc tham chiếu' : 'Rule reference';
  String get comparisonType => isVietnamese ? 'Kiểu đối chiếu' : 'Comparison type';
  String get matchingMode => isVietnamese ? 'Chế độ so khớp' : 'Matching mode';
  String get originalSource => isVietnamese ? 'Nguồn gốc (A)' : 'Original source';
  String get updatedSource => isVietnamese ? 'Nguồn cập nhật (B)' : 'Updated source';
  String get characterDifference => isVietnamese ? 'Sai khác từng ký tự:' : 'Character difference:';
  String get textDiffExceedsLimit => isVietnamese
      ? 'Không tô vùng khác biệt: chuỗi vượt giới hạn hiển thị của màn hình thử nghiệm. Kết luận so sánh được giữ nguyên.'
      : 'Difference highlighting disabled: string exceeds the preview limit. Comparison conclusion remains unchanged.';
  String similarityRatio(String pct) => isVietnamese ? 'Độ tương đồng: $pct%' : 'Similarity: $pct%';
  String get differenceInString => isVietnamese ? 'Khác biệt trong chuỗi' : 'Differences in string';
  String get diffPositionNote => isVietnamese
      ? 'Vị trí tính trên chuỗi sau chuẩn hóa; vùng khác nằm trong ⟦ ⟧.'
      : 'Position calculated on normalized string; difference region enclosed in ⟦ ⟧.';
  String get diffLegend => isVietnamese
      ? '␠ dấu cách · ⇥ tab · ↵ xuống dòng · ␍ về đầu dòng · ⍽ dấu cách không ngắt · ∅ đoạn trống'
      : '␠ space · ⇥ tab · ↵ newline · ␍ carriage return · ⍽ non-breaking space · ∅ empty';
  String get placeInCellBadge => isVietnamese
      ? 'Ảnh trong ô (Place in Cell)'
      : 'Place in Cell';
  String get placeOverCellsBadge => isVietnamese
      ? 'Ảnh đặt thủ công (Place over Cells)'
      : 'Place over Cells';
  String get placeOverCells => isVietnamese ? 'Đặt nổi trên ô' : 'Place over Cells';
  String get imageValueChanged => isVietnamese ? 'Hình ảnh đã thay đổi' : 'Image value changed';
  String get numericValueChanged => isVietnamese ? 'Giá trị số đã thay đổi' : 'Numeric value changed';
  String get addedFilter => isVietnamese ? 'Thêm mới' : 'Added';
  String get deletedFilter => isVietnamese ? 'Đã xóa' : 'Deleted';
  String get modifiedFilter => isVietnamese ? 'Đã sửa' : 'Modified';
  String reviewUnresolvedCount(int count) => isVietnamese
      ? 'Xem xét $count mục chưa giải quyết ›'
      : 'Review $count unresolved ›';
  String get tableDiff => isVietnamese ? 'So sánh bảng' : 'Table Diff';
  String tableDiffPair(String a, String b) => 'Table Diff · $a ↔ $b';
  String get previousPage => isVietnamese ? 'Trang trước' : 'Previous page';
  String get nextPage => isVietnamese ? 'Trang sau' : 'Next page';
  String get noRowsData => isVietnamese ? 'Không có dòng dữ liệu.' : 'No rows of data.';
  String get rowAddedInB => isVietnamese ? 'Dòng thêm ở nguồn B' : 'Row added in source B';
  String get rowDeletedInA => isVietnamese ? 'Dòng đã xóa ở nguồn A' : 'Row deleted in source A';
  String get quickViewSheet => isVietnamese ? 'Xem nhanh (Sheet)' : 'Quick view (Sheet)';
  String get inspectDetailAction => isVietnamese ? 'Xem chi tiết' : 'Inspect details';
  String get openFullDetailPage => isVietnamese ? 'Mở trang chi tiết' : 'Open details page';
  String get editAgain => isVietnamese ? 'Chỉnh sửa lại' : 'Edit configuration';
  String get confirmAndRunNow => isVietnamese ? 'Xác nhận lần này & Chạy' : 'Confirm & Run';
  String get scanSampleOcr => isVietnamese ? 'Quét OCR mẫu' : 'Scan sample OCR';
  String get identicalFilesTitle => isVietnamese
      ? 'Hai tệp A và B hoàn toàn giống nhau.'
      : 'File A and File B are identical.';
  String sheetsComparedCells(int sheets, int cells) => isVietnamese
      ? '$sheets sheet đã so sánh · $cells ô'
      : '$sheets sheets compared · $cells cells';
  String totalDifferencesCount(int count) => isVietnamese
      ? '$count sai khác'
      : '$count differences';
  String get noDifferencesFound => isVietnamese ? 'Không có sai khác nào' : 'No differences found';
  String get previewReport => isVietnamese ? 'Xem trước báo cáo' : 'Preview report';
  String get cancelExport => isVietnamese ? 'Hủy xuất' : 'Cancel export';
  String get confirmFormatAndReportScope => isVietnamese
      ? 'Xác nhận định dạng và phạm vi báo cáo'
      : 'Confirm format and report scope';
  String includeComparedCells(int count) => isVietnamese
      ? 'Bao gồm $count ô đã so sánh trong toàn bộ bảng tính.'
      : 'Include $count compared cells across the workbook.';
  String get differencesAndUnresolved => isVietnamese
      ? 'Sai khác và chưa giải quyết'
      : 'Differences and unresolved';
  String get fullComparison => isVietnamese ? 'Toàn bộ đối chiếu' : 'Full comparison';
  String get backToDifferences => isVietnamese ? 'Quay lại danh sách sai khác' : 'Back to differences';
  String differencePadIndexRatio(String current, String total) => isVietnamese
      ? 'SAI KHÁC $current / $total'
      : 'DIFFERENCE $current / $total';
  String percentReviewed(int percent) => isVietnamese
      ? 'Đã xem xét $percent%'
      : '$percent% reviewed';
  String get keptUnresolvedNotice => isVietnamese
      ? 'Giữ nguyên trạng thái chưa giải quyết. Không suy diễn thay đổi.'
      : 'Kept unresolved. No changes are inferred.';
  String get noReliableMatch => isVietnamese
      ? 'Không có cặp ghép tin cậy 1:1'
      : 'No reliable one-to-one match';
  String get previous => isVietnamese ? 'Trước' : 'Previous';
  String get next => isVietnamese ? 'Sau' : 'Next';
  String numericDifference(String label) => isVietnamese
      ? 'Sai khác số: $label'
      : 'Numeric difference: $label';
  String totalCount(int count) => isVietnamese
      ? 'Tổng cộng $count'
      : '$count total';
  String imageLabel(String type) => isVietnamese
      ? 'Ảnh ($type)'
      : 'Image ($type)';
  String normLabel(String norm) => isVietnamese
      ? 'Chuẩn hóa: $norm'
      : 'Norm: $norm';
  String get reportScope => isVietnamese ? 'Phạm vi báo cáo' : 'Report scope';
  String get csvSubtitle => isVietnamese ? 'Danh sách phẳng các ô đã so sánh' : 'Flat list of compared cells';
  String get jsonSubtitle => isVietnamese ? 'Báo cáo đầy đủ và bằng chứng đối chiếu' : 'Complete comparison report and evidence';
  String get prepareReport => isVietnamese ? 'Chuẩn bị báo cáo' : 'Prepare report';
  String get saveToDevice => isVietnamese ? 'Lưu về thiết bị' : 'Save to device';
  String get reportSavedToast => isVietnamese ? 'Báo cáo đã lưu về thiết bị của bạn.' : 'Report saved to your device.';
  String get reportSavedTitle => isVietnamese ? 'Đã lưu báo cáo' : 'Report saved';
  String get unableToSaveReport => isVietnamese ? 'Không thể lưu báo cáo' : 'Unable to save report';
  String get chooseAnotherLocationRetry => isVietnamese ? 'Hãy chọn vị trí khác và thử lại.' : 'Choose another location and try again.';
  String get listViewToggle => isVietnamese ? 'Dạng danh sách ›' : 'List view ›';
  String get tableViewToggle => isVietnamese ? 'Dạng bảng ›' : 'Table view ›';
  String get noChangesInFilter => isVietnamese ? 'Không có thay đổi nào theo bộ lọc này' : 'No changes in this filter';
  String get unpairedRow => isVietnamese ? 'Dòng chưa ghép' : 'Unpaired row';
  String get originalImagePlacement => isVietnamese ? 'Vị trí ảnh gốc' : 'Original image placement';
  String get updatedImagePlacement => isVietnamese ? 'Vị trí ảnh cập nhật' : 'Updated image placement';
  String get originalNormalized => isVietnamese ? 'Gốc (đã chuẩn hóa)' : 'Original normalized';
  String get updatedNormalized => isVietnamese ? 'Cập nhật (đã chuẩn hóa)' : 'Updated normalized';

  // ===========================================================================
  // Settings & History
  // ===========================================================================
  String get sectionComparison => isVietnamese ? 'ĐỐI SOÁT' : 'COMPARISON';
  String get sectionDeviceData => isVietnamese ? 'THIẾT BỊ & DỮ LIỆU' : 'DEVICE & DATA';
  String get sectionAbout => isVietnamese ? 'VỀ DYTAVA' : 'ABOUT DYTAVA';
  String get sectionLanguage => isVietnamese ? 'NGÔN NGỮ' : 'LANGUAGE';
  String get languageTitle => isVietnamese ? 'Ngôn ngữ hiển thị' : 'Display language';
  String get languageSubtitle => isVietnamese
      ? 'Chuyển đổi giữa Tiếng Việt và Tiếng Anh'
      : 'Switch between English and Vietnamese';
  String get vietnamese => 'Tiếng Việt';
  String get english => 'English';
  String get compareModeSetting => isVietnamese ? 'Chế độ đối chiếu' : 'Compare mode';
  String get compareModeValue => isVietnamese ? 'Đối chiếu nhanh' : 'Quick Compare';
  String get compareModeDesc => isVietnamese
      ? 'Gợi ý ánh xạ; xác nhận các trường hợp chưa chắc chắn.'
      : 'Propose mappings; confirm uncertain matches.';
  String get comparisonRulesSetting => isVietnamese ? 'Quy tắc đối chiếu' : 'Comparison rules';
  String get comparisonRulesDesc => isVietnamese
      ? 'Giá trị, khoảng trắng và chữ hoa thường.'
      : 'Values, spaces and text case.';
  String get rulePresetsSetting => isVietnamese ? 'Mẫu quy tắc' : 'Rule presets';
  String get rulePresetsDesc => isVietnamese
      ? 'Khám phá các quy tắc đối chiếu có sẵn.'
      : 'Explore the available comparison rules.';
  String get sessionStorageSetting => isVietnamese ? 'Lưu trữ phiên' : 'Session storage';
  String get inMemoryValue => isVietnamese ? 'Trong bộ nhớ tạm' : 'In memory';
  String get sessionStorageDesc => isVietnamese
      ? 'Dữ liệu được xóa khi đóng đối chiếu.'
      : 'Data is cleared when you close the comparison.';
  String get privacySetting => isVietnamese ? 'Quyền riêng tư' : 'Privacy';
  String get onThisDeviceValue => isVietnamese ? 'Trên thiết bị này' : 'On this device';
  String get privacyDesc => isVietnamese
      ? 'Tệp được xử lý cục bộ. Báo cáo lưu tại vị trí bạn chọn.'
      : 'Files are processed locally. Reports save to a location you choose.';
  String get saveSettings => isVietnamese ? 'Lưu cài đặt' : 'Save settings';
  String get chooseWhatCounts => isVietnamese
      ? 'Chọn những gì được coi là sai khác.'
      : 'Choose what counts as a difference.';
  String get deleteComparisonTitle => isVietnamese ? 'Xóa đối chiếu này?' : 'Delete comparison?';
  String deleteComparisonContent(String label) => isVietnamese
      ? 'Bạn có chắc chắn muốn xóa "$label" khỏi lịch sử đối chiếu?'
      : 'Are you sure you want to delete "$label" from your comparison history?';
  String get clearAllHistoryTitle => isVietnamese ? 'Xóa toàn bộ lịch sử?' : 'Clear all history?';
  String get clearAllHistoryContent => isVietnamese
      ? 'Tất cả các phiên đối chiếu đã lưu sẽ bị xóa vĩnh viễn. Hành động này không thể hoàn tác.'
      : 'All saved comparison sessions will be permanently removed. This action cannot be undone.';
  String savedComparisonsCount(int count) => isVietnamese
      ? '$count đối chiếu đã lưu'
      : '$count saved comparisons';
  String workbooksCount(int count) => isVietnamese
      ? '$count bảng tính'
      : '$count workbooks';

  // ===========================================================================
  // Diagnostics / Compare Demo Page
  // ===========================================================================
  String get semanticComparisonTitle => isVietnamese ? 'So sánh dữ liệu' : 'Data comparison';
  String get understandEveryDifference => isVietnamese ? 'Hiểu rõ từng sai khác.' : 'Understand every difference.';
  String get understandDifferenceDesc => isVietnamese
      ? 'Thử so sánh hai giá trị theo quy tắc ngữ nghĩa. Dùng luồng chính để nhập tệp và xuất CSV/JSON.'
      : 'Test comparing two values using semantic rules. Use the main workflow to import files and export CSV/JSON.';
  String get sourceAValue => isVietnamese ? 'Giá trị nguồn A' : 'Source A value';
  String get sourceBValue => isVietnamese ? 'Giá trị nguồn B' : 'Source B value';
  String get semanticDataType => isVietnamese ? 'Kiểu dữ liệu ngữ nghĩa' : 'Semantic data type';
  String get compareAction => isVietnamese ? 'So sánh' : 'Compare';
  String get statusPrefix => isVietnamese ? 'Trạng thái:' : 'Status:';
  String get typeIdentifier => isVietnamese ? 'Mã định danh' : 'Identifier';
  String get typeFreeText => isVietnamese ? 'Văn bản' : 'Free text';
  String get typeDecimal => isVietnamese ? 'Số thập phân' : 'Decimal';
  String get typeBoolean => isVietnamese ? 'Đúng / Sai' : 'Boolean';
  String get typePercentage => isVietnamese ? 'Phần trăm' : 'Percentage';
  String get textPreserveSpaceNotice => isVietnamese
      ? 'giữ khoảng trắng giữa các từ'
      : 'preserves spaces between words';
  String get stringRuleExplanation => isVietnamese
      ? 'Quy tắc chuỗi: bỏ khoảng trắng đầu/cuối; giữ khoảng trắng giữa các từ, phân biệt hoa/thường và dấu.'
      : 'String rules: trims leading/trailing whitespace; preserves intermediate whitespace, case-sensitive and accent-sensitive.';
  String get invalidConfig => isVietnamese ? 'Cấu hình không hợp lệ:' : 'Invalid configuration:';

  // ===========================================================================
  // Toasts & Notifications
  // ===========================================================================
  String get success => isVietnamese ? 'Thành công' : 'Success';
  String get error => isVietnamese ? 'Lỗi' : 'Error';
  String get warning => isVietnamese ? 'Cảnh báo' : 'Warning';
  String get info => isVietnamese ? 'Thông tin' : 'Info';
  String get comparisonFileReady => isVietnamese ? 'Tệp đối soát đã sẵn sàng' : 'Comparison file is ready';
  String get unsupportedFormat => isVietnamese ? 'Định dạng không được hỗ trợ' : 'Unsupported format';

  // ===========================================================================
  // Workflow Controller Status & Error Messages
  // ===========================================================================
  String get activityFailed => isVietnamese
      ? 'Tác vụ thất bại. Hãy kiểm tra lại nguồn và cấu hình.'
      : 'Activity failed. Please verify sources and configuration.';
  String get imagePairUnsupported => isVietnamese
      ? 'P0 chỉ cho phép một nguồn ảnh; phía còn lại phải là bảng.'
      : 'Only one image source is supported; the other must be tabular.';
  String get retryLimitExceeded => isVietnamese
      ? 'Đã hết số lần thử. Hãy chọn lại nguồn.'
      : 'Retry limit exceeded. Please reselect sources.';
  String get retryLimitConfig => isVietnamese
      ? 'Đã hết số lần thử. Hãy kiểm tra lại cấu hình.'
      : 'Retry limit exceeded. Please check configuration.';
  String get snapshotNotValidated => isVietnamese
      ? 'Nguồn chưa có bằng chứng xác thực đầy đủ.'
      : 'Source snapshot is not fully validated.';
  String get ocrReviewRequired => isVietnamese
      ? 'Cần xác nhận mọi ô trong phạm vi ảnh.'
      : 'Review required for all cells in image range.';
  String get accessRevoked => isVietnamese
      ? 'Quyền truy cập nguồn đã bị thu hồi.'
      : 'Source access has been revoked.';
  String get sheetMappingRequired => isVietnamese
      ? 'Cần chọn các cặp sheet chưa xác định được.'
      : 'Please resolve undetermined sheet pairs.';
  String inputNotReady(String side) => isVietnamese
      ? 'Nguồn $side chưa sẵn sàng để xem trước.'
      : 'Source $side is not ready for preview.';
  String get mappingConfirmationRequired => isVietnamese
      ? 'Cần xác nhận ánh xạ ít nhất một cặp cột.'
      : 'Please confirm mapping for at least one column pair.';
  String get modeConfirmationRequired => isVietnamese
      ? 'Cần xác nhận chế độ ghép hàng.'
      : 'Please confirm the row matching mode.';
  String get policyConfirmationRequired => isVietnamese
      ? 'Cần xác nhận chính sách cho từng cột.'
      : 'Please confirm column comparison policies.';
  String get directionConfirmationRequired => isVietnamese
      ? 'Cần xác nhận chiều so sánh.'
      : 'Please confirm comparison direction.';
  String get keyInvalid => isVietnamese
      ? 'Khóa cần là tuple cột IDENTIFIER, không trim hoặc tolerance.'
      : 'Key column must be an IDENTIFIER tuple without trim or tolerance.';
  String get mappingInvalid => isVietnamese
      ? 'Ánh xạ phải là 1:1 giữa các Field ID hiện hành.'
      : 'Mapping must be 1:1 between active field IDs.';
  String get policyInvalid => isVietnamese
      ? 'Thiếu hoặc sai cấu hình kiểu dữ liệu, locale hoặc tolerance.'
      : 'Invalid or missing data type, locale, or tolerance configuration.';
  String get validatingConfigPhase => isVietnamese
      ? 'Xác thực cấu hình'
      : 'Validating configuration';
  String get progressInvalid => isVietnamese
      ? 'Tiến trình tác vụ không hợp lệ.'
      : 'Task progress is invalid.';
  String get resultBindingInvalid => isVietnamese
      ? 'Kết quả không thuộc cấu hình hiện hành.'
      : 'Result does not match active configuration.';
  String get resultNotCurrent => isVietnamese
      ? 'Cần so sánh lại trước khi xuất.'
      : 'Comparison must be re-run before exporting.';
  String get exportDisabled => isVietnamese
      ? 'Định dạng này chưa có bộ xuất được kiểm chứng trên mobile.'
      : 'This format does not yet have a verified exporter on mobile.';
  String get exportRetriesExceeded => isVietnamese
      ? 'Đã hết số lần thử xuất trong phiên này.'
      : 'Export retry limit exceeded for this session.';
  String get resultStale => isVietnamese
      ? 'Kết quả đã mất hiệu lực; cần so sánh lại.'
      : 'Result is stale; comparison must be re-run.';
  String get cleanupFailed => isVietnamese
      ? 'Không thể hoàn tất dọn dữ liệu tạm.'
      : 'Could not complete temporary data cleanup.';
  String get sourceRevalidationRequired => isVietnamese
      ? 'Nguồn khôi phục cần được xác thực lại.'
      : 'Restored source requires re-validation.';

  // Sheet mapping summary
  String sheetPairsMapped(int count) => isVietnamese
      ? 'Đã ghép $count cặp sheet'
      : '$count sheet pairs mapped';
  String sheetPairsUnresolved(int count) => isVietnamese
      ? 'Cần xác nhận $count cặp sheet'
      : '$count sheet pairs need confirmation';
  String sheetCountSummary(int a, int b, bool auto) => isVietnamese
      ? '$a sheet A · $b sheet B${auto ? ' · Khớp tự động' : ''}'
      : '$a sheets A · $b sheets B${auto ? ' · Auto matched' : ''}';
  String get sheetMappingHint => isVietnamese
      ? 'Chọn các cặp còn mơ hồ. Không dùng thứ tự tab để ghép.'
      : 'Select ambiguous pairs. Tab order is not used for mapping.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final effective = locale.languageCode == 'vi' ? const Locale('vi') : const Locale('en');
    return SynchronousFuture<AppLocalizations>(AppLocalizations(effective));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
