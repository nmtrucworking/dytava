---
document_id: DYT-ADR-REGISTER-001
version: 1.0.0
date: 2026-11-11
status: ACCEPTED_ENGINEERING_BASELINE
baseline: Android P0 / Flutter-Dart
external_academic_signoff: PENDING
implementation_evidence: NOT_YET_VERIFIED
supersedes: INP-ADR-001..009 OPEN register (Input 0.1.0)
---

# Dytava — 9 quyết định kiến trúc cho Android P0

> **Phạm vi hiệu lực:** Quyết định thiết kế của nhóm dự án, không phải chứng nhận đã có tính năng hay chữ ký chấp thuận của giảng viên. Contract Input 0.1.0 vẫn **DRAFT**, acceptance tests vẫn **PLANNED**. Thay đổi schema/code theo quyết định này trước khi tuyên bố P0 hoàn thành. Master 2.2 (11/11/2026) là baseline lịch sử khi có xung đột về scope/priority; tài liệu này chỉ ghi đè các quyết định INP-ADR-001..009, không ghi đè semantic invariants của Core.

> **Scope update 12/11/2026:** [EXP-ADR-001..003](ADR_SCOPE_EXPANSION_2026-11-12.md) ghi đè trần sản phẩm 10 MiB/source và loại trừ PDF output: scope mới 1 GB/source + merged diff PDF + Dytava template PDF. Các budgets nhỏ ở ADR-004 là profile lịch sử, không là default/cap scope mới. Semantic/OCR/source immutability giữ nguyên.

## Phạm vi giao P0 đã quyết định

- **Nền tảng:** Flutter/Dart trên Android; APK cài được và chạy thử máy thật. iOS là P1.
- **Chọn đúng 2 nguồn A/B:** .xlsx, .csv, .tsv; **một** trong hai nguồn được phép là **một** ảnh .png/.jpg/.jpeg, chụp hoặc chọn từ thư viện. Không hỗ trợ image-image ở P0.
- **Cấu trúc:** chính xác một table/scope được chọn trên mỗi nguồn. XLSX có thể chứa nhiều sheet nhưng mỗi comparison chỉ chọn một sheet và một range; không tự ghép nhiều sheet.
- **Chức năng:** đọc/preview, xác nhận header/scope, mapping, chọn positional hoặc key matching, xác nhận policy/chiều so sánh, chạy comparison, thống kê và chỉ ra vị trí A/B, export CSV + JSON và hai PDF theo EXP-ADR-002. Status EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED độc lập với input states.
- **Kiểu ngữ nghĩa P0:** IDENTIFIER, FREE_TEXT, DECIMAL, BOOLEAN, PERCENTAGE và null kinds trên corpus có oracle. DATE/TIME, MONEY, các subtype nâng cao phải qua test riêng mới bật; không thể suy ra từ icon/JSON policy.
- **OCR P0 tối thiểu:** local/bundled Latin/Vietnamese text recognition, một ảnh chứa một bảng tương đối rõ; ảnh/crop/geometry cùng recognized text được giữ; bắt buộc người dùng sửa/xác nhận kết quả trước compare. Không cam kết trích xuất bảng không cần review, chữ viết tay, nhiều trang, bảng không đều, PDF input, cloud OCR.
- **Chưa thuộc P0:** JSON/JSONL, XLS/XLSM/XLSB/ODS, **PDF input**, HEIC/WEBP, XML/HTML, multi-sheet pairing, ảnh–ảnh, iOS, cloud backend OCR, history đầy đủ, đồng bộ cloud.
- **P0 release gate:** mỗi capability phải có adapter/device corpus và evidence; kết quả Web/PoC không được dùng thay kết quả Flutter. Flutter hiện chỉ là semantic comparison PoC.

## INP-ADR-001 — Vai trò A/B và hướng báo cáo

**Quyết định: ACCEPTED.** Giao diện đề xuất **A = baseline**, **B = phiên bản cần kiểm tra**, và **A_TO_B** là giá trị hiển thị ban đầu. Người dùng **phải xác nhận hướng** trước khi run/export; có nút đảo chiều thành B_TO_A. A/B không tự mang ý nghĩa cũ/mới. A_TO_B: chỉ có ở B = ADDED, chỉ có ở A = REMOVED; B_TO_A đảo nhãn. Direction đổi → invalidate comparison result/report, **không** thay raw snapshots nếu bytes/config không đổi.

