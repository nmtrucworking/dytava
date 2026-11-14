---
document_id: DYT-RTM-001
version: 0.4.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng (Android trước; web/iOS có gate riêng)
---

# Dytava — Requirement Traceability Matrix

> Ma trận này **chỉ liên kết** IDs đã được định nghĩa tại [PRD](../product/PRD.md), [SRS](SRS.md), [NFR](NFR.md), [Input](../specs/input/README.md), [Core](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md), [Report](../specs/report/README.md), [Expansion](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) và [ADR](../decisions/ADR_REGISTER_P0_2026-11-11.md). Nó không là test result. Mọi trạng thái thực thi bên dưới mặc định **PLANNED/NOT_VERIFIED**.

## 1. FR → product use case → specialized contract → verification

| SRS ID | Product story | Input/Core contract hoặc ADR | Test kế hoạch / evidence yêu cầu | Phase | Execution |
| --- | --- | --- | --- | --- | --- |
| FR-001 | US-01, US-02 | INP-REQ-001/002/003/007 | INP-TC-001..009/016; Android file provider | P0 | PLANNED |
| FR-002 | US-03 | INP-REQ-004, INP-ADR-003/005 | INP-TC-017..020; XLSX sheet chooser | P0 | PLANNED |
| FR-003 | US-01, US-07, US-11 | INP-REQ-005, INP-RULE-021..025 | INP-TC-021..025/039; provenance oracle | P0 | PLANNED |
| FR-004 | US-03, US-06 | INP-REQ-005/006, INP-ADR-008 | INP-TC-029/030; suggestion vs confirmation | P0 | PLANNED |
| FR-005 | US-04 | INP-REQ-009, INP-ADR-008 | INP-TC-027/029; mapping invalidation E2E | P0 | PLANNED |
| FR-006 | US-04 | Core key semantics, ADR-008 | Semantic key/duplicate oracle, E2E-03/04 | P0 | PLANNED |
| FR-007 | US-05, US-07 | Core matching, ADR-001 | Added/removed/direction golden; E2E-03 | P0 | PLANNED |
| FR-008 | US-05 | Core null/identifier, ADR-006 | Semantic TC-02/03 (TC-02 so sánh hai chuỗi); E2E-05 mới dành cho identifier text và XLSX numeric mất lexical evidence | P0 | PLANNED |
| FR-009 | US-05, US-06 | Core normalization/policy | Semantic TC-01/04/06; policy digest golden (TC-15 từ Master chưa đăng ký trong semantic registry) | P0 | PLANNED |
| FR-010 | US-10 | Core formula design | Formula/cache corpus, must not execute expressions | P1+ | PLANNED |
| FR-011 | US-10 | Metadata separate report | Style/meta fixtures | P1+ | PLANNED |
| FR-012 | US-11 | INP-REQ-010/011, INP-ADR-002 | INP-TC-039/040, Android OCR E2E-06/07 | **P0** | PLANNED |
| FR-013 | US-07, US-08 | Report spec, source refs via INP-005 | Golden report + CSV injection E2E-09 | P0 | PLANNED |
| FR-014 | US-05, US-08 | Core policy digest/versioning | Deterministic replay; policy-change golden | P0 | PLANNED |
| FR-015 | US-09 | INP-REQ-008/011, ADR-009 | INP-TC-003/004/034..038, E2E-08 | P0 | PLANNED |
| FR-016 | US-13 | EXP-ADR-001, INP-REQ-002/007/008, NFR §3 | LARGE-TC-001..008; valid 1 GB A/B, bounded memory/disk, EOF/hash/cancel | P0 mở rộng | PLANNED |
| FR-017 | US-14 | EXP-ADR-002, Report spec §2 | REP-TC-001..005/008..012; merged union PDF + render/count oracle | P0 mở rộng | PLANNED |
| FR-018 | US-15 | EXP-ADR-002, Report spec §3 | REP-TC-003/005..012; template Dytava 1.0.0 + PDF/JSON reconciliation | P0 mở rộng | PLANNED |

