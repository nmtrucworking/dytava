# 14. Lộ trình, nhân sự, chi phí và risk register

## 14.1. Lộ trình theo exit criteria (tham khảo nhóm 1-2 người, không phải lịch cam kết)

| Sprint | Phạm vi | Exit criteria |
|---|---|---|
| 0 (1 tuần) | spike POI/OOXML/CSV/JSON trên Android, dataset | quyết định adapter dựa bằng chứng PoC |
| 1 (1-2 tuần) | UI import/preview, canonical data contracts | import 2 nguồn, golden sample đúng |
| 2 (2 tuần) | mapping/key/matcher/canonicalization | core test matrix pass |
| 3 (1-2 tuần) | result detail, export, report manifest | replay deterministic, export safe |
| 4 (1-2 tuần) | error handling, file guardrails, retention, benchmark | no critical failures in defined corpus |
| 5 (1-2 tuần) | OCR local + manual review optional | OCR evaluation and clear limitation |
| 6 (tùy) | additional file adapters + cloud OCR | riêng security/cost gates |

## 14.2. Chi phí nền tảng

| Mục | Offline MVP | Cloud extension |
|---|---|---|
| Android Studio/Kotlin/Compose/Room | 0 license fee | 0 license fee |
| Phần mềm OCR ML Kit bundled | không có phí theo request | 0 khi dùng local |
| GitHub-hosted CI | phụ thuộc hạn mức plan, không giả định luôn miễn phí | tương tự |
| Backend/cloud OCR | không cần | usage based + hosting + logging + egress |
| QA thiết bị | dùng thiết bị có sẵn, opportunity cost | thêm device matrix |
| Phát hành store | phí tài khoản/phân phối tùy kênh | tương tự |

**TCO:** `development hours × internal rate + testing/device cost + CI/build + API calls × unit cost + storage + support + security/compliance`. Không gộp chi phí lao động thành 0 chỉ vì sinh viên tự làm. Thiết lập budget alert nếu kích hoạt cloud OCR; giá thực tế phải xác nhận tại lúc triển khai và theo region.

## 14.3. Risk register

| ID | Rủi ro | Probability / Impact (ước lượng) | Mitigation |
|---|---|---|---|
| R-01 | POI Android incompatibility | High / High | spike, fallback OOXML parser/event |
| R-02 | false semantic equivalence | Medium / Critical | field policy, ambiguous unresolved, gold tests |
| R-03 | large workbook OOM | High / High | streaming, page/chunk, quota |
| R-04 | OCR bad table structure | High / High | manual verification, data-quality gates |
| R-05 | XLSM active content/CSV injection | Medium / Critical | no macro execution, escape output |
| R-06 | exposing PII to cloud/log | Medium / Critical | local default, consent, minimum telemetry |
| R-07 | key duplicates/missing | High / Medium | profile, block auto-match |
| R-08 | unsupported formats overpromised | High / High | capability levels, explicit phase gates |
| R-09 | rule drift after updates | Medium / High | versioned manifest and golden corpus |
| R-10 | lack of ownership/maintenance | Medium / High | named roles, runbook, release cadence |

## 14.4. RACI gợi ý

Product owner/giảng viên chốt yêu cầu và policy nghiệp vụ; Android developer chịu UI/integration; data engineer chịu canonical model và matching; QA reviewer xác định gold truth; security reviewer phê duyệt cloud/retention trước go-live. Nếu một người kiêm nhiều vai trò, vẫn cần kiểm tra chéo độc lập cho kết luận dữ liệu quan trọng.
