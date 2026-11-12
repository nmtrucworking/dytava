---
document_id: DYT-ADR-EXP-001
version: 0.1.0
status: ACCEPTED_FOR_SCOPE
owner: TBD
reviewer: TBD
updated: 2026-11-12
release_baseline: P0 mở rộng
---

# Quyết định mở rộng: input 1 GB và hai loại PDF

Căn cứ: yêu cầu chủ dự án ngày 12/11/2026. Các quyết định dưới đây **được chấp nhận về phạm vi**; implementation, contract migration, benchmark và nghiệm thu vẫn chưa hoàn thành. Không cần quyết định scope lần nữa để bắt đầu triển khai. Owner/reviewer và academic OCR sign-off của baseline trước vẫn giữ trạng thái riêng.

## EXP-ADR-001 — Dung lượng nguồn tối đa 1 GB

**ACCEPTED_FOR_SCOPE.** Trần sản phẩm là **1 GB = 1.000.000.000 byte cho từng artifact A hoặc B**, tính trên bytes nguồn thực đọc, không phải tổng phiên và không phải 1 GiB. Hai nguồn có thể đạt tổng 2.000.000.000 byte. Bytes giải nén, pixels, row/cell count, bộ nhớ, scratch disk và output có budgets độc lập tại [NFR §3](../requirements/NFR.md#3-resource-profiles-và-trần-input-1-gb).

Thay thế trần sản phẩm 10 MiB/source trong INP-ADR-004. Profile `android-p0-conservative-v1` giữ làm hồ sơ lịch sử/compatibility, **không** là giới hạn mặc định của scope mới. Profile mục tiêu `large-input-v1` phải có streaming/chunking, disk-backed snapshots/indexes, external matching khi cần, preview phân trang, cancellation/progress và preflight tài nguyên. Chỉ sửa hằng số file-size không đáp ứng quyết định này. Không kế thừa mặc định các trần 20.000 rows/100 columns/500.000 cells hoặc watchdog tổng 60 giây sang profile lớn.

1 GB là yêu cầu dung lượng, không tự mở thêm định dạng, nhiều sheet hoặc ảnh–ảnh. Các guard chống ZIP bomb và pixel bomb vẫn bắt buộc; tệp dưới trần có thể bị từ chối vì cấu trúc/guard/device thiếu tài nguyên với lý do cụ thể. Tuy nhiên phải có corpus hợp lệ tại biên 1 GB chạy hết import → compare → export để công bố hỗ trợ 1 GB trên nền tảng/profile đó; không dùng việc từ chối mọi tệp lớn như cách đáp ứng yêu cầu.

## EXP-ADR-002 — Hai đầu ra PDF độc lập

**ACCEPTED_FOR_SCOPE.** Scope **P0 mở rộng** bổ sung cả hai lựa chọn, giữ CSV/JSON:

1. `MERGED_DIFF_PDF`: hợp nhất kết quả đối chiếu hai selected tables vào **một tệp PDF**, với định dạng theo trạng thái và dữ liệu hai phía khi khác nhau. Đây là hợp nhất cách trình bày diff, không hợp nhất/sửa dữ liệu nguồn hoặc ghép thô hai PDF.
2. `DYTAVA_REPORT_PDF`: báo cáo theo template Dytava có version, gồm nhận diện, tóm tắt, phương pháp/policy, thống kê, sai khác, unresolved, cảnh báo và lineage.

Nguồn chuyên trách cho layout, lựa chọn phạm vi, metadata, template và acceptance là [Report Export Specification](../specs/report/README.md). FR-013 giữ summary/CSV/JSON; FR-017/018 sở hữu hai PDF. Không tự coi PDF input/OCR hoặc PDF pháp lý đã được hỗ trợ vì có PDF output.

## EXP-ADR-003 — Phân pha và khả năng mở rộng

**ACCEPTED_FOR_SCOPE.** 1 GB và hai PDF là yêu cầu phải giao của **P0 mở rộng**, không để PDF tiếp tục trong danh sách loại trừ khỏi scope. Android P0 giữ ưu tiên; thiết kế dùng chung với web/iOS, mỗi nền tảng phải có evidence riêng. Bộ exporter mở rộng theo format/template version, nhận result snapshot/read-only streams, không cài lại semantic engine.

Không thay đổi semantics EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED, direction, source immutability, OCR review, một selected table mỗi nguồn hoặc mặc định không upload. Khi thiếu khả năng chạy local, không tự fallback cloud. Nhu cầu backend/batch hoặc input formats khác cần scope riêng.

## Hồ sơ thay đổi và tác động

| Trước | Scope mới | Nguồn sở hữu |
| --- | --- | --- |
| 10 MiB/source, conservative rows/cells, 60s total attempt | 1 GB/source; resource profiles theo workload/device, không kế thừa trần nhỏ | PRD, SRS FR-016, NFR §3 |
| P0 chỉ CSV/JSON, PDF để sau | CSV/JSON + merged diff PDF + Dytava report PDF | SRS FR-013/017/018, Report spec |
| Whole-result/whole-workbook memory candidate | Streamed tables/results, private disk spill, paginated rendering | Architecture |
| INP-TC-001..040/semantic TC-* | Giữ nguyên; thêm LARGE-TC-* và REP-TC-* | Testing plan và Report spec |

Ưu tiên khi xung đột: quyết định này ghi đè **scope/limits/export exclusions** tương ứng của register 11/11/2026 và Master lịch sử; Input/Core tiếp tục sở hữu wire/semantic invariants. Schemas Input 0.1.0 và fixtures nhỏ không tự thay version hoặc thành large-file evidence. Xem [Document Control](../governance/DOCUMENT_CONTROL.md).
