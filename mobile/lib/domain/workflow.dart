// Internal activity models. These are not ISC-1/EP-1/ER-1/EX-1 wire schemas.
import 'package:excelcompare_core/excelcompare_core.dart';

enum SourceSide { a, b }

enum SourceFormat { csv, tsv, xlsx, png, jpeg }

enum InputState {
  unselected,
  selected,
  preflighting,
  parsing,
  needsReview,
  previewReady,
  failed,
  cancelled,
}

enum JobState {
  created,
  validating,
  running,
  needsReview,
  cancelling,
  cancelled,
  completed,
  failed,
  partial,
  interrupted,
}

enum ExportState {
  requested,
  validating,
  rendering,
  verifying,
  publishing,
  cancelling,
  cancelled,
  completed,
  failed,
}

enum ResultValidity { current, stale, revoked }

enum MatchingMode { positional, key }

enum ComparisonDirection { aToB, bToA }

enum ExportKind { csvDiff, jsonReport, mergedDiffPdf, dytavaReportPdf }

enum ExportSelection { fullComparison, differencesOnly }

enum WorkflowScreen {
  home,
  sources,
  preview,
  ocrReview,
  mapping,
  policy,
  progress,
  results,
  detail,
  export,
}

extension SourceFormatInfo on SourceFormat {
  bool get isImage => this == SourceFormat.png || this == SourceFormat.jpeg;
}

extension JobStateInfo on JobState {
  bool get active => const {
    JobState.validating,
    JobState.running,
    JobState.needsReview,
    JobState.cancelling,
  }.contains(this);
}

extension ExportStateInfo on ExportState {
  bool get active =>
      this != ExportState.completed &&
      this != ExportState.failed &&
      this != ExportState.cancelled;
}

final class WorkflowIssue implements Exception {
  const WorkflowIssue(this.code, this.message, {this.retryable = false});
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => '$code: $message';
}

final class SourceArtifact {
  const SourceArtifact({
    required this.id,
    required this.label,
    required this.format,
    required this.privateRef,
  });
  final String id;
  final String label;
  final SourceFormat format;

  /// Only an access adapter may resolve this. Never serialize into reports.
  final String privateRef;
}

final class ImportBinding {
  const ImportBinding(
    this.artifactId,
    this.generation,
    this.revision,
    this.attempt,
  );
  final String artifactId;
  final int generation;
  final int revision;
  final int attempt;
  @override
  bool operator ==(Object other) =>
      other is ImportBinding &&
      artifactId == other.artifactId &&
      generation == other.generation &&
      revision == other.revision &&
      attempt == other.attempt;
  @override
  int get hashCode => Object.hash(artifactId, generation, revision, attempt);
}

final class ImportConfiguration {
  const ImportConfiguration({
    this.scopeConfirmed = false,
    this.ocrRevision = 0,
    this.reviewedCells = const {},
  });
  final bool scopeConfirmed;
  final int ocrRevision;
  final Set<String> reviewedCells;
}

final class TableField {
  const TableField(this.id, this.label);
  final String id;
  final String label;
}

final class TableRecord {
  TableRecord(
    this.id,
    this.ordinal,
    Map<String, SourceCell> cells,
    Map<String, String> locations,
  ) : cells = Map.unmodifiable(cells),
      locations = Map.unmodifiable(locations);
  final String id;
  final int ordinal;
  final Map<String, SourceCell> cells;

  /// Fixture locations in the demo; real SourceRef adapters are still gated.
  final Map<String, String> locations;
}

final class InputSnapshot {
  InputSnapshot({
    required this.id,
    required this.binding,
    required Iterable<TableField> fields,
    required Iterable<TableRecord> records,
    required this.fullValidation,
    required this.ocrReviewed,
  }) : fields = List.unmodifiable(fields),
       records = List.unmodifiable(records);
  final String id;
  final ImportBinding binding;
  final List<TableField> fields;
  final List<TableRecord> records;
  final bool fullValidation;
  final bool ocrReviewed;
}

final class ReviewCell {
  const ReviewCell(this.id, this.recognizedText);
  final String id;
  final String recognizedText;
}

