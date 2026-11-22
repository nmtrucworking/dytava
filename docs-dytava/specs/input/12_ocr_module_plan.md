# Module OCR độc lập — trạng thái, pipeline và cổng tích hợp

Document ID: INP-012\
Version: 0.1.0 (documentation; không thay đổi wire schema)\
Status: DRAFT — PLANNED / NOT_IMPLEMENTED\
Platform: Flutter/Dart — Android trước, iOS sau\
Owner: TBD\
Updated: 22/11/2026

## 1. Mục đích và quan hệ với tài liệu khác

Tài liệu này mô tả OCR như một **module độc lập**: trạng thái hiện tại, pipeline 6 bước, ranh giới với Comparison Engine và tiêu chí kiểm thử bắt buộc trước khi tích hợp. Tài liệu không lặp lại quy tắc đã có:

| Nội dung | Nguồn sở hữu |
| --- | --- |
| Quy tắc review, giữ text gốc, không fabricate formula (INP-RULE-037–039) | [INP-010](10_ocr_image_input.md) |
| `OcrExtraction`, `OcrReviewReceipt`, image union, migration target 0.2 | [INP-011 §OCR](11_streaming_snapshot_contract.md) |
| Quyết định engine (ML Kit Text Recognition v2 bundled, Latin) | [INP-ADR-002](../../decisions/ADR_REGISTER_P0_2026-11-11.md) |
| Test INP-TC-039/040 | [INP-009](09_acceptance_tests.md) |
| Yêu cầu đọc dữ liệu từ ảnh chụp | Đề cương mục 3.2.9, [Project Description](../../project/Project%20Description.md) |

Khi mâu thuẫn, INP-010/011 giữ ngữ nghĩa dữ liệu; tài liệu này giữ kế hoạch triển khai và cổng tích hợp.

## 2. Trạng thái hiện tại (22/11/2026)

> **Module OCR độc lập đã được triển khai trong mã nguồn mobile (`lib/ocr/`) theo quy trình 6 bước, hỗ trợ tiếng Việt có dấu (NFC).** Việc tích hợp vào báo cáo hoàn thiện chính thức của dự án vẫn tuân thủ cổng kiểm thử G0–G7 bên dưới (ưu tiên hoàn thiện và kiểm thử luồng Excel/CSV trước).

| Thành phần | Trạng thái | Bằng chứng trong mã |
| --- | --- | --- |
| Nhận dạng ký tự (ML Kit v2 Latin bundled + mẫu tiếng Việt offline) | IMPLEMENTED (Module độc lập) | `lib/ocr/infrastructure/mlkit_ocr_adapter.dart` (`TextRecognitionScript.latin` hỗ trợ tiếng Việt `vi` + `SampleVietnameseOcrRecognitionAdapter`) |
| Chuẩn hóa tiếng Việt có dấu (Unicode NFC + kiểm tra bất thường dấu thanh) | IMPLEMENTED | `lib/ocr/domain/vietnamese_text.dart`, `lib/ocr/domain/latin_nfc_tables.g.dart` |
| Tiền xử lý ảnh (crop/phối cảnh 4 góc `copyRectify`, xoay 90°, tăng tương phản, ánh xạ tọa độ nghịch đảo) | IMPLEMENTED | `lib/ocr/infrastructure/ocr_image_preprocessor.dart`, `OcrGeometry` |
| Tái cấu trúc hàng, cột, ô + cảnh báo rủi ro cấu trúc | IMPLEMENTED | `lib/ocr/domain/ocr_table_reconstructor.dart` (`OcrRisk`) |
| Màn hình review OCR 3 giai đoạn (Tiền xử lý → Xác nhận lưới trước → Duyệt từng ô & cấp receipt) | IMPLEMENTED | `lib/features/workflow/screens/preview_and_ocr_view.dart`, `lib/ocr/domain/ocr_session.dart` |
| Cầu nối chuẩn hóa sang Comparison Engine (`InputSnapshot` + `CellKind.ocrText`) | IMPLEMENTED | `lib/ocr/infrastructure/ocr_capture_service.dart`, `lib/infrastructure/mobile_input_port.dart` |
| Kiểm thử đơn vị & tích hợp (OCR-TC-001..008) | IMPLEMENTED | `test/ocr/ocr_module_test.dart` |

