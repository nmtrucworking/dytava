---
document_id: DYT-REP-001
version: 0.3.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng
---

# Report Export Specification — PDF diff và báo cáo Dytava

Nguồn duy nhất cho **hợp đồng trình bày/xuất báo cáo**, theo [quyết định mở rộng](../../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md). [SRS](../../requirements/SRS.md) sở hữu FR-013/017/018; [Core](../../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) sở hữu kết luận so sánh; [NFR](../../requirements/NFR.md) sở hữu budgets/chất lượng. Đặc tả bao quát hai PDF. [Template renderer Web/CLI 1.0.0](RENDERER.md) đã có implementation và mẫu PDF; merged diff renderer, Flutter renderer, full lifecycle và benchmark 1 GB chưa được nghiệm thu.

## 1. Loại đầu ra và preconditions

| Export kind | File | Nội dung |
| --- | --- | --- |
| `CSV_DIFF` | Một `.csv` | Diff dữ liệu máy đọc, an toàn khi mở bằng ứng dụng bảng tính |
| `JSON_REPORT` | Một `.json` | Kết quả có lineage/manifest theo schema report cần version hóa |
| `MERGED_DIFF_PDF` | **Một `.pdf` cho cả A/B** | Bảng đối chiếu hợp nhất, format theo trạng thái |
| `DYTAVA_REPORT_PDF` | **Một `.pdf` theo template** | Báo cáo Dytava có bìa, thống kê, phương pháp và chi tiết |

Chỉ export result snapshot **COMPLETED, hiện hành**: có input hashes, selected scopes, import/parser revisions, policy digest, direction confirmed và comparison result ID. Chặn kết quả stale/partial/cancelled hoặc OCR chưa review. Không cần source còn mở nếu snapshot hoàn chỉnh có đủ evidence; nếu phải đọc lại bytes thì revalidate access/hash. Không tự tính lại kết quả trong renderer.

Mỗi lựa chọn tạo một artifact riêng; chọn cả hai PDF tạo hai tệp riêng. PDF input không được suy ra từ các đầu ra này. Một comparison vẫn có đúng một selected table/scope ở mỗi phía.

## 2. Merged diff PDF — FR-017

### 2.1 Cách hợp nhất

- Một lưới logic có union các field đã map và field chỉ có một phía, theo thứ tự mapping xác nhận; ghi rõ header A/B nếu khác nhãn. Mỗi matched row xuất một lần, có row key/ordinal và SourceRef hai phía.
- `EXACT`: trình bày giá trị chung một lần; `EQUIVALENT`: giữ **cả biểu diễn A và B**, kèm nhãn tương đương theo policy. Không thay raw text bằng canonical rồi làm mất khác biệt biểu diễn.
- `DIFFERENT`/`UNRESOLVED`: mỗi cell trình bày A và B bằng hai dòng hoặc hai subcolumns có nhãn; canonical/rule/reason ở detail hoặc phụ lục. Null, missing, blank và empty string có ký hiệu/legend riêng, không biến thành số 0.
- Hàng/cột chỉ có một phía được giữ trong union, nhãn `ROW_ADDED/REMOVED`, `FIELD_ADDED/REMOVED` theo **direction đã xác nhận**. Đây là structural differences, không là trạng thái cell thứ năm. Side vắng mặt có marker missing.
- Có legend, tên/identity nguồn, scope, direction, result ID và page numbering. Tên tệp không thay cho identity/hash. Không mutate sources hoặc tạo “bảng đúng” thay người dùng.

### 2.2 Format theo trạng thái

| Loại | Màu nhấn / nền nhạt | Hiển thị bắt buộc |
| --- | --- | --- |
| EXACT | `#10B981` / `#ECFDF5` | Nhãn EXACT + icon exact; giá trị chung |
| EQUIVALENT | `#2563EB` / `#EFF6FF` | Nhãn EQUIVALENT + icon equivalent; A/B và rule trace |
| DIFFERENT | `#EF4444` / `#FEF2F2` | Nhãn DIFFERENT + icon different; A/B |
| UNRESOLVED | `#F59E0B` / `#FFFBEB` | Nhãn UNRESOLVED + icon unresolved; lý do cần review |
| ADDED / REMOVED | Xanh lá / đỏ theo direction | Nhãn đầy đủ, marker `+`/`−`, side hiện diện/vắng mặt |

Màu chính thức từ [branding](../../branding.md). Dùng màu làm nền/viền/nhấn, chữ có contrast phù hợp; không dùng màu sáng làm chữ nhỏ trên nền trắng. In grayscale vẫn hiểu nhờ nhãn/icon; gạch bỏ của REMOVED không che mất giá trị.

### 2.3 Phạm vi và bảng lớn

Default `FULL_COMPARISON`: bao gồm exact/equivalent/different/unresolved và structural differences. Cho phép `DIFFERENCES_ONLY` hoặc filtered rows do người dùng **chọn rõ**, nhưng PDF phải ghi filter/scope, số hàng/ô được xuất và tổng số của toàn comparison. Không gắn nhãn full report cho bản lọc. UNRESOLVED phải nằm trong bản differences-only; equivalent được đưa vào theo lựa chọn riêng được ghi rõ.

