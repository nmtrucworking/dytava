# EXCELCOMPARE | Product & Technical Documentation package

Phiên bản 1.0-DESIGN, 22/10/2026. Đây là **bộ hồ sơ thiết kế** để phát triển Android/Kotlin. Chưa có ứng dụng thực thi hay bằng chứng production certification.

## Đầu ra

- `EXCELCOMPARE_MASTER.docx` - tài liệu văn phòng tổng hợp.
- `EXCELCOMPARE_MASTER.pdf` - bản PDF cùng nội dung.
- `EXCELCOMPARE_MASTER.md` - mã nguồn nội dung để chỉnh sửa.
- `docs/` - 16 tài liệu Markdown tách theo chủ đề.
- `schemas/comparison_policy.example.json` - ví dụ policy.
- `examples/report_example.json` - mẫu output truy vết.
- `examples/acceptance_cases.json` - test cases có expected results.
- `diagrams/architecture.png` - sơ đồ.

## Thứ tự đọc đề xuất

01 Product brief -> 02 PRD -> 03 SRS -> 04 Formats -> 05 Dtypes -> 06 Contracts -> 07 Architecture -> 08 OCR -> 09 NFR -> 10 Security -> 11 Testing -> 12 DevOps -> 13 Operations -> 14 Roadmap -> 15 ADR -> 16 References.

## Cảnh báo kỹ thuật

Apache POI trên Android, các adapter XLS/ODS/XLSB và pipeline OCR bảng phải được kiểm chứng trên thiết bị thật trước khi quảng cáo support. Cloud OCR chỉ là optional và chỉ được triển khai sau khi có cơ chế consent, proxy và giới hạn ngân sách.