## 3. Ưu tiên và quyết định cần cập nhật

**Ưu tiên hiện hành:** hoàn thiện và kiểm thử quy trình so sánh Excel/CSV trước. OCR phát triển tách biệt và chỉ nối vào luồng chính khi đạt toàn bộ cổng tại §7.

> **Xung đột cần xử lý:** INP-ADR-002 (11/11/2026) xếp OCR vào **Android P0**. Ưu tiên mới tương ứng với việc **hoãn OCR khỏi bản phát hành đầu tiên**. Cần một ADR sửa đổi (ví dụ `INP-ADR-002a`) ghi rõ: OCR chuyển sang giai đoạn sau, lý do, và việc xác nhận với giảng viên về mức OCR tối thiểu của đề cương 3.2.9. Cho đến khi ADR được cập nhật, tài liệu này không tự thay đổi ADR.

## 4. Ranh giới module

```text
┌──────────────────────────── OCR module (độc lập) ────────────────────────────┐
│ ImageArtifact → Preprocess → Recognize → Reconstruct → Review → Normalize   │
└──────────────────────────────────────────────────────────────┬───────────────┘
                                                               │ validated SourceTable (target 0.2)
                                                               ▼
                         Comparison Engine (không biết nguồn là ảnh hay Excel)
```

- **OCR-RULE-001:** Đầu ra duy nhất cho Core là `SourceTable` đã validate, cùng mô hình chuẩn hóa với XLSX/CSV, kèm provenance OCR theo INP-011. Comparison Engine không import code OCR, không đọc confidence, không có nhánh xử lý riêng cho ảnh.
- **OCR-RULE-002:** OCR nằm sau một port (ví dụ `OcrExtractionPort`). Khi module chưa đạt cổng, port trả capability `UNAVAILABLE`; UI không hiển thị nhập ảnh như tính năng thật. Adapter demo hiện tại chỉ được bật qua injection kiểm thử.
- **OCR-RULE-003:** Module có thể phát triển, build và kiểm thử độc lập (package hoặc thư mục riêng, test riêng, corpus riêng). Lỗi hoặc thiếu module không làm hỏng luồng Excel/CSV.

## 5. Pipeline 6 bước

| # | Bước | Đầu vào → đầu ra | Ghi nhận bắt buộc | Lỗi / dừng |
| --- | --- | --- | --- | --- |
| 1 | Ảnh chụp bảng tính / tài liệu | Camera hoặc gallery (thao tác chủ động) → `ImageArtifact` | sha256, kích thước, EXIF orientation; không gửi cloud | Vượt giới hạn pixel/decode → INP-ERR-004 |
| 2 | Tiền xử lý ảnh | Ảnh gốc → ảnh dẫn xuất: crop, xoay, tăng tương phản, hiệu chỉnh phối cảnh | Transform affine/homography **và nghịch đảo** về hệ `oriented_image_pixels`; ảnh gốc read-only | Transform không khả nghịch hoặc không hữu hạn → dừng |
| 3 | Nhận dạng ký tự (OCR) | Ảnh dẫn xuất → token/dòng text + polygon + confidence | Engine/model/version; `recognized_text` nguyên gốc; confidence `null` nếu SDK không cung cấp | Không phát hiện text → NEEDS_REVIEW, không sinh ô giả |
| 4 | Tái cấu trúc hàng, cột, ô | Token + polygon → đề xuất lưới (grid proposal) | `grid_revision`, phương pháp, chỉ số rủi ro cấu trúc (§6) | Không suy ra lưới đủ tin cậy → NEEDS_REVIEW hoặc UNSUPPORTED_LAYOUT |
| 5 | Người dùng kiểm tra và hiệu chỉnh | Lưới + text → lưới và text đã xác nhận | Xác nhận lưới trước, sau đó receipt từng ô (INP-011) | Đổi crop/lưới/text → receipt liên quan bị vô hiệu |
| 6 | Chuẩn hóa dữ liệu → Comparison Engine | Bảng đã review → `SourceTable` target 0.2 | `reviewed_text` dùng cho Core, có correction trace; kiểu dữ liệu theo policy, không theo OCR | Thiếu receipt hiện hành ở bất kỳ ô nào trong scope → chặn handoff |

