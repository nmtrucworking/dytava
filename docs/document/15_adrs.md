# 15. Architecture Decision Records và vấn đề còn mở

## ADR-001: Offline-first core

**Status:** Proposed/Accepted for design baseline. **Context:** Dữ liệu bảng có thể nhạy cảm, sinh viên muốn tránh chi phí API, cần offline. **Decision:** so sánh và normalize local; cloud không bắt buộc. **Trade-off:** performance/format limits theo thiết bị, thiếu remote management.

## ADR-002: Canonical Table Model thay vì so sánh Excel raw trực tiếp

**Decision:** mọi adapter trả `Table + Field + Row + Cell + Provenance`, nguồn excel giữ metadata cụ thể trong extension. **Consequence:** dễ hỗ trợ CSV/JSON/OCR; phải nêu rõ mất tính năng đặc thù Excel khi nguồn không chứa chúng.

## ADR-003: Policy-based semantic equivalence

**Decision:** không ép kiểu toàn cục; chỉ normalize qua field policy; ambiguous unresolved. **Consequence:** nhiều bước UI hơn, đổi lại audit được.

## ADR-004: File adapters là plugin nội bộ

**Decision:** version capability per adapter, read-only. XLS/XLSB/ODS/PDF chưa được ghi 'supported' trước khi test. **Consequence:** có thể triển khai từng pha không làm hỏng core.

## ADR-005: OCR là nguồn không đáng tin cậy cho bảng

**Decision:** manual confirm before compare, retain polygon provenance; on-device primary, cloud opt-in. **Consequence:** không so formula/meta từ ảnh, không hứa tự động 100%.

## ADR-006: Không ghi lại file nguồn

**Decision:** treat source immutable, export artifact mới qua SAF. **Consequence:** tránh mất dữ liệu và đơn giản hóa rollback.

## ADR-007: Tách same-value khỏi same-formula

**Decision:** formula-level compare là mode riêng với cached/evaluated caveat. **Consequence:** giống số nhưng khác logic vẫn hiển thị.

## ADR-008: Không coi bản thiết kế là chứng cứ đã QA production

**Decision:** mọi chỉ tiêu latency/accuracy phải có measurement report khi nghiệm thu; số ở tài liệu là targets. **Consequence:** giảm claims thiếu dữ kiện.

## Câu hỏi cần quyết định trước production

1. Mục tiêu khách hàng chính (học phần vs người dùng doanh nghiệp) là ai? 2. Thiết bị thấp nhất và giới hạn file lớn nhất? 3. Dữ liệu có thông tin cá nhân nhạy cảm hay không? 4. Định nghĩa 'giống nhau' theo mode mặc định? 5. Kịch bản xls/xlsb/ods bắt buộc hay chỉ mở rộng? 6. Có cần backend multiuser, audit immutable log, SSO không? 7. OCR có bắt buộc cloud hoặc được phép gửi dữ liệu không? 8. Báo cáo tương đương cần pháp lý/kiểm toán cấp nào? 9. Có yêu cầu giữ lịch sử nhiều năm hay chỉ local temporary? 10. Ai sở hữu quy tắc semantic và approval khi cập nhật?
