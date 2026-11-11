# Dytava — Real-world Data Corpus (4 levels)

**Dữ liệu thực tế, không tạo giá trị giả.** Bộ ZIP này là **gói danh mục nguồn + công cụ tải**, không chứa 12 file dữ liệu gốc. Dữ liệu được tải trực tiếp từ các nhà cung cấp, giữ nguyên tên, nội dung và checksum. Trong môi trường tạo gói chưa thể tải các tệp nhị phân nguồn nên chưa thể xác minh thống kê worksheet/row count.

## Tải về

Điều kiện: Python 3.10+ và kết nối Internet. Không cần cài thư viện ngoài.

```bash
python download_real_data.py --group G1
python download_real_data.py --group G2
python download_real_data.py --group G3
python download_real_data.py --group G4 --include-large
# Hoặc tải tất cả (G4 được bỏ qua nếu thiếu --include-large)
python download_real_data.py --all --include-large
```

Dùng `--list` để hiển thị nguồn, `--dry-run` để xem tệp sẽ tải và `--output <path>` để đổi thư mục lưu. Nếu nguồn từ chối tải tự động, truy cập đường dẫn trực tiếp trong `source_urls.csv` hoặc trang công bố chính thức ở `dataset_manifest.json`.

## Bốn nhóm

| Nhóm | Loại | 3 file | Nguồn dữ liệu và lưu ý |
|---|---|---|---|
| G1 | Cơ bản | CSV snapshot 2025-06, 2026-05, 2026-10 | Country Codes; mã quốc gia, dữ liệu danh mục |
| G2 | Trung bình | XLSX bản 2023, 2024, 2025 | ONS England/Wales dân số; worksheet và bố cục báo cáo |
| G3 | Nâng cao | CSV snapshot 2024-11, 2026-06, 2026-11 | OWID CO2; rất nhiều cột, đổi đơn vị, sửa số liệu lịch sử |
| G4 | Cực hạn | Archive Excel 2025-10, 2025-12, 2026-01 | WDI World Bank; tải qua ZIP, kích thước hàng chục MB nén |

## Quy trình đánh giá

- Kiểm tra A/B, A/C và B/C; **không mặc định** khác năm là lỗi dữ liệu.
- Chuẩn hóa sheet/schema và khóa ghép theo quy tắc công bố, không tự động ép `00123` thành `123`.
- Những trường hợp không có đủ khóa, mapping hoặc thông tin đơn vị được phân loại `UNRESOLVED` khi phù hợp; không coi mọi tệp lỗi là `UNRESOLVED`.
- Sinh ground truth độc lập sau khi đã đối chiếu nguồn, không dùng output của engine làm truth.
- Đo riêng import success, sheet detection, row alignment Precision/Recall, difference Precision/Recall, abstention, time p50/p95, peak memory.
- Tệp trong archive G4 cần giải nén để lấy workbook Excel trước khi nhập vào ứng dụng; Dytava không mặc nhiên hỗ trợ ZIP trực tiếp.

## Liên hệ báo cáo

- 5.1.3. Bộ dữ liệu kiểm thử: mô tả 4 nhóm và provenance.
- 5.1.4. Ground Truth: tạo và kiểm duyệt nhãn.
- 5.3.1–5.3.3. EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED.
- 5.3.4. Precision, Recall, Unresolved Rate và Coverage.
- 5.4–5.5. Hiệu năng, tính ổn định và tương thích.

## Bản quyền

- G1: Repo cho biết PDDL; nguồn ISO và dữ liệu bên thứ ba có thể có hạn chế. Xem README repo.
- G2: ONS Open Government Licence v3.0, trừ khi được quy định khác.
- G3: OWID CC BY cho nội dung tự tạo, phải kiểm tra giấy phép các nguồn dữ liệu gốc.
- G4: WDI theo CC BY 4.0, có thể kèm điều khoản cho nguồn bên thứ ba.

**Không đưa các archive lớn vào Git thông thường.** Commit manifest, downloader, kết quả kiểm thử và checksum; lưu dữ liệu gốc ở kho lưu trữ riêng.