**Các lưu ý trước test PASS:** Registry semantic [TC-02](../examples/acceptance_cases.json) dùng hai giá trị chuỗi `00123` và `123`, kỳ vọng DIFFERENT; trường hợp này **không mâu thuẫn** với ADR-006. Riêng nguồn XLSX lưu numeric `123` có thể đã mất thông tin lexical identifier, nên E2E-05 mới phải kiểm tra UNRESOLVED/review theo ADR-006. Không sửa oracle TC-02 để gộp hai trường hợp. InputConfig 0.1.0 chưa hỗ trợ image P0: cần migration trước khi INP-TC-039/040 có integration runner.

## 2. NFR → verification matrix

| Quality requirement | Evidence gate / dataset | Execution |
| --- | --- | --- |
| NFR-PERF-01..04 | Platform/device benchmark p50/p95/peak memory/scratch/output; profile large-input-v1, 50k×15 và valid 1 GB boundary corpus | NOT_VERIFIED |
| NFR-REL-01 | Consent-based pilot crash-free with denominator; not a unit-test metric | NOT_VERIFIED |
| NFR-REL-02/03 | Cancellation, restart and temp cleanup injection; INP-TC-034..038 | NOT_VERIFIED |
| NFR-SEC-01/02/03/04 | Source hashes, redacted logs, network/offline inspection, malformed/CSV injection corpus | NOT_VERIFIED |
| NFR-COR-01/02 | Golden semantic report deterministic; refs and rule IDs | NOT_VERIFIED |
| NFR-UX-02 | PDF text extraction + page render + fonts/reading order/grayscale, REP-TC-003/004/006/012 | NOT_VERIFIED |
| NFR-UX-01 | TalkBack/scaled fonts/manual accessibility checklist | NOT_VERIFIED |
| NFR-OPS-01 | Android airplane-mode first install, OCR bundled model usable immediately | NOT_VERIFIED |
| NFR-OCR-01 | INP-TC-039/040 and OCR review/crop invalidation device tests | NOT_VERIFIED |
| NFR-PRIV-01 | Inspect app-private storage after success, fail, cancel, process death and restart | NOT_VERIFIED |
| NFR-TEST-01 | Signed APK + CI + device evidence with commit SHA/fixture hashes | NOT_VERIFIED |

## 3. Evidence record template

Một result chỉ được chuyển từ `PLANNED` → `PASS/FAIL` khi gắn:
```yaml
requirement_ids: [FR-012, NFR-OCR-01, INP-REQ-010]
test_ids: [INP-TC-039, INP-TC-040]
status: NOT_RUN   # đổi thành PASS/FAIL sau khi thực thi
commit_sha: null
app_build: null
engine_version: null
adapter_and_model_versions: null
device_model: null
android_api_level: null
fixture_hashes: []
runner_command: null
run_timestamp_utc: null
evidence_uri: null
notes: "Documented plan; no runtime evidence yet."
```

**Không điền null bằng dữ liệu dự đoán.** Chỉ tạo artifact evidence khi test runner chạy thật; traceability không chứng minh implementation. Kết quả Web/Node.js không thay thế Android device results.

## 4. Change impact procedure

