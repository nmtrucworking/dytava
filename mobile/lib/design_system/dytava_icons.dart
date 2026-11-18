import 'package:excelcompare_core/excelcompare_core.dart';

import '../domain/workflow.dart';

/// Định nghĩa đường dẫn tài nguyên Icons, Định dạng tệp và Logos chính thức của Dytava (Vault v2.0).
/// Cung cấp bộ hằng số ngữ nghĩa và hàm tra cứu theo trạng thái nghiệp vụ.
class DytavaIcons {
  DytavaIcons._();

  static const String assetPrefix = 'assets/dytava';

  // ==========================================
  // 1. Brand Symbols & Logos (12)
  // ==========================================
  static const String symbol = '$assetPrefix/brand/svg/dytava-symbol.svg';
  static const String horizontal =
      '$assetPrefix/brand/svg/dytava-horizontal.svg';
  static const String horizontalCompact =
      '$assetPrefix/brand/svg/dytava-horizontal-compact.svg';
  static const String horizontalWhite =
      '$assetPrefix/brand/svg/dytava-horizontal-white.svg';
  static const String pillBlue = '$assetPrefix/brand/svg/dytava-pill-blue.svg';
  static const String app = '$assetPrefix/brand/svg/dytava-app.svg';
  static const String appLight = '$assetPrefix/brand/svg/dytava-app-light.svg';
  static const String appDark = '$assetPrefix/brand/svg/dytava-app-dark.svg';
  static const String appCircle =
      '$assetPrefix/brand/svg/dytava-app-circle.svg';
  static const String appPurple =
      '$assetPrefix/brand/svg/dytava-app-purple.svg';
  static const String mono = '$assetPrefix/brand/svg/dytava-mono.svg';
  static const String iosFullbleed =
      '$assetPrefix/brand/svg/dytava-ios-fullbleed.svg';

  // ==========================================
  // 2. Core Functional Features & Navigation
  // ==========================================
  static const String compare = '$assetPrefix/icons/svg/color/compare.svg';
  static const String compareFiles =
      '$assetPrefix/icons/svg/color/compare-files.svg';
  static const String compareTable =
      '$assetPrefix/icons/svg/color/compare-table.svg';
  static const String compareProgress =
      '$assetPrefix/icons/svg/color/compare-progress.svg';
  static const String ocr = '$assetPrefix/icons/svg/color/ocr.svg';
  static const String importData = '$assetPrefix/icons/svg/color/import.svg';
  static const String mapping = '$assetPrefix/icons/svg/color/mapping.svg';
  static const String normalize = '$assetPrefix/icons/svg/color/normalize.svg';
  static const String policy = '$assetPrefix/icons/svg/color/policy.svg';
  static const String report = '$assetPrefix/icons/svg/color/report.svg';
  static const String history = '$assetPrefix/icons/svg/color/history.svg';
  static const String saveRule = '$assetPrefix/icons/svg/color/save-rule.svg';
  static const String learn = '$assetPrefix/icons/svg/color/learn.svg';
  static const String info = '$assetPrefix/icons/svg/color/info.svg';
  static const String help = '$assetPrefix/icons/svg/color/help.svg';
  static const String settings = '$assetPrefix/icons/svg/color/settings.svg';

  // Navigation & Directional
  static const String navHome = '$assetPrefix/icons/svg/color/home.svg';
  static const String navCompare = '$assetPrefix/icons/svg/color/compare.svg';
  static const String navHistory = '$assetPrefix/icons/svg/color/history.svg';
  static const String navLearn = '$assetPrefix/icons/svg/color/learn.svg';
  static const String navSettings = '$assetPrefix/icons/svg/color/settings.svg';
  static const String back = '$assetPrefix/icons/svg/color/back.svg';
  static const String forward = '$assetPrefix/icons/svg/color/forward.svg';
  static const String chevronDown =
      '$assetPrefix/icons/svg/color/chevron-down.svg';
  static const String chevronUp = '$assetPrefix/icons/svg/color/chevron-up.svg';
  static const String expand = '$assetPrefix/icons/svg/color/expand.svg';
  static const String collapse = '$assetPrefix/icons/svg/color/collapse.svg';
  static const String openExternal =
      '$assetPrefix/icons/svg/color/open-external.svg';

