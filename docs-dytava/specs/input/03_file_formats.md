# Định dạng file và hợp đồng adapter

> **Quyết định scope ngày 11/11/2026:** [9 ADR](../../decisions/ADR_REGISTER_P0_2026-11-11.md) chốt P0 Android là XLSX/CSV/TSV + PNG/JPEG với manual OCR review (tối đa một nguồn ảnh); JSON chuyển P1. Các adapter vẫn CHƯA được chứng minh triển khai. Schema ImportConfig 0.1.0 chưa thể ingest ảnh P0, phải version-migrate trước khi bật.

Document ID: INP-003\
Version: 0.1.1 (documentation; wire schemas vẫn 0.1.0)\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 12/11/2026

## 1. Mục đích và phạm vi

Định nghĩa các định dạng tệp đầu vào mà Dytava dự kiến tiếp nhận, các phương pháp nhận diện định dạng, yêu cầu đối với parser, giới hạn xử lý và tiêu chí xác nhận một định dạng được hỗ trợ.

Tài liệu này mô tả **định dạng của dữ liệu nguồn**, không quy định thuật toán xác định hai giá trị có tương đương hay không.

## 2. Thuật ngữ và định nghĩa

|Capability|Ý nghĩa|
|---|---|
|`FULL_SEMANTIC`|Adapter bảo toàn đủ raw type, cấu trúc, định dạng và provenance cần thiết cho chế độ so sánh đã khai báo|
|`TABULAR_VALUES_ONLY`|Chỉ trích xuất được giá trị dạng bảng|
|`OCR_REVIEW_REQUIRED`|Dữ liệu cần được người dùng xác nhận trước khi so sánh|
|`UNSUPPORTED`|Không thể hoặc không được phép xử lý|

Một định dạng có thể được hỗ trợ ở một capability level nhưng không hỗ trợ tất cả các tính năng so sánh.

Capability phải được xác định theo adapter và phiên bản thực thi, không chỉ dựa trên extension.

## 3. Các thành phần dữ liệu

### P0 — Android MVP

|Format|Extension|Kiểu dữ liệu|
|---|---|---|
|Excel Workbook|`.xlsx`|OOXML spreadsheet|
|Comma-Separated Values|`.csv`|Delimited text|
|Tab-Separated Values|`.tsv`|Delimited text|
|Raster Image OCR|`.png`, `.jpg`, `.jpeg`|Một ảnh/một bảng, manual review bắt buộc (INP-ADR-002)|

Đây là phạm vi đã chốt ở mức engineering baseline qua INP-ADR-002; dữ liệu ảnh có contract riêng tại INP-010. Chỉ được đánh dấu một adapter là implemented/supported sau khi đạt các bài kiểm thử tương ứng.

### P1 — Mở rộng

|Format|Extension|
|---|---|
|JSON flat records|`.json`|
|JSON Lines|`.jsonl`, `.ndjson`|
|Legacy Excel|`.xls`|
|Macro-enabled Excel|`.xlsm`|
|OpenDocument Spreadsheet|`.ods`|

Các adapter P1 cần được kiểm chứng riêng trên thiết bị mục tiêu.

### P2 — Mở rộng nâng cao

|Format|Extension|
|---|---|
|Portable Document Format|`.pdf`|
|Extended image formats|`.webp`, `.heic`|
|XML|`.xml`|
|HTML Table|`.html`, `.htm`|
|Excel Binary Workbook|`.xlsb`|

**PDF ở đây là input format**, chưa thuộc P0. [Scope mở rộng](../../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) đã cho phép **PDF output** (merged diff + Dytava report) tại [Report spec](../report/README.md), không đồng nghĩa adapter đọc PDF. PDF và hình ảnh không cung cấp cùng mức thông tin cấu trúc như tệp bảng tính gốc.

### Ngoài phạm vi mặc định

- Parquet / Arrow.

- Tệp ZIP chứa nhiều tệp dữ liệu độc lập.

- Google Sheets URL.

- Kết nối cơ sở dữ liệu trực tiếp.

- API bên thứ ba.

Việc hỗ trợ các nguồn này yêu cầu quyết định phạm vi riêng.

## 4. Quy tắc và ràng buộc

