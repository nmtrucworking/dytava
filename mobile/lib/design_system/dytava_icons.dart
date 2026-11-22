import 'package:excelcompare_core/excelcompare_core.dart';

import '../domain/workflow.dart';

/// Định nghĩa đường dẫn tài nguyên Icons, Định dạng tệp và Logos chính thức của Dytava (Vault v2.0).
/// Cung cấp bộ hằng số ngữ nghĩa và hàm tra cứu theo trạng thái nghiệp vụ.
class DytavaIcons {
  DytavaIcons._();

  static const String assetPrefix = 'assets/dytava';

  // ==========================================
  // 1. Brand Symbols & Logos
  // ==========================================
  static const String horizontal =
      '$assetPrefix/brand/svg/dytava-horizontal.svg';
  static const String app = '$assetPrefix/brand/svg/dytava-app.svg';

  // ==========================================
  // 2. Core Functional Features & Navigation
  // ==========================================
  static const String compare = '$assetPrefix/icons/svg/glyph/compare.svg';
  static const String compareFiles =
      '$assetPrefix/icons/svg/glyph/compare-files.svg';
  static const String compareProgress =
      '$assetPrefix/icons/svg/glyph/compare-progress.svg';
  static const String ocr = '$assetPrefix/icons/svg/glyph/ocr.svg';
  static const String importData = '$assetPrefix/icons/svg/glyph/import.svg';
  static const String mapping = '$assetPrefix/icons/svg/glyph/mapping.svg';
  static const String normalize = '$assetPrefix/icons/svg/glyph/normalize.svg';
  static const String policy = '$assetPrefix/icons/svg/glyph/policy.svg';
  static const String report = '$assetPrefix/icons/svg/glyph/report.svg';
  static const String history = '$assetPrefix/icons/svg/glyph/history.svg';
  static const String saveRule = '$assetPrefix/icons/svg/glyph/save-rule.svg';
  static const String info = '$assetPrefix/icons/svg/glyph/info.svg';
  static const String help = '$assetPrefix/icons/svg/glyph/help.svg';
  static const String settings = '$assetPrefix/icons/svg/glyph/settings.svg';

  // Navigation & Directional
  static const String navHome = '$assetPrefix/icons/svg/glyph/home.svg';
  static const String navCompare = '$assetPrefix/icons/svg/glyph/compare.svg';
  static const String navHistory = '$assetPrefix/icons/svg/glyph/history.svg';
  static const String navLearn = '$assetPrefix/icons/svg/glyph/learn.svg';
  static const String navSettings = '$assetPrefix/icons/svg/glyph/settings.svg';
  static const String back = '$assetPrefix/icons/svg/glyph/back.svg';
  static const String forward = '$assetPrefix/icons/svg/glyph/forward.svg';
  static const String expand = '$assetPrefix/icons/svg/glyph/expand.svg';
  static const String openExternal =
      '$assetPrefix/icons/svg/glyph/open-external.svg';

  // ==========================================
  // 3. Actions & Table Geometry
  // ==========================================
  static const String play = '$assetPrefix/icons/svg/glyph/play.svg';
  static const String upload = '$assetPrefix/icons/svg/glyph/upload.svg';
  static const String export = '$assetPrefix/icons/svg/glyph/export.svg';
  static const String delete = '$assetPrefix/icons/svg/glyph/delete.svg';
  static const String close = '$assetPrefix/icons/svg/glyph/close.svg';
  static const String cancel = '$assetPrefix/icons/svg/glyph/cancel.svg';
  static const String check = '$assetPrefix/icons/svg/glyph/check.svg';
  static const String plus = '$assetPrefix/icons/svg/glyph/plus.svg';
  static const String edit = '$assetPrefix/icons/svg/glyph/edit.svg';
  static const String copy = '$assetPrefix/icons/svg/glyph/copy.svg';
  static const String search = '$assetPrefix/icons/svg/glyph/search.svg';
  static const String filter = '$assetPrefix/icons/svg/glyph/filter.svg';
  static const String sort = '$assetPrefix/icons/svg/glyph/sort.svg';
  static const String camera = '$assetPrefix/icons/svg/glyph/camera.svg';
  static const String crop = '$assetPrefix/icons/svg/glyph/crop.svg';
  static const String rotate = '$assetPrefix/icons/svg/glyph/rotate.svg';
  static const String preview = '$assetPrefix/icons/svg/glyph/preview.svg';
  static const String files = '$assetPrefix/icons/svg/glyph/files.svg';
  static const String workbook = '$assetPrefix/icons/svg/glyph/workbook.svg';
  static const String rows = '$assetPrefix/icons/svg/glyph/rows.svg';
  static const String columns = '$assetPrefix/icons/svg/glyph/columns.svg';
  static const String cells = '$assetPrefix/icons/svg/glyph/cells.svg';
  static const String key = '$assetPrefix/icons/svg/glyph/key.svg';
  static const String link = '$assetPrefix/icons/svg/glyph/link.svg';