Một PDF có nhiều trang: lặp headers và key columns theo từng dải cột, định danh horizontal band và continuation, giữ tọa độ A/B. Mặc định A4 landscape cho merged diff, portrait/landscape theo template cho report. Nội dung dài wrap và tiếp tục trang sau có marker; không cắt hàng/cột/text âm thầm, không shrink đến chữ không đọc được. PDF dùng text/vector, **không chụp toàn lưới thành một ảnh**. Nếu vượt export budget, báo lỗi trước/đang render, cho người dùng đổi scope rồi export lại; không đánh dấu bản dở là hoàn tất. Nhiều trang vẫn là **một tệp**, không tự chia thành nhiều PDF.

## 3. Template báo cáo Dytava — FR-018

Baseline template: `template_id=dytava-comparison-report`, `template_version=1.0.0` (đã có [renderer Web/CLI](RENDERER.md); chưa có Flutter renderer).

| Thứ tự | Khối bắt buộc | Nội dung |
| --- | --- | --- |
| 1 | Bìa / nhận diện | Logo Dytava chính thức, tiêu đề “Báo cáo đối chiếu dữ liệu”, report ID, thời điểm + múi giờ, template version |
| 2 | Nguồn và phạm vi | A/B, format, byte sizes, SHA-256, sheet/range, direction và confirmation; giới hạn/capability/losses |
| 3 | Tóm tắt | Số rows/fields/matched cell pairs; bốn trạng thái; added/removed riêng; tỷ lệ và mẫu số |
| 4 | Phương pháp | KEY/POSITIONAL, field mapping, dtype, locale/tolerance/null policy, engine/parser/config/policy versions và digest |
| 5 | Sai khác chính | Bảng chi tiết theo row/key/field, raw A/B, trạng thái, rule/reason, SourceRef; số liệu theo scope/filter xuất |
| 6 | Chưa kết luận / cảnh báo | UNRESOLVED, OCR review/corrections, missing evidence, losses, giới hạn và những gì cần kiểm tra thủ công |
| 7 | Kết luận theo dữ liệu | Diễn giải thống kê, không tự khẳng định “giống hoàn toàn” khi có unresolved hoặc bản lọc; không thay phê duyệt nghiệp vụ |
| 8 | Phụ lục / audit | Manifest summary/result ID, schema/exporter/template versions, legend, cấu hình đầy đủ hoặc tham chiếu JSON; SourceRefs cần thiết |

Typography đóng gói local: **Plus Jakarta Sans** cho headings, **Be Vietnam Pro** cho nội dung tiếng Việt, **IBM Plex Mono** cho dữ liệu/IDs. Font embedding/subsetting phải giữ dấu tiếng Việt, copy/search được; lưu giấy phép font theo kho branding. Logo/illustration dùng assets có sẵn, không vẽ lại; illustration chỉ hỗ trợ trình bày, không thay evidence. Header/footer có logo nhỏ, report ID và `Trang n/N`, không chứa implementation jargon không cần thiết.