|Rule ID|Quy tắc|
|---|---|
|INP-RULE-009|Extension không phải bằng chứng duy nhất về định dạng|
|INP-RULE-010|Parser phải khai báo capability được hỗ trợ|
|INP-RULE-011|Giá trị CSV/TSV ban đầu được coi là text|
|INP-RULE-012|JSON null khác missing property|
|INP-RULE-013|Không thực thi macro hoặc external resource|
|INP-RULE-014|Cấu trúc tệp không hợp lệ phải được từ chối an toàn|
|INP-RULE-015|Không làm mất raw type/provenance mà không ghi nhận giới hạn|
|INP-RULE-016|Không tuyên bố hỗ trợ format trước khi adapter đạt acceptance tests|

| Format P0 | MIME hint | Bằng chứng cấu trúc | Capability có thể công bố sau PoC | Metadata không có/không suy ra |
| --- | --- | --- | --- | --- |
| XLSX | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | ZIP + Content_Types + workbook relationships + worksheet parts hợp lệ | FULL_SEMANTIC nếu đủ evidence theo mode; nếu thiếu công bố loss hoặc từ chối mode | Không phục hồi leading zeros từng bị người dùng làm mất trước khi lưu |
| CSV | text/csv | Text decode strict + dialect parse toàn scope | TABULAR_VALUES_ONLY | Không workbook/style/formula metadata |
| TSV | text/tab-separated-values | Text decode strict + tab dialect/profile | TABULAR_VALUES_ONLY | Không workbook/style/formula metadata |
| JSON | application/json | JSON grammar + records shape | TABULAR_VALUES_ONLY với native type tags/provenance | Không worksheet/Excel format; không flatten ngầm |

MIME là hint, không proof. Capability phải trả kèm adapter_id/version, unsupported features và losses theo field/mode; không tự gắn FULL_SEMANTIC cho mọi XLSX. TABULAR_VALUES_ONLY vẫn phải có provenance và raw kind tối thiểu; không được hiểu là cho phép bỏ mất chúng. UTF-8/double-quote trong fixture là profile explicit, chưa chốt mọi default sản phẩm.

## 5. Input / Output Contract

### XLSX

#### Các thành phần cần hỗ trợ

- Workbook.

- Worksheet.

- Row.

- Column.

- Cell.

- Shared strings.

- Number formats.

- Cell types.

- Formula và cached result.

- Excel date system.

- Source coordinates.

#### Các loại ô

|Cell kind|Mô tả|
|---|---|
|Number|Giá trị số được lưu trong workbook|
|String|Giá trị chuỗi|
|Boolean|Giá trị logic|
|Formula|Ô chứa công thức|
|Blank|Ô trống|
|Error|Ô chứa mã lỗi Excel|
|Date-like|Ô số được biểu diễn dưới dạng ngày/thời gian theo format|

Date-like là diễn giải dựa trên value và formatting metadata, không phải lúc nào cũng là physical storage type độc lập trong OOXML.

#### Các tình huống cần xử lý

- Merged cells.

- Hidden rows và hidden columns.

- Multiple worksheets.

- Missing cells.

- Formula không có cached result.

- Excel 1900 và 1904 date system.

- Workbook được bảo vệ bằng mật khẩu.

- Shared strings hoặc relationships không hợp lệ.

- Workbook có số lượng ô lớn.

#### Security

- Không thực thi macro.

- Không đánh giá hoặc tải external links.

- Không thực thi nội dung nhúng.

- Kiểm tra ZIP entries, kích thước giải nén và giới hạn tài nguyên.

- Không tự ghi đè workbook.

- Không vô hiệu hóa các cơ chế bảo vệ parser để cố đọc file bị lỗi.

### CSV

#### Cấu trúc

CSV là định dạng bảng trong đó các record được biểu diễn dưới dạng text và các field được phân tách bởi delimiter.

Mỗi field phải được tiếp nhận dưới dạng text ban đầu.

#### Parser requirements

- Hỗ trợ quoted fields.

- Hỗ trợ delimiter bên trong quoted fields.

- Hỗ trợ escaped double quotes theo quy ước CSV.

- Hỗ trợ xuống dòng bên trong quoted fields.

- Xử lý UTF-8 BOM.

- Xử lý line endings khác nhau.

- Không tự xóa khoảng trắng nội dung của field.

- Bảo toàn số 0 đứng trước.

