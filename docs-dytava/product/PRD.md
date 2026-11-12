---
document_id: DYT-PRD-001
version: 0.2.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-12
release_baseline: P0 mở rộng (Android trước; web/iOS có gate riêng)
source: EXCELCOMPARE_MASTER_ANDROID_IOS 2.2 sections 01-02 (historical)
decision_authority: INP-ADR-001..009 + EXP-ADR-001..003 accepted for scope 2026-11-12
---

# Dytava — Product Requirements Document (PRD)

> **Tài liệu nguồn cho nhu cầu người dùng, giá trị, release scope và hành trình sản phẩm.** Các điều kiện hệ thống kiểm tra được thuộc [SRS](../requirements/SRS.md); NFR, kiến trúc, Input và semantic policy thuộc tài liệu chuyên trách. **DRAFT không có nghĩa đã triển khai/kiểm thử.**

## 1. Mục tiêu và căn cứ

Đề bài học phần: **so sánh 02 tệp Excel/bảng dữ liệu**, phát hiện điểm giống/khác, **thống kê và nêu vị trí sai khác**, **đọc dữ liệu từ ảnh chụp** và cung cấp **tệp cài đặt ứng dụng**. Mục tiêu là tránh các false differences do biểu diễn số, định dạng, thứ tự bản ghi và schema không đồng nhất, đồng thời không đưa ra kết luận tương đương khi thiếu bằng chứng.

**Jobs-to-be-done:** khi nhận hai bảng của cùng nghiệp vụ, người dùng cần xác định bản ghi/cột/ô thêm, xóa, sửa; phân biệt `EXACT`, `EQUIVALENT`, `DIFFERENT`, `UNRESOLVED`; xem nguồn gốc của mỗi kết luận; và xuất một biên bản đối chiếu có thể kiểm tra lại.

**Mở rộng ngày 12/11/2026:** [EXP-ADR-001..003](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) đưa input tối đa 1 GB/tệp và cả hai PDF vào **P0 mở rộng**. Đây là yêu cầu sản phẩm, chưa là tính năng runtime đã đạt.

**Nguồn gốc quyết định:** [Project Description](../project/Project%20Description.md), [Master 2.2 lịch sử](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md), [9 ADR đã chốt](../decisions/ADR_REGISTER_P0_2026-11-11.md). PRD ghi **định hướng sản phẩm**, không cấp quyền thay đổi chuẩn dữ liệu của [Input](../specs/input/README.md) hoặc thuật toán của [Core](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md).

## 2. Người dùng và kịch bản

| Nhóm | Bài toán | Pha |
| --- | --- | --- |
| Sinh viên, kế toán, hành chính | So báo cáo/danh sách xuất nhiều lần, giải thích sai khác | P0 |
| Nhân viên kiểm thử dữ liệu | Đối chiếu bảng trước/sau chuyển đổi hoặc đồng bộ | P0 |
| Người chỉ có ảnh bảng | Nhận dạng **một** bảng từ ảnh, chỉnh sửa/xác nhận rồi so với bảng tệp | P0, giới hạn |
| Quản trị dữ liệu/doanh nghiệp | Quy tắc dùng chung, audit nâng cao, multi-sheet, metadata và tích hợp | P1+ |

Ứng dụng **không** thay thế quyết định nghiệp vụ; nhãn `EQUIVALENT` phụ thuộc policy được xác nhận, `UNRESOLVED` là trạng thái hợp lệ. Không tự suy đoán dữ liệu ẩn, công thức hoặc số 0 đầu mã từ ảnh/tệp.

## 3. Release scope — nguồn quản lý duy nhất cho phase assignment

