# Nguồn artifact, metadata và vòng đời

> **ADR status 11/11/2026:** [INP-ADR-001..009 đã chốt](../../decisions/ADR_REGISTER_P0_2026-11-11.md) cho Android P0, gồm OCR có review. Các câu “OPEN”, “OCR P2” hoặc “chưa quyết định” của baseline 0.1.0 khi xung đột là lịch sử; schema và test implementation vẫn DRAFT/PLANNED.

Document ID: INP-002\
Version: 0.1.1 (documentation; wire schemas vẫn 0.1.0)\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 12/11/2026

## 1. Mục đích và phạm vi

Tài liệu đặc tả các nguồn dữ liệu được Dytava tiếp nhận, các thuộc tính của tệp đầu vào, cơ chế truy cập, vòng đời dữ liệu và những ràng buộc cần thỏa mãn trước khi chuyển sang quá trình phân tích định dạng.

Source Artifact được hiểu là một tài nguyên dữ liệu do người dùng lựa chọn để hệ thống đọc và xử lý.

## 2. Thuật ngữ và định nghĩa

Một phiên so sánh tiếp nhận hai nguồn:

|Source|Vai trò|
|---|---|
|Source A|Nguồn dữ liệu thứ nhất|
|Source B|Nguồn dữ liệu thứ hai|

Hai nguồn được quản lý độc lập về file metadata, quyền truy cập, quá trình kiểm tra và trạng thái nhập dữ liệu.

Không mặc định Source A là dữ liệu chính xác hoặc Source B là bản cập nhật khi chưa có cấu hình xác nhận.

### 2.1. Các loại nguồn

**P0 — Android**

- Local file storage.

- Android Storage Access Framework (SAF).

- Tệp từ document provider được hệ điều hành cho phép.

**P1 — iOS**

- Files application.

- iCloud Drive hoặc các file provider được hệ điều hành hỗ trợ.

- Tệp được người dùng chọn thông qua Document Picker.

**P2 — Mở rộng**

- Hình ảnh từ thư viện.

- Hình ảnh được chụp bằng camera.

- Các nguồn từ hệ thống bên ngoài, nếu được phê duyệt.

Các nguồn P2 chưa được xác nhận là tính năng đã triển khai.

## 3. Các thành phần dữ liệu

Một Input Artifact được định danh bằng `artifact_id` và liên kết với một phiên so sánh.

|Field|Data type|Bắt buộc|Mô tả|
|---|---|---|---|
|`schema_version`|String|Có|Contract version 0.1.0|
|`name_origin`|Enum provider/generated|Có|Nguồn tên hiển thị|
|`artifact_id`|String|Có|Định danh duy nhất trong phạm vi hệ thống|
|`source_side`|Enum A/B|Có|Vai trò nguồn dữ liệu|
|`file_name`|String|Có*|Tên tệp do provider cung cấp|
|`file_extension`|String?|Không|Phần mở rộng được khai báo|
|`declared_mime_type`|String?|Không|MIME type do provider trả về|
|`format`|String?|Sau preflight|Định dạng được xác định từ nội dung|
|`size_bytes`|Integer?|Khi khả dụng|Kích thước tính bằng byte|
|`sha256`|String?|Sau khi đọc thành công|Hash SHA-256 của bytes nguồn|
|`access_ref`|Opaque reference|Có khi đọc|Tham chiếu truy cập file, không phải đường dẫn công khai|
|`selected_scope`|Array<Scope>?|Sau khi chọn scope|Sheet, table hoặc range được chọn|

* Nếu provider không cung cấp tên tệp hợp lệ, hệ thống cần đặt tên hiển thị nội bộ và ghi nhận tình huống này; không được suy luận tên tệp là bằng chứng về định dạng.

Các trường nullable phải được xử lý rõ ràng, không tự thay bằng chuỗi rỗng hoặc giá trị giả.

Schema yêu cầu các khóa `format`, `size_bytes`, `sha256`, `selected_scope` kể cả khi giá trị null trong lifecycle; chỉ handoff khi đã resolve đầy đủ. `access_ref={kind, token}` là opaque token nội bộ. Trạng thái và validation issues thuộc runtime envelope, không nhúng trong InputArtifact schema. Owner của wire contract: [input_artifact.schema.json](schemas/input_artifact.schema.json).

## 4. Quy tắc và ràng buộc

### 4.1. Artifact ID

