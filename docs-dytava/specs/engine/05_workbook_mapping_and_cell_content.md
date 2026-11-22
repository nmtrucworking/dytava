# Ghép toàn workbook và nội dung ô ngoài text

Ngày: 20/11/2026. Phạm vi: web và Flutter mobile. Quyết định sản phẩm: so sánh **tất cả worksheet**, xem tổng hợp và từng cặp; tự ghép khi đủ bằng chứng, chỉ hỏi phần chưa xác định được. Tài liệu này thay quy định cũ về một selected sheet/scope và yêu cầu xác nhận mọi đề xuất **đối với ghép sheet**. Các gate về policy, chiều so sánh, OCR và độ tin cậy dữ liệu vẫn có hiệu lực. Không sửa ngầm wire Input 0.1.0 thành hợp đồng workbook.

## 1. Vấn đề đã tìm thấy

- Mobile đăng ký file bằng `tables.keys.first`; web thử tên sheet phía còn lại rồi fallback về sheet đầu. Hai workbook đảo thứ tự tab có thể bị so sai cặp.
- Chọn lại sheet trước đây làm parse/so sánh lại; không có kết quả cố định của toàn workbook để lọc.
- Các quy định một scope/table tại INP-004 và L0 không mô tả yêu cầu mới này.
- Giá trị scalar trong XML không đủ đại diện ô rich value. Hai ảnh khác nhau có thể cùng cache `#VALUE!`; so text sẽ báo EXACT sai.
- Tên media, thứ tự ZIP entry, số `rId`, vị trí tab và kích thước bảng không phải định danh nội dung.

## 2. Ghép sheet

1. Inspect toàn bộ danh mục worksheet, gồm sheet ẩn, veryHidden, sheet rỗng. Giữ tên thật, trạng thái, header, kiểu ô và tọa độ nguồn. Sheet ẩn có cảnh báo trong UI/report. Chartsheet/đối tượng không có bảng dữ liệu phải được khai báo ngoài capability hoặc từ chối; không coi như bảng rỗng đã so xong.
2. Ưu tiên tên mang nghĩa trùng chính xác; sau đó tên sau trim, gom khoảng trắng và lowercase, nếu hai phía đều duy nhất. Không bỏ dấu tiếng Việt.
3. Tên rỗng hoặc mặc định như `Sheet1`, `Sheet2`, `Trang tính 1` **không phải bằng chứng định danh**. Workbook Excel hợp lệ yêu cầu tên sheet; “không có tên” trong tác vụ thông thường được hiểu là chưa đặt tên nghiệp vụ. Tên XML thiếu/hỏng cần validation riêng.
4. Với các sheet chưa ghép, tính điểm cấu trúc từ nhãn header có nghĩa, số cột và kiểu dữ liệu trội của tối đa 64 dòng. Các header tự sinh `Cột n` không phải bằng chứng tên nghiệp vụ. Không dùng số dòng hoặc thứ tự tab để quyết định.
5. Điểm hiện thực: `0.75 × Dice(header sets) + 0.15 × min(width)/max(width) + 0.10 × type agreement`. Type agreement dùng các cột trùng nhãn có sample khác rỗng; nếu không có là 0.5. Điểm cần ≥ 0.80, cao hơn đối thủ ở **cả hai phía** ≥ 0.08. Xét toàn bộ ứng viên trước khi nhận cặp; không ghép greedy theo tab.
6. Ghép một–một. Nếu còn sheet ở cả hai phía mà chưa đủ căn cứ, hiển thị lựa chọn cặp hoặc giữ riêng. Không tự xem ambiguous là added/removed. Khi chỉ còn sheet một phía, ghi nhận sheet added/removed, kể cả sheet rỗng.
7. Lưu phương thức `name`, `structure`, `manual`, `only-a`, `only-b` và score. Thay nguồn/ánh xạ làm kết quả cũ stale. Không tự tái dùng lựa chọn cho workbook mới.

Ví dụ: A/Sheet1 có `ProductID, Photo, Cost`; A/Sheet2 có `EmployeeID, Name, StartDate`. B/Sheet1 là nhân viên, B/Sheet2 là sản phẩm. Ghép A/Sheet1 ↔ B/Sheet2 và A/Sheet2 ↔ B/Sheet1. Nếu cả bốn sheet đều có cùng schema và kiểu dữ liệu, giữ mơ hồ và hỏi người dùng; không chọn đường chéo theo vị trí.

Giới hạn: đây là heuristic bảo thủ, không phải bằng chứng chắc chắn hai bảng có cùng nghiệp vụ. Sheet cùng schema có thể cần chọn; sheet đổi toàn bộ header hoặc chỉ có header tự sinh cũng cần chọn. Tên có nghĩa trùng vẫn được ưu tiên ngay cả khi schema thay đổi, để báo sai khác cấu trúc.

## 3. Thực thi và kết quả