**Lý do:** nhất quán Added/Removed mà vẫn tránh ngầm định business truth. **Kiểm chứng:** direction switch test với same two hashes, added/removed inversion, metadata report có direction và confirmation.

## INP-ADR-002 — OCR là bắt buộc trong Android P0

**Quyết định: ACCEPTED.** Nâng **minimal reviewed image import** từ P2 lên **Android P0** vì đề bài học phần yêu cầu đọc ảnh. Chỉ .png/.jpg/.jpeg; tối đa một image source và một page/table; camera và gallery đều yêu cầu hành động người dùng. Chọn **ML Kit Text Recognition v2 bundled on-device** (Latin) làm hướng thực thi, qua Flutter platform plugin được PoC/pin version tương thích; **không được chọn cấu hình unbundled đòi tải model lúc chạy P0 offline**. Nhận dạng chữ và phục hồi bảng là hai module khác nhau.

**Luồng:** image import → giới hạn decode/orientation/crop → OCR text + bbox/polygon → người dùng chỉ định/chỉnh hàng/cột và text → review receipt theo artifact hash/config revision/extraction revision/cell reference → validated SourceTable → comparison. Raw recognized text không bị sửa; reviewed_text riêng, confidence có thể null và không tự bypass review. SourceRef dùng polygon trong oriented image pixels, không được tự gán Excel cell address. Xử lý ảnh mới/crop/rotation/layout change invalidates confirmation. Không suy ra công thức/style/hidden cells, không upload ảnh/EXIF mặc định.

**Giới hạn nghiệp vụ:** text detection **không** là table recognition; bảng không có layout đủ tin cậy phải NEEDS_REVIEW hoặc UNSUPPORTED, không tự sinh ô giả. Chỉ so sánh khi mọi cell trong selected scope đã review/confirm.

**Contract migration bắt buộc:** InputConfig schema 0.1.0 hiện chưa mô tả image scope/config P0; tạo bản schema thích hợp có version mới, OCR extraction manifest và review receipt schema, cập nhật adapter capability và fixtures **trước khi enable**. Không tự coi schema hiện hữu là P0-ready.

**Kiểm chứng:** offline-first-run (sau cài APK, airplane mode), Vietnamese diacritics, 00123, table line breaks/merge, low/absent confidence, crop invalidation, permission revoke, image overly large, manual correction + compare cùng một nguồn CSV/XLSX; INP-TC-039/040 phải có runner/evidence. Xác nhận với giảng viên phạm vi OCR tối thiểu khi chốt nghiệm thu học phần.

