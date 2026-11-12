---
document_id: DYT-NFR-001
version: 0.2.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-12
release_baseline: P0 mở rộng (Android trước; web/iOS có gate riêng)
source: EXCELCOMPARE_MASTER_ANDROID_IOS 2.2 sections 09-11 (historical)
---

# Dytava — Non-Functional Requirements (NFR)

> **Nguồn duy nhất cho mục tiêu chất lượng đo được và phương pháp xác minh**. `TARGET` là mục tiêu phải đo, `BOOTSTRAP_GUARDRAIL` là trần từ chối an toàn chưa được benchmark, `RELEASE_GATE` là điều kiện không được bỏ qua; không nhầm một trong ba với kết quả thực nghiệm. P0 Android offline-first + reviewed OCR theo [9 ADR](../decisions/ADR_REGISTER_P0_2026-11-11.md).

## 1. Định nghĩa evidence và trạng thái

- **Requirement status:** `DRAFT` (tài liệu chưa approved). **Execution status** cho toàn bộ chỉ số dưới đây: `NOT_VERIFIED`; không điền PASS khi chưa có test.
- Mọi evidence gắn `commit_sha`, `build_id`, device model/RAM/API level/ABI, Flutter/Dart/Android plugin versions, dataset/fixture hash, parser/engine/policy version, run count, p50/p95/min/max (nếu metric thời gian), peak memory, kết quả và log đã redacted.
- Golden oracle độc lập với output engine; performance sampling/benchmark có cold/hot runs và nêu rõ điều kiện nền; không lấy kết quả Web làm bằng chứng mobile.
- **Release-blocking**: sai kết luận ngữ nghĩa, source mutation, cloud upload ngoài ý muốn, export injection có thể thực thi, dữ liệu cá nhân trong logs, OCR bypass review hoặc crash/OOM trong corpus P0 đã chốt.

## 2. Catalogue yêu cầu chất lượng

| ID | Thuộc tính / requirement | Objective / đo lường | Cách chứng minh / Gate |
| --- | --- | --- | --- |
| **NFR-PERF-01** | Responsiveness preview | Mục tiêu nghiên cứu `≤3s` để hiển thị **preview đầu tiên của small corpus** trên thiết bị tham chiếu; **không đồng nghĩa Input PREVIEW_READY** | Android p50/p95 cold/hot; TARGET chưa đo |
| **NFR-PERF-02** | Throughput stress | Corpus 50.000×15 là một mốc stress trong scope mở rộng; bổ sung valid corpus tới 1 GB/source, không áp cap P0 cũ 20k rows | Streaming/external matching, full oracle và resource measurements; P0 mở rộng gate |
| **NFR-PERF-03** | Peak memory & bounded work | Không OOM trong corpus P0 trên Android device reference 4GB/6GB được chốt; không load toàn workbook/bitmap không giới hạn | Android Profiler/heap max, repeat runs; release gate |
| **NFR-PERF-04** | Large-file resource stability | Import → compare → export nguồn tới 1 GB; bounded working set, stage timings, peak scratch/output, quota/disk headroom | LARGE-TC-* theo profile/nền tảng, NOT_VERIFIED |
| **NFR-UX-02** | PDF readability / fidelity | Không mất/trùng/cắt rows/cells/text; Vietnamese searchable/embedded fonts, labels không chỉ màu, headers/reading order | REP-TC-003/004/006/012; render + extraction + visual QA |
| **NFR-REL-01** | Crash-free sessions | Mục tiêu pilot `≥99,5%` chỉ sau telemetry được đồng ý, có mẫu số và thời gian quan sát; **không thể kết luận từ unit tests** | Pilot thống kê; POST-P0 TARGET |
| **NFR-REL-02** | Cancellation | Cancel/timeout/retry không tạo report `COMPLETED` một phần; cleanup idempotent | Inject cancel ở mỗi stage, verify output/cleanup |
| **NFR-SEC-01** | Source immutability | **0 ghi dữ liệu vào nguồn gốc**; import, OCR/crop, export chỉ dùng derivatives/outputs mới | Hash bytes trước/sau, file/SAF permission tests |
| **NFR-SEC-02** | Data disclosure | **0 raw cell/URI/access token/OCR text trong logs/crash/telemetry**; không upload mặc định | Log/packet/app storage inspections |
| **NFR-COR-01** | Determinism | Cùng bytes hash + import config/adapter version + policy digest + engine + match mode cho cùng semantic report (trừ generated_at/non-semantic metadata) | Golden compare canonical report, multiple runs |
| **NFR-COR-02** | Explainability | **100% EQUIVALENT matched pairs** có rule ID, canonical trace; mọi diff có SourceRef thật hoặc missing reason | Automated report schema/audit checks |
| **NFR-UX-01** | Accessibility | Text scale, screen reader labels, touch targets, trạng thái có text/icon không chỉ màu; review screen không giấu blocker | Manual Android TalkBack/font scale + widget tests; acceptance checklist |
| **NFR-OPS-01** | Offline capability | Sau cài app **và trước khi kết nối lần đầu**, import/compare/export và OCR bundled chạy airplane mode | Android offline-first-run test (first install, no network) |
| **NFR-REL-03** | Safe restore | Sau process death không xuất hiện snapshot READY giả; access/hash/config revalidate; startup scratch sweep | Kill/restart/revocation tests |
| **NFR-SEC-03** | Safe output | CSV text không thành executable formula; PDF không JavaScript/attachments/remote actions; mọi report không chứa access secrets | Malicious export corpus với `=`, `+`, `-`, `@`, tab/CR và encoding variants |
| **NFR-SEC-04** | Untrusted input | ZIP bombs, external entities, active content và malformed sources fail closed; không tải linked resources hoặc chạy formula/macros | Fuzz/corpus + blocked network tests |
| **NFR-OCR-01** | OCR review integrity | 100% cell trong selected OCR scope có review receipt hiện hành; edit crop/layout invalidates receipts; confidence không override | INP-TC-039/040 + device integration |
| **NFR-PRIV-01** | Data minimization / retention | Không giữ raw/parsed source/bitmap mặc định sau session; private disk spill chỉ sống khi consumers cần; cleanup khi release resources/fail/cancel/close, startup sweep after crash | App-private storage and lifecycle tests |
| **NFR-TEST-01** | Reproducible release evidence | P0 capability chỉ được công bố với parser/OCR corpus, versioned outputs, physical device smoke, signed APK | QA report + artifacts + CI gate |

