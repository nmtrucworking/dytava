# Dytava — Kiểm thử dữ liệu thực tế

| ID | Nhóm | Cặp | Mục tiêu | Điều kiện đạt |
|---|---|---|---|---|
| REAL-01 | G1 | A-B, B-C | Ghép mã quốc gia | ISO key được bảo toàn; so chính xác theo policy |
| REAL-02 | G1 | A-C | Thay đổi tên/danh mục và null | Không tự kết luận hai country codes là một khi thiếu định danh |
| REAL-03 | G2 | A-B, B-C | Workbook nhiều worksheet | Tất cả worksheet được liệt kê; parser giữ nguyên tên, vị trí, data type |
| REAL-04 | G2 | A-C | Schema / multi-header | Đưa mapping không rõ sang review thay vì tự suy đoán |
| REAL-05 | G3 | A-B, B-C | Chỉ tiêu CO2 theo ISO+year | Khớp khóa và đơn vị trước khi so giá trị |
| REAL-06 | G3 | A-C | Unit change, schema drift | Báo schema/unit mismatch; không tự quy đổi khi thiếu policy |
| REAL-07 | G4 | A-B, B-C | Archive Excel lớn | Không crash/OOM; tiến trình có thể hủy an toàn |
| REAL-08 | G4 | A-C | Lịch sử cập nhật WDI | Trace đúng indicator, country, year và source edition |
| REAL-09 | ALL | A-B, A-C, B-C | Accuracy | Chỉ báo Precision/Recall khi ground truth đã kiểm chứng độc lập |
| REAL-10 | ALL | A-B, A-C, B-C | Reproducibility | Mỗi lần chạy lưu SHA-256, engine version, policy digest, thiết bị |

**Cảnh báo:** Các kết quả mong đợi trong bảng là hành vi/điều kiện nghiệm thu, không phải số lượng sai khác đã được đo. Ground truth chưa có sẵn ở cấp ô.
