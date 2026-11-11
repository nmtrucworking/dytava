/**
 * Dytava / ExcelCompare - Product Admin Portal Controller
 */
import { CompareEngine } from "./compare-engine.js";

export const ACCEPTANCE_CASES_DATA = [
  { id: "TC-01", type: "decimal", left: "8.5", right: "8,5", policy: "vi-VN decimal separator", expected: "EQUIVALENT" },
  { id: "TC-02", type: "identifier", left: "00123", right: "123", policy: "preserve leading zeros", expected: "DIFFERENT" },
  { id: "TC-03", type: "numeric", left: "0", right: "BLANK", policy: "distinct null zero", expected: "DIFFERENT" },
  { id: "TC-04", type: "boolean", left: "false", right: "Không", policy: "alias false=Không", expected: "EQUIVALENT" },
  { id: "TC-05", type: "date", left: "01/02/26", right: "2026-02-01", policy: "unknown locale date", expected: "UNRESOLVED" },
  { id: "TC-06", type: "percentage", left: "0.1", right: "10%", policy: "percent scaling", expected: "EQUIVALENT" },
  { id: "TC-07", type: "money", left: "100000", right: "100001", policy: "zero tolerance currency", expected: "DIFFERENT" },
  { id: "TC-08", type: "text", left: "Nguyễn An", right: "Nguyen An", policy: "preserve accents", expected: "DIFFERENT" },
  { id: "TC-09", type: "identifier", left: "SV001", right: "sv001", policy: "case-sensitive identifier", expected: "DIFFERENT" },
  { id: "TC-10", type: "numeric", left: "1,234", right: "1.234", policy: "unknown locale separator", expected: "UNRESOLVED" }
];

export class AdminPortal {
  constructor() {
    this.releases = [];
    this.featureFlags = [];
    this.acceptanceCases = [...ACCEPTANCE_CASES_DATA];
    this.engine = new CompareEngine();
  }

  runAllAcceptanceTests() {
    return this.acceptanceCases.map(tc => {
      const start = performance.now();
      const res = this.engine.compareCells(tc.left, tc.right, "testField", tc.type);
      const duration = (performance.now() - start).toFixed(2);
      const passed = res.status === tc.expected;
      return {
        ...tc,
        actual: res.status,
        passed,
        durationMs: duration,
        reason: res.reason,
        ruleId: res.ruleId
      };
    });
  }

  testSinglePolicy(valA, valB, type) {
    return this.engine.compareCells(valA, valB, "customField", type);
  }

}