  // ==========================================
  // 3. Actions & Table Geometry
  // ==========================================
  static const String play = '$assetPrefix/icons/svg/color/play.svg';
  static const String pause = '$assetPrefix/icons/svg/color/pause.svg';
  static const String upload = '$assetPrefix/icons/svg/color/upload.svg';
  static const String download = '$assetPrefix/icons/svg/color/download.svg';
  static const String export = '$assetPrefix/icons/svg/color/export.svg';
  static const String share = '$assetPrefix/icons/svg/color/share.svg';
  static const String delete = '$assetPrefix/icons/svg/color/delete.svg';
  static const String close = '$assetPrefix/icons/svg/color/close.svg';
  static const String cancel = '$assetPrefix/icons/svg/color/cancel.svg';
  static const String check = '$assetPrefix/icons/svg/color/check.svg';
  static const String plus = '$assetPrefix/icons/svg/color/plus.svg';
  static const String minus = '$assetPrefix/icons/svg/color/minus.svg';
  static const String edit = '$assetPrefix/icons/svg/color/edit.svg';
  static const String copy = '$assetPrefix/icons/svg/color/copy.svg';
  static const String refresh = '$assetPrefix/icons/svg/color/refresh.svg';
  static const String search = '$assetPrefix/icons/svg/color/search.svg';
  static const String filter = '$assetPrefix/icons/svg/color/filter.svg';
  static const String sort = '$assetPrefix/icons/svg/color/sort.svg';
  static const String camera = '$assetPrefix/icons/svg/color/camera.svg';
  static const String crop = '$assetPrefix/icons/svg/color/crop.svg';
  static const String rotate = '$assetPrefix/icons/svg/color/rotate.svg';
  static const String calendar = '$assetPrefix/icons/svg/color/calendar.svg';
  static const String preview = '$assetPrefix/icons/svg/color/preview.svg';
  static const String files = '$assetPrefix/icons/svg/color/files.svg';
  static const String workbook = '$assetPrefix/icons/svg/color/workbook.svg';
  static const String rows = '$assetPrefix/icons/svg/color/rows.svg';
  static const String columns = '$assetPrefix/icons/svg/color/columns.svg';
  static const String cells = '$assetPrefix/icons/svg/color/cells.svg';
  static const String key = '$assetPrefix/icons/svg/color/key.svg';
  static const String link = '$assetPrefix/icons/svg/color/link.svg';
  static const String fingerprint =
      '$assetPrefix/icons/svg/color/fingerprint.svg';

  // ==========================================
  // 4. Status, Verdicts & Security
  // ==========================================
  static const String exact = '$assetPrefix/icons/svg/color/exact.svg';
  static const String equivalent =
      '$assetPrefix/icons/svg/color/equivalent.svg';
  static const String different = '$assetPrefix/icons/svg/color/different.svg';
  static const String unresolved =
      '$assetPrefix/icons/svg/color/unresolved.svg';
  static const String differences =
      '$assetPrefix/icons/svg/color/differences.svg';
  static const String added = '$assetPrefix/icons/svg/color/added.svg';
  static const String removed = '$assetPrefix/icons/svg/color/removed.svg';
  static const String duplicate = '$assetPrefix/icons/svg/color/duplicate.svg';
  static const String loading = '$assetPrefix/icons/svg/color/loading.svg';
  static const String pending = '$assetPrefix/icons/svg/color/pending.svg';
  static const String partial = '$assetPrefix/icons/svg/color/partial.svg';
  static const String empty = '$assetPrefix/icons/svg/color/empty.svg';
  static const String warning = '$assetPrefix/icons/svg/color/warning.svg';
  static const String success = '$assetPrefix/icons/svg/color/success.svg';
  static const String error = '$assetPrefix/icons/svg/color/error.svg';
  static const String shield = '$assetPrefix/icons/svg/color/shield.svg';
  static const String privacy = '$assetPrefix/icons/svg/color/privacy.svg';
  static const String encrypted = '$assetPrefix/icons/svg/color/encrypted.svg';
  static const String offline = '$assetPrefix/icons/svg/color/offline.svg';
  static const String noAccess = '$assetPrefix/icons/svg/color/no-access.svg';

  // ==========================================
  // 5. Semantic Data Types (dtype-*)
  // ==========================================
  static const String dtypeIdentifier =
      '$assetPrefix/icons/svg/color/dtype-identifier.svg';
  static const String dtypeDecimal =
      '$assetPrefix/icons/svg/color/dtype-decimal.svg';
  static const String dtypeInteger =
      '$assetPrefix/icons/svg/color/dtype-integer.svg';
  static const String dtypeString =
      '$assetPrefix/icons/svg/color/dtype-string.svg';
  static const String dtypeDate = '$assetPrefix/icons/svg/color/dtype-date.svg';
  static const String dtypeDatetime =
      '$assetPrefix/icons/svg/color/dtype-datetime.svg';
  static const String dtypeBoolean =
      '$assetPrefix/icons/svg/color/dtype-boolean.svg';
  static const String dtypePercentage =
      '$assetPrefix/icons/svg/color/dtype-percentage.svg';
  static const String dtypeCurrency =
      '$assetPrefix/icons/svg/color/dtype-currency.svg';
  static const String dtypeNull = '$assetPrefix/icons/svg/color/dtype-null.svg';

