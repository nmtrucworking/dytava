---
document_id: DYT-MOBILE-IMPL-001
version: 0.2.0
status: DRAFT
implementation_state: IN_PROGRESS
owner: TBD
reviewer: TBD
updated: 2026-11-18
release_baseline: Android P0; functional activity foundation + Mobile UX fast-track
---

# Mobile — nền tảng flow và activity

Bản triển khai ngày 18/11/2026 ưu tiên **hành vi, điều phối và tối ưu hóa trải nghiệm người dùng di động (Mobile UX)**, bám sát Design System Dytava v2.0 và 8 Activity cốt lõi. Hỗ trợ luồng chuẩn 10 màn hình và luồng thao tác tinh gọn (Fast-Track 1-Tap Actions), nhưng **chưa là ứng dụng nhập/so sánh/xuất tệp production**. Không thay yêu cầu PRD/SRS, không enable capability từ branding hoặc từ test fixture.

Nguồn thiết kế: [PRD §5](../product/PRD.md#5-user-journey-p0-và-tiêu-chí-trải-nghiệm), [UI/UX](../design/UI_UX_SPEC.md), [8 activity](../diagrams/MOBILE_ACTIVITIES.md), [3 state machines](../diagrams/MOBILE_STATES.md), [INP-008](../specs/input/08_import_state_machine.md), [EP-1](../specs/engine/01_execution_plan.md), [ER-1/WP-1](../specs/engine/04_result_runtime.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md), [RP-1](../requirements/RESOURCE_PROFILES.md).

`Activity` ở đây là nghiệp vụ và màn hình Flutter. Android vẫn dùng **một** `MainActivity extends FlutterActivity`; không thêm một native Activity cho mỗi bước.

## 1. Capability thực tế

| Phần | Đã triển khai | Chưa có / gate còn thiếu |
| --- | --- | --- |
| Presentation SCR-01..10 | Guided flow 4 giai đoạn, Bottom Navigation 5 Tab (Trang chủ, So sánh, Lịch sử, Học tập, Cài đặt), bộ UI Components chuẩn v2.0, **Sheet Diff 2 Sheets** (Hợp nhất A↔B & Song song A\|B), Fast-Track 1-tap flow, 41 mobile tests pass | UX sign-off, TalkBack/device evidence trên thiết bị vật lý |
| ACT-02 / Input | Hai slot độc lập, attempt binding, review scope/header, snapshot đầy đủ của fixture, hỗ trợ nạp/xác thực nhanh inline | SAF/file picker, content sniffing, UTF-8/dialect, parser XLSX/CSV/TSV, EOF/hash thật, streaming/private spill |
| ACT-03 / OCR | Một slot ảnh, review **từng** cell mẫu, revision mới xóa review, stale confirmation bị bỏ | Camera/gallery, ảnh gốc/geometry/crop, recognizer bundled, corrections/receipts Input0.2 và schema migration |
| ACT-04 / Plan | Mapping bằng Field IDs 1:1, tự động ghép cột cùng tên, KEY/POSITIONAL, ordered keys, typed policy, source separators, tolerance, direction và confirmations | EP-1/CE-1 wire/digest/compiled policy đầy đủ, structural-only mode, enabled device profiles/capability registry |
| ACT-05/06 / Compare | Matcher fixture bounded, strict text keys, duplicate/null ownership, absence guard, structural riêng, Core PoC 5 types, conservation audit | Comparison NEEDS_REVIEW/RESOLVE generations, external sort/index, isolate protocol WP-1, leases, backpressure, SQLite/ER-1 durable publication, pipeline 1 GB |
| ACT-07 / Result | Immutable fixture result, summary, N/A khi mẫu số 0, filter chips ngang, duyệt Trước/Sau trong detail, character diff highlight, JSON preview | Disk cursors QO-1/EX-1, byte-bounded query/detail, provenance SourceRef thật, tìm kiếm/structural drill-down |
| ACT-07 / Export | Explicit FULL/DIFFERENCES_ONLY, JSON **preview trong RAM**, render/verify/publish-to-preview lifecycle | CSV, JSON report schema production, destination/provider/save/share, durable commit/receipt, hai PDF, template/fonts |
| ACT-08 / Recovery | Cancel hợp tác, đợi port settle/cleanup; invalidation; finite retries; restore entry point chỉ SELECTED | Journal bền vững/startup sweep, timeout/strong-stop worker, process-death/device/permission-provider integration |

Không bật user comparison thật. `UnavailableComparisonPort` chặn cả capability và profile; composition chỉ nối **Demo** ports; người dùng phải chọn rõ flow mẫu trước khi chạy. Giới hạn 100 records của fixture comparator là bảo vệ harness, **không phải trần sản phẩm**, không là profile `large-input-v1` được ENABLED.

Tất cả models tại `domain/workflow.dart` là **internal application models**, không serialize thành ISC-1/EP-1/ER-1/EX-1. `fullValidation=true` ở adapter mẫu chỉ xác nhận toàn fixture đã dựng, không khẳng định đã đọc EOF/hash của tệp. Fixture locations mang tiền tố `fixture/`, không giả thành địa chỉ CSV/XLSX/OCR thật. JSON preview không phải `dytava-engine-report/1.0.0` hoặc legacy report schema.

## 2. Cấu trúc và ownership code

| File | Trách nhiệm |
| --- | --- |
| [`main.dart`](../../mobile/lib/main.dart) | MaterialApp + theme + entry screen |
| [`app/workflow_composition.dart`](../../mobile/lib/app/workflow_composition.dart) | Composition rõ ràng cho harness fixture; nơi thay adapters sau admission |
| [`domain/workflow.dart`](../../mobile/lib/domain/workflow.dart) | Immutable artifacts/bindings/snapshots/config/plan/result, cancellation và port interfaces; không import Flutter |
| [`application/workflow_controller.dart`](../../mobile/lib/application/workflow_controller.dart) | State transitions, readiness/route guards, invalidation, retries, orchestration; dùng ChangeNotifier để cập nhật view |
| [`features/workflow/workflow_page.dart`](../../mobile/lib/features/workflow/workflow_page.dart) | 10 màn hình chức năng; chỉ gửi commands, render state và giữ input UI cục bộ |
| [`infrastructure/demo/demo_workflow_ports.dart`](../../mobile/lib/infrastructure/demo/demo_workflow_ports.dart) | Input/KEY/POSITIONAL/JSON preview fixture-only; không resolve đường dẫn người dùng |
| [`features/diagnostics/compare_demo_page.dart`](../../mobile/lib/features/diagnostics/compare_demo_page.dart) | Diagnostic 2 giá trị cũ, vẫn truy cập từ Home và giữ regression tests |

Không thêm plugin/dependency. Không sửa semantic engine để che mất dữ liệu. UI hoàn chỉnh có thể thay từng screen mà không chuyển logic so sánh/guard vào widget.

## 3. Luồng kiểm tra thủ công

Từ `mobile/`, chạy `flutter run`; tại Home chọn **So sánh mới (dữ liệu mẫu)**:

1. Chọn bảng mẫu A → Kiểm tra A → Kiểm tra nguồn mẫu → xác nhận scope/header → trở về nguồn. Lặp lại với B. Hai nguồn có cùng tên `sample.csv` nhưng artifact ID khác nhau.
2. Chỉ sau cả hai PREVIEW_READY mới mở ánh xạ. Ghép `id→id`, `amount→amount`; xác nhận mapping.
3. Mặc định POSITIONAL là gợi ý; có thể chọn KEY, thêm `id` vào tuple. Xác nhận mode, policy và direction. `id` là IDENTIFIER; `amount` là DECIMAL, separator A=`.`, B=`,`, tolerance=`0`.
4. Chạy → validating/running/audit → kết quả: **8 cell pairs = 5 EXACT + 1 EQUIVALENT + 1 DIFFERENT + 1 UNRESOLVED**, 4 hàng ghép, 1 ROW_ADDED ở B. Semantic agreement = 6/8 = 75%; structural không nằm trong mẫu số.
5. Detail amount `8.5`/`8,5` giữ cả raw và canonical `8.5`. `abc`/`9` là UNRESOLVED, không ép DIFFERENT.
6. Export → chọn JSON + phạm vi → xác nhận → tạo preview. FULL có 8 cells; DIFFERENCES_ONLY có 2 cells (DIFFERENT + UNRESOLVED), structural vẫn hiện; equivalent không được mặc định đưa vào differences-only. Đây không phải thao tác lưu tệp.
7. Quay lại đổi direction rồi chạy lại: B-only thành ROW_REMOVED. Đổi policy/direction giữ raw snapshots nhưng khóa query/export kết quả cũ. Đổi source/config nhập xóa mapping và affected snapshot, giữ bên độc lập.
8. Để thử nhánh OCR, chọn **OCR giả lập** cho một phía; xác nhận riêng cả 8 ô. Một ô thiếu thì không thể tiếp tục. Nút giả lập đổi crop/layout tăng revision, xóa review cũ. Không có thao tác crop ảnh thật.

Back giữ dữ liệu còn hợp lệ; đóng phiên đợi active work dừng rồi clear fixture snapshots/results/preview. App paused/detached yêu cầu cancel, không quảng cáo background resume. App restart hiện về Home; chưa có journal tự khôi phục. `restoreSources` là entry point có test để gắn journal về sau.

## 4. Guards và invariants

- Import callback chỉ commit với đúng `(artifact_id, generation, config_revision, attempt)` và token chưa bị hủy. Parsing callback sai state bị bỏ; snapshot chỉ commit sau parsing + fullValidation. Review confirmation phải mang `expectedBinding` hiện hành.
- Replace/reset/config change cancel work cũ; slot mới có binding mới. New import chờ old port settle. Source revoke vô hiệu hóa affected snapshot/result; bên còn lại vẫn độc lập.
- Mapping chỉ tham chiếu fields hiện hành, mỗi bên dùng tối đa một lần. Phải confirm mapping/mode/policy/direction. KEY yêu cầu IDENTIFIER không trim/tolerance; key tuples không nối chuỗi bằng delimiter. Fixture dùng JSON string-array framing injective cho subset, **không gọi là CE-1**.
- Duplicate key ở bất kỳ phía nào giữ toàn group unresolved; không chọn first/last. Invalid key không tạo absence proof giả cho phía còn lại. Cell denominator chỉ gồm mapped cells của matched rows. Fixture matcher audit conservation hai phía trước return.
- Result bytes immutable; validity riêng current/stale/revoked. Cancel đến sau terminal không sửa COMPLETED. UI không query hoặc export stale result, kể cả đang đứng ở màn hình kết quả/cấu hình khi snapshot bị thu hồi.
- Cancel chỉ thành công sau khi port trả về và cleanup hoàn tất. Fixture ports nhường event loop theo work units; chưa có deadline/strong-stop cho adapter không hợp tác. Adapter production bắt buộc bổ sung bound RP-1 trước enable.
- Retry có trần 3 attempts trong một cấu hình fixture; import ERROR không retry nếu `retryable=false`. Thay cấu hình/nguồn là ý định mới, không là vòng retry tự động. Đây không là giá trị RP-1 production.
- Export recheck validity giữa render/verify/publish và cancellation trước publish; port sở hữu commit boundary. Preview không giữ URI/private refs. Các nhánh comparison NEEDS_REVIEW/RESOLVE, PARTIAL và recovery history bền vững vẫn chưa có adapter runtime; fixture harness không phát sinh các nhánh này. Port production phải chứng minh atomic/pending provider, idempotency, leases, cleanup và recheck tại commit; giao diện port hiện chưa thay EX-1 adapter.

## 5. Test và mức evidence

Chạy từ `mobile/`:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

| Runner | Kiểm tra hiện có | Liên kết yêu cầu (chỉ partial evidence) |
| --- | --- | --- |
| [`workflow_controller_test.dart`](../../mobile/test/workflow/workflow_controller_test.dart) | Independent slots, full validation, confirmations, stale callbacks/review, cancel/cleanup, invalidate/revoke, capability/profile gate, export scope, restore | ACT-01..08; FR-001/002/005/006/009/013/014/015; INP-TC-034..038 concepts |
| [`demo_comparison_test.dart`](../../mobile/test/workflow/demo_comparison_test.dart) | KEY reorder/duplicate/invalid/tuple framing, POSITIONAL tails, structural vs cell counts, N/A | ACT-05/06; FR-006..009; UDG matching ownership subset |
| [`workflow_widget_test.dart`](../../mobile/test/workflow/workflow_widget_test.dart) | User thao tác xuyên source→config→result→detail→preview ở 390×844; OCR chọn từng ô; button guards | SCR-01..10 (conditional OCR test); UX-TC-002/007/008 partial |
| [`widget_test.dart`](../../mobile/test/widget_test.dart) | Diagnostic semantic UI cũ và 4 verdict illustrations | Semantic regression; không phải production SCR-08 |

Các tests này không chạy parser thật, Android SAF/OCR, disk/worker kill, no-cloud network inspection, 1 GB, PDF, TalkBack hoặc signed release. **Không đổi INP-TC/UDG-TC/LARGE-TC/REP-TC/UX-TC trong registry sang PASS** từ fixture tests. Kết quả lần chạy và build được ghi sau khi thực thi tại phần evidence bên dưới.

Các nhánh job `NEEDS_REVIEW → RESOLVE` và `PARTIAL` hiện mới có enum tham chiếu, chưa có command/outcome runtime trong coordinator mẫu; adapter production cần bổ sung trước khi bật capability tương ứng. `INTERRUPTED` hiện chỉ qua restore entry point, chưa được ghi từ journal thật.

## 6. Bước triển khai tiếp theo

1. FileAccess scoped SAF + versioned Input schemas migration; adapters đọc/hash đúng bytes, giữ raw/provenance, scope/header/dialect confirmations, EOF validation; fidelity corpus trước bật format.
2. Private snapshot/index/result stores + lease ownership/journal/recovery, bounded workers WP-1, resource governor RP-1 + cancel timeout/strong stop. KEY external sort phải giữ full-scope duplicate/null detection.
3. OCR bundled/offline + original geometry, grid editing/corrections và review receipts. Không dùng receipt của fixture thay Input0.2.
4. ER-1 durable audit/publish + EX-1 stable cursor/detail. Thay bounded in-memory fixture query bằng backend cursors trước workload thực.
5. CSV/JSON report adapters và hai PDF theo Report spec; destination atomic commit, count/coverage/fidelity/hash/reader evidence.
6. Device calibration, airplane-mode/privacy/kill/pressure/1 GB/PDF corpus, rồi enabled capabilities/profile. Hoàn chỉnh visual/UX sau khi flow và adapters ổn định.

## 7. Evidence chạy ngày 18/11/2026

- SDK thực tế: Flutter 3.47.9 stable / Dart 3.13.7 trên macOS ARM64.
- `cd mobile && flutter analyze`: **PASS, No issues found**.
- `cd mobile && flutter test`: **PASS, 33 tests** (19 coordinator + 6 matcher + 2 guided widget + 6 diagnostic).
- `cd mobile && flutter build apk --debug`: **PASS**; artifact `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `node scripts/render-mobile-diagrams.mjs --check`: documentation QA cho 30 diagrams/50 source fingerprints; thay đổi owner docs lần này chỉ cập nhật implementation status, không đổi flow mục tiêu.
- [Machine-readable execution summary](../testing/mobile-flow-evidence.json) ghi base commit, fingerprint source của working tree, SHA-256 APK và giới hạn evidence. Đây là bản chưa commit, không gắn test thành công của working tree cho nguyên trạng base commit.
- Chưa chạy trên Android device/emulator trong lần này; APK build và widget viewport không là device/release proof. Không đổi registry acceptance production sang PASS.

## 8. Giải thích sai khác chuỗi — 18/11/2026

Theo xác nhận của người dùng, giữ `DIFFERENT` cho `nguyen van a` ↔ `nguyen vana` và **chỉ rõ vị trí khác**. Quy tắc chuỗi không đổi: diagnostic hiện trim đầu/cuối; giữ khoảng trắng bên trong, hoa/thường và dấu; không tự dùng độ giống nhau làm equality. Nguồn semantics vẫn là [Core decision table](../specs/core/COMPARISON_DECISIONS.md#2-decision-cases-theo-dtype).

Diagnostic và Difference Detail hiển thị bằng chứng từ canonical text đã có trong decision; không chạy lại comparator hoặc thay verdict:

```text
Vị trí khác biệt đầu tiên: ký tự Unicode thứ 11.
A: nguyen␠van⟦␠⟧a
B: nguyen␠van⟦∅⟧a
```

`␠` là dấu cách U+0020; `∅` là đoạn không có ký tự. Có chú thích riêng cho tab, LF/CR và NBSP. Vị trí đếm Unicode scalar, bắt đầu từ 1, trên **chuỗi sau chuẩn hóa**, không giả là byte offset/SourceRef hoặc vị trí grapheme. Prefix/suffix chung được giữ; vùng giữa được đánh dấu cả hai phía. Nhiều khác biệt bên trong được gom một vùng liên tục; đây chưa là minimal edit script/LCS hoặc chỉ số similarity.

- [`TextDifference`](../../mobile/lib/domain/text_difference.dart): mô hình bằng chứng thuần Dart, không quyết định semantics.
- [`TextDifferenceEvidence`](../../mobile/lib/features/shared/text_difference_evidence.dart): dùng chung diagnostic và detail; chỉ dựng highlight khi mở màn hình và mỗi chuỗi ≤8192 UTF-16 code units. Vượt giới hạn ghi rõ bỏ highlight, giữ nguyên kết luận.
- [`text_difference_test.dart`](../../mobile/test/workflow/text_difference_test.dart): dấu cách bị thiếu, chèn/xóa đầu/cuối, dấu tiếng Việt, emoji/scalar offsets, whitespace controls và giới hạn hiển thị.
- [`widget_test.dart`](../../mobile/test/widget_test.dart): tái hiện đúng cặp tên, giữ DIFFERENT, hiện vị trí 11/vùng A/B và xóa bằng chứng cũ khi input đổi.

Không thay Core policy hoặc acceptance registry production. Evidence cho thay đổi này được ghi riêng ở [text-difference-evidence.json](../testing/text-difference-evidence.json); summary 33 tests/APK ở §7 giữ làm bằng chứng lần chạy nền tảng trước đó.

Kiểm tra bản bổ sung: `flutter analyze` **PASS**, `flutter test` **39 tests PASS**, `flutter build apk --debug` **PASS**.