| Hạng mục | Android P0 — Must | Giai đoạn sau / loại trừ khỏi P0 |
| --- | --- | --- |
| Platform | Flutter/Dart, APK Android có thể cài/kiểm thử ngoại tuyến | iOS P1; Web/server ngoài evidence mobile |
| Nguồn | 2 nguồn A/B: XLSX, CSV, TSV; **tối đa 1 nguồn** PNG/JPG/JPEG từ camera/gallery | JSON/JSONL, XLS/XLSM/ODS P1; **PDF input**, HEIC, XLSB, XML/HTML P2+; ảnh–ảnh không thuộc P0 |
| Dung lượng | Tối đa **1 GB/source**, hai nguồn độc lập; pipeline lớn và resource profile theo NFR | Không kế thừa trần nhỏ 10 MiB/20k rows làm cap sản phẩm; không tự mở cloud |
| Scope | Một table/scope cho mỗi nguồn, XLSX cho phép người dùng chọn 1 sheet/range | Multi-sheet pairing/batch |
| OCR | On-device bundled Latin/Vietnamese text recognition + chỉnh hàng/cột/text + xác nhận thủ công | Cloud OCR, không review, chữ viết tay, nhiều trang/bảng phức tạp |
| Comparison | POSitional hoặc KEY explicit, mapping 1:1, dtype/policy xác nhận; phát hiện added/removed/changed, bốn trạng thái | MULTISET/ORDERED_SEQUENCE, tự suy key không xác nhận |
| Semantic types | IDENTIFIER, FREE_TEXT, DECIMAL, BOOLEAN, PERCENTAGE + null kinds có golden corpus | DATE/TIME/MONEY, unit, formula/metadata compare chỉ bật sau tests/phase |
| Kết quả | Thống kê đúng mẫu số, chi tiết hai phía, provenance/lý do, lọc sai khác | Dashboard doanh nghiệp, đồng bộ/cloud |
| Export | CSV diff + JSON report/manifest; **một merged diff PDF** cho A/B và **PDF theo template Dytava**; không ghi nguồn | XLSX export, nhập PDF/OCR PDF và chia sẻ lịch sử nâng cao có scope riêng |
| Reliability | Cancel/retry, cleanup, restart import sau process death, no raw retention | Resume tiến độ parse chính xác, long-lived raw cache |

**Chỉ chấp nhận một ảnh tại một trong hai phía**, ví dụ ảnh vs CSV; chưa cam kết ảnh vs ảnh. Nhận dạng văn bản **không** đồng nghĩa tái dựng cấu trúc bảng tự động chính xác. Người dùng phải nhìn thấy ảnh gốc và chỉnh/confirm vùng dữ liệu trước comparison. Mức OCR tối thiểu cần xác nhận với giảng viên (**academic sign-off pending**).

## 4. User stories — giữ ID gốc Master 2.2

| ID | Story sản phẩm / outcome | P0? | Xác minh tại |
| --- | --- | --- | --- |
| US-01 | Người dùng chọn 2 nguồn, xem metadata/khả năng đọc và identity độc lập | Must | SRS FR-001, INP-REQ-001/002 |
| US-02 | Không tin riêng extension; cảnh báo sai MIME/định dạng | Must | SRS FR-001, INP-REQ-003 |
| US-03 | Xem preview có giới hạn, chọn worksheet/scope và xác nhận header | Must | SRS FR-002, INP-REQ-004 |
| US-04 | Ghép trường, chọn positional hoặc khóa xác nhận, thấy duplicate/null-key | Must | SRS FR-005/006 |
| US-05 | Phân biệt bốn trạng thái và đưa ra lý do kiểm chứng được | Must | SRS FR-007/008/009 |
| US-06 | Chọn quy tắc theo field, xem raw, parsed, canonical và tác động của policy | Must | SRS FR-004/009 |
| US-07 | Thống kê, lọc và xem vị trí sai khác cho cả A và B | Must | SRS FR-007/013 |
| US-08 | Xuất CSV/JSON có lineage; nguồn không thay đổi | Must | SRS FR-013, NFR-SEC-01 |
| US-09 | Hủy an toàn; khi app bị ngắt khôi phục **chọn nguồn rồi revalidate**, không resume partial | Must | SRS FR-015, INP-008 |
| US-10 | So biểu thức formula/style/metadata | P1+ | SRS FR-010/011 |
| US-11 | OCR một ảnh thành bảng, **review bắt buộc** rồi mới so | **Must** | SRS FR-012, INP-TC-039/040 |
| US-12 | Gợi ý mapping tự động với confidence và xác nhận | P1+ | SRS FR-005; P0 mapping manual |
| US-13 | Đối chiếu nguồn dung lượng tới 1 GB/tệp với progress, cancel và preview phân trang | Must, P0 mở rộng | SRS FR-016; NFR §3 |
| US-14 | Xuất một PDF hợp nhất diff hai nguồn, thấy cả raw A/B và format trạng thái | Must, P0 mở rộng | SRS FR-017; Report spec |
| US-15 | Xuất báo cáo có nhận diện, thống kê, audit và kết luận theo template Dytava | Must, P0 mở rộng | SRS FR-018; Report spec |

