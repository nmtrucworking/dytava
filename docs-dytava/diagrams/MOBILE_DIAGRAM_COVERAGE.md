---
document_id: DYT-DIAG-COVERAGE-001
version: 1.0.0
status: DRAFT
owner: Documentation integration role
reviewer: TBD
updated: 2026-11-17
release_baseline: Android P0 mở rộng; UDG3.1
execution_state: NOT_VERIFIED
---

# Mobile diagrams — coverage và kiểm soát tính nhất quán

Bộ sơ đồ gồm **30 hình**: [8 activity](MOBILE_ACTIVITIES.md), [8 sequence](MOBILE_SEQUENCES.md), [3 state machines](MOBILE_STATES.md) và [11 system/domain/deployment/release diagrams](MOBILE_MODELS.md). Mermaid là nguồn chỉnh sửa; SVG là bản render dẫn xuất. Sơ đồ đọc cùng owner docs, không thay hợp đồng, wire schemas, test oracles hoặc version registry.

**Trạng thái:** đối chiếu thiết kế với owner contracts và kiểm tra tài liệu/render; không có engine/device/1 GB/PDF runtime verification trong công việc này. Coverage trong bảng nghĩa yêu cầu được **tham chiếu/biểu diễn**, không có nghĩa implementation đáp ứng hoặc test PASS. Không tuyên bố mọi chi tiết raw/wire có thể suy ra chỉ từ hình.

## 1. Nguồn, precedence và baseline

Theo [Document Control](../governance/DOCUMENT_CONTROL.md), domain owner quyết định nghĩa; không dùng archive hoặc code PoC ghi đè docs hiện hành.