- Mỗi cặp dùng một table comparison riêng. Không nối các sheet rồi align dòng xuyên sheet.
- Tổng workbook là tổng các bộ đếm theo sheet; hàng/cột/sheet added/removed được trình bày riêng với matched cell pairs.
- Chế độ “Tất cả” bao gồm mọi cặp và sheet một phía; chọn từng cặp chỉ lọc kết quả đã tính, không parse lại và không thay tổng phạm vi export.
- Web dùng cài đặt ghép dòng chung; cột khóa chỉ được chọn nếu có trong toàn bộ danh mục bảng. Không đổi ngầm một key đã chọn thành positional. Mobile suy luận cấu hình từng cặp từ schema của cặp đó, giữ direction/web policy; cặp preview giữ cấu hình đã duyệt. Các rule có cùng Field ID được kế thừa. JSON theo sheet ghi mode/key đã dùng.
- Snapshot và ID dòng/ô có sheet identity, không trùng giữa các cặp. Địa chỉ ảnh/dữ liệu dùng tọa độ thật kể cả khi bỏ dòng trắng khỏi bảng preview.
- JSON giữ sheet mapping, kết quả từng cặp, tổng và cảnh báo. CSV có cột Sheet A/Sheet B; sheet rỗng thêm/bớt có bản ghi cấu trúc. Web report renderer/PDF có summary từng sheet và sheet structural details, trong budget renderer hiện hành. Không âm thầm cắt report vượt budget.
- Giới hạn dòng/ô áp dụng cả tổng workbook; việc mở rộng nhiều sheet không nhân vô hạn budget một sheet.

## 4. Ảnh “Place in Cell”

Nhận định “ảnh ở media, XML giữ địa chỉ” đúng hướng nhưng chưa đủ: ô chứa địa chỉ **gián tiếp**, qua nhiều bảng chỉ mục và relationship.

Chuỗi Microsoft local image được xử lý:

```text
worksheet/c[@r, @vm]
 → metadata/valueMetadata/bk[vm - 1]
 → rc (metadata type XLRICHVALUE; t là chỉ mục 1-based)
 → futureMetadata[@name='XLRICHVALUE']/bk[rc.v]
 → richdata:rvb/@i
 → Rich Value Data/rv[i], @s chọn Rich Value Structure/s
 → k[@n='_rvRel:LocalImageIdentifier'] xác định vị trí v, không hard-code v đầu
 → richValueRels/rel[v] (0-based)
 → relationship theo r:id, không theo thứ tự .rels
 → resolve Target tương đối theo part chứa relationship
 → bytes media
```

Tên part có thể khác tên thường gặp; phải theo relationship. `vm` là 1-based, chỉ mục rich value/local-image là 0-based. Không duyệt `xl/media/imageN` theo số N. Một media có thể được nhiều ô tham chiếu.

Hành vi hiện thực:

- Phân tích gói gốc trước khi ExcelJS flatten cell; Flutter đọc XML theo local name.
- Giữ `image` là loại nội dung riêng. Nhãn hash hiển thị không biến ảnh thành chuỗi nghiệp vụ.
- SHA-256 là chỉ mục nội dung; EXACT cần cả digest, độ dài và bytes bằng nhau. Cùng ảnh đổi tên media/rId vẫn EXACT. Khác bytes là DIFFERENT, chưa tuyên bố khác về thị giác.
- Ảnh ↔ text/blank là khác kiểu. Thiếu media, metadata hỏng, rich type chưa hỗ trợ hoặc tham chiếu ngoài là UNRESOLVED; hai cached error giống nhau không được đi qua shortcut EXACT.
- Không tải URL, chạy công thức, macro hoặc OCR ảnh nhúng. Chưa có so sánh pixel, perceptual hash, nội dung OCR hay hiển thị thumbnail ảnh trong luồng này.
- Vị trí ô và digest nằm trong report; không nhúng bytes ảnh vào JSON/CSV.

## 5. Các lỗi tương tự phải tính đến