Các tỷ lệ lấy từ [SRS §4.4](../../requirements/SRS.md#44-summary-and-denominator-không-trộn-đơn-vị); mẫu số 0 là N/A, không trộn row/field/cell. Template không tự loại unresolved để tăng tỷ lệ. Timestamps trình bày theo timezone chọn khi export, lưu timezone trong metadata; dữ liệu semantic vẫn deterministic khi bỏ metadata trình bày thay đổi.

Có thể thêm template mới qua registry `template_id/version`, field mapping và render tests. Không cho template tùy ý chạy script, tải font/ảnh từ mạng hoặc sửa kết luận Core. Sửa layout không đổi semantic report version; đổi wire report hoặc cách hiểu số liệu cần version/migration riêng.

## 4. Hợp đồng exporter và lifecycle

[EX-1 streaming query/export](STREAMING_EXPORT_CONTRACT.md) là nguồn chi tiết cho cursor/request/manifest, ER-1 target JSON, bridge legacy, PDF layout và publication protocol. Existing [JSON Schema report1.0.0](schemas/dytava-report.schema.json) giữ compatibility; executable target schemas/renderer/calibration chưa triển khai. Shape dưới đây chỉ là summary, EX-1 sở hữu nghĩa đầy đủ:

```text
ExportRequest(result_snapshot_id, export_kind,
  selected_scope={FULL_COMPARISON|DIFFERENCES_ONLY|FILTERED, filters, counts},
  template_ref?, locale, timezone, page_setup, resource_profile_ref,
  include_source_display_names, destination)
ExportManifest(export_id, export_kind, result_id, source_hashes,
  selected_scopes, direction, policy_digest, engine/config/parser_versions,
  report_schema_version, exporter_version, template_id/version?,
  applied_filters, total_counts, exported_counts, warnings,
  created_at, timezone, output_byte_size, output_sha256, completion_state)
```

`template_ref` bắt buộc với DYTAVA_REPORT_PDF; merged diff dùng layout version được ghi manifest. Destinations/access grants không được chép vào PDF/JSON công khai. Hash output chỉ tính sau đóng tệp; lưu ở sidecar/metadata quản lý bên ngoài artifact, **không nhúng hash của chính toàn bộ PDF vào chính nó**. Không tuyên bố hash là chữ ký số hoặc xác nhận pháp lý.

Luồng: explicit export → validate immutable snapshot/request/budget → render từng page/band vào temp private → flush/close → verify page count/scope/output hash → user-selected destination/commit → COMPLETE. Cancel/error/disk full/provider revoke → đóng handles, cleanup temp, không publish artifact partial; nếu provider không có atomic rename, phải có cơ chế pending/commit phù hợp và thông báo failure, không quảng cáo atomicity chưa kiểm chứng. Export retry tạo attempt mới, không trộn bytes cũ. Result/scratch cần giữ đến khi consumers kết thúc, xóa khi đóng phiên hoặc hết lifecycle; không xóa sớm làm hỏng export tiếp theo.

## 5. Security, privacy và khả năng đọc

PDF không chứa JavaScript, embedded source files, executable attachments, actions hoặc auto-open remote links. Dữ liệu người dùng được render như text, không như markup/script. Không tự fetch URL, font hoặc image từ cell. Chỉ export theo hành động người dùng; cảnh báo ngắn rằng PDF chi tiết chứa dữ liệu nguồn và do người dùng quản lý sau chia sẻ. Không gửi nội dung lên backend hoặc log.

Tên nguồn hiển thị trong report theo lựa chọn export; mặc định giữ nhãn A/B, scope/hash để truy vết. Không kèm URI, path nội bộ, token hoặc EXIF. Ghi rõ output không mã hóa/ký số/PDF-A/PDF-UA trừ khi capability được triển khai và test riêng. Headings, reading order, table headers và nhãn trạng thái phải có kiểm tra accessibility; không tuyên bố chuẩn chứng nhận chỉ từ việc dùng thư viện PDF.

## 6. Acceptance registry

| ID | Requirement | Procedure / oracle | Expected |
| --- | --- | --- | --- |
| REP-TC-001 | FR-017 | Fixture hai bảng có đủ bốn trạng thái | Một PDF union, raw A/B, format/legend và refs đúng oracle |
| REP-TC-002 | FR-017 | Đảo A_TO_B/B_TO_A, rows/fields chỉ ở một bên | ADDED/REMOVED đảo đúng; không thay raw/hashes |
| REP-TC-003 | FR-017/018 | Null/missing/blank/empty/zero, ID 00123, Vietnamese/multiline | Không mất biểu diễn; search/copy text và dấu đúng |
| REP-TC-004 | FR-017 | Bảng nhiều trang, rất rộng, cell dài | Một PDF, không mất/trùng rows/cells; headers/keys/bands/continuations đọc được |
| REP-TC-005 | FR-017/018 | Full, differences-only, filtered export | Ghi filters/counts; unresolved không biến mất; không giả full scope |
| REP-TC-006 | FR-018 | Template Dytava 1.0.0 trên golden result | Đủ tám khối, assets/fonts/version, số liệu khớp JSON/oracle |
| REP-TC-007 | FR-018 | Zero matched pairs, only structural diffs, unresolved-only | Rates N/A khi mẫu số 0, không kết luận tương đương sai |
| REP-TC-008 | FR-013/017/018 | Stale revision, pending OCR, cancelled/partial result | Chặn export trước publish; không report COMPLETE giả |
| REP-TC-009 | FR-017/018, NFR-SEC-03 | Script/URL/markup/control chars/paths trong data | Text an toàn; không executable content, fetch, access secrets hoặc source mutation |
| REP-TC-010 | FR-015/017/018 | Cancel/disk full/provider revoke lúc render/commit | Failure có lý do, temp cleanup; không publish PDF dở |
| REP-TC-011 | FR-014/018 | Replay cùng result/config/template + locale/timezone | Nội dung/số liệu semantic bằng nhau; output hash kiểm tra từ tệp hoàn chỉnh |
| REP-TC-012 | FR-017/018, NFR-UX-02 | Render pages, in grayscale, inspect reading order/fonts | Không overlap/cắt chữ, đủ labels/legend; accessibility checklist có evidence |

Các REP-TC-* vẫn PLANNED cho nghiệm thu toàn target; unit/E2E, PDF mẫu và long-cell smoke của [renderer](RENDERER.md) chỉ là evidence cho subset đã triển khai. Không chuyển cả registry sang PASS từ các kiểm tra này. Nghiệm thu cần golden JSON độc lập, PDF text extraction, page renders và visual QA, counts reconciliation, font/active-content inspection, device/browser evidence. Xem [kế hoạch dung lượng lớn](../../testing/EXPANDED_SCOPE_ACCEPTANCE.md) cho pipeline 1 GB.
