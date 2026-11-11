# 11. Test Strategy, test cases và quality gates

## 11.1. Phương pháp kiểm thử

- Unit: policy parser/canonicalizer/compare state, unicode/timezone/locale, duplicate keys.
- Property-based: symmetry `compare(a,b)` tương thích đảo A/B, determinism, idempotent normalization; điều kiện tiên quyết rõ.
- Golden fixtures: cùng dataset đã biết mọi diff; so report JSON normalized bỏ timestamps.
- Metamorphic: đảo thứ tự hàng **không** thay đổi semantic results ở key-mode; đổi style **không** ảnh hưởng content result.
- Integration: adapters XLSX/CSV/JSON, file corrupt, password protected, 1900/1904 dates.
- Instrumentation: SAF, permissions, process death/restart, storage low, sharing/export.
- Performance: corpus nhiều hàng/cột/sharedStrings, timing distributions p50/p95, max RSS/heap, cold/hot run.
- Security: Excel injection, zipbomb, XML entity, fuzz corpus, malicious formulas, privacy logs.
- OCR: CER, table reconstruction, manual review workflow, same screenshot vs original.

## 11.2. Các test case ưu tiên

| ID | Dữ liệu A | Dữ liệu B | Kỳ vọng |
|---|---|---|---|
| TC-01 | 8.5 numeric | '8,5' string | EQUIVALENT **nếu** locale vi-VN và decimal field |
| TC-02 | '00123' | 123 numeric | DIFFERENT khi identifier |
| TC-03 | 0 | blank | DIFFERENT by default |
| TC-04 | false boolean | 'Không' | EQUIVALENT chỉ với alias configured |
| TC-05 | '01/02/26' | '2026-02-01' | UNRESOLVED khi format date 2-digit year/locale không rõ |
| TC-06 | 100000.00 | 100000 | EQUIVALENT nếu decimal ignores scale |
| TC-07 | Key duplicated | two records same key | UNRESOLVED alignment, no silent first-match |
| TC-08 | rows reordered | same rows | EXACT/EQUIVALENT no changes in key-mode |
| TC-09 | formula `=SUM(A1:A2)` | formula `=A1+A2` | formula changed; values can match |
| TC-10 | archive 1KB→1GB | no other | rejected with safe error |
| TC-11 | input `=HYPERLINK(...)` | report CSV/XLSX | exported as safe text not executable formula |
| TC-12 | OCR '85' | source '8.5' | needs review / unresolved until confirmed |
| TC-13 | schema new column | schema old | FIELD_ADDED |
| TC-14 | Excel 1900/1904 date serial | same date | equivalent after date-system decode |
| TC-15 | 10% | 0.1 | equivalent under percent policy only |
| TC-16 | Policy changed between runs | same file hashes | different policy_digest, separate report revision |

## 11.3. Release gates

Gate 0: parser PoC trên Android thật; Gate 1: unit coverage tập trung critical policies >= 90% branch trên core (mục tiêu nội bộ, không đại diện correctness); Gate 2: các golden fixtures đạt 100%; Gate 3: security tests critical pass; Gate 4: performance benchmark thiết bị mục tiêu; Gate 5: smoke test signed release; Gate 6: release approval và rollback test.

## 11.4. Dataset đánh giá

Ít nhất 3 lớp: (a) synthetic controlled, (b) open datasets không chứa PII, (c) dữ liệu thực đã ẩn danh và có quyền sử dụng. Label truth độc lập; không lấy output engine làm ground truth. Công bố confidence interval nếu đánh giá mô hình OCR/heuristics; đừng chỉ nêu 'độ chính xác 99%' thiếu mẫu số.
