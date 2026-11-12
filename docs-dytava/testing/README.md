---
version: 0.2.0
---
# Bộ dữ liệu kiểm thử Dytava - từ cơ bản đến siêu phức tạp

>[!NOTE] Phạm vi
>So sánh hai tệp dữ liệu có cấu trúc, kiểm tra độ chính xác của `Difference Engine`, `DataType Policy Engine`, khả năng đọc nhiều định dạng, hiệu năng và độ ổn định trên Android/iOS bằng Flutter. Chưa bao gồm OCR

## Scope mở rộng và nghiệm thu

Theo [quyết định 12/11](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md), input tối đa 1 GB/source và hai PDF nằm trong P0 mở rộng. [LARGE-TC-001..008](EXPANDED_SCOPE_ACCEPTANCE.md) mô tả corpus/biên dung lượng/resources; [REP-TC-001..012](../specs/report/README.md) mô tả PDF union/template/pagination/security. Chưa có corpus 1 GB, PDF golden hoặc runtime evidence cho scope mới. Bộ real-data dưới đây giữ nguyên nguồn/hashes; không tự trở thành benchmark 1 GB.

## Thang đo 12 cấp độ

| 01-03  | 04-06      | 07-09    | 10-12   |
| ------ | ---------- | -------- | ------- |
| Cơ bản | Trung bình | Nâng cao | Cực hạn |
*Độ khó tăng theo số lượng bản ghi, số chiều dữ liệu, mức độ bất định, độ phức tạp cấu trúc, yêu cầu tài nguyên và rủi ro bảo mật - không chỉ theo dung lượng tệp*

## 1. Danh sách dataset và kịch bản kiểm thử
### Giai đoạn I - Cơ bản (Level 01-03)