`artifact_id` định danh một tài nguyên được chọn trong hệ thống.

Không dùng `file_name` làm khóa duy nhất vì nhiều tệp có thể trùng tên.

### 4.2. SHA-256

SHA-256 được tính từ nội dung bytes của tệp khi hệ thống có quyền đọc đầy đủ.

Mục đích:

- Nhận biết cùng một nội dung tệp.

- Phát hiện thay đổi bytes giữa các lần xử lý.

- Liên kết dữ liệu đầu vào với báo cáo so sánh.

- Hỗ trợ tái lập kết quả.

SHA-256 giống nhau không chứng minh hai tệp có cùng ý nghĩa nghiệp vụ. SHA-256 cũng không phải cơ chế xác thực nguồn phát hành hoặc chữ ký số.

### 4.3. Metadata

Metadata từ provider chỉ được xem là thông tin khai báo.

Các trường như extension, MIME và dung lượng cần được đối chiếu với nội dung thực tế khi có thể.

Các invariant bắt buộc:

- Input được đọc theo nguyên tắc read-only.

- Không thay đổi bytes của nguồn.

- Không tự động đổi tên, di chuyển hoặc ghi đè nguồn.

- Không thực thi macro hoặc active content.

- Không tự truy cập tài nguyên bên ngoài được nhúng trong file.

- Không tự gửi nội dung nguồn lên server.

Nếu cần bản sao tạm để xử lý, hệ thống phải kiểm soát nơi lưu, quyền truy cập, thời gian tồn tại và cơ chế xóa.

|Rule ID|Quy tắc|
|---|---|
|INP-RULE-001|Mỗi phiên so sánh cần hai nguồn A và B hợp lệ trước khi bắt đầu comparison|
|INP-RULE-002|Không dùng tên file làm định danh duy nhất|
|INP-RULE-003|Không tin extension hoặc MIME làm bằng chứng duy nhất về định dạng|
|INP-RULE-004|Không được ghi đè nguồn trong quá trình nhập|
|INP-RULE-005|Mất quyền truy cập phải được báo thành lỗi rõ ràng|
|INP-RULE-006|File vượt giới hạn phải được từ chối an toàn|
|INP-RULE-007|Hash chỉ có giá trị xác nhận nội dung bytes đã được đọc|
|INP-RULE-008|Không ghi raw file content hoặc full URI vào telemetry|

## 5. Input / Output Contract

[Artifact schema](schemas/input_artifact.schema.json) là wire shape chuẩn. Manifest session có đúng hai artifact side A/B và artifact_id khác nhau; manifest envelope được kiểm tra bằng validator ứng dụng. `format` là định dạng đã phát hiện, không phải extension. selected_scope là danh sách scope có discriminator kind như INP-004; khả năng biểu diễn nhiều scope không chốt cardinality sản phẩm.

