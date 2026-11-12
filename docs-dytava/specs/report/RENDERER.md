# Dytava template renderer 1.0.0

Implementation hiện tại: **Web + Node CLI**, template `dytava-comparison-report@1.0.0`.
Renderer nhận result/report đã tính, không chạy matching/normalization, không mutate source.
Đây là renderer cho `DYTAVA_REPORT_PDF`; `MERGED_DIFF_PDF`, Flutter renderer và pipeline
input 1 GB chưa được triển khai trong thay đổi này.

## Sử dụng

Tại gốc repository:

```sh
npm ci
npm run build
npm run report:render
```

Lệnh cuối tạo mẫu từ [report fixture](../../examples/report-renderer/report.json):

- `output/pdf/dytava-report.pdf`: PDF A4 có font local, text/vector và footer Trang n/N.
- `output/pdf/dytava-report.html`: HTML tự chứa, font và branding được embed, không gọi mạng.
- `output/pdf/dytava-report.manifest.json`: template/version, scope/counts/lineage và SHA-256 output sau đóng tệp.

Truyền report khác:

```sh
npm run report:render -- --input path/to/report.json --output output/pdf/my-report.pdf --timezone Asia/Ho_Chi_Minh
```

CLI dùng Chromium từ Playwright đã có trong devDependencies; nếu máy chưa có browser binary,
chạy `npx playwright install chromium`. Không yêu cầu Express server và không gửi report lên server.
Output staging nằm trong thư mục destination, PDF chỉ rename ra tên đích sau khi render xong;
ba tệp PDF/HTML/manifest không phải một transaction atomic chung. Không ghi đè input JSON.

Trên Web: chạy comparison → **PDF Dytava** → xem preview → **In / Lưu PDF** trong print dialog.
Trình duyệt quyết định destination và thiết lập in; để giữ màu, bật background graphics.
Page numbering/footer của CLI được điều khiển bởi Chromium; ở print dialog web, headers/footers
phụ thuộc cấu hình trình duyệt. Chỉ CLI tạo sidecar hash của **PDF bytes thực tế**.

## Contract và guards

- [JSON Schema 1.0.0](schemas/dytava-report.schema.json) được sinh từ Zod tại
  `web/js/report/model.js`; schema hình dạng không thay cross-record validation runtime.
- Input mới yêu cầu COMPLETED, current, direction confirmed, OCR NOT_REQUIRED/CONFIRMED,
  hashes/source bytes/parser version, policy digest và import revision.
- Tổng bốn cell statuses phải khớp matched_cell_pairs; structural counters riêng.
  FULL_COMPARISON phải có đủ cell/structural details theo summary; DIFFERENCES_ONLY
  giữ đủ DIFFERENT/UNRESOLVED; PROVIDED_DETAILS ghi rõ giới hạn scope.
- Renderer hiện có budget **2.000 detail / 2.000.000 byte JSON**. Vượt budget báo lỗi,
  không silent truncate. Đây là document-rendering budget, không phải input-file limit,
  cũng không là chứng minh pipeline 1 GB đã đạt.
- Template ID/version phải nằm trong implementation đã đăng ký. Không nhận template script,
  remote assets, arbitrary markup hoặc access_ref/token fields.
- Metadata không có được hiển thị “Chưa cung cấp”; không fabricate SourceRef/hash/digest.
  Null, missing side, empty string, blank có marker riêng; dữ liệu số 0 vẫn hiển thị 0.
- Tên tệp không hiển thị mặc định, có thể opt-in bằng `includeSourceNames` ở renderer API.

## Legacy report và quyền riêng tư

Engine web hiện xuất `schema_version=1`, chưa có đầy đủ lineage của contract mới.
Adapter chỉ dùng khi `allowLegacy: true` hoặc CLI `--allow-legacy`. Preview web dùng chế độ
này và ghi rõ **Metadata chưa đầy đủ**, không giả tạo source hashes, SourceRefs hoặc
confirmation. Legacy phải có timestamp thực, counters/differences hợp lệ; ví dụ lịch sử
có placeholders không được coi là input đã sẵn sàng render.

Preview nhận payload từ opener cùng origin/source + token ngẫu nhiên, một lần; không
localStorage/sessionStorage/backend upload. Reload/đóng preview làm mất dữ liệu. Tất cả
nội dung report được escape; font/SVG lấy từ assets chính thức. CLI chặn network và
JavaScript, PDF không tự gắn embedded sources hoặc hành động remote.

## File triển khai

| File | Trách nhiệm |
| --- | --- |
| `web/js/report/model.js` | Contract, guards, legacy adapter, limits |
| `web/js/report/renderer.js` | Tám khối báo cáo, trạng thái, scope, diễn giải và manifest |
| `web/css/report.css` | Screen/print layout, short-card keeps, long-cell continuation |
| `web/report.html`, `web/js/report-viewer.js` | Preview riêng và local print dialog |
| `scripts/render-report.js` | Self-contained HTML, Chromium PDF, footer/hash/staged output |
| `tests/report-renderer.test.js` | Guards, counters, safety, zero denominator, legacy và source hashes |

## Kiểm chứng và giới hạn

`npm test` và `npm run test:e2e` bao gồm renderer guards và local preview (8 khối,
assets/fonts, metadata disclosure, narrow layout, không POST report). PDF mẫu đã render
và visual QA; fixture nguồn và hash được kiểm tra độc lập. Long-cell smoke test bảo toàn
200 dòng tiếng Việt qua nhiều trang. Đây không là nghiệm thu toàn bộ REP-TC-* hoặc LARGE-TC-*.

Còn cần: Flutter/Android/iOS exporters/device evidence, merged diff union/pagination,
full large-result streaming, cancellation/lifecycle dưới process death/quota/provider failure,
accessibility manual checklist, kiểm thử nhiều browsers/printers. PDF có tagging do Chromium
nhưng không tuyên bố chứng nhận PDF/UA, PDF/A, mã hóa hoặc chữ ký số.