#### Ví dụ

Giá trị nguồn `00123` phải được bảo toàn là text `"00123"`.

Giá trị `8,5` không tự động được diễn giải thành Decimal 8.5 khi chưa có schema/policy hoặc parser profile phù hợp.

#### Các trường hợp lỗi

- Quoted field chưa được đóng.

- Encoding không thể giải mã.

- Số field trong record không phù hợp với chính sách cấu trúc.

- Header trống hoặc trùng khi hệ thống yêu cầu unique header.

- Tệp vượt resource limits.

### TSV

TSV tương tự CSV nhưng sử dụng tab làm delimiter mặc định.

Yêu cầu:

- Bảo toàn text.

- Hỗ trợ encoding và BOM theo parser profile.

- Xử lý record boundaries rõ ràng.

- Xác định cơ chế quote và escape được hỗ trợ.

- Không tự chuyển text thành số, boolean hoặc ngày.

- Kiểm tra tính nhất quán số cột.

Các quy tắc quote/escape không được giả định giống mọi hệ thống tạo TSV; cần ghi nhận profile được sử dụng.

### JSON

#### Dạng dữ liệu dự kiến

P0 dự kiến hỗ trợ dữ liệu dạng bản ghi, ví dụ mảng các object có key là tên field.

Dạng `{headers, rows}` có thể được hỗ trợ khi adapter khai báo rõ contract và validation.

JSON nested objects/arrays không được tự động làm phẳng mà không có quy tắc mapping.

#### JSON native types

|JSON value|Physical/logical information|
|---|---|
|String|Bảo toàn kiểu chuỗi|
|Number|Bảo toàn biểu diễn số khi adapter có khả năng|
|Boolean|Bảo toàn true/false|
|Null|Phân biệt với missing property|
|Object|Cấu trúc phức hợp, không tự chuyển thành text|
|Array|Cấu trúc phức hợp, không tự chuyển thành text|

#### Ràng buộc

- Không chuyển các số chính xác cao sang `double` rồi coi kết quả đó là raw value chính xác.

- Phân biệt property không tồn tại và property có giá trị `null`.

- Phân biệt string `"123"` với JSON number `123`.

- Không tự giả định mọi JSON file là dữ liệu bảng.

- Nếu cấu trúc không được hỗ trợ, báo lỗi rõ ràng hoặc yêu cầu người dùng chọn records path khi tính năng này được triển khai.

### Adapter output

Sau khi phân tích thành công, adapter phải cung cấp dữ liệu cho tầng Input Model.

Thông tin tối thiểu cần xác định:

|Thành phần|Mô tả|
|---|---|
|Source artifact|Tài nguyên nguồn và metadata|
|Source scope|Sheet, table hoặc phạm vi được chọn|
|Fields|Danh sách cột và định danh cột|
|Rows|Các bản ghi|
|Cells|Giá trị nguồn và physical data type|
|Source references|Vị trí dữ liệu trong nguồn|
|Parse warnings|Các vấn đề không làm dừng toàn bộ import|
|Capabilities|Mức độ dữ liệu/metadata được adapter bảo toàn|

Cấu trúc chi tiết được định nghĩa trong `04_tabular_structure.md`, `05_data_types_provenance.md` và các JSON Schema tương ứng.

P0 JSON profile cụ thể của draft: UTF-8 root array of flat objects, property union theo first appearance; missing property thành kind missing. Reject duplicate object keys (không last-wins), nested object/array values và non-object records bằng 009/011 theo nguyên nhân. Root [] chưa đủ suy ra fields thì review. Records selector và dạng {headers,rows} chỉ bật khi có profile riêng đã kiểm thử, không mặc nhiên có trong P0. JSON number phải giữ token hoặc khai báo loss và chặn mode yêu cầu precision. SourceCell 0.1.0 không chứa complex JSON values.

TSV fixture/profile đề xuất dùng tab delimiter và double-quote escape; profile khác phải khai báo riêng, không đoán. Các hợp đồng raw_lexeme/null/formula/ref chi tiết chỉ định nghĩa tại [INP-005](05_data_types_provenance.md).

## 6. Luồng xử lý

### Nguyên tắc

Không xác định định dạng chỉ dựa trên tên tệp.

Các nguồn thông tin cần đối chiếu:

1. Extension của file.

2. MIME type do provider khai báo.

3. File signature hoặc magic bytes nếu có.

4. Cấu trúc nội dung thực tế.

5. Kết quả kiểm tra parser.

### XLSX

XLSX là một gói OOXML dựa trên ZIP.

Adapter phải kiểm tra sự tồn tại và tính hợp lệ của các thành phần liên quan, chẳng hạn:

- `[Content_Types].xml`.

- Workbook relationships.

- Worksheet parts.

- Shared strings nếu được tham chiếu.

- Styles và number formats khi cần diễn giải kiểu dữ liệu.

ZIP signature đơn lẻ không chứng minh nội dung là XLSX hợp lệ.

### CSV / TSV

CSV và TSV không có magic bytes cố định.

Cần xác định:

- Text encoding.

- Byte Order Mark nếu có.

- Field delimiter.

- Quote character.

- Escape convention.

- Line ending.

- Header row.

Khi có nhiều cách diễn giải hợp lệ, hệ thống cần yêu cầu xác nhận hoặc đánh dấu trường hợp chưa giải quyết.

### JSON

JSON được xác định bằng cấu trúc cú pháp và khả năng phân tích nội dung.

Hệ thống không coi một file văn bản là JSON hợp lệ chỉ vì extension là `.json`.

## 7. Edge Cases và Error Handling

Lỗi phát ra dùng [INP-007](07_validation_errors.md): unsupported 008; corrupted 009; password 010; encoding 016; ambiguous 012; limits 004; unsafe 017; capability loss 013; mismatch 007. Không duy trì bộ FORMAT_* khác trong adapter mới. XLSX protected file không được giả bảng rỗng; malformed CSV quotes không được bỏ dòng; JSON duplicate keys không được ghi đè im lặng.

## 8. Security & Privacy

Không thực thi macro, formula, active content hoặc linked resources. ZIP/XML guards áp dụng trước và trong parse; limits không chỉ tính compressed file size. Không tự sửa workbook. Với scope 1 GB/source, không load toàn workbook vào heap; adapter phải có streaming/private spill hoặc strategy được memory PoC chứng minh, budgets extraction/entries/ratio theo NFR. Không nới ZIP guards chỉ để nhận file dưới trần.

## 9. Acceptance Criteria

- INP-TC-008: Nhận diện XLSX hợp lệ thông qua cấu trúc OOXML.

- INP-TC-009: Từ chối tệp ZIP thông thường được đổi tên thành XLSX.

- INP-TC-010: CSV bảo toàn identifier `00123`.

- INP-TC-011: CSV đọc đúng quoted delimiter và multiline field.

- INP-TC-012: JSON phân biệt string, number, boolean, null và missing property.

- INP-TC-013: Parser từ chối tệp bị hỏng bằng lỗi có cấu trúc.

- INP-TC-014: Tệp vượt resource limit được từ chối an toàn.

- INP-TC-015: XLSX bảo toàn thông tin formula/cache và location khi capability tương ứng được khai báo.

- INP-TC-016: Các định dạng chưa triển khai không được hiển thị như supported.

Đây là các kiểm thử cần xây dựng, chưa phải kết quả đã xác nhận.

## 10. Open Questions

- Parser XLSX Dart nào đáp ứng được raw types, formula và provenance?

- Giới hạn kích thước tệp theo từng định dạng là bao nhiêu?

- Có hỗ trợ CSV encoding khác UTF-8 trong P0 không?

- Header row có bắt buộc tồn tại không?

- JSON records path có nằm trong P0 không?

- Có cho phép import nhiều sheet cùng lúc không?

- Có hỗ trợ TXT trong P0 như Web hiện tại không?

- Các thông tin formatting/style của XLSX có được so sánh trong P0 không?

**Document status:** DRAFT — Pending parser capability review, device testing and approval.

Theo dõi các quyết định parser/defaults trong [README](README.md#decision-register).

## 11. References

[INP-002](02_source_artifacts.md), [INP-004](04_tabular_structure.md), [INP-005](05_data_types_provenance.md), [INP-007](07_validation_errors.md), [CSV RFC 4180](https://www.rfc-editor.org/rfc/rfc4180), [JSON RFC 8259](https://www.rfc-editor.org/rfc/rfc8259).