Bước 2 có thể tự động đề xuất (phát hiện biên tài liệu, góc nghiêng) nhưng người dùng phải nhìn thấy và chỉnh được kết quả crop/phối cảnh trước bước 3.

## 6. Nhận dạng văn bản ≠ nhận dạng cấu trúc bảng

OCR có thể đọc đúng ký tự nhưng vẫn đặt sai hàng, cột. Hai loại lỗi này được đo và kiểm soát riêng.

- **OCR-RULE-004:** Confidence ký tự **không** được dùng làm bằng chứng cho vị trí ô. Dữ liệu OCR không được tự động coi là chính xác khi cấu trúc chưa được người dùng xác nhận.
- **OCR-RULE-005 — Xác nhận lưới trước xác nhận ô:** Người dùng xác nhận số hàng, số cột, dòng tiêu đề và vùng bảng trên overlay ảnh. Chỉ sau đó mới review từng ô. Thay đổi lưới làm vô hiệu toàn bộ receipt ô của vùng bị ảnh hưởng.
- **OCR-RULE-006 — Tín hiệu rủi ro cấu trúc:** Module tính các cảnh báo sau và đánh dấu nổi bật trên UI review. Cảnh báo chỉ giúp người dùng tập trung, **không** miễn review cho ô không có cảnh báo:
  - số ô khác nhau giữa các hàng (hàng thiếu/thừa ô);
  - token nằm cắt qua đường biên cột hoặc chồng lên hai ô;
  - một ô chứa nhiều dòng text (có thể là hai hàng bị gộp);
  - kiểu dữ liệu lệch so với phần lớn cột (ví dụ chữ trong cột số);
  - cột hoặc hàng rỗng hoàn toàn bên trong bảng;
  - nghi merged cell, đường kẻ bị mất, bảng không có đường kẻ;
  - ô rỗng: phân biệt “ô trống thật” và “không phát hiện được text” (`OCR_NO_DETECTION`, theo INP-011).
- **OCR-RULE-007:** Không lấp ô thiếu bằng nội suy hoặc giá trị hàng lân cận. Ô người dùng nhập thêm mang `correction_origin=USER_ENTERED`, không ghi như text do recognizer đọc.

## 7. Cổng tích hợp vào luồng chính

OCR chỉ được bật cho người dùng (capability `AVAILABLE`) khi **tất cả** điều kiện sau đạt, kèm bằng chứng lưu trong repo:

| Cổng | Tiêu chí | Bằng chứng |
| --- | --- | --- |
| G0 — Phụ thuộc | Luồng Excel/CSV đạt acceptance của phiên bản hiện hành | Báo cáo test Excel/CSV |
| G1 — Quyết định | ADR sửa đổi INP-ADR-002 đã chốt; mức OCR tối thiểu được giảng viên xác nhận | ADR + biên bản |
| G2 — Schema | Schema target 0.2 (IMAGE, `OcrExtraction`, `OcrReviewReceipt`) có validator và negative tests | `specs/input/schemas` + test |
| G3 — Engine PoC | Plugin pin version, chạy offline bundled trên thiết bị Android tham chiếu | Log PoC, phiên bản |
| G4 — Corpus | Bộ ảnh có ground truth độc lập (text + vị trí hàng/cột), gồm: bảng có kẻ, không kẻ, nghiêng, phối cảnh, mờ, merged cell, số có số 0 đứng đầu, tiếng Việt có dấu | `fixtures/ocr/` + oracle |
| G5 — Độ chính xác | Đo riêng **CER** (character error rate) theo ô và **tỷ lệ đặt đúng ô** (text nằm đúng hàng/cột). Ngưỡng đặt sau benchmark lần đầu và ghi vào tài liệu này; không dùng ngưỡng chưa đo | Báo cáo benchmark |
| G6 — An toàn dữ liệu | Không có đường handoff khi còn ô thiếu receipt; chỉnh crop/lưới vô hiệu receipt; không gọi mạng | INP-TC-039/040, OCR-TC dưới đây |
| G7 — Tách biệt | Tắt/gỡ module OCR, toàn bộ test Excel/CSV vẫn xanh | CI |

