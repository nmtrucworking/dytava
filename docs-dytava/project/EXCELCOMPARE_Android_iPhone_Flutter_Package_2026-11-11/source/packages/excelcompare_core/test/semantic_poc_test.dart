import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:test/test.dart';

void main() {
  const engine = SemanticPolicyEngine();
  const dot = DecimalInputPolicy(decimalSeparator: '.');
  const comma = DecimalInputPolicy(decimalSeparator: ',');

  test('8.5 number vs 8,5 CSV string equivalent with strict source profiles', () {
    final f = FieldPolicy(field: 'score', type: SemanticType.decimal,
        sourceA: dot, sourceB: comma);
    final decision = engine.compare(
        const SourceCell(CellKind.number, rawLexeme: '8.5'),
        const SourceCell(CellKind.text, rawLexeme: '8,5'), f);
    expect(decision.status, DecisionStatus.equivalent);
    expect(decision.left!.label, '8.5');
  });

  test('identifiers preserve leading zeros', () {
    final f = FieldPolicy(field: 'key', type: SemanticType.identifier);
    expect(engine.compare(const SourceCell(CellKind.text, rawLexeme: '00123'),
        const SourceCell(CellKind.text, rawLexeme: '123'), f).status,
        DecisionStatus.different);
  });

  test('numeric identifiers fail closed, no cast', () {
    final f = FieldPolicy(field: 'key', type: SemanticType.identifier);
    expect(engine.compare(const SourceCell(CellKind.text, rawLexeme: '00123'),
        const SourceCell(CellKind.number, rawLexeme: '123'), f).status,
        DecisionStatus.unresolved);
  });

  test('0 versus blank are different', () {
    final f = FieldPolicy(field: 'score', type: SemanticType.decimal, sourceA: dot);
    expect(engine.compare(const SourceCell(CellKind.number, rawLexeme: '0'),
        const SourceCell(CellKind.blank), f).status, DecisionStatus.different);
  });

  test('boolean aliases must be explicit', () {
    final f = FieldPolicy(field: 'passed', type: SemanticType.boolean,
        aliases: {'Không': false});
    expect(engine.compare(const SourceCell(CellKind.boolean, rawLexeme: 'false'),
        const SourceCell(CellKind.text, rawLexeme: 'Không'), f).status,
        DecisionStatus.equivalent);
    final noAlias = FieldPolicy(field: 'passed', type: SemanticType.boolean);
    expect(engine.compare(const SourceCell(CellKind.boolean, rawLexeme: 'false'),
        const SourceCell(CellKind.text, rawLexeme: 'Không'), noAlias).status,
        DecisionStatus.unresolved);
  });

  test('10% equals 0.1 with approved scaling', () {
    final f = FieldPolicy(field: 'ratio', type: SemanticType.percentage,
        sourceA: dot, sourceB: dot, percentSignIsScale: true);
    expect(engine.compare(const SourceCell(CellKind.number, rawLexeme: '0.1'),
        const SourceCell(CellKind.text, rawLexeme: '10%'), f).status,
        DecisionStatus.equivalent);
  });

  test('decimal without explicit locale is unresolved', () {
    final f = FieldPolicy(field: 'score', type: SemanticType.decimal);
    final decision = engine.compare(const SourceCell(CellKind.text, rawLexeme: '1,234'),
        const SourceCell(CellKind.text, rawLexeme: '1.234'), f);
    expect(decision.status, DecisionStatus.unresolved);
    expect(decision.reason, ReasonCode.localeAmbiguous);
  });

  test('unreviewed OCR blocks decision', () {
    final f = FieldPolicy(field: 'score', type: SemanticType.decimal,
        sourceA: dot, sourceB: dot);
    expect(engine.compare(const SourceCell(CellKind.ocrText, rawLexeme: '85',
        ocrReviewed: false),
        const SourceCell(CellKind.number, rawLexeme: '85'), f).reason,
        ReasonCode.ocrReviewRequired);
  });

  test('money-like values not auto tolerated', () {
    final f = FieldPolicy(field: 'score', type: SemanticType.decimal,
        sourceA: dot, sourceB: dot);
    expect(engine.compare(const SourceCell(CellKind.number, rawLexeme: '100000'),
        const SourceCell(CellKind.number, rawLexeme: '100001'), f).status,
        DecisionStatus.different);
  });

  test('invalid negative tolerance throws', () {
    expect(() => FieldPolicy(field: 'x', type: SemanticType.decimal,
        toleranceAbs: '-0.01'), throwsFormatException);
  });
}