| Dạng nội dung | Rủi ro khi chỉ đọc scalar/text | Xử lý hiện tại / việc cần bổ sung |
| --- | --- | --- |
| `IMAGE()` / `_xlfn.IMAGE()` | Cùng URL khác bytes theo thời điểm; cache lỗi/trống; URL cần auth | Nếu resolve được local image qua metadata thì so bytes; nếu chưa có bytes xác thực thì UNRESOLVED. Không tự tải mạng |
| WPS `DISPIMG`, `cellimages.xml` | Tên ảnh là lookup key, không phải nội dung | Nhận công thức, giữ UNRESOLVED; cần adapter riêng cho quan hệ cellimages |
| Ảnh nổi / `drawing`, VML | Anchor phủ ô không có nghĩa ảnh là giá trị ô; có thể phủ nhiều ô | Cảnh báo UI/report, chưa so như cell. Cần diff object riêng gồm anchor, crop, transform, bytes |
| Rich linked types, Stocks/Geography, rich arrays | Scalar fallback/error không phản ánh đầy đủ object | Ô có `vm` không resolve được local image giữ UNRESOLVED; cần model type-specific trước khi mở capability |
| Công thức thường + cached result | Công thức khác vẫn cùng kết quả; cache cũ hoặc thiếu; shared formula/array/spill không thể đọc độc lập | Hiện values-oriented; cần formula text/AST, cache freshness và dependency mode riêng. Không chạy Excel recalculation |
| Hyperlink | Cùng nhãn khác URL; URL không nằm trong text ô | Text comparison chưa đảm bảo URL equality; cần giữ target/tooltip riêng |
| Rich text, phonetic runs | Nhiều run/style; ghép text có thể bỏ định dạng hoặc lẫn phonetic text | Cần tách visible text khỏi annotations và compare format riêng |
| Merged cells | Các ô con có thể trả giá trị anchor hoặc blank khác nhau giữa thư viện | Giữ ô neo; cảnh báo merge; không auto-fill. Cần merge geometry parity |
| Số, ngày, tiền, % và mã | Giá trị số khác display; số 0 đầu, date1900/1904, serial 60, time/timezone, custom formats | Có hỗ trợ values cơ bản; chưa tuyên bố fidelity mọi format. Cần golden fixtures riêng |
| Hidden rows/columns, filters, structured tables, nhiều vùng trong một sheet | “Nhìn thấy” khác “tồn tại”; một header không đại diện mọi table | Toàn worksheet hiện vẫn dùng một table/header được phát hiện; cần scope/range policy và multi-region adapter riêng |
| Comments/notes/threaded comments, validation, conditional format | Khác metadata không làm đổi scalar | Ngoài values comparison; cần object/metadata diff và cảnh báo capability |
| OLE, chart, pivot/cache, external link | Đối tượng hoặc cache nằm ngoài sheetData | OLE/drawing có cảnh báo; chartsheet chưa hỗ trợ. Không refresh external data hoặc giả định đã so toàn bộ object workbook |
| ZIP/relationship bị hỏng, part thiếu, target ngoài gói | Ô ảnh bị biến thành lỗi/trống hoặc bị ghép sai media | Reject cấu trúc không đọc được; rich content chưa resolve → UNRESOLVED. Không truy cập file/network theo Target |

Các mục “cần” là giới hạn/đề xuất tiếp theo, không phải tuyên bố đã hỗ trợ.

## 6. Mã nguồn và kiểm thử

- Ghép sheet: `web/js/sheet-mapping.js`, `packages/excelcompare_core/lib/src/sheet_mapping.dart`.
- Ảnh: `web/js/xlsx-cell-content.js`, `mobile/lib/infrastructure/xlsx_cell_content.dart`.
- Fixture tổng hợp chung Node/Flutter: `tests/fixtures/workbook-{a,b,broken}.xlsx`; generator `build-workbook-fixtures.js`. Đây là fixture OOXML tổng hợp, không phải file được Microsoft Excel tạo và nghiệm thu trên thiết bị.
- Tests: `tests/workbook.test.js`, `mobile/test/workflow/workbook_comparison_test.dart`, browser regressions trong `tests/e2e/app.spec.js`.
- Không đồng nhất unit/browser tests với nghiệm thu file thực Excel/WPS/Google Sheets, iOS/Android device hoặc benchmark input lớn.

Kiểm chứng trong workspace ngày 20/11/2026: `npm run check` (build + 52 Node tests), `npm run test:e2e` (13 Chromium tests), `flutter test --no-pub` (82 tests), `dart test` trong core (12 tests). Sau điều chỉnh guard ảnh/ordinal, chạy lại bộ workbook Flutter (6 tests) và core; `flutter analyze --no-pub` không có issue. Đã kiểm tra screenshot browser 390 px với workbook nhiều sheet. Tất cả các kiểm thử nêu trên PASS; không tuyên bố nghiệm thu thiết bị thật.


## 7. Nguồn chính thức

- [MS-XLSX Local Image Type](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-xlsx/aac1e2a6-7072-4e66-b1de-f20b8bf63318): `_localImage`, LocalImageIdentifier và alt text.
- [MS-XLSX Metadata](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-xlsx/3dd44d53-847b-402f-a8c7-41a85024caf7): `XLRICHVALUE` và `rvb`.
- [MS-XLSX richValueRels](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-xlsx/5bbff086-f47d-4137-936b-8fe49ada3832): danh sách quan hệ.
- [MS-XLSX Rich Value Data](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-xlsx/896934fd-8df7-43f4-b154-2d39371c270d): part và relationship.
- [MS-OI29500 cell vm indexing](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oi29500/8c8d962a-5d15-4229-a28f-2ebf88bdd6fc): metadata index 1-based.
- [Microsoft IMAGE function](https://support.microsoft.com/en-us/excel/functions/image-function): ảnh URL và hạn chế truy cập.