### Test bổ sung (planned)

| ID | Kịch bản | Kỳ vọng |
| --- | --- | --- |
| OCR-TC-001 | Text đọc đúng 100% nhưng lưới lệch một cột | Không handoff khi lưới chưa xác nhận; sau sửa lưới, receipt cũ vô hiệu |
| OCR-TC-002 | Confidence 0.99 ở mọi ô | Vẫn yêu cầu xác nhận lưới và từng ô |
| OCR-TC-003 | Hàng thiếu một ô | Cảnh báo cấu trúc; không tự dồn ô sang trái/phải |
| OCR-TC-004 | Ô không phát hiện text, người dùng nhập tay | `recognized_text=null`, `USER_ENTERED`, có polygon và receipt |
| OCR-TC-005 | Chỉnh phối cảnh rồi xoay lại | Transform nghịch đảo đưa polygon về đúng ảnh gốc; receipt cũ vô hiệu |
| OCR-TC-006 | “00123” trong ảnh | Giữ dạng text; kiểu dữ liệu do policy quyết định (INP-RULE-039) |
| OCR-TC-007 | Module OCR không có mặt (capability `UNAVAILABLE`) | UI không quảng cáo nhập ảnh; luồng Excel/CSV không đổi |
| OCR-TC-008 | So sánh bảng OCR đã review với XLSX | Core nhận `SourceTable` giống mọi nguồn khác; diff dùng `reviewed_text` |

## 8. Lộ trình đề xuất

```text
Phase 0 (hiện tại)  Excel/CSV hoàn thiện + kiểm thử; OCR = prototype UI, capability UNAVAILABLE
Phase 1             ADR sửa đổi, schema target 0.2 + validator, corpus + ground truth
Phase 2             PoC engine offline + tiền xử lý; benchmark CER riêng, chưa có lưới
Phase 3             Tái cấu trúc bảng + tín hiệu rủi ro; benchmark tỷ lệ đặt đúng ô
Phase 4             Review UX thật (overlay, xác nhận lưới, receipt) thay dữ liệu mẫu
Phase 5             Đạt G0–G7 → bật capability, cập nhật README/báo cáo trạng thái
```

Mỗi phase kết thúc bằng bằng chứng kiểm thử; không chuyển trạng thái tài liệu sang IMPLEMENTED chỉ dựa trên UI.

## 9. Ngoài phạm vi

PDF input, nhiều trang/nhiều bảng mỗi ảnh, chữ viết tay, cloud OCR, so sánh ảnh-với-ảnh, khôi phục công thức/định dạng/ô ẩn. Mở rộng các mục này cần quyết định riêng.

## 10. Open Questions

- Mức OCR tối thiểu cho đề cương 3.2.9 (chỉ cần chứng minh pipeline, hay cần đạt ngưỡng chính xác)?
- Thuật toán tái cấu trúc bảng: dựa trên đường kẻ, dựa trên phân cụm tọa độ token, hay kết hợp?
- ML Kit Latin có đủ cho tiếng Việt có dấu không — cần đo trong G4/G5 trước khi giữ lựa chọn của INP-ADR-002.
- Thiết bị Android tham chiếu và người sở hữu corpus/benchmark.