**Tham khảo kỹ thuật:** [Google ML Kit bundled vs unbundled](https://developers.google.com/ml-kit/tips/installation-paths); [Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2); [Vietnamese support](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages); [Flutter plugin](https://pub.dev/packages/google_mlkit_text_recognition). Plugin/version cần thử native build, không chọn chỉ từ trang giới thiệu.

## INP-ADR-003 — Phạm vi sheet/table

**Quyết định: ACCEPTED.** P0 có **1 selected table/scope trên mỗi nguồn**, so sánh một cặp table A/B. XLSX: người dùng chọn một worksheet và một phạm vi hình chữ nhật; CSV/TSV: một logical table; OCR: một image, một bảng review. Không tự ghép nhiều sheets, multi-range hay tự hợp nhất bảng. Một workbook có nhiều sheet vẫn mở được để **chọn** sheet, nhưng không so sánh tất cả sheet trong một job.

**Kiểm chứng:** nhiều sheet → có UI chọn 1, không silent merge; đổi scope invalidate snapshot/mapping; sheet không tồn tại → CONFIG_INVALID.

## INP-ADR-004 — Android P0 conservative resource profile (lịch sử)

**PARTIALLY SUPERSEDED về scope/bytes ceiling bởi EXP-ADR-001.** Các số dưới đây giữ để audit profile nhỏ; không áp làm giới hạn P0 mở rộng. NFR §3 sở hữu budgets hiện hành. Bảo vệ parser/ZIP/OCR không bị bãi bỏ.

**Quyết định: ACCEPTED về chính sách, BUDGETS = BOOTSTRAP/CHƯA BENCHMARK.** Sử dụng registry read-only `android-p0-conservative-v1`; các **trần từ chối ban đầu** (không phải mức hiệu năng đã chứng minh):
- file input đọc: ≤ **10 MiB/source**; XLSX tổng decompressed ≤ **64 MiB**, ≤ **2.000** ZIP entries, compression ratio tổng ≤ **100:1**;
- selected table ≤ **20.000 data rows**, ≤ **100 columns**, ≤ **500.000 cells** (giới hạn nào đến trước);
- CSV/TSV một cell ≤ **32 KiB UTF-8**, JSON depth ≤ **32** nếu parser P1 được thử;
- OCR một image ≤ **12 megapixels** (pixel width × height), một page; kiểm tra cả kích thước file/decoder trước cấp buffer;
- preflight/parse/OCR một attempt có watchdog **60 giây**, hỗ trợ cancel/cleanup; hết budget → structured issue, không đếm là PASS.

Không cho file tự tăng limits; kiểm tra trước **và trong** read/decompress/parse. Từ chối sớm bằng INP-ERR-004/017/011 tương ứng; giới hạn ratio có thể từ chối file hợp lệ để bảo vệ thiết bị. Cần benchmark thiết bị Android thực tế (đặc biệt máy RAM thấp) và **giảm trần** nếu kiểm thử thất bại; chỉ tăng trần bằng profile version + evidence, không tự nới. Chỉ công bố giới hạn được chứng minh sau release gate.

## INP-ADR-005 — Header và encoding

**Quyết định: ACCEPTED.** XLSX: gợi ý dòng đầu của selected range làm header; CSV/TSV: gợi ý first logical record (không phải physical line nếu quoted multiline). **Không auto-commit header**: người dùng xác nhận row index hoặc chọn `none` trước full validation. Header trùng/trống không tự sửa nhãn; mapping bằng Field ID. Default parser dialect cố định: CSV comma, TSV tab, quote `"`, UTF-8 strict (BOM nếu có được kiểm soát); không silently guess locale/decimal/encoding. Nếu nguồn thực tế khác, chọn dialect/encoding **tường minh** trước parse. Không dùng first-row sample để suy ra full-EOF readiness.

**Kiểm chứng:** header row2, no-header, duplicate names, BOM, invalid UTF-8, CSV multiline, decimal comma text, rejected unconfirmed autodetect.

## INP-ADR-006 — Numeric identifiers / leading zeros

**Quyết định: ACCEPTED.** ID lưu dạng text giữ lexical representation: `00123` khác `123`. Numeric XLSX cell `123` (kể cả display format `00000`) **không được tái tạo** thành ID `00123`; giữ storage number, format và display riêng khi có. Nếu policy IDENTIFIER cần literal nhưng bytes chỉ chứa numeric representation, đưa về **UNRESOLVED / provenance-loss review**, không tự ép sang text ID hay kết luận tương đương. Người dùng có thể sửa *policy* hoặc file nguồn có chứng cứ, nhưng không thay raw token.

**Kiểm chứng:** string vs numeric, leading zeros, precision loss, XLSX formatting, repeatable audit reason.

## INP-ADR-007 — XLSX parser và fidelity

**Quyết định: ACCEPTED về kiến trúc.** Chỉ một `XlsxFormatAdapter` phía infrastructure giao `SourceTable` với capability rõ (`TABULAR_VALUES_ONLY` hoặc `FULL_SEMANTIC` có evidence). Dùng package Dart `excel` v4 làm **ứng viên PoC**, kiểm tra nếu cần bổ sung đọc OOXML trực tiếp cho raw token/formula/cache/date system/provenance. Không khóa/publish dependency từ giả định; pin version **sau** PoC chạy trên Android. Không thực thi formula, macro, external links; không fabricate cached values/date interpretation; nếu loss ảnh hưởng requested mode, trả REVIEW/ERROR thay vì tuyên bố full fidelity.

**Bộ gate XLSX:** fixture 1900/1904 (gồm serial 60), shared strings, inline strings, blank/missing, hidden/merged, formula/cached missing, exact numeric lexemes, format display/ID zeros, multiple worksheets, ZIP bomb, malformed OOXML, memory/cancel. Nếu parser không bảo toàn đủ thông tin ở P0, công bố scope hỗ trợ hạn chế và không enable semantic mode tương ứng.

## INP-ADR-008 — Xác nhận dtype, key và matching

**Quyết định: ACCEPTED.** UI có thể đề xuất dtype/mapping/key nhưng **không chạy comparison theo inference chưa xác nhận**. User confirm một comparison profile: table pairing, field mapping bằng Field IDs, policy digest, A/B direction và **matching mode**. P0 có `POSITIONAL` hoặc `KEY`; KEY bắt buộc user confirm unique key field(s), duplicate-key → review/unresolved theo Core; POSITIONAL không ép chọn key. Preset strict-text cho phép confirm một lần toàn bộ profile, nhưng không thay raw/semantic bằng guessing. Đổi config/policy/key invalidate các downstream results liên quan.

**Kiểm chứng:** inferred key chưa confirm → blocked; duplicate keys không overwrite; config revision/mapping stale → blocked; explicit positional no key succeeds.

## INP-ADR-009 — Scratch, retention, permission và restore

**Quyết định: ACCEPTED, bổ sung lifecycle theo EXP-ADR-001/003.** Scope mới cho phép parsed chunks/key indexes/PDF temp app-private để xử lý 1 GB; giữ đến khi active consumers kết thúc, không tự lưu raw dài hạn. File nguồn **read-only**; khi provider không seekable, có thể tạo bản sao *temporary app-private* của đúng bytes đã hash trong sandbox; không đồng bộ, không upload, không lưu cache raw mặc định. Scratch chỉ sống trong attempt/session hiện hành, cleanup khi success/fail/cancel/đóng phiên; nếu process bị kill, **startup sweep** xóa scratch còn sót, không tuyên bố xóa ngay trong thời điểm bị kill. Lịch sử P0 không chứa raw file, URI/token, recognized text hay full report; chỉ lưu metadata an toàn nếu có user opt-in. Export file/report phải là user action rõ ràng.

Sau restore, **không** tự tin cậy PREVIEW_READY hoặc resume từ partial parse: reset SELECTED/recheck access/hash/config/adapter; nếu access_ref không còn thì UNSELECTED. Permission revoked/source changed invalidate snapshots/receipts/mapping. Trên Android dùng system file picker/SAF grants qua platform API được kiểm chứng; không xin broad storage permission khi không cần. Scratch không được quảng cáo là encrypted-at-rest nếu thực tế chưa chứng minh.

**Kiểm chứng:** read-only source hash unchanged, revoke, cancel, process death/relaunch, startup cleanup, log redaction, no implicit upload, permission flow.

## Release criteria và traceability

| Gate | Điều kiện bắt buộc | Tình trạng hiện tại |
| --- | --- | --- |
| Contract | Update schemas/fixtures cho OCR P0, validate offline; đủ versioning | CHƯA THỰC THI |
| Android input | XLSX/CSV/TSV thật, one-scope, parser corpus và provenance | CHƯA KIỂM CHỨNG |
| Android OCR | Camera/gallery + bundled offline model + manual review + SourceTable | CHƯA KIỂM CHỨNG |
| Comparison | Key/positional, policy confirmation, traceable diff, CSV/JSON và hai PDF theo EXP-ADR-002 | CHƯA KIỂM CHỨNG |
| P0 mở rộng | 1 GB/source + hai PDF + LARGE/REP gates theo NFR/Report spec | CHƯA KIỂM CHỨNG |
| Reliability | Unit/integration/device tests, resource profile benchmark, CI green | CHƯA ĐẠT EVIDENCE |
| Packaging | Signed/installable APK, installed offline smoke test, build metadata | CHƯA ĐẠT EVIDENCE |

**Truy vết:** INP-ADR-001 → INP-001/006/008; 002 → INP-010 + INP-TC-039/040; 003 → INP-004; 004 → INP-007; 005 → INP-004/006; 006 → INP-005; 007 → INP-003/005; 008 → INP-006/008; 009 → INP-002/008. Existing tests `INP-TC-001..040` remain PLANNED until executable evidence, not auto-passed by these ADRs.

**External confirmation:** đưa giảng viên xác nhận rằng OCR với *một ảnh một bảng có review thủ công* đáp ứng yêu cầu học phần. Nếu yêu cầu OCR image-image hoặc tự nhận dạng không cần review, cần thay đổi scope/release plan có version, không tự tuyên bố P0 đạt.