NFR-PERF-01 và NFR-REL-01 là **mục tiêu tham khảo từ Master 2.2**, không phải kết quả đạt được. Mục tiêu OCR CER/WER/cell accuracy chưa có threshold được chốt bởi corpus; xem mục 5. Không được tự thiết lập 99% OCR accuracy mà không có mẫu số/CI.

## 3. Resource profiles và trần input 1 GB

[EXP-ADR-001](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) thay trần sản phẩm conservative của INP-ADR-004. **Trần input là 1 GB = 1.000.000.000 byte/source**, không phải 1 GiB (1.073.741.824 byte), không phải tổng A+B. Hai nguồn có thể tổng 2 GB; bytes output/scratch không tính vào source size. File đúng trần được qua size gate; byte thứ 1.000.000.001 phải bị chặn bằng INP-ERR-004. Size unknown phải kiểm đếm trong read; không tin extension/provider metadata hoặc chỉ compressed size.

| Resource dimension | Yêu cầu profile `large-input-v1` | Điều kiện nghiệm thu |
| --- | --- | --- |
| Source bytes | ≤1.000.000.000/source; A/B độc lập | Biên −1/đúng/+1 byte; full valid corpus tới trần; không chỉ metadata |
| Compressed vs decompressed | Budgets riêng cho total extraction, ZIP entry bytes/count, shared strings, compression ratio | Giá trị theo adapter/device được version hóa trước enable; chống bomb luôn bật, không mặc định 64 MiB là cap lớn |
| Rows / columns / cells | Profile theo workload/format/device; bounded row stream + paginated UI | Không kế thừa 20k/100/500k như cap toàn sản phẩm; corpus lớn phải đi hết, giữ count/provenance |
| Cell length / parser buffers | Bound riêng có version, không truncate; quoted multiline/UTF-8 qua chunk boundaries | Oracle cho long cells, malformed data, boundary tokens |
| OCR pixels / decode | Bound riêng trước cấp bitmap; một ảnh/bảng và review theo ADR-002 | Trần source 1 GB không cho phép bitmap vô hạn; pixel/dimension guards theo device |
| RAM / scratch disk / browser quota | Working set có budget và reserved headroom; estimates trước import/export, kiểm tra trong job | RAM không tăng theo toàn file; measure peak memory + peak scratch/output; disk full/quota fail có lý do |
| Time / liveness | Budget theo stage và inactivity watchdog; progress + cancel | Không áp watchdog tổng 60s của profile nhỏ cho file 1 GB; latency/cancel thresholds phải chốt qua benchmark |
| PDF output | Page/band/text stream, font cache/buffers/output disk có budget riêng | Không hardcode source cap thành output cap; không silent page/row truncation hoặc tự tách nhiều PDF |

**Profile nhỏ lịch sử:** `android-p0-conservative-v1` (10 MiB/source, 64 MiB extraction, 2.000 entries, 100:1, 20k rows/100 cols/500k cells, 32 KiB/cell, 12MP, 60s total) chỉ dùng để tái hiện baseline/compatibility. Không được dùng nó làm default rồi quảng cáo đã hỗ trợ 1 GB. Profile mới được chọn theo capability đã công bố, cùng ID/version trong snapshot/report.