  // ==========================================
  // 6. File Formats (18 trong kho, ưu tiên P0/P1)
  // ==========================================
  static const String fileXlsx = '$assetPrefix/formats/svg/file-xlsx.svg';
  static const String fileCsv = '$assetPrefix/formats/svg/file-csv.svg';
  static const String fileTsv = '$assetPrefix/formats/svg/file-tsv.svg';
  static const String filePng = '$assetPrefix/formats/svg/file-png.svg';
  static const String fileJpg = '$assetPrefix/formats/svg/file-jpg.svg';
  static const String fileXls = '$assetPrefix/formats/svg/file-xls.svg';
  static const String filePdf = '$assetPrefix/formats/svg/file-pdf.svg';
  static const String fileJson = '$assetPrefix/formats/svg/file-json.svg';

  // ==========================================
  // 7. Semantic Resolvers & Helpers
  // ==========================================
  static String colorIcon(String name) =>
      '$assetPrefix/icons/svg/color/$name.svg';
  static String outlineIcon(String name) =>
      '$assetPrefix/icons/svg/outline/$name.svg';
  static String glyphIcon(String name) =>
      '$assetPrefix/icons/svg/glyph/$name.svg';
  static String formatIcon(String ext) =>
      '$assetPrefix/formats/svg/file-${ext.toLowerCase().replaceAll('.', '')}.svg';
  static String png512(String name) => '$assetPrefix/icons/png_512/$name.png';

  /// Trả về asset SVG biểu tượng định dạng tệp theo `SourceFormat`
  static String forFormat(SourceFormat format) => switch (format) {
    SourceFormat.xlsx => fileXlsx,
    SourceFormat.csv => fileCsv,
    SourceFormat.tsv => fileTsv,
    SourceFormat.png => filePng,
    SourceFormat.jpeg => fileJpg,
  };

  /// Trả về asset SVG biểu tượng kết luận đối chiếu theo `DecisionStatus`
  static String forDecision(DecisionStatus status) => switch (status) {
    DecisionStatus.exact => exact,
    DecisionStatus.equivalent => equivalent,
    DecisionStatus.different => different,
    DecisionStatus.unresolved => unresolved,
  };

  /// Trả về asset SVG biểu tượng kiểu ngữ nghĩa theo `SemanticType`
  static String forSemanticType(SemanticType type) => switch (type) {
    SemanticType.identifier => dtypeIdentifier,
    SemanticType.decimal => dtypeDecimal,
    SemanticType.freeText => dtypeString,
    SemanticType.boolean => dtypeBoolean,
    SemanticType.percentage => dtypePercentage,
  };

  /// Trả về asset SVG biểu tượng trạng thái nhập nguồn theo `InputState`
  static String forInputState(InputState state) => switch (state) {
    InputState.unselected => empty,
    InputState.selected => files,
    InputState.preflighting || InputState.parsing => loading,
    InputState.needsReview => warning,
    InputState.previewReady => success,
    InputState.failed => error,
    InputState.cancelled => cancel,
  };

  /// Danh sách các tài nguyên icon chính thức dùng cho kiểm thử tự động (Asset QA)
  static const List<String> allCoreAssets = [
    symbol,
    horizontal,
    horizontalCompact,
    compare,
    compareFiles,
    compareTable,
    compareProgress,
    ocr,
    importData,
    mapping,
    normalize,
    policy,
    report,
    history,
    saveRule,
    learn,
    info,
    help,
    settings,
    navHome,
    navCompare,
    navHistory,
    navLearn,
    navSettings,
    back,
    forward,
    chevronDown,
    chevronUp,
    expand,
    collapse,
    openExternal,
    play,
    pause,
    upload,
    download,
    export,
    share,
    delete,
    close,
    cancel,
    check,
    plus,
    minus,
    edit,
    copy,
    refresh,
    search,
    filter,
    sort,
    camera,
    crop,
    rotate,
    calendar,
    preview,
    files,
    workbook,
    rows,
    columns,
    cells,
    key,
    link,
    fingerprint,
    exact,
    equivalent,
    different,
    unresolved,
    differences,
    added,
    removed,
    duplicate,
    loading,
    pending,
    partial,
    empty,
    warning,
    success,
    error,
    shield,
    privacy,
    encrypted,
    offline,
    noAccess,
    dtypeIdentifier,
    dtypeDecimal,
    dtypeInteger,
    dtypeString,
    dtypeDate,
    dtypeDatetime,
    dtypeBoolean,
    dtypePercentage,
    dtypeCurrency,
    dtypeNull,
    fileXlsx,
    fileCsv,
    fileTsv,
    filePng,
    fileJpg,
    fileXls,
    filePdf,
    fileJson,
  ];
}