Baseline mới: [LARGE-TC-*](../testing/EXPANDED_SCOPE_ACCEPTANCE.md) và [REP-TC-*](../specs/report/README.md#6-acceptance-registry) bổ sung, không thay INP-TC-001..040/semantic TC-*.

PRD US/phase change → SRS FR mapping → Input/Core contract/ADR implications → NFR gates → architecture module changes → fixtures/test runner → evidence. Nếu không resolve đủ liên kết, giữ DRAFT và mở issue thay vì âm thầm xóa ID.

## 5. Thuật toán chính UDG v3 → layers → requirements

Nguồn thiết kế hiện hành: [UDG3.1](../specs/engine/README.md); [30 gap dispositions và UDG-TC-001..020](../testing/UDG_CONTRACT_ACCEPTANCE.md) liên kết owner contracts/examples. [Review v3](../project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md) chỉ giữ lịch sử gap IDs. Bảng này không định nghĩa thêm yêu cầu, thay oracle hoặc công bố PASS; fixtures Fxx vẫn là danh mục thiết kế.

| Layer | Requirement / owner refs | Verification kế hoạch |
| --- | --- | --- |
| L0 Scope/plan | FR-001/002/005/006/012/016, EXP-ADR-001..003, NFR §3 | Capability/phase/profile và confirmation gates |
| L1 Access | FR-001/003/015/016, Input/ADR-009 | INP-TC-003/006/037; LARGE-TC-001/004/005/008 |
| L2 Parse/snapshot | FR-003/008/012/016, INP-005/008/010 | INP-TC-021..025/039/040; LARGE-TC-003/004 |
| L3 Geometry/mapping | FR-002/004/005, Input scope/field IDs | Scope/header/field mapping cases; v3 F10/F11/F12/F13/F22/F24 theo phase |
| L4 Policy/hash | FR-008/009/014, Core §5.2..6 | Semantic golden; v3 F04/F06/F07/F15/F19 |
| L5 Candidates/index | FR-006/016, Core keys | Global duplicate/null/collision cases; LARGE-TC-002/003/006 |
| L6 Alignment | FR-006/007/014, SRS §4.2 | KEY/POSITIONAL P0; v3 F16/F20 chỉ extension ORDERED/MULTISET |
| L7 Typed diff | FR-008/009; FR-010/011 P1+ | Core semantic golden, flags/verdict precedence, unknown/loss cases |
| L8 Audit/result | FR-007/013/014/015, SRS §4.4, Report | Conservation/counts, stale/partial guards; LARGE-TC-005/007/008 |
| L9 Runtime | FR-015/016, INP-008, ADR-009, NFR-REL-02/03 | INP-TC-034..038; LARGE-TC-005/006 |
| L10 UI/export | FR-013/017/018, Report/NFR-UX-02 | REP-TC-001..012; LARGE-TC-007; no incomplete publication |

Toàn bộ thực thi của phần bổ sung này là **PLANNED/NOT_RUN**; lần cập nhật 13/11/2026 chỉ review/biên soạn docs, không kiểm tra mã hoặc chạy benchmark.

## 6. Contract baseline → UDG cases

| Contract | FR / NFR liên quan | UDG verification kế hoạch |
| --- | --- | --- |
| EP-1/capability matrix | FR-001/002/005/006/012/016 | UDG-TC-001/002/015 |
| ISC-1/target Input0.2 | FR-001/003/008/012/015/016, NFR-SEC/PRIV/REL | UDG-TC-003..006/018 |
| GF-1/geometry | FR-002/004/005, explainability | UDG-TC-007/008 |
| CE-1/CFG-1 | FR-008/009/014, NFR-COR-01/02 | UDG-TC-009/010/011 |
| Candidate/alignment | FR-006/007/014/016, bounded work | UDG-TC-011..013; extensions riêng P0 |
| Core decision tables | FR-008/009; FR-010/011 extensions | UDG-TC-014/015 |
| ER-1/WP-1 | FR-013/014/015/016, NFR-REL/COR/PRIV | UDG-TC-015..018 |
| EX-1 | FR-013/017/018, NFR-UX-02/SEC-03 | UDG-TC-019/020; REP-TC-* |
| RP-1 | NFR-PERF-01..04, NFR-REL-02/03 | UDG-TC-002/013/017; LARGE-TC-* |

Execution mọi hàng NOT_RUN. Schema/validator migration, calibration và device evidence còn cần hiện thực; contract SPECIFIED không tự thành VERIFIED. Không thay semantic/Input/Report/LARGE oracle cũ.