final class ImportReview {
  ImportReview(this.issue, {Iterable<ReviewCell> cells = const []})
    : cells = List.unmodifiable(cells);
  final WorkflowIssue issue;
  final List<ReviewCell> cells;
}

final class ImportOutcome {
  const ImportOutcome.ready(InputSnapshot value)
    : snapshot = value,
      review = null;
  const ImportOutcome.review(ImportReview value)
    : review = value,
      snapshot = null;
  final InputSnapshot? snapshot;
  final ImportReview? review;
}

final class SourceSlot {
  const SourceSlot({
    required this.side,
    this.state = InputState.unselected,
    this.artifact,
    this.generation = 0,
    this.revision = 0,
    this.attempt = 0,
    this.config = const ImportConfiguration(),
    this.snapshot,
    this.review,
    this.issue,
    this.cancelling = false,
  });
  final SourceSide side;
  final InputState state;
  final SourceArtifact? artifact;
  final int generation;
  final int revision;
  final int attempt;
  final ImportConfiguration config;
  final InputSnapshot? snapshot;
  final ImportReview? review;
  final WorkflowIssue? issue;
  final bool cancelling;
  bool get busy =>
      cancelling ||
      state == InputState.preflighting ||
      state == InputState.parsing;
  bool get ready =>
      state == InputState.previewReady &&
      snapshot?.fullValidation == true &&
      snapshot?.binding == binding;
  ImportBinding get binding =>
      ImportBinding(artifact?.id ?? '', generation, revision, attempt);
}

final class FieldMapping {
  const FieldMapping(this.fieldA, this.fieldB);
  final String fieldA;
  final String fieldB;
}

final class FieldRule {
  const FieldRule({
    required this.type,
    this.trim = false,
    this.separatorA = '.',
    this.separatorB = ',',
    this.tolerance = '0',
  });
  final SemanticType type;
  final bool trim;
  final String separatorA;
  final String separatorB;
  final String tolerance;
  FieldPolicy compile(String field) => FieldPolicy(
    field: field,
    type: type,
    trim: trim,
    sourceA: DecimalInputPolicy(decimalSeparator: separatorA),
    sourceB: DecimalInputPolicy(decimalSeparator: separatorB),
    toleranceAbs: tolerance,
    percentSignIsScale: true,
    aliases: const {'true': true, 'false': false, 'Có': true, 'Không': false},
  );
}

final class ComparisonConfiguration {
  ComparisonConfiguration({
    Iterable<FieldMapping> mappings = const [],
    Map<String, FieldRule> rules = const {},
    this.mode = MatchingMode.positional,
    Iterable<String> keys = const [],
    this.direction = ComparisonDirection.aToB,
    this.mappingConfirmed = false,
    this.modeConfirmed = false,
    this.policyConfirmed = false,
    this.directionConfirmed = false,
  }) : mappings = List.unmodifiable(mappings),
       rules = Map.unmodifiable(rules),
       keys = List.unmodifiable(keys);
  final List<FieldMapping> mappings;
  final Map<String, FieldRule> rules;
  final MatchingMode mode;

  /// Ordered A-side field IDs, resolved through the confirmed mapping.
  final List<String> keys;
  final ComparisonDirection direction;
  final bool mappingConfirmed;
  final bool modeConfirmed;
  final bool policyConfirmed;
  final bool directionConfirmed;
}

final class FrozenPlan {
  const FrozenPlan(this.id, this.revision, this.a, this.b, this.config);
  final String id;
  final int revision;
  final InputSnapshot a;
  final InputSnapshot b;
  final ComparisonConfiguration config;
}

final class CellDifference {
  const CellDifference({
    required this.id,
    required this.rowA,
    required this.rowB,
    required this.mapping,
    required this.a,
    required this.b,
    required this.locationA,
    required this.locationB,
    required this.decision,
  });
  final String id;
  final String rowA;
  final String rowB;
  final FieldMapping mapping;
  final SourceCell a;
  final SourceCell b;
  final String? locationA;
  final String? locationB;
  final ComparisonDecision decision;
}