Các budget device-dependent chưa chốt giữ **TBD/NOT_VERIFIED**, phải resolve trong registry ứng dụng trước khi enable profile; thiếu profile → INP-ERR-011. File không được tự nâng budgets. Input không an toàn, unsupported layout, hết quota hoặc vượt decompressed/pixel budgets vẫn fail closed ngay cả khi source ≤1 GB, kèm limit/observed/profile và hướng khắc phục. Không tự giảm scope hoặc fallback cloud. Nếu thiết bị không đạt, công bố capability chưa hỗ trợ trên thiết bị đó, không hạ trần sản phẩm âm thầm.

**Release gate 1 GB:** [LARGE-TC-001..008](../testing/EXPANDED_SCOPE_ACCEPTANCE.md) với corpus hợp lệ ở biên, hai nguồn cùng lớn, large-row workload (bao gồm 50.000×15 hoặc lớn hơn), XLSX expansion riêng, parser correctness, cancel/disk pressure và hai PDF. Không khẳng định mọi file dưới trần đều hợp lệ, cũng không chấp nhận từ chối mọi file lớn để đạt gate. Phải nêu rõ platform/device/format/profile đã kiểm thử; web/Android/iOS không thay evidence cho nhau.

## 4. Threat model, privacy và failure handling

| Boundary / threat | Control P0 | Evidence |
| --- | --- | --- |
| Device file providers / permission revoked | Scoped Android SAF access; recheck, source hash guard | INP-TC-003/037, Android permission tests |
| Zip/OOXML untrusted parser | Entry/decompressed/ratio limits; no XML external entity, no macro/links | Malicious corpus |
| OCR image / EXIF | App-private derivative, bounded decode, no implicit cloud; location/EXIF not in telemetry | OCR privacy tests / packet capture |
| CSV/JSON/PDF report | Export explicit, escaping/typed text, PDF passive content + font local + metadata redaction | Spreadsheet injection, PDF active-content/packet/page inspection |
| App kill / low memory | Cancellation token, idempotent cleanup, restore resets READY | Stress/process-death |
| Local cache / backup | Không lưu raw dài hạn; private raw/parsed/index/PDF temp theo session/consumers, sweep on startup | Inspect app sandbox/backups/browser quota |
| Policy/data loss | Fail closed/UNRESOLVED when insufficient provenance or source ambiguity | Core golden and audit trace |

**Tránh claim không có bằng chứng:** `Drift/SQLite` không tự mã hóa; ứng dụng hiện không có quyền gọi là encrypted-at-rest nếu chưa có implement/audit. Cloud OCR, cloud telemetry và backend API không nằm trong Android P0.

## 5. Phương pháp test, chỉ số và quality gates

### 5.1 Accuracy & OCR metrics

- Semantic comparison: precision/recall theo **nhãn oracle**, `unresolved_rate` báo riêng, phân loại row/field/cell khác đơn vị không gộp.
- OCR: `CER`, `WER`, `cell_exact_accuracy`, `table_structure_F1`, critical-field-error rate, manual review time. **Chưa có ngưỡng chấp nhận định lượng** vì cần pilot/corpus được phân loại; release P0 chặn nếu không thể review hoặc tạo SourceTable có provenance.
- Baseline corpus: synthetic controlled + public non-PII + permitted/anonymized real data; các ví dụ `INP-TC-001..040` đều PLANNED đến khi có evidence.

### 5.2 Gates

| Gate | Loại | Bằng chứng phải gắn |
| --- | --- | --- |
| G0 | Input/semantic contracts | JSON schemas + fixture verifier và expected outputs |
| G1 | Dart domain | unit/golden/property tests; coverage tập trung critical policies; Master đề xuất ≥90% branch là TARGET chưa được chứng minh |
| G2 | Adapters | XLSX fidelity/ZIP/CSV dialect/device cases; capability registry |
| G3 | Android OCR | Offline bundled plugin + one-table manual review/correction + provenance |
| G4 | Security/privacy | Source mutation, malicious import/export, logs/permission/restart |
| G5 | Performance/UX | Android reference device benchmarks, accessibility and failure injection |
| G7 | P0 mở rộng 1 GB + PDF | LARGE-TC-* + REP-TC-*, full valid boundary corpus, PDF extraction/render/visual QA, counts/lineage reconciliation |
| G6 | Packaging | Signed APK install/run smoke offline, build versions, checksum và checklist |

Gates G0–G7 là **NOT_VERIFIED** tại thời điểm tạo tài liệu; việc Master có CI workflow không chứng minh pipeline xanh. Release guide chi tiết: [Build/Release](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md).

## 6. Giai đoạn P1 và quản trị thay đổi

iOS P1 phải benchmark và kiểm thử riêng với Files/iCloud, sandbox, VoiceOver, share/export, signing; không dùng Android evidence thay cho iOS. Đổi numeric thresholds hay security policy phải cập nhật NFR + ADR nếu liên quan, tăng resource profile version, gắn benchmark data và cập nhật [traceability](TRACEABILITY_MATRIX.md). Ngưỡng chưa chốt giữ `TBD` và chặn tuyên bố kết quả, không lấp bằng số suy đoán.