| Domain | Nguồn sở hữu hiện hành | Cách áp dụng trong sơ đồ |
| --- | --- | --- |
| Product/phase | [PRD](../product/PRD.md), [SRS](../requirements/SRS.md), [ADR register](../decisions/ADR_REGISTER_P0_2026-11-11.md), [scope expansion](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) | Android P0, một scope mỗi nguồn, tối đa một ảnh, 1 GB/source và hai PDF |
| Input/raw | [Input index INP-001..011](../specs/input/README.md), [ISC-1](../specs/input/11_streaming_snapshot_contract.md), [current schemas](../specs/input/schemas/import_config.schema.json) | Strict validation, raw/provenance, EOF/hash, target0.2 migration và readiness guards |
| Core | [Semantic spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md), [policy2.1.0](../project/comparison_policy.v2.example.json), [CE-1](../specs/core/CANONICAL_ENCODING.md), [decision tables](../specs/core/COMPARISON_DECISIONS.md) | Typed field policies, four verdicts, framing, signatures, no implicit casts |
| Execution | [UDG3.1](../specs/engine/README.md), [EP-1](../specs/engine/01_execution_plan.md), [Geometry](../specs/engine/02_geometry_mapping.md), [Matching](../specs/engine/03_candidate_alignment.md) | Frozen plan, confirmed geometry, P0 matching và disabled extension gates |
| Runtime/persistence | [Architecture](../architecture/ARCHITECTURE.md), [ER-1/WP-1](../specs/engine/04_result_runtime.md) | Domain boundaries, cursors/leases, staging, atomic publish, cancel/recovery |
| Resource/quality | [NFR](../requirements/NFR.md), [RP-1](../requirements/RESOURCE_PROFILES.md) | Finite calibrated limits, control reserve, no invented benchmark thresholds |
| Presentation/export | [Report](../specs/report/README.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md), [legacy renderer boundary](../specs/report/RENDERER.md), [existing report schema](../specs/report/schemas/dytava-report.schema.json) | Bounded query/output, counts/scope, safe text/passive PDF, no semantic recomputation |
| Verification/release | [RTM](../requirements/TRACEABILITY_MATRIX.md), [Input cases](../specs/input/09_acceptance_tests.md), [UDG cases](../testing/UDG_CONTRACT_ACCEPTANCE.md), [large-input cases](../testing/EXPANDED_SCOPE_ACCEPTANCE.md), [release guide](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Planned evidence gates, platform-specific testing, no false implementation PASS |

[mobile-diagrams.baseline.json](mobile-diagrams.baseline.json) ghi SHA-256 các owner docs, registry/schema và nguồn chính được đối chiếu. Fingerprint chỉ phát hiện nội dung thay đổi; không là phê duyệt, chữ ký hoặc chứng minh semantics. Khi fingerprint thay đổi phải review diagram affected rồi cập nhật baseline có chủ ý, không tự ghi đè baseline để làm checker xanh.

Archive Master2.2, UDG3.0 PDF/DOCX/review gốc và bundle snapshots chỉ dùng audit khi được owner docs dẫn. README/code PoC/brand assets không là capability evidence. Không snapshot `.obsidian`, raw user datasets hoặc file người dùng đang biên tập riêng vào baseline này.

### Các điểm xung đột lịch sử đã xử lý

| Điểm dễ lệch | Quyết định áp dụng |
| --- | --- |
| Master/ADR-004 còn cap10 MiB, 20k rows hoặc total60s | EXP-ADR/NFR/RP-1: source cap1.000.000.000 bytes, workload/device limits riêng; không kế thừa cap nhỏ làm cap sản phẩm |
| SAD nhắc 12MP bootstrap | Theo RP-1/NFR: OCR dimensions/pixels/decode limits phải được profile resolve/calibrate; không copy số bootstrap thành enabled production limit |
| Input0.1/examples cũ ghi JSON P0 hoặc ảnh scope chưa có schema | PRD/ADR: JSON input P1; một reviewed image Android P0 nhưng target0.2 schema/validator/capability gates bắt buộc |
| UDG3.0 sample có COMPLETE/UNDETERMINED, hash shortcut hoặc moved inference | Current contracts: COMPLETED cho job; UNRESOLVED cho cell; full-byte verification và no definitive P0 MOVED |
| Core/source prose nhắc POSITION, advanced types, relative tolerance hoặc similarity | P0 dispatch dùng POSITIONAL/KEY theo EP-1; types/operations có capability, không tự thêm relative tolerance hoặc fuzzy join |
| Existing renderer dytava-report1.0.0 và engine ER-1 | Namespaces khác; bridge nhỏ/representable có guards; không whole-result legacy envelope cho1GB hoặc COUNT_GROUP |
| Provider không có atomic rename | Chỉ verified pending-object/commit strategy thay thế; direct visible writes không rollback guarantee bị reject |
| Schema/brand/CI có mặt trong repo | Không cấp VERIFIED, ENABLED hoặc release PASS; cần fixture/device/calibration evidence |

## 2. FR-001..018 và phase coverage

IDs trong bảng chỉ tham chiếu [SRS](../requirements/SRS.md); phase do PRD/SRS sở hữu.

| FR | Diagram references | Ranh giới đã giữ |
| --- | --- | --- |
| FR-001 | ACT-02; SEQ-01; ST-01; MOD-01/05 | A/B independent, read-only content validation và access guards |
| FR-002 | ACT-02/04; SEQ-01/03; MOD-07 | Một selected table/scope mỗi phía; header/scope user confirm |
| FR-003 | ACT-02/03/06; SEQ-01/02/05; MOD-03/07 | Raw kinds, actual SourceRefs, OCR geometry/corrections và loss declaration |
| FR-004 | ACT-04; SEQ-03; MOD-07 | Inference/GF-1 là proposals, không semantic truth/auto-accept |
| FR-005 | ACT-04; SEQ-03; MOD-03/07 | Field ID bijection, revisions và stale mapping blocked |
| FR-006 | ACT-04/05; SEQ-03/04; MOD-10 | Explicit KEY/POSITIONAL, ordered strict tuple keys; global duplicates/null handling |
| FR-007 | ACT-05; SEQ-04/05; MOD-04 | Separate row/field structural events; direction đổi labels, không fabricate cell pairs |
| FR-008 | ACT-06; MOD-03/08 | Distinct missing/blank/empty/null/zero; numeric identifier lexical loss unresolved |
| FR-009 | ACT-06; SEQ-03/04/05; MOD-08 | Confirmed typed policy, four-state precedence, trace và capability gates |
| FR-010 | MOD-10 | P1+ formula modes theo Core decision table, không evaluate; không nằm P0 run path |
| FR-011 | MOD-10 | P1+ style/metadata facets riêng, không trộn cell similarity |
| FR-012 | ACT-03; SEQ-02; MOD-03/05/11 | Một bundled/offline OCR image, all selected cells reviewed, current receipts |
| FR-013 | ACT-07; SEQ-05/06; MOD-04 | Counts/denominators, CSV/JSON lineage và safe output |
| FR-014 | ACT-04/05; SEQ-03/04; MOD-08/11 | Deterministic lineage/versions/digests; timestamp ngoài semantic comparison |
| FR-015 | ACT-08; SEQ-07/08; ST-01/02/03; MOD-09 | Cancel/retry/cleanup, stale guards, restart/revalidate sau process death |
| FR-016 | ACT-02/05; SEQ-01/04; MOD-05/09/11 | 1 GB/source, full EOF/hash, bounded parse/match/spill và evidence gates |
| FR-017 | ACT-07; SEQ-06; ST-03; MOD-11 | Một merged union PDF/kind, raw A/B/status/structural labels, full/filtered counts |
| FR-018 | ACT-07; SEQ-06; ST-03; MOD-11 | Template Dytava versioned, local fonts, audit và immutable result source |

## 3. Input requirements và ADR coverage

| Input requirement | Diagram references |
| --- | --- |
| INP-REQ-001 | ACT-01/02; SEQ-01/03; ST-01 |
| INP-REQ-002 | SEQ-01/08; MOD-03/05/09 |
| INP-REQ-003 | ACT-02; SEQ-01; MOD-10 |
| INP-REQ-004 | ACT-02/04; SEQ-01/03; MOD-07 |
| INP-REQ-005 | ACT-06; SEQ-01/02/05; MOD-03/08 |
| INP-REQ-006 | ACT-04; SEQ-03; MOD-08 |
| INP-REQ-007 | ACT-02; SEQ-01/07; ST-01; MOD-09 |
| INP-REQ-008 | ACT-08; SEQ-07/08; ST-01/02/03 |
| INP-REQ-009 | ACT-04; SEQ-03; MOD-03 |
| INP-REQ-010 | ACT-03; SEQ-02; MOD-03/05 |
| INP-REQ-011 | SEQ-01/02/06/08; MOD-05/09 |
| INP-REQ-012 | MOD-11; coverage §1/6 và baseline/checker |

| ADR | Diagram references và cách áp dụng |
| --- | --- |
| INP-ADR-001 | ACT-04/05; SEQ-03; explicit direction và stale result sau đổi chiều |
| INP-ADR-002 | ACT-03; SEQ-02; bundled OCR, một ảnh và target schema gates |
| INP-ADR-003 | ACT-02/04; MOD-01/07; một scope/table mỗi nguồn |
| INP-ADR-004 | MOD-09/11; historical small profile không thay expanded scope |
| INP-ADR-005 | ACT-02; SEQ-01; header/dialect/encoding phải confirm |
| INP-ADR-006 | ACT-06; MOD-08; không tái tạo identifier leading zeros từ numeric/display |
| INP-ADR-007 | SEQ-01; MOD-02/05/11; một adapter boundary, fidelity gates; không chốt dependency từ proposal |
| INP-ADR-008 | ACT-04; SEQ-03; proposal không auto-confirm policy/mode/key |
| INP-ADR-009 | ACT-08; SEQ-08; MOD-09; scratch/leases/minimal recovery và no raw history |
| EXP-ADR-001 | SEQ-01/04; MOD-09/11; 1 GB/source, full validated pipeline |
| EXP-ADR-002 | ACT-07; SEQ-06; merged diff và Dytava report là hai outputs |
| EXP-ADR-003 | MOD-02/05/10/11; P0 mở rộng, platform evidence riêng, no cloud fallback |

## 4. NFR coverage

| NFR | Diagram references / giới hạn evidence |
| --- | --- |
| NFR-PERF-01 | ACT-02; SEQ-01; provisional preview khác PREVIEW_READY; chưa claim latency |
| NFR-PERF-02 | MOD-09/11; stress/boundary corpus là planned evidence |
| NFR-PERF-03 | SEQ-04; MOD-05/09; whole-process bounded allocation, không OOM-based governor |
| NFR-PERF-04 | SEQ-01/04/06; MOD-09/11; private spill, stage/disk/output bounds |
| NFR-UX-02 | ACT-07; SEQ-06; MOD-11; labels, Vietnamese fonts, page/band coverage và render QA gates |
| NFR-REL-01 | MOD-11; pilot crash-free target post-P0, không suy từ unit tests |
| NFR-REL-02 | SEQ-07; ST-02/03; durable cleanup trước cancel ACK |
| NFR-SEC-01 | SEQ-01/02/06; MOD-05; nguồn read-only và output tách biệt |
| NFR-SEC-02 | SEQ-01/07/08; MOD-05/11; no raw/URI/token logs/public report |
| NFR-COR-01 | ACT-04/05; MOD-08/11; deterministic versions/hash/config |
| NFR-COR-02 | ACT-06; SEQ-05; MOD-03/04; rule/canonical/SourceRefs |
| NFR-UX-01 | MOD-11; TalkBack/text-scale/touch-target review là device/UI acceptance, không chứng minh chỉ bằng diagram |
| NFR-OPS-01 | SEQ-02; MOD-05/11; bundled assets/model và airplane-mode first-run evidence |
| NFR-REL-03 | SEQ-08; ST-01/02; no restore partial READY |
| NFR-SEC-03 | SEQ-06; MOD-11; CSV reader corpus, passive PDF, no secrets |
| NFR-SEC-04 | SEQ-01; MOD-05/09/11; unsafe ZIP/XML/links fail closed, no execution |
| NFR-OCR-01 | SEQ-02; ACT-03; receipt revision/hash/polygon và selected-cell count |
| NFR-PRIV-01 | SEQ-08; MOD-09; active-consumer retention và orphan sweep |
| NFR-TEST-01 | MOD-11; versioned schemas/oracles/device/profile/signing evidence |

## 5. Ba mươi UDG gaps và planned acceptance

Đây là references tới [owner gap registry](../testing/UDG_CONTRACT_ACCEPTANCE.md), không đổi disposition SPECIFIED/PENDING hoặc trạng thái NOT_RUN.

| Gap ID | Diagram references | Acceptance references |
| --- | --- | --- |
| UDG-L0-01 | ACT-04; MOD-01/10 | UDG-TC-001 |
| UDG-L0-02 | MOD-09/11 | UDG-TC-002 |
| UDG-L1-01 | SEQ-01; MOD-05 | UDG-TC-003 |
| UDG-L1-02 | SEQ-01; MOD-09 | UDG-TC-004 |
| UDG-L2-01 | SEQ-01/02; MOD-03 | UDG-TC-006 |
| UDG-L2-02 | SEQ-01; MOD-05 | UDG-TC-005 |
| UDG-L2-03 | SEQ-01; ACT-02 | UDG-TC-005 |
| UDG-L3-01 | ACT-04; MOD-07 | UDG-TC-007 |
| UDG-L3-02 | MOD-07; ACT-04 | UDG-TC-008 |
| UDG-L3-03 | MOD-07 | UDG-TC-008 |
| UDG-L4-01 | MOD-08; ACT-05 | UDG-TC-009/011 |
| UDG-L4-02 | ACT-05/06; MOD-08/10 | UDG-TC-010 |
| UDG-L4-03 | SEQ-03; MOD-08 | UDG-TC-009/010 |
| UDG-L5-01 | ACT-05; SEQ-04 | UDG-TC-012 |
| UDG-L5-02 | ACT-05; SEQ-04 | UDG-TC-011/012 |
| UDG-L5-03 | MOD-10 | UDG-TC-013 |
| UDG-L6-01 | MOD-10 | UDG-TC-013 |
| UDG-L6-02 | MOD-09/10 | UDG-TC-013 |
| UDG-L6-03 | MOD-04/10 | UDG-TC-011/013 |
| UDG-L7-01 | ACT-06; SEQ-04/05; MOD-04 | UDG-TC-014/015 |
| UDG-L7-02 | ACT-06; MOD-10 | UDG-TC-014 |
| UDG-L7-03 | SEQ-05; MOD-09 | UDG-TC-014 |
| UDG-L8-01 | ACT-05; MOD-04 | UDG-TC-015 |
| UDG-L8-02 | SEQ-04; MOD-04 | UDG-TC-016 |
| UDG-L8-03 | ACT-05; SEQ-08; ST-02; MOD-09 | UDG-TC-015/018 |
| UDG-L9-01 | SEQ-04/07; ST-02 | UDG-TC-016/017 |
| UDG-L9-02 | SEQ-04/05/07; MOD-09 | UDG-TC-017 |
| UDG-L9-03 | SEQ-08; ST-01/02 | UDG-TC-018 |
| UDG-L10-01 | ACT-07; SEQ-06; MOD-04 | UDG-TC-019 |
| UDG-L10-02 | SEQ-05/06; ST-03; MOD-09 | UDG-TC-019/020 |

Input cases INP-TC-001..040, semantic TC-* và E2E cases giữ owner oracles hiện hành; diagrams không thay expected payloads. LARGE-TC-001..008 gắn SEQ-01/04/06/07/08 và MOD-09/11. REP-TC-001..012 gắn ACT-07, SEQ-05/06, ST-03 và MOD-11. Không đánh dấu các registry này PASS từ việc vẽ hình.

## 6. Checklist đối chiếu và kiểm tra tái lập

Các invariants đã dùng để desk-review diagrams:

1. Scope đúng Android P0 mở rộng: A/B independent, một scope mỗi nguồn, tối đa một reviewed image; JSON/iOS và extension types/modes giữ pha riêng.
2. Preflight đúng thứ tự; actual byte/decompression/token/pixel counters; source/parsed hash cùng bytes; no READY từ sample/prefix hoặc mismatched attempt.
3. Raw/provenance không bị semantic normalization sửa; OCR original/correction riêng, receipts current và all selected cells reviewed.
4. Plan/mapping/mode/key/policy/direction confirm; CE-1/CFG-1 bytes/digests/version bindings; no hash-only identity, implicit casts, tolerance keys hoặc auto-accepted GF-1.
5. Global duplicates/null/absence proof, positional tails, full ownership conservation; structural events khác cell verdicts; rates denominator0 là N/A và unresolved giữ trong denominator.
6. Bounded credits/chunks/work/write/read transactions; current WP-1 tuple/sequence/dedup; no stale commit hoặc fake cancel ACK.
7. Full audit trước atomic publication; all full-result ledgers kể cả exact/equivalent; result validity mutable riêng, no export partial/stale/cancelled.
8. Stable keyset/cursor/filter binding, immutable detail, highlight omission không đổi verdict; renderer không recompute semantics.
9. Bốn output kinds, explicit scope/counts, safe CSV/JSON/passive PDF, local fonts/assets, no silent truncation/split; provider strategy verified, output hash ngoài chính artifact.
10. Owners/leases giữ evidence tới khi consumers xong; cancel/failure/close/startup cleanup, no raw history hoặc process-death resume; user-owned exports không bị sweep.
11. No invented enabled profile/calibration/benchmark/sign-off; separate platform evidence và release gates. Không thay wire0.1 hoặc legacy report1.0 tại chỗ.

Tool kiểm tra: [render-mobile-diagrams.mjs](../../scripts/render-mobile-diagrams.mjs).

```bash
# Từ gốc repository, dùng Playwright đã khai báo trong package.json
node scripts/render-mobile-diagrams.mjs --check

# Sau khi sửa Mermaid và đối chiếu lại owner docs, render SVG dẫn xuất
node scripts/render-mobile-diagrams.mjs --render
```

Checker so fingerprints, các link/anchor, ID coverage và syntax/render của 30 Mermaid blocks; kiểm node labels không tràn và edge labels không chồng nhau trong layout đã render. Nó **không tự chứng minh semantic compliance**, không tự enable capabilities, sửa requirements, cập nhật baseline hoặc chạy acceptance runtime. Renderer dùng Mermaid11.12.2 pinned với SHA-256 integrity check, cache tạm ngoài repo; Chromium từ Playwright. Nếu môi trường chưa có browser thì cần cài theo tooling của repo trước khi chạy, không thay package/runtime dependencies của app chỉ để vẽ sơ đồ.

Docs QA ngày 17/11/2026: render/check 30 diagrams, 48 source fingerprints, 219 local links/anchors; đủ coverage references cho 18 FR, 12 INP-REQ, 19 NFR và 30 UDG gaps. Standalone SVG XML và source-to-SVG metadata được kiểm tra; các hình sequence/state/resource đại diện được xem lại. Kết quả này chỉ áp dụng tài liệu, không đổi execution state NOT_VERIFIED của runtime/acceptance registries.

`MANIFEST_SHA256.txt` được cập nhật cho chính các file thuộc công việc này. Files `.obsidian` hoặc ảnh người dùng tạo riêng không bị sửa/thêm vào bộ sơ đồ hay baseline. Khi bổ sung diagram ID/source phải cập nhật index/coverage, rerender và refresh task-owned manifest entries; giữ execution status riêng với docs QA.
