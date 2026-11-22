import 'package:test/test.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
void main() {
  test('meaningful names win despite schema changes, generic labels require structure', () {
    expect(mapSheets([SheetDescriptor('Revenue', ['id'])], [SheetDescriptor('Revenue', ['other'])]).pairs.single.method, 'name');
    final a = [SheetDescriptor('Sheet1', ['sku', 'cost']), SheetDescriptor('Sheet2', ['person', 'name'])];
    final b = [SheetDescriptor('Sheet1', ['person', 'name']), SheetDescriptor('Sheet2', ['sku', 'cost'])];
    expect(mapSheets(a, b).pairs.map((p) => (p.a, p.b, p.method)), [(0, 1, 'structure'), (1, 0, 'structure')]);
    expect(mapSheets([SheetDescriptor('A', ['Cột 1'])], [SheetDescriptor('B', ['Cột 1'])]).complete, isFalse);
  });
  test('binary content comparison precedes text/number policy and verifies bytes after hash', () {
    const engine = WebCellEngine();
    const image = SourceCell(CellKind.image, rawLexeme: 'same', imageDigest: 'same-hash', imageBytes: [1, 2]);
    const other = SourceCell(CellKind.image, rawLexeme: 'same', imageDigest: 'same-hash', imageBytes: [1, 3]);
    expect(engine.compare(image, other).status, DecisionStatus.different);
    expect(engine.compare(image, const SourceCell(CellKind.text, rawLexeme: 'same')).status, DecisionStatus.different);
    expect(engine.compare(image, image).status, DecisionStatus.exact);
    const unknown = SourceCell(CellKind.unsupported, rawLexeme: '#VALUE!');
    expect(engine.compare(unknown, unknown).status, DecisionStatus.unresolved);
    expect(const SemanticPolicyEngine().compare(unknown, unknown, FieldPolicy(field: 'f', type: SemanticType.freeText)).status, DecisionStatus.unresolved);
  });
}