Source size tối đa theo [NFR §3](../../requirements/NFR.md#3-resource-profiles-và-trần-input-1-gb): 1 GB/source; metadata size unknown không phải unlimited. Hash/count theo bounded stream đến EOF, source bytes và decompressed bytes là hai counters độc lập; hai nguồn có budgets tổng RAM/scratch riêng. Profile nhỏ fixture không là cap sản phẩm.

InputSnapshot phải hash đúng bytes adapter đọc. Chỉ được reuse snapshot nếu artifact hash/config revision/parser version còn khớp; không hash một lượt rồi parse bytes đã thay ở lượt khác. Report public bỏ access_ref/token. SourceRef chỉ trỏ artifact_id và vị trí trong nguồn.

## 6. Luồng xử lý

1. Người dùng chọn vị trí Source A hoặc Source B.

2. Hệ thống mở bộ chọn tệp của nền tảng.

3. Người dùng lựa chọn tệp.

4. Hệ thống tiếp nhận tham chiếu truy cập.

5. Đọc metadata có sẵn.

6. Kiểm tra khả năng truy cập.

7. Kiểm tra dung lượng và giới hạn tài nguyên.

8. Chuyển nguồn sang bước xác định định dạng.

9. Tính hash trong quá trình đọc hoặc theo phương thức đã thiết kế.

10. Lưu manifest của artifact sau khi kiểm tra thành công.

Quy trình không được ghi đè hoặc chỉnh sửa tệp nguồn.

Các giai đoạn logic:

1. **Selected:** Đã tiếp nhận tham chiếu.

2. **Preflight:** Đang kiểm tra tính hợp lệ.

3. **Accessible:** Có thể đọc.

4. **Parsed:** Đã phân tích dữ liệu.

5. **Unavailable:** Không còn khả năng truy cập.

6. **Released:** Đã giải phóng tài nguyên.

Đây là mô tả vòng đời dữ liệu, không phải bảng chuyển trạng thái chính thức. State Machine được định nghĩa riêng trong `08_import_state_machine.md`.

## 7. Edge Cases và Error Handling

Lỗi nguồn sử dụng [registry INP-007](07_validation_errors.md) duy nhất: INP-ERR-001/002/003/004/005/006/007/015. Các tên INPUT_* trong draft cũ chỉ là alias di trú ở registry. Dung lượng provider không có dùng null; stream phải đếm bytes thực. Permission revoked hoặc bytes thay đổi invalidate snapshot/review; không silently reuse. File zero-byte khác bảng có header nhưng không có data rows.

## 8. Security & Privacy

### Android

Sử dụng cơ chế chọn tài liệu được hệ điều hành hỗ trợ.

- Chỉ truy cập tài nguyên được người dùng lựa chọn.

- Không yêu cầu quyền quản lý toàn bộ bộ nhớ nếu không cần thiết.

- Không giả định file URI luôn có quyền đọc sau khi ứng dụng khởi động lại.

- Kiểm tra lại quyền truy cập khi khôi phục phiên.

### iOS

Sử dụng Files / Document Picker thông qua plugin hoặc platform adapter phù hợp.

- Tuân thủ cơ chế sandbox.

- Không giả định đường dẫn bên ngoài sandbox có thể truy cập lâu dài.

- Kiểm tra khả năng đọc sau khi app khởi động lại.

- Kiểm thử với các file provider khác nhau.

### Access Reference

`access_ref` là tham chiếu nội bộ đến cơ chế truy cập tệp.

Không ghi trực tiếp URI nhạy cảm hoặc đường dẫn đầy đủ vào telemetry, crash logs và báo cáo công khai.

Retention và scratch policy đã chốt theo INP-ADR-009: private sandbox scratch chỉ trong attempt/session, cleanup khi success/fail/cancel/close, sweep sau process death; không lưu raw mặc định. Bản sao tạm nếu cần chỉ là derivative private; cleanup khi cancel/lỗi/kết thúc theo policy đã quyết định. Không cache raw thường trực và không có TTL 24 giờ; metadata/history chỉ tối thiểu và không chứa raw. Không giả định provider seekable; phải đóng handles cả khi provider ngắt kết nối.

## 9. Acceptance Criteria

- INP-TC-001: Hai tệp cùng tên vẫn có artifact ID riêng.

- INP-TC-002: Người dùng chọn file không hợp lệ và nhận được lỗi thích hợp.

- INP-TC-003: File bị thu hồi quyền truy cập không được âm thầm tái sử dụng.

- INP-TC-004: Bytes của file nguồn không thay đổi sau khi import.

- INP-TC-005: Hash của cùng một chuỗi bytes có tính xác định.

- INP-TC-006: Metadata không đủ không dẫn đến việc tự suy đoán định dạng.

- INP-TC-007: File vượt hạn mức được từ chối và giải phóng tài nguyên.

Các test trên là tiêu chí thiết kế, chưa phải kết quả kiểm thử đã đạt.

## 10. Open Questions

- Dung lượng tối đa của một file trên Android P0?

- Có lưu bản sao file tạm trong app sandbox không?

- Có hỗ trợ khôi phục tệp sau khi process bị hủy không?

- Khi hai nguồn có cùng SHA-256, có cho phép bỏ qua một phần so sánh không?

- Chính sách lưu trữ và xóa cache chính thức là gì?

- Có cho phép người dùng đảo vai trò Source A và Source B không?

**Document status:** DRAFT — Pending technical review and approval.

Các câu hỏi liên quan A/B, limits, parser và retention được theo dõi bằng ID trong [decision register](README.md#decision-register), không diễn giải chúng thành defaults đã phê duyệt.

## 11. References

[INP-001](01_input_scope.md), [INP-003](03_file_formats.md), [INP-008](08_import_state_machine.md), [Android SAF](https://developer.android.com/training/data-storage/shared/documents-files). Platform APIs/plugin cụ thể phải PoC; tài liệu không pin dependency chưa kiểm chứng.
