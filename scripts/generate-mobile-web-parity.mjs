// Regenerate the independent Dart parity oracle from the current web engine.
import { writeFileSync } from 'node:fs';
import { CompareEngine } from '../web/js/compare-engine.js';
const pairs = [['8.5','8,5'],['005','5'],['SV001','sv001'],['10%','0.1'],['true','Có'],['No','false'],['','0'],['NULL',''],['1,234','1.234'],['07/10','0.7'],['2026-11-18','18/11/2026'],['01/02/26','2026-02-01'],['Apple','apple'],[' x ','x'],['a   b','a b'],['a','b'],['150,000,000','150.000.000'],['9007199254740993','9007199254740992'],['007','007'],['12.0','12']];
const policies = [{}, {case_sensitive_text:true}, {trim_text:false}, {preserve_leading_zeros:false}, {case_sensitive_identifier:false}, {distinct_null_zero:false}, {tolerance_abs:1}];
const fixtures = policies.flatMap(policy => pairs.map(([a,b]) => {
  const result = new CompareEngine(policy).compareCells(a,b);
  return { a,b,policy,status:result.status,rule:result.ruleId,normA:result.normA,normB:result.normB };
}));
writeFileSync(new URL('../mobile/test/fixtures/web-cell-parity.json', import.meta.url), JSON.stringify(fixtures,null,2)+'\n');