  // ==========================================
  // 4. Status, Verdicts & Security
  // ==========================================
  static const String exact = '$assetPrefix/icons/svg/glyph/exact.svg';
  static const String equivalent =
      '$assetPrefix/icons/svg/glyph/equivalent.svg';
  static const String different = '$assetPrefix/icons/svg/glyph/different.svg';
  static const String unresolved =
      '$assetPrefix/icons/svg/glyph/unresolved.svg';
  static const String differences =
      '$assetPrefix/icons/svg/glyph/differences.svg';
  static const String added = '$assetPrefix/icons/svg/glyph/added.svg';
  static const String removed = '$assetPrefix/icons/svg/glyph/removed.svg';
  static const String duplicate = '$assetPrefix/icons/svg/glyph/duplicate.svg';
  static const String loading = '$assetPrefix/icons/svg/glyph/loading.svg';
  static const String pending = '$assetPrefix/icons/svg/glyph/pending.svg';
  static const String partial = '$assetPrefix/icons/svg/glyph/partial.svg';
  static const String empty = '$assetPrefix/icons/svg/glyph/empty.svg';
  static const String warning = '$assetPrefix/icons/svg/glyph/warning.svg';
  static const String success = '$assetPrefix/icons/svg/glyph/success.svg';
  static const String error = '$assetPrefix/icons/svg/glyph/error.svg';
  static const String shield = '$assetPrefix/icons/svg/glyph/shield.svg';
  static const String privacy = '$assetPrefix/icons/svg/glyph/privacy.svg';
  static const String offline = '$assetPrefix/icons/svg/glyph/offline.svg';

  // ==========================================
  // 5. Semantic Data Types (dtype-*)
  // ==========================================
  static const String dtypeIdentifier =
      '$assetPrefix/icons/svg/glyph/dtype-identifier.svg';
  static const String dtypeDecimal =
      '$assetPrefix/icons/svg/glyph/dtype-decimal.svg';
  static const String dtypeString =
      '$assetPrefix/icons/svg/glyph/dtype-string.svg';
  static const String dtypeBoolean =
      '$assetPrefix/icons/svg/glyph/dtype-boolean.svg';
  static const String dtypePercentage =
      '$assetPrefix/icons/svg/glyph/dtype-percentage.svg';

  // ==========================================
  // 6. File Formats
  // ==========================================
  static const String fileXlsx = '$assetPrefix/formats/svg/file-xlsx.svg';
  static const String fileCsv = '$assetPrefix/formats/svg/file-csv.svg';
  static const String fileTsv = '$assetPrefix/formats/svg/file-tsv.svg';
  static const String filePng = '$assetPrefix/formats/svg/file-png.svg';
  static const String fileJpg = '$assetPrefix/formats/svg/file-jpg.svg';
  static const String fileJson = '$assetPrefix/formats/svg/file-json.svg';

  // ==========================================
  // 7. Semantic Resolvers & Helpers
  // ==========================================
  /// Trả về asset SVG biểu tượng định dạng tệp theo `SourceFormat`
  static String forFormat(SourceFormat format) => switch (format) {
    SourceFormat.json => fileJson,
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

  /// Danh sách các tài nguyên icon chính thức đang sử dụng dùng cho kiểm thử tự động (Asset QA)
  static const List<String> allCoreAssets = [
    horizontal,
    app,
    compare,
    compareFiles,
    compareProgress,
    ocr,
    importData,
    mapping,
    normalize,
    policy,
    report,
    history,
    saveRule,
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
    expand,
    openExternal,
    play,
    upload,
    export,
    delete,
    close,
    cancel,
    check,
    plus,
    edit,
    copy,
    search,
    filter,
    sort,
    camera,
    crop,
    rotate,
    preview,
    files,
    workbook,
    rows,
    columns,
    cells,
    key,
    link,
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
    offline,
    dtypeIdentifier,
    dtypeDecimal,
    dtypeString,
    dtypeBoolean,
    dtypePercentage,
    fileXlsx,
    fileCsv,
    fileTsv,
    filePng,
    fileJpg,
    fileJson,
  ];
}