*Độ ưu tiên là quyết định mới theo ADR; các hạng mục US-09 và US-11 trong Master cũ không được giữ nguyên cấp Should/Could.*

## 5. User journey P0 và tiêu chí trải nghiệm

1. **Bắt đầu:** mở so sánh mới, chọn A và B (file hoặc một ảnh); không đòi quyền truy cập toàn bộ storage.
2. **Nhập và preview:** từng nguồn tự preflight, chọn phạm vi và header, xác nhận encoding/dialect khi cần; nguồn còn `REVIEW/ERROR` không được dùng làm comparison snapshot.
3. **OCR nếu có:** ảnh gốc + overlay/text/cell grid; người dùng sửa cấu trúc và text, xác nhận tất cả selected cells; thay crop/layout làm mất hiệu lực review cũ.
4. **Ánh xạ & policy:** xác nhận table/field mapping, matching mode KEY/POSITIONAL, dtype + source locale/tolerance; xác nhận chiều A→B/B→A.
5. **So sánh:** progress và cancel, hiển thị lỗi có hướng khắc phục; tuyệt đối không tự nhận FULLY READY từ preview sampling.
6. **Kết quả:** tách cell statuses, row added/removed, schema differences và unresolved; truy cập source positions thật; bốn trạng thái có chữ/icon, không chỉ màu.
7. **Export:** chọn CSV, JSON, **PDF diff hợp nhất** hoặc **PDF báo cáo Dytava**; chọn full/filtered scope rõ ràng, xem page setup/template và export progress/cancel. Output riêng, file gốc read-only; không tự lưu raw file/ảnh vào lịch sử. Layout và nội dung tại [Report spec](../specs/report/README.md).

**Màn hình P0:** Home/Start, Source Selection, Preflight + Scope Preview, OCR Review (conditional), Field Mapping, Policy Confirmation, Comparison Progress, Results, Difference Detail, Export. Wireframe/visual style từ branding chỉ là thiết kế; chưa phải evidence UI hoạt động.

## 6. Success criteria và kiểm soát tuyên bố

| Mục tiêu | Chỉ dấu cần đo | Điều kiện chấp nhận |
| --- | --- | --- |
| Kết quả có thể giải thích | Mỗi equivalent có rule trace; diff có source ref hoặc missing reason | SRS golden/oracle tests |
| Không phá hủy dữ liệu | Hash/bytes A/B không thay đổi sau import/cancel/export | NFR-SEC-01, Input acceptance |
| OCR có kiểm soát | 100% selected OCR cells được review/confirm trước compare | INP-TC-039/040 + Android integration |
| An toàn và offline | Core + OCR bundled hoạt động ở airplane mode, không cloud call | NFR-OPS-01 và device evidence |
| Ổn định và hiệu năng | p50/p95, peak memory, limit/error rate trên corpus được chốt | NFR; không dùng con số chưa đo làm kết quả |
| Dung lượng mở rộng | Corpus biên 1 GB/source chạy hết pipeline trên profile/nền tảng công bố | FR-016, LARGE-TC-*; không chỉ kiểm tra file picker |
| Hai PDF | Diff union và template Dytava đọc được, số liệu đúng, không thiếu dữ liệu âm thầm | FR-017/018, REP-TC-* |
| Bàn giao học phần | Signed/installable APK và quy trình trình diễn | Release guide và Android smoke test |

## 7. Ngoài phạm vi và rủi ro quyết định

Không cam kết 100% OCR, suy luận locale tự động, tái tính formula, audit pháp lý hay hỗ trợ mọi workbook phức tạp. Trước khi phê duyệt PRD phải: (i) giảng viên xác nhận OCR tối thiểu, (ii) quyết định thiết bị Android tham chiếu và mức dữ liệu thực, (iii) xác nhận chủ sở hữu sản phẩm/reviewer. Độ lớn/capability P0 chỉ được công bố sau parser/OCR PoC và release tests.

**Change control:** đổi pha/bài toán người dùng ở PRD → đánh giá lại SRS/NFR/Architecture và ADR baseline cùng [quyết định mở rộng](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md). Không sửa trực tiếp các test/status `PLANNED` chỉ để phản ánh scope mới.