final class StructuralChange {
  const StructuralChange(this.kind, this.side, this.recordId);
  final String kind;
  final SourceSide side;
  final String recordId;
}

final class RecordUnresolved {
  RecordUnresolved(this.reason, Iterable<String> a, Iterable<String> b)
    : recordsA = List.unmodifiable(a),
      recordsB = List.unmodifiable(b);
  final String reason;
  final List<String> recordsA;
  final List<String> recordsB;
}

final class ComparisonResult {
  ComparisonResult({
    required this.id,
    required this.plan,
    required Iterable<CellDifference> cells,
    required Iterable<StructuralChange> structural,
    required Iterable<RecordUnresolved> unresolvedRecords,
    required this.matchedRecords,
  }) : cells = List.unmodifiable(cells),
       structural = List.unmodifiable(structural),
       unresolvedRecords = List.unmodifiable(unresolvedRecords);
  final String id;
  final FrozenPlan plan;
  final List<CellDifference> cells;
  final List<StructuralChange> structural;
  final List<RecordUnresolved> unresolvedRecords;
  final int matchedRecords;
  int count(DecisionStatus status) =>
      cells.where((c) => c.decision.status == status).length;
  double? get exactRate =>
      cells.isEmpty ? null : count(DecisionStatus.exact) / cells.length;
  double? get agreementRate => cells.isEmpty
      ? null
      : (count(DecisionStatus.exact) + count(DecisionStatus.equivalent)) /
            cells.length;
}

final class ExportRequest {
  const ExportRequest(this.kind, this.selection);
  final ExportKind kind;
  final ExportSelection selection;
}

final class PreparedExport {
  const PreparedExport(this.previewText, this.selectedCellCount);
  final String previewText;
  final int selectedCellCount;
}

final class ExportReceipt {
  const ExportReceipt(this.id, this.previewText, {required this.previewOnly});
  final String id;
  final String previewText;
  final bool previewOnly;
}

final class Cancellation {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) throw const WorkCancelled();
  }
}

final class WorkCancelled implements Exception {
  const WorkCancelled();
}

/// Implementations own and close their attempt resources before returning.
abstract interface class InputPort {
  Future<ImportOutcome> importSource(
    SourceArtifact artifact,
    ImportBinding binding,
    ImportConfiguration config,
    Cancellation cancel,
    void Function() onParsing,
  );
}

abstract interface class ComparisonPort {
  List<WorkflowIssue> get startBlockers;
  Future<ComparisonResult> compare(
    FrozenPlan plan,
    Cancellation cancel,
    void Function(String phase, int done, int? total) onProgress,
  );
}

abstract interface class ExportPort {
  bool supports(ExportKind kind);
  Future<PreparedExport> render(
    ComparisonResult result,
    ExportRequest request,
    Cancellation cancel,
  );
  Future<void> verify(PreparedExport pending, Cancellation cancel);
  Future<ExportReceipt> publish(
    PreparedExport pending,
    String attemptId,
    Cancellation cancel,
  );
  Future<void> discard(PreparedExport? pending);
}

extension ComparisonConfigurationCopy on ComparisonConfiguration {
  ComparisonConfiguration copyWith({
    Iterable<FieldMapping>? mappings,
    Map<String, FieldRule>? rules,
    MatchingMode? mode,
    Iterable<String>? keys,
    ComparisonDirection? direction,
    bool? mappingConfirmed,
    bool? modeConfirmed,
    bool? policyConfirmed,
    bool? directionConfirmed,
  }) => ComparisonConfiguration(
    mappings: mappings ?? this.mappings,
    rules: rules ?? this.rules,
    mode: mode ?? this.mode,
    keys: keys ?? this.keys,
    direction: direction ?? this.direction,
    mappingConfirmed: mappingConfirmed ?? this.mappingConfirmed,
    modeConfirmed: modeConfirmed ?? this.modeConfirmed,
    policyConfirmed: policyConfirmed ?? this.policyConfirmed,
    directionConfirmed: directionConfirmed ?? this.directionConfirmed,
  );
}
