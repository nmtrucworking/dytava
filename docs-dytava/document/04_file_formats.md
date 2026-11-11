# 04. Định dạng tệp, MIME, phạm vi adapter và giới hạn

## 4.1. Ma trận đầu vào (tính năng **thiết kế**, không phải hỗ trợ đã triển khai)

| Format | Pha | Parser/adapter đề xuất | Hạn chế/gate |
|---|---|---|---|
| `.xlsx` OOXML | P0 | OOXML SAX/event reader hoặc Apache POI XSSF event | thử nghiệm Android compatibility, zipbomb/size limits |
| `.csv` | P0 | Apache Commons CSV hoặc RFC 4180 parser | charset/locale/delimiter/quotes/BOM phải xác nhận |
| `.tsv` | P0 | text delimited adapter | escaping/quotes/encoding, row length |
| `.json` | P0 | kotlinx.serialization streaming JSON arrays/objects | records path selector, nested arrays not flattened silently |
| `.jsonl` / `.ndjson` | P1 | line streaming JSON decoder | lỗi 1 dòng không được nuốt, schema drift |
| `.xls` | P1 | POI HSSF/event (PoC trước khi cam kết Android) | giới hạn cũ, formula/chart/metadata |
| `.xlsm` | P1 | XLSX-compatible read only, không execute VBA | không ghi đè/không bảo toàn macro khi export |
| `.ods` | P1 | ODF/OpenDocument parser adapter | kiểm tra implementation Android, merged cells, formula semantics |
| `.xml` | P2 | secure streaming XML (StAX/SAX) + user-selected XPath-like mapping | entity expansion/XXE protection; không suy luận bảng tùy ý |
| `.html` table | P2 | Jsoup table adapter, sanitizer | row/col spans, nested tables, script ignored |
| `.xlsb` | P2 | POI XSSFB event read hoặc backend adapter | chỉ bật khi PoC có corpus và benchmark |
| `.pdf` | P2 | parser + table layout/OCR pipeline | metadata/công thức Excel **không thể** khôi phục |
| `.png/.jpg/.webp/.heic` | P2 | Android decoder + ML Kit OCR + table reconstruction | hình ảnh ≠ workbook; confidence, manual review |
| `.parquet/.arrow` | Out by default | optional desktop/server adapter | phụ thuộc native/lib, không ép vào APK cơ bản |
| `.zip` nhiều file | Out by default | explicit archive import future | nested bomb/path traversal risk |
| Google Sheets URL | Out by default | user export to XLSX/CSV, OAuth integration future | không scraping màn hình, không bắt buộc network |

## 4.2. MIME và magic bytes

Kiểm tra signature + structural integrity + MIME provider + extension; mọi bất đồng phải hiển thị. OOXML có ZIP signature nhưng vẫn phải xác nhận `[Content_Types].xml` và workbook relationships. Legacy XLS có OLE Compound File signature. CSV/TSV/JSON text không có magic cố định: xác định BOM/charset, sampling, parser validation, UTF-8 default có user override.

Không đọc 'file `.xlsx`' bằng cách tin phần mở rộng duy nhất. Không thực thi macro, công thức bên ngoài, embedded scripts hoặc external links. Không tự download linked resources.

## 4.3. Nguồn có kiểu dữ liệu khác nhau

CSV/TSV: giá trị ban đầu được coi là TEXT và kiểu mục tiêu do schema inference + policy, không xem trường `00123` thành integer nếu chưa được chấp thuận. JSON: bảo tồn JSON number/string/boolean/null và lexical representation số khi có thể. XLSX: bảo tồn raw stored type, displayed value và format code. OCR: TEXT + geometric positions + confidence (nếu available), chỉ nâng lên canonical typed sau xác nhận.

## 4.4. Output formats

- `report.json`: máy đọc, đầy đủ schema, status, provenance, rules, manifest; format chuẩn và có `schema_version`.
- `report.csv`: bảng diff phẳng, encode UTF-8 BOM tùy cấu hình, bảo vệ formula injection; metadata phức tạp báo sang JSON riêng.
- `report.xlsx`: summary sheet / differences sheet / unresolved sheet / manifest sheet; tất cả dữ liệu chưa tin cậy được ghi như **string cell**, không ghi formula executable.
- `report.pdf`: human readable tùy chọn khi đã có output template và kiểm thử layout.

## 4.5. Định nghĩa hỗ trợ theo mức

`FULL_SEMANTIC`: parser có raw type, sheet, formula và coordinate đủ cho chế độ đó; `TABULAR_VALUES_ONLY`: chỉ giá trị bảng; `OCR_REVIEW_REQUIRED`: phải xác nhận; `UNSUPPORTED`: từ chối an toàn. Một format không đồng nghĩa hỗ trợ tất cả cấp so sánh.
