# Ngữ nghĩa trạng thái so sánh Dytava (Comparison State Semantics)

Trong hệ thống Dytava, việc so sánh hai tệp dữ liệu được phân định thành **4 trạng thái độc lập và loại trừ lẫn nhau**:

| Mã trạng thái | Màu sắc (HEX) | Nền phụ (Soft BG) | Tên tiếng Việt | Nhãn hiển thị | Ý nghĩa kỹ thuật |
|---|---|---|---|---|---|
| **EXACT** | `#10B981` | `#ECFDF5` | Giống hoàn toàn | `EXACT` | Hai giá trị ô trùng khớp chính xác 100% sau khi đọc thô hoặc ép kiểu cơ bản. |
| **EQUIVALENT** | `#2563EB` | `#EFF6FF` | Tương đương | `EQUIVALENT` | Hai giá trị khác biệt về mặt biểu diễn văn bản (ví dụ `01/10/2026` vs `2026-10-01`, `1.000` vs `1000`) nhưng được bộ quy tắc (Policy / Normalizer) xác nhận tương đương giá trị thực tế. |
| **DIFFERENT** | `#EF4444` | `#FEF2F2` | Khác biệt | `DIFFERENT` | Hai giá trị khác nhau rõ ràng và không thỏa mãn bất kỳ quy tắc chuẩn hóa tương đương nào. |
| **UNRESOLVED** | `#F59E0B` | `#FFFBEB` | Chưa xác định | `UNRESOLVED` | Thuật toán chưa đủ căn cứ để kết luận (ví dụ: thiếu policy, dữ liệu OCR có độ tin cậy thấp, trường khóa trùng lặp hoặc xung đột kiểu dữ liệu). Cần người dùng can thiệp thủ công. |

---

## Nguyên tắc thiết kế giao diện (UI Rules)
1. **Không gộp `UNRESOLVED` vào `DIFFERENT`:** Dữ liệu chưa xác định phải được hiển thị riêng biệt để người dùng tập trung giải quyết thủ công.
2. **Luôn đi kèm nhãn và biểu tượng:** Không bao giờ thể hiện trạng thái chỉ bằng màu sắc đơn thuần (đáp ứng tiêu chuẩn tiếp cận tiếp cận WCAG 2.1 AA).
3. **Phân tách Trạng thái so sánh và Kiểu dữ liệu (DType):** Kiểu dữ liệu (Số, Chuỗi, Ngày giờ...) có màu nhận diện riêng và không bị ghi đè bởi màu của trạng thái so sánh.
