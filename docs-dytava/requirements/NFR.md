---
document_id: DYT-NFR-001
version: 0.1.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-12
release_baseline: Android P0
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
| **NFR-PERF-02** | Throughput stress | Master đề xuất 50.000×15 nhưng **ngoài giới hạn P0 20.000 rows**; giữ làm stress objective P1+ thay vì P0 promise | Memory/latency stress; NOT P0 gate |
| **NFR-PERF-03** | Peak memory & bounded work | Không OOM trong corpus P0 trên Android device reference 4GB/6GB được chốt; không load toàn workbook/bitmap không giới hạn | Android Profiler/heap max, repeat runs; release gate |
| **NFR-REL-01** | Crash-free sessions | Mục tiêu pilot `≥99,5%` chỉ sau telemetry được đồng ý, có mẫu số và thời gian quan sát; **không thể kết luận từ unit tests** | Pilot thống kê; POST-P0 TARGET |
| **NFR-REL-02** | Cancellation | Cancel/timeout/retry không tạo report `COMPLETED` một phần; cleanup idempotent | Inject cancel ở mỗi stage, verify output/cleanup |
| **NFR-SEC-01** | Source immutability | **0 ghi dữ liệu vào nguồn gốc**; import, OCR/crop, export chỉ dùng derivatives/outputs mới | Hash bytes trước/sau, file/SAF permission tests |
| **NFR-SEC-02** | Data disclosure | **0 raw cell/URI/access token/OCR text trong logs/crash/telemetry**; không upload mặc định | Log/packet/app storage inspections |
| **NFR-COR-01** | Determinism | Cùng bytes hash + import config/adapter version + policy digest + engine + match mode cho cùng semantic report (trừ generated_at/non-semantic metadata) | Golden compare canonical report, multiple runs |
| **NFR-COR-02** | Explainability | **100% EQUIVALENT matched pairs** có rule ID, canonical trace; mọi diff có SourceRef thật hoặc missing reason | Automated report schema/audit checks |
| **NFR-UX-01** | Accessibility | Text scale, screen reader labels, touch targets, trạng thái có text/icon không chỉ màu; review screen không giấu blocker | Manual Android TalkBack/font scale + widget tests; acceptance checklist |
| **NFR-OPS-01** | Offline capability | Sau cài app **và trước khi kết nối lần đầu**, import/compare/export và OCR bundled chạy airplane mode | Android offline-first-run test (first install, no network) |
| **NFR-REL-03** | Safe restore | Sau process death không xuất hiện snapshot READY giả; access/hash/config revalidate; startup scratch sweep | Kill/restart/revocation tests |
| **NFR-SEC-03** | Safe output | CSV text không được diễn giải thành executable formula khi mở trong ứng dụng bảng tính; file report không chứa access secrets | Malicious export corpus với `=`, `+`, `-`, `@`, tab/CR và encoding variants |
| **NFR-SEC-04** | Untrusted input | ZIP bombs, external entities, active content và malformed sources fail closed; không tải linked resources hoặc chạy formula/macros | Fuzz/corpus + blocked network tests |
| **NFR-OCR-01** | OCR review integrity | 100% cell trong selected OCR scope có review receipt hiện hành; edit crop/layout invalidates receipts; confidence không override | INP-TC-039/040 + device integration |
| **NFR-PRIV-01** | Data minimization / retention | Không giữ raw source/bitmap mặc định sau session; scratch cleanup success/failure/cancel/close, startup sweep after crash | App-private storage and lifecycle tests |
| **NFR-TEST-01** | Reproducible release evidence | P0 capability chỉ được công bố với parser/OCR corpus, versioned outputs, physical device smoke, signed APK | QA report + artifacts + CI gate |

NFR-PERF-01 và NFR-REL-01 là **mục tiêu tham khảo từ Master 2.2**, không phải kết quả đạt được. Mục tiêu OCR CER/WER/cell accuracy chưa có threshold được chốt bởi corpus; xem mục 5. Không được tự thiết lập 99% OCR accuracy mà không có mẫu số/CI.

## 3. Resource profile của Android P0

Nguồn trần từ chối bootstrap duy nhất: [INP-ADR-004](../decisions/ADR_REGISTER_P0_2026-11-11.md), `android-p0-conservative-v1`; giới hạn có thể phải **hạ thấp** sau benchmark, không tự nâng để mở tệp.

| Resource dimension | Bootstrap reject ceiling | Ghi chú |
| --- | --- | --- |
| Source file | 10 MiB mỗi source | Kể cả ảnh và XLSX; kiểm bytes thực khi đọc |
| XLSX decompressed payload | 64 MiB | ZIP shared strings/worksheets và total extraction |
| ZIP entries / compression ratio | 2.000 entries / 100:1 | Từ chối suspicious ZIP, không tắt guard |
| Table | ≤20.000 data rows, ≤100 columns, ≤500.000 cells | Giới hạn nào đến trước |
| CSV/TSV cell | ≤32 KiB UTF-8/cell | Không truncate im lặng |
| OCR image | ≤12 megapixels, một ảnh/bảng | Pre-decode dimensions và memory budget |
| Attempt watchdog | 60 giây (preflight/parse/OCR) | Timeout → structured issue + cleanup; không coi là hiệu năng cam kết |

**Acceptance:** input vượt giới hạn → `INP-ERR-004`/security code tương ứng, ngừng trước khi tiêu thụ tài nguyên mất kiểm soát. Không yêu cầu mọi tệp dưới trần phải chạy trong 60 giây hoặc không OOM trước khi có benchmark. Trước khi đặt `SUPPORTED`, phải có ma trận thiết bị/corpus hiện thực, dự phòng tài nguyên và profile version trong report.

## 4. Threat model, privacy và failure handling

| Boundary / threat | Control P0 | Evidence |
| --- | --- | --- |
| Device file providers / permission revoked | Scoped Android SAF access; recheck, source hash guard | INP-TC-003/037, Android permission tests |
| Zip/OOXML untrusted parser | Entry/decompressed/ratio limits; no XML external entity, no macro/links | Malicious corpus |
| OCR image / EXIF | App-private derivative, bounded decode, no implicit cloud; location/EXIF not in telemetry | OCR privacy tests / packet capture |
| CSV/JSON report | Export explicit, escaping/typed text treatment, metadata redaction | Spreadsheet injection tests |
| App kill / low memory | Cancellation token, idempotent cleanup, restore resets READY | Stress/process-death |
| Local cache / backup | No raw content persisted; scratch life only session/attempt, sweep on startup | Inspect app sandbox/backups |
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
| G6 | Packaging | Signed APK install/run smoke offline, build versions, checksum và checklist |

Gates G0–G6 là **NOT_VERIFIED** tại thời điểm tạo tài liệu; việc Master có CI workflow không chứng minh pipeline xanh. Release guide chi tiết: [Build/Release](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md).

## 6. Giai đoạn P1 và quản trị thay đổi

iOS P1 phải benchmark và kiểm thử riêng với Files/iCloud, sandbox, VoiceOver, share/export, signing; không dùng Android evidence thay cho iOS. Đổi numeric thresholds hay security policy phải cập nhật NFR + ADR nếu liên quan, tăng resource profile version, gắn benchmark data và cập nhật [traceability](TRACEABILITY_MATRIX.md). Ngưỡng chưa chốt giữ `TBD` và chặn tuyên bố kết quả, không lấp bằng số suy đoán.
