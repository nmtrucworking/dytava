# Port thuật toán và luồng web sang mobile — 18/11/2026

Mobile dùng `createMobileWorkflow()` làm composition mặc định. `createDemoWorkflow()` vẫn dành cho fixture/test cũ. Không nhúng WebView hoặc phụ thuộc máy chủ để so sánh.

## Luồng đã nối

1. Chọn riêng tệp A/B: XLSX, CSV, TSV, TXT hoặc JSON. Đọc/parse trên isolate, báo trạng thái đang đọc. Parser worker có timeout 30 giây. XLS cũ cần lưu lại thành XLSX.
2. Xem trước, chọn sheet trong màn hình xem trước. Đổi sheet thay snapshot, hủy hiệu lực cấu hình/kết quả cũ. Giữ số 0 theo định dạng Excel, tỷ lệ %, cached formula, rich text và ngày. Tìm header trong 15 dòng đầu như web; giữ vị trí ô nguồn thực tế.
3. Tự ghép cột theo tên và đề xuất khóa có tên ID/mã/code/SKU khi duy nhất. Không tự dùng STT hay cột đầu tiên làm khóa. Không có khóa tin cậy thì đề xuất ORDERED_SEQUENCE; vẫn chọn được POSITIONAL và KEY thủ công.
4. Xác nhận cấu hình và chạy so sánh trên isolate riêng. Giữ guard cancel, revision, stale result và frozen plan của controller; hủy hoặc timeout kết thúc worker. Tiến trình cập nhật theo lô 250 hàng.
5. Hiển thị hai bảng A/B đồng bộ cuộn ngang/dọc, cùng trang 100 hàng đã căn chỉnh. Hàng thêm/xóa nằm tại vị trí căn chỉnh, có khoảng trống ở nguồn đối ứng. Bộ lọc ALL/EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED/ADDED/REMOVED tính theo hàng. Danh sách ô cũ vẫn truy cập được.
6. Chạm ô để xem raw, canonical, vị trí nguồn, rule và lý do; chạm số dòng để xem lý do ghép. Highlight từ LCS và edit-distance chỉ tính khi xem ô.
7. Tạo preview CSV/JSON trên isolate; nút Lưu mở bộ chọn vị trí gốc của thiết bị. Preview màn hình tối đa 20.000 ký tự, dữ liệu lưu đầy đủ. CSV trung hòa công thức bảng tính. Không bật PDF hoặc OCR thật.

## Thuật toán

- `packages/excelcompare_core/lib/src/web_comparison.dart`: các nhánh EXACT, identifier, null/zero, percentage, boolean aliases, date ISO/DD/MM/YYYY, decimal/tolerance, whitespace và case folding theo `web/js/compare-engine.js`. Trả normalized value, status, rule ID và explanation. SemanticPolicyEngine PoC cũ vẫn độc lập.
- `mobile/lib/infrastructure/mobile_comparison_port.dart`: KEY bằng map, POSITIONAL, ORDERED_SEQUENCE theo chữ ký dòng duy nhất → LIS anchors → Needleman–Wunsch trong từng đoạn. Có lineage, rationale, STT metadata và khác biệt schema kể cả ô trống.
- Quy tắc đặt thủ công vẫn tôn trọng trim/locale/tolerance của từng cột. Tùy chọn “Tự suy luận kiểu như bản web” bật đường chuẩn hóa web mặc định cho cột tự đề xuất.
- `mobile/lib/domain/word_difference.dart`: token LCS có budget; Levenshtein hai hàng bộ nhớ, sử dụng Unicode scalar. Không tạo HTML từ dữ liệu nguồn.

## Khác biệt có chủ đích so với web

- Không mang theo lỗi fallback vị trí: ngân sách cumulative 4.000.000 lượt so sánh cột trong DP. Đoạn vượt ngân sách thành nhóm hàng UNRESOLVED, không tự kết luận ADDED/REMOVED hoặc ghép cặp vị trí. Dùng hai hàng Float64 và traceback Uint8 thay ma trận Float64 đầy đủ.
- Không mang theo lỗi similarity của chuỗi >1.000 ký tự. Vượt 1.000.000 trạng thái edit distance thì không hiển thị tỷ lệ; verdict vẫn được giữ.
- Chữ ký anchor dùng JSON framing để tránh va chạm do delimiter trong nội dung. Khóa tuple cũng dùng JSON framing.
- KEY có trống/trùng bị từ chối rõ ràng như web, không lấy bản ghi đầu rồi bỏ bản ghi còn lại.
- Grid dựng tối đa 100 hàng/trang, dùng ListView.builder; hai pane luôn dùng cùng tập hàng, kể cả trường hợp chỉ có structural changes.
- JSON mobile có schema riêng `dytava-mobile-web-parity/v1`; không giả danh đầy đủ wire contracts của spec hoặc báo cáo web có cùng schema.

## Kiểm chứng

Kết quả trên workspace ngày 18/11/2026: Flutter analyze sạch; 76/76 mobile tests, 10/10 core tests; APK debug build thành công. Hai test parser/parity (11 ca tổng cộng) đã được chạy lại sau khi chuẩn hóa biểu diễn phần trăm Excel.

- Oracle 140 cặp giá trị × chính sách được sinh trực tiếp bằng engine web, so verdict, rule ID và canonical A/B trong Dart. Sinh lại: `node scripts/generate-mobile-web-parity.mjs`; fixture được version cùng code.
- `mobile/test/workflow/web_parity_test.dart`: insert/renumber/lineage, KEY/reorder/duplicate, DP vượt budget, schema blank, highlight, worker cancellation/binding, CSV thật → proposal → worker → report và JSON validation.
- `mobile/test/workflow/web_grid_test.dart`: grid ở 320/800 dp, giữ khoảng trống inserted row, bộ lọc, mở ô và rationale.
- Giữ các test controller/demo/giao diện cũ bằng injection rõ ràng; test native worker chạy ngoài fake clock của widget test.
- Lệnh: trong `mobile/`, chạy `flutter analyze`, `flutter test`, `flutter build apk --debug`; trong `packages/excelcompare_core/`, chạy `dart test`.

Giới hạn parser hiện giữ cùng constants như web (500 MiB, 1.500.000 dòng, 500 cột, 25.000.000 ô), không phải chứng nhận thiết bị xử lý được đầu vào cực đại. Pipeline vẫn trong RAM, không phải pipeline disk-backed 1 GB. Cần calibration peak memory/timing và kiểm thử lưu tệp trên các thiết bị mục tiêu trước khi công bố năng lực dung lượng lớn.
