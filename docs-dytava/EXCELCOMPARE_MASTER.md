---
title: "EXCELCOMPARE — BỘ TÀI LIỆU SẢN PHẨM & KỸ THUẬT"
subtitle: "PRD • SRS • Kiến trúc • Data Types • OCR • Security • QA • DevOps • Operations"
author: "Bản thiết kế tham chiếu — Android/Kotlin"
date: "22 tháng 10 năm 2026"
lang: vi-VN
---

> **Trạng thái:** 1.0-DESIGN / Proposed baseline. Tài liệu này là đặc tả hướng production, **chưa phải** chứng nhận ứng dụng đã được triển khai, kiểm thử hoặc có hạ tầng đang vận hành.

> **Phân định:** Ràng buộc gốc: so sánh 2 file Excel, thống kê giống và khác, chỉ vị trí sai khác, đọc nội dung từ ảnh, đóng gói cài đặt. Tất cả hỗ trợ format mới, chính sách semantic, cloud OCR và vận hành là phần mở rộng được đề xuất.

## DANH MỤC TÀI LIỆU

01. Product Brief và quyết định phạm vi
02. PRD - Yêu cầu sản phẩm và hành trình người dùng
03. SRS - Chức năng và quy tắc nghiệp vụ
04. Định dạng tệp, MIME, phạm vi adapter và giới hạn
05. DataType, chuẩn hóa ngữ nghĩa và policy engine
06. Data contracts, schema và provenance
07. Thiết kế kiến trúc, module và công nghệ
08. Đặc tả OCR: API, kiểm soát lỗi và privacy
09. NFR, hiệu năng, reliability, accessibility
10. Threat model, bảo mật và quản trị dữ liệu
11. Test Strategy, test cases và quality gates
12. Build, CI/CD, phát hành và bảo trì
13. Runbook vận hành, bảo trì và xử lý sự cố
14. Lộ trình, nhân sự, chi phí và risk register
15. Architecture Decision Records và vấn đề còn mở
16. Nguồn kỹ thuật, thuật ngữ, giới hạn xác minh

**Tài liệu đi kèm:** ví dụ `comparison_policy.example.json`, `report_example.json`, `acceptance_cases.json`, sơ đồ kiến trúc và README.

# 01. Product Brief và quyết định phạm vi

**Mã dự án:** EXC; **tên làm việc:** ExcelCompare; **bản tài liệu:** 1.0-DESIGN; **ngày:** 22/10/2026; **nền tảng mục tiêu:** Android/Kotlin; **trạng thái:** baseline thiết kế, chưa chứng nhận production.

## 1.1. Tuyên bố vấn đề

Nhiều hệ thống xuất báo cáo dạng bảng tính nhưng cùng dữ liệu có thể khác tên cột, thứ tự hàng, kiểu lưu trữ, cách viết ngày/số, công thức và metadata. So sánh hai tệp bằng cách nhìn trực tiếp hoặc so từng tọa độ ô gây báo sai khác giả và bỏ sót sai khác nghiệp vụ. Ảnh chụp là nguồn đầu vào khó hơn vì chỉ giữ lại biểu diễn trực quan và không thể truy cập các thuộc tính ẩn trong workbook.

## 1.2. Giá trị sản phẩm

Ứng dụng tiếp nhận hai nguồn dạng bảng, ánh xạ schema, xác định định danh hàng, chuẩn hóa theo **quy tắc công khai**, đưa ra kết luận có thể truy vết (*exact / equivalent / different / unresolved*), xem chi tiết ô/bản ghi khác biệt và xuất báo cáo kiểm toán. Không thay đổi dữ liệu nguồn.

## 1.3. Người dùng mục tiêu và các trường hợp sử dụng

| Người dùng | Nhu cầu | Ưu tiên |
|---|---|---|
| Sinh viên/kế toán/nhân sự | So danh sách, điểm số, công nợ, kiểm kê giữa hai lần xuất | P0 |
| Nhân viên kiểm thử dữ liệu | So đầu ra của hai hệ thống sau migrate | P0 |
| Quản trị dữ liệu | Ánh xạ schema, audit, quy tắc chuẩn hóa | P1 |
| Người dùng chỉ có ảnh chụp | OCR bảng đơn giản, hiệu chỉnh rồi so | P2 |

## 1.4. In scope / out of scope

**P0 - MVP:** Android offline; import XLSX/CSV/TSV/JSON dạng bản ghi theo adapter; xem preview, chọn sheet/table, header row; mapping cột thủ công; xác định key đơn/ghép; chuẩn hóa text/decimal/date/boolean/identifier/percentage; đối chiếu record; xuất CSV/XLSX báo cáo đơn giản an toàn; lưu cấu hình và lịch sử so sánh có kiểm soát.

**P1:** XLS legacy theo proof-of-concept, xlsm chỉ đọc dữ liệu và không chạy macro, ODS adapter riêng, metadata/công thức ở chế độ báo cáo, gợi ý mapping an toàn, xử lý dữ liệu lớn streaming, quy tắc tái sử dụng.

**P2:** OCR ML Kit với xác nhận ô; cloud layout OCR opt-in; XLSB/PDF/XML/HTML/JSONL; tích hợp hệ thống ngoài; sync đa thiết bị.

**Không cam kết:** mọi công thức Excel tái tính được; suy luận đúng 100% schema/locale; khôi phục macro; ảnh OCR có metadata Excel; tự động sửa file gốc; phát hiện gian lận doanh nghiệp chỉ bằng sự khác biệt.

## 1.5. Chỉ số thành công và ranh giới trách nhiệm

| Nhóm | Chỉ số đề xuất (chưa đo) | Điều kiện nghiệm thu |
|---|---|---|
| An toàn dữ liệu | 0 lần ghi vào nguồn; 0 nội dung ô trong telemetry | kiểm thử có chứng cứ |
| Độ đúng | 100% các quy tắc chuẩn hóa có unit test và golden fixture | không tự tương đương khi ambiguous |
| Truy vết | 100% difference có source coordinate + rule version hoặc lý do missing | review report |
| Ổn định | Không crash/OOM trên bộ stress đã chốt cho thiết bị tham chiếu | benchmark thực nghiệm |
| Định lượng | Có precision, recall, unresolved rate, elapsed time, peak memory | công bố số đo kèm dữ liệu và cấu hình |

**Quyết định sản phẩm:** ‘production-grade specification’ khác ‘production-qualified product’. Các SLO sẽ chỉ được cam kết sau khi đo trên thiết bị và corpus thực tế.


# 02. PRD - Yêu cầu sản phẩm và hành trình người dùng

## 2.1. Jobs-to-be-done

Khi nhận hai bản báo cáo từ nguồn khác nhau, người dùng muốn thấy bản ghi nào thiếu/thừa/thay đổi, tránh báo sai do định dạng khác nhau, biết căn cứ của kết luận và xuất được biên bản có thể xác minh lại.

## 2.2. User stories (ưu tiên MoSCoW)

| ID | User story / tiêu chí chấp nhận | Mức |
|---|---|---|
| US-01 | Chọn hai tệp bằng Android SAF; hiển thị tên, hash, dung lượng, cảnh báo nguồn | Must |
| US-02 | Tự nhận định dạng qua signature/MIME/content, không tin đuôi file | Must |
| US-03 | Preview 50-100 hàng đầu, lọc sheet/table, chọn hàng header | Must |
| US-04 | Mapping cột A:B, xác nhận cột khóa, cảnh báo key duplicate/null | Must |
| US-05 | Phân loại EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED và ghi lý do | Must |
| US-06 | Bật/tắt chuẩn hóa từng field; xem giá trị raw/typed/normalized | Must |
| US-07 | Xem summary + filter + chi tiết tọa độ ô hai phía | Must |
| US-08 | Xuất report có dữ liệu kiểm toán, không làm thay đổi nguồn | Must |
| US-09 | Hủy an toàn và khôi phục session sau lỗi/đứt tác vụ | Should |
| US-10 | So sánh công thức, style, metadata theo tùy chọn | Should |
| US-11 | OCR ảnh bảng → hiệu chỉnh preview → xác nhận rồi so | Could |
| US-12 | Đề xuất map bằng heuristics, nhưng buộc xác nhận khi mơ hồ | Could |

## 2.3. User flow

1. Dashboard → 'So sánh mới'. 2. Chọn A, B (SAF). 3. Preflight: file hợp lệ, dung lượng, quyền, bảo vệ bằng mật khẩu. 4. Chọn sheet/table + header. 5. Mapping fields + key + loại so. 6. Chọn policy datatype/locale/tolerance. 7. Review cấu hình. 8. Job tiến độ/phân trang + hủy. 9. Báo cáo 4 trạng thái & structural differences. 10. Export/Share/Delete session.

## 2.4. Các màn hình

| Screen | Dữ liệu/chức năng | Edge UX |
|---|---|---|
| Home | lịch sử gần đây, tạo phiên, quyền riêng tư | empty state |
| Import | 2 nguồn, kiểm tra khả năng đọc, nguồn truy cập | permission revoked/unsupported |
| Sheet Preview | grid ảo hóa, dropdown sheet, header preview | rất nhiều cột/cell merge |
| Mapping | schema A/B, confidence gợi ý, key selector | duplicate, missing, ambiguous |
| Policy | datatype ngữ nghĩa, locale, null, tolerance, alias | chỉ đổi policy có version mới |
| Compare | thanh tiến độ, số bản ghi, cancel, error | app background/process death |
| Results | dashboard summary, tabs rows/fields/values/meta | zero diff vs unresolved |
| Difference Detail | A/B raw typed canonical, location, rule, explanation | OCR thiếu tin cậy |
| Export | CSV/XLSX/JSON, anonymize, location SAF | CSV injection |
| OCR Confirm | hình gốc + overlay bounding boxes + editable grid | mất cột/ô gộp |

## 2.5. Các nguyên tắc UX bắt buộc

- Không dùng màu duy nhất để truyền trạng thái; có biểu tượng/chữ.
- Hiển thị rõ `không thể kết luận` khác `không khác`.
- Khi dự đoán mapping hoặc datatype, công bố confidence, cho sửa và xem trước tác động.
- Chỉ tệp do người dùng chọn được đọc; không yêu cầu quyền quản lý toàn bộ bộ nhớ.
- Không quảng cáo '100% chính xác' cho OCR hay semantic inference.


# 03. SRS - Chức năng và quy tắc nghiệp vụ

## 3.1. Ma trận chức năng

| ID | Requirement | Logic, đầu ra và tiêu chí chấp nhận |
|---|---|---|
| FR-001 | Import & detect format | content sniffing, extension chỉ gợi ý; báo mismatch, không thực thi active content |
| FR-002 | Select source scope | workbook/sheet/range hoặc table; nguồn text 1 bảng mặc định |
| FR-003 | Extract provenance | giá trị nguồn, kiểu, display text, formula, original coordinate |
| FR-004 | Profile fields | null rate, inferred dtype, distinct, sample, collision warning |
| FR-005 | Align schema | mapping 1:1 mặc định, mapping 1:n là biến đổi rõ ràng; ghi config |
| FR-006 | Key match | unique key / composite key; duplicate được đưa vào tập lỗi |
| FR-007 | Compare records | row added/removed/updated, move chỉ là thay đổi vị trí |
| FR-008 | Exact compare | so typed raw theo chính sách; phân biệt blank/null/zero |
| FR-009 | Semantic compare | canonicalize theo field rule; xuất evidence transform |
| FR-010 | Compare formulas | so expression, cached values, annotate stale/unsupported |
| FR-011 | Compare metadata | report metadata tách riêng, không trộn cell similarity |
| FR-012 | OCR import | text + geometry; tái dựng table; bắt buộc manual confirmation |
| FR-013 | Export report | summary, detailed diff, manifest, policy/version, unresolved |
| FR-014 | Re-run | cùng input hash + config + engine version phải cho output deterministic |
| FR-015 | Lifecycle | cancellation, retry theo job state, cleanup temp |

## 3.2. Kế toán số lượng và thống kê

Các trạng thái chính **loại trừ nhau** ở đơn vị so sánh 'matched cell pair': `EXACT`, `EQUIVALENT`, `DIFFERENT`, `UNRESOLVED`. `TYPE_CHANGED`, `FORMULA_CHANGED`, `STYLE_CHANGED`, `OCR_REVIEWED` là flags độc lập.

`exact_rate = exact_pairs / compared_matched_pairs`. `semantic_agreement_rate = (exact + equivalent) / compared_matched_pairs`; mẫu số gồm unresolved để không làm đẹp chỉ số. Bản ghi và cột unmatched báo độc lập; tổng kết không cộng trộn đơn vị khác nhau (cells + rows + sheets).

## 3.3. Phân loại sai khác và precedence

| Mã | Định nghĩa | Xử lý |
|---|---|---|
| SHEET_ADDED / REMOVED | Sheet chỉ ở một file | structural diff |
| FIELD_ADDED / REMOVED | Cột chưa map | schema diff |
| KEY_DUPLICATE | khóa không duy nhất | unresolved alignment, không gán tùy tiện |
| ROW_ADDED / REMOVED | Không có matched key | record diff |
| VALUE_CHANGED | hai canonical typed values không bằng | substantive diff |
| TYPE_CHANGED | raw storage type thay đổi | flag, có thể semantic match |
| EQUIVALENT_REPRESENTATION | raw khác nhưng canonical bằng | equivalent + rule id |
| NULL_MISMATCH | blank/null/empty/zero khác policy | diff hoặc unresolved |
| FORMULA_CHANGED | biểu thức công thức thay đổi | flag tùy mode |
| METADATA_CHANGED | document metadata khác | metadata report riêng |
| OCR_UNCERTAIN | OCR chưa được xác nhận hoặc vùng tin cậy thấp | unresolved, không tự xác nhận |

## 3.4. Matching modes

1. **POSITION:** đồng vị trí hàng/cột; hữu ích khi cấu trúc cố định, không dùng để suy luận 'row changed' khi thứ tự đảo.
2. **KEY:** join theo khóa đơn/ghép đã canonicalize bằng **quy tắc định danh nghiêm ngặt**, không dùng approximate string similarity để nối tự động.
3. **MULTISET:** không có key; đối chiếu theo multiset của dấu vân tay bản ghi; báo unpaired rows và duplicate counts, không suy diễn record identity.
4. **ORDERED_SEQUENCE:** so theo thứ tự để phát hiện chèn/xóa; dùng diff algorithm có giới hạn hiệu năng, không áp dụng mặc định.

## 3.5. Invariants

- Không sửa workbook nguồn trong bất kỳ giai đoạn nào.
- Kết luận `EQUIVALENT` phải có `rule_id` và canonical values, không chỉ là similarity score.
- Bất kỳ parse/mapping/locale ambiguity trọng yếu đều trở thành `UNRESOLVED` hoặc phải được người dùng xác nhận.
- Mỗi difference có 2 provenance paths, hoặc `null` có lý do rõ (row/file missing).
- Không so sánh numeric mã định danh chỉ vì trông giống số.


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


# 05. DataType, chuẩn hóa ngữ nghĩa và policy engine

## 5.1. Các tầng type

1. **Physical/storage dtype:** OOXML `s/n/b/e/inlineStr`, JSON native type, CSV textual, formula cell, OCR text.
2. **Logical dtype:** `string`, `int64`, `decimal`, `date`, `datetime`, `bool`, `null`, `array`, `object`.
3. **Semantic dtype:** `identifier`, `person_name`, `currency`, `percentage`, `unit_quantity`, `postal_code`, `phone`, `email`, `timezone_datetime`, `enum`.
4. **Normalization profile:** locale, timezone, trim, Unicode normalization, case, allowed aliases, numeric rounding/tolerance, null sentinels.

**Không** áp dụng một bộ cast toàn cục. Dtype inference chỉ là suggestion; policy xác nhận quyết định.

## 5.2. Bảng chiến lược

| Semantic dtype | Canonical | Quy tắc / cảnh báo |
|---|---|---|
| identifier | Unicode NFC string | preserve leading zeros, case theo field, no numeric cast |
| free_text | NFC string | trim outer whitespace optional; không bỏ dấu mặc định |
| person_name | NFC string | trim/multiple whitespace optional; bỏ dấu chỉ gợi ý, không tự match |
| integer | arbitrary precision integer | parse locale; decimal fraction không tự truncate |
| decimal | `BigDecimal` + scale policy | dấu thập phân locale, no binary float equality |
| money | ISO currency + BigDecimal | không so nếu đơn vị tiền khác mà thiếu FX/cùng thời điểm |
| percentage | dimensionless decimal | `'10%' → 0.10` chỉ khi field có `%` semantics |
| boolean | enum {true,false,null} | alias dictionary field-specific (Có/Không/1/0) |
| date | `LocalDate` ISO | định dạng input và Excel 1900/1904 date system |
| datetime | `Instant` hoặc local datetime tagged zone | không bỏ timezone; DST ambiguity unresolved |
| phone | E.164 **nếu** có region rule | giữ string gốc; mã vùng/ngữ cảnh thiếu unresolved |
| email | string domain normalization policy | local part case policy; không tự lowercase toàn bộ |
| enum | stable code | dictionary versioned, many-to-one mappings review |
| unit_quantity | value + UCUM-like unit | quy đổi chỉ khi loại đại lượng tương thích |
| blank/null/empty | tagged union | 0 ≠ null; Excel empty string ≠ missing by default |

## 5.3. Các ca nguy hiểm

- `00123` vs `123` là **DIFFERENT** nếu field là mã, mặc dù parse numeric bằng nhau.
- `1,234` không có locale là **UNRESOLVED**; theo en-US là 1234, vi-VN có thể là 1.234.
- `0.1` vs `10%` chỉ EQUIVALENT nếu field là tỷ lệ và representation scale đã định.
- `2026-03-01T00:30+07:00` vs `2026-02-28T17:30Z` có cùng instant, nhưng khác local calendar day; profile quyết định.
- `TRUE` vs `1` chỉ EQUIVALENT nếu boolean mapping được cho phép.
- `8.5` vs `8,5` chỉ so Decimal tương đương khi quy tắc decimal separator tường minh.
- `Nguyen An` vs `Nguyễn An` không tự coi bằng nếu họ tên pháp lý, vì khác ký tự.
- BigDecimal `0.300` vs `0.3`: bằng theo giá trị nếu policy ignore scale, khác theo biểu diễn nếu strict formatting mode.
- `null`, missing cell, blank, empty string, `N/A` và zero là những trạng thái khác nhau trừ khi null mapping cụ thể.

## 5.4. Pipeline canonicalization

`RawCell -> Detect original_type -> Validate field policy -> Parse with locale -> Normalize typed value -> Attach transformation trace -> Compare`; mọi lỗi parse trả `UNRESOLVED + reason_code`. Không dùng `Double` để so tiền.

## 5.5. Matching và độ đúng

- Align field thủ công, tên giống/gần nhau là gợi ý chứ không phải sự thật.
- Key matching dùng strict canonical identifier; duplicate key tạo bucket unresolved thay vì chọn hàng ngẫu nhiên.
- Compound key đóng gói có length prefix hoặc typed tuple để tránh collision (`('ab','c')` khác `('a','bc')`).
- Stable hash (SHA-256) dùng tối ưu tra cứu; **hash match không đủ** để đồng nhất typed semantics khi serializer/rule khác phiên bản.
- Exactness ưu tiên hơn fuzzy matching; fuzzy scores chỉ cho ứng viên review.

## 5.6. Thuật toán quy mô lớn

Xây map `key -> row reference` với streamed chunks khi có unique key, so typed normalized cells khi match. Khi RAM thấp, phân vùng theo stable hash xuống encrypted temporary storage và sort-merge, hoặc embedded SQLite index + disk. Độ phức tạp trung bình cho hash-join là O(n+m), memory O(min(n,m)) nếu map một phía; sort-merge O(n log n + m log m) nếu chưa sắp xếp. Yêu cầu thực nghiệm tránh khẳng định thời gian cố định.


# 06. Data contracts, schema và provenance

## 6.1. Entities

| Entity | Các trường trọng yếu | Ý nghĩa / constraint |
|---|---|---|
| `ComparisonSession` | id, created_at, engine_version, status, policy_digest | lineage và trạng thái |
| `InputArtifact` | id, uri_hint, file_name, detected_format, sha256, size, selected_scope | không lưu URI public vô thời hạn |
| `SourceTable` | id, artifact_id, sheet_name, row_count, column_count, header_row | phạm vi xử lý |
| `SourceCell` | table_id, row, col, raw_type, raw_value, display, formula | không ghi log/telemetry |
| `FieldMapping` | source_field_a/b, semantic_type, normalization_policy | 1-to-1 mặc định |
| `RecordPair` | key, row_ref_a, row_ref_b, match_mode, status | unique/reference |
| `Difference` | id, category, severity, field, refs, raw/normalized, rule_id, reason | audit trail |
| `OCRToken` | text, polygon, source_image, confidence_optional | geometry và review |
| `ReportManifest` | schema_version, source_hashes, policy_digest, engine, counts | reproducibility |

## 6.2. Versioning

- Dùng SemVer với **engine** và **report schema** độc lập (`engine=1.0.0`, `schema=1`).
- Stable canonical serialization: field order deterministic, UTC timestamps với nguồn timezone, decimal canonical string.
- `policy_digest = SHA-256(canonical_policy_json)`; report kết quả phải chứa snapshot policy hoặc reference kèm hash.
- `source_sha256` chỉ nhằm chứng minh cùng byte tệp, không khẳng định nội dung nghiệp vụ giống nhau.
- Room migrations forward-only, backup/restore có sơ đồ rõ; không xóa database sản phẩm khi migration thất bại.

## 6.3. Output JSON contract

`ComparisonReport` có `source_a`, `source_b`, `mapping`, `policy`, `summary`, `schema_differences`, `record_differences`, `cell_differences`, `unresolved`, `warnings`, `generated_at`. Cả `source_location` và `comparison_location` phải có; tọa độ OCR là pixel polygon thay vì địa chỉ ô Excel gốc.

## 6.4. Referential integrity

`Difference` tham chiếu tới `RecordPair` khi có match; `source_ref` dạng discriminated union `{type:excel, sheet, address}` / `{type:csv, line, field}` / `{type:json, pointer}` / `{type:ocr, page, polygon}`. Không giả lập `Sheet1!A1` cho dữ liệu vốn là JSON/PDF.

## 6.5. Các trường tuyệt đối không ghi telemetry

Nội dung cell raw/canonical, tên cá nhân, danh sách định danh, full path file, file URI, ảnh OCR gốc, access tokens, ảnh bảng. Cho phép metric tổng hợp như `duration_ms`, `format_type`, `row_count_bucket`, `error_code` với consent và chống tái nhận diện.


# 07. Thiết kế kiến trúc, module và công nghệ

## 7.1. Kiến trúc baseline

**Android-first offline-first**, Clean Architecture / ports-adapters đơn giản: Presentation (Compose + ViewModel) → Domain (UseCases + policies) → Data (Adapters + repositories + Room). Không đặt logic normalize vào UI; engine là Kotlin/JVM thuần để có thể chạy unit test không Android và tái sử dụng trên server/desktop tương lai.

![Sơ đồ kiến trúc](/mnt/data/excelcompare_pd/diagrams/architecture.png)

## 7.2. Module/repository layout

```text
excelcompare/
  app/                    # Android manifest, Compose navigation, DI
  core/model/             # immutable canonical domain types
  core/compare/           # matching, normalization, diff, explanations
  core/policy/            # policy validator, parser profiles, versions
  core/storage/           # local cache, Room, lifecycle
  feature/import/         # picker, sniffer, preview
  feature/mapping/        # field/key mapping UX
  feature/results/        # report query and filters
  feature/ocr/            # optional on-device OCR + review
  adapter/xlsx/           # streaming OOXML read adapter
  adapter/delimited/      # CSV/TSV import/export
  adapter/json/           # JSON/JSONL table adapter
  adapter/legacy-xls/     # optional, after Android proof of concept
  adapter/ods/            # optional independent parser
  export/report/          # report JSON/CSV/XLSX
  benchmark/              # device benchmarks and fuzz corpus
  docs/                   # ADRs, policies, operational runbooks
```

## 7.3. Công nghệ và vai trò - dùng phiên bản qua version catalog khóa tại thời điểm bắt đầu triển khai

| Lớp | Công nghệ | Vai trò / quyết định |
|---|---|---|
| Language/Build | Kotlin, Android Gradle Plugin, Gradle Kotlin DSL, JDK theo AGP | compile, tests, build; pin versions sau compatibility test |
| UI | Jetpack Compose, Material 3, Navigation | màn hình responsive; StateFlow one-way flow |
| Architecture | ViewModel, Coroutines, Flow, Hilt hoặc Koin (chọn một) | job/state/dependency injection |
| Local metadata | Room; Proto DataStore | sessions, policy, diff index và setting |
| Import | Android Storage Access Framework / ContentResolver | scoped read input, no broad storage permission |
| XLSX | Apache POI event API nếu chạy được trên Android; thay thế: OOXML SAX secure custom adapter | tránh memory bloat; require device PoC |
| CSV | Apache Commons CSV hoặc parser RFC4180 | deterministic delim/escaping |
| JSON | kotlinx.serialization / streaming JsonReader | JSON arrays + JSONL |
| OCR | Google ML Kit Text Recognition v2 bundled | on-device tiếng Việt; layout reconstruct riêng |
| Layout OCR Cloud | Azure Document Intelligence `prebuilt-layout` hoặc Google Document AI | optional service side, opt-in consent + proxy |
| Imaging | Android Bitmap/ExifInterface; OpenCV optional | crop, rotate, deskew; no AI training mandatory |
| Security | Android Keystore, encrypted application storage based on threat model | secrets/at rest; network TLS for optional API |
| Observability | structured local logs without PII; optional crash service with consent | non-sensitive telemetry, error aggregation |
| QA | JUnit, Kotest optional, instrumented tests, Compose UI tests, Macrobenchmark | correctness/perf/regr |
| CI/CD | GitHub Actions/Gradle, dependency checks, lint, SBOM, Android signing | controlled releases |

**Important integration risk:** Apache POI là thư viện Java, không thể mặc định mọi artifact XSSF/HSSF chạy ổn định trên mọi Android API/ABI. Cần PoC kiểm chứng minSdk, DEX footprint, dependency conflict, font APIs, memory, reads thực tế. Không ép POI usermodel vào RAM mobile cho workbook lớn.

## 7.4. Dependency rules

`app -> feature -> domain interfaces <- adapters`; domain không import `android.*`, `org.apache.poi.*`, OCR SDK hoặc `androidx.room.*`. Format adapters tuân thủ `TableReader` contract: `sniff, inspect, open(scope), rows(): Flow<Row>, close`, versioned capabilities, cancel-friendly.

## 7.5. Policy update impact

Chỉnh locale/key/mapping có thể làm thay đổi toàn bộ kết quả, do đó phải invalidating diff cache, tăng `config_revision`, lưu prior report for history nhưng không giả là cùng phiên so sánh.


# 08. Đặc tả OCR: API, kiểm soát lỗi và privacy

## 8.1. Chế độ OCR

**Local default:** ML Kit v2 Text Recognition (script Latin, hỗ trợ tiếng Việt), chạy on-device. Trả text + geometry; **không đảm bảo table cell structure**. ML Kit bundled tránh tải mô hình lúc chạy, APK tăng dung lượng; unbundled giảm APK nhưng phải chuẩn bị download model.

**Cloud option:** Document AI/Layout APIs trả table structure đối với input hỗ trợ; nhưng vẫn có lỗi OCR, hạn mức/trả phí, yêu cầu internet và vấn đề chuyển dữ liệu cho bên thứ ba. Dùng backend proxy có quota/budget/expiry/auth; KHÔNG nhúng cloud secret trong APK.

## 8.2. OCR workflow

1. Chọn ảnh → rotate EXIF/crop/perspective/deskew/contrast (giữ original bất biến). 2. OCR text blocks. 3. Tái dựng bảng: line grouping Y; tìm cột bằng geometry + table borders + grid consistency; xử lý merged cell bằng flag uncertainty. 4. Preview editable grid đối chiếu overlay ảnh. 5. Manual confirmation. 6. Infer datatype / mapping; không cho OCR bỏ qua xác nhận ở field khóa hoặc số tiền. 7. Compare và annotate source reference `image/page/polygon`.

## 8.3. Giới hạn kỹ thuật không được che giấu

- Ảnh không chứa workbook metadata, công thức chưa hiển thị, font structural internals, hidden sheet/row, original logical type.
- ML Kit không tự xác định merged cells/headers; bảng nghiêng/chồng lớp/không lưới có thể không phục hồi được.
- OCR probability/confidence: không phải provider nào cũng trả confidence per cell; không được lấy `confidence=1` làm mặc định.
- Không tự đưa OCR text qua AI cloud nếu chưa có opt-in và minh bạch nơi lưu trú dữ liệu.

## 8.4. Metrics OCR

- `CER/WER` kiểm thử nhận dạng ký tự/từ; `cell_exact_accuracy` sau reconstruction; `table_structure_F1` khi có ground truth bounding boxes; `critical_field_error_rate` cho key/money/date; `manual_review_time`; `end_to_end_difference_precision_recall`.
- Bộ kiểm thử tối thiểu đề xuất: nhiều loại ảnh, ánh sáng, lóa, độ nghiêng, số lượng cột, tiếng Việt, ngày/số, merged cells; giá trị chấp nhận phải suy ra từ pilot không tự tuyên bố trước.

## 8.5. API contract cloud optional

`POST /v1/ocr/jobs` nhận ảnh encrypted transit, metadata consent/idempotency; trả `job_id` và TTL. `GET /v1/ocr/jobs/{id}` trả PENDING/PROCESSING/REVIEW_REQUIRED/FAILED, token coords, table geometry, result schema. `DELETE /v1/ocr/jobs/{id}` xóa nội dung theo retention. Hạn mức per-user + max page/byte + backoff, timeout, circuit breaker, tenant isolation. Không cung cấp chức năng này trong offline-only build.


# 09. NFR, hiệu năng, reliability, accessibility

## 9.1. NFR catalogue

| ID | Tiêu chí | Mục tiêu ban đầu để thử nghiệm, không phải đo đạt |
|---|---|---|
| NFR-PERF-01 | Preview file vừa | Hiển thị preview đầu tiên ≤ 3s cho corpus nhỏ trên thiết bị benchmark |
| NFR-PERF-02 | So sánh 50.000 record × 15 cột | Không OOM, có progress/cancel; latency xác định sau benchmark |
| NFR-PERF-03 | Memory | Không vượt ngưỡng heap cho thiết bị 4GB/6GB RAM đã chọn; streaming |
| NFR-REL-01 | Crash-free | ≥ 99.5% phiên theo telemetry được đồng ý, sau pilot |
| NFR-REL-02 | Cancel | Không tạo report hoàn tất một phần; cleanup temp idempotent |
| NFR-SEC-01 | Source immutability | 0 write operations to original URIs |
| NFR-SEC-02 | Information disclosure | Không raw cell data trong logs, crash, cloud mặc định |
| NFR-COR-01 | Determinism | Input hashes + engine/policy version giống → report semantic giống |
| NFR-COR-02 | Explainability | 100% semantic equivalence có rule trace |
| NFR-UX-01 | Accessibility | font scaling, screen readers, contrast, non-color indicators |
| NFR-OPS-01 | Offline | core comparison chạy airplane mode |

## 9.2. Các ràng buộc Android

- minSdk/targetSdk chốt khi build sau kiểm tra chính sách Play và thư viện; không tự đoán tại thời điểm đặc tả.
- Android lifecycle: process death, low-memory, SAF URI permission revoked; tác vụ dài phải có checkpoint/resume hoặc restart an toàn, foreground processing only nếu Android requirements phù hợp.
- Job design theo scope: synchronous lightweight preview; long comparison scheduled/cancellable, status persisted; hạn chế giữ bitmaps/workbook trong heap.
- Grid ảo hóa + pagination result query tránh render hàng triệu ô trong Compose.

## 9.3. Resource guardrails do nhóm đặt rồi benchmark

- Giới hạn kích thước file theo tier thiết bị, số sheet/cell, số ZIP entries, decompressed size, số shared strings.
- Preflight estimate row/cell count; thông báo khi vượt giới hạn, gợi ý chỉ chọn sheet hoặc sampling.
- Quotas cấu hình cục bộ, không được tùy tiện tắt zip-bomb checks để đọc file 'khó'.

## 9.4. Khả năng mở rộng theo platform

Core engine Kotlin/JVM không lệ thuộc UI cho desktop/server; parser cần tách đa nền tảng. Nếu dữ liệu doanh nghiệp lớn, một backend batch processor có thể triển khai sau khi xác lập privacy/compliance và chi phí vận hành, không phải giả định MVP phải dùng cloud.


# 10. Threat model, bảo mật và quản trị dữ liệu

## 10.1. Tài sản cần bảo vệ

Bảng điểm/danh sách nhân sự, mã khách hàng, dữ liệu kế toán, ảnh chụp, policy và report, phiên so sánh. Input tệp được xem là **untrusted content** ngay cả khi người dùng chọn trực tiếp.

## 10.2. Threat model (STRIDE rút gọn)

| Rủi ro | Biện pháp |
|---|---|
| Zip bomb/OOXML oversize | giới hạn extract/entry count/compression ratio, parse streaming, fail closed |
| XML entity expansion/XXE | secure parser, disable external DTD/entities, no outbound references |
| Spreadsheet formula injection lúc export | mọi user-controlled raw text viết thành string cell và escape CSV, test bằng Excel/LibreOffice |
| Macro/external link execution | read-only, never run VBA/active content; no external formula resolution |
| Lộ file trên máy | SAF user grant, app-internal private cache, TTL, no world-readable exports |
| Lộ thông tin qua logs/crash | redact by design, telemetry opt-in, aggregate-only metrics |
| API key leak | none in APK, server-side secret manager (nếu bật cloud) |
| Man-in-the-middle | TLS, standard cert validation, no trust-all certificates |
| Cloud vendor disclosure | explicit consent, visible recipient/purpose, retention control, data minimization |
| Report tampering | manifest hash/signature optional; compare hash before audit |
| Stale cache/confusing old report | bind input sha, config revision, engine/report version |
| Local DB sensitive data at rest | Room is not encryption by default; assess SQLCipher/Keystore-backed protection or no raw data persistence |

## 10.3. Privacy by design

Default không gửi file lên server; không yêu cầu danh bạ, vị trí, quyền quản lý mọi file, không thu thập raw dữ liệu cho phân tích. Xóa tệp tạm sau session hoặc thời gian ngắn được cấu hình; cho người dùng xóa toàn bộ lịch sử. Export public phải do người dùng chủ động chọn nơi lưu.

**Chính sách lưu trữ baseline:** Original copy tạm xóa khi hoàn tất hoặc 24 giờ nếu người dùng cần tiếp tục; parsed content và report cached lưu chỉ khi opt-in, mặc định tối thiểu; chỉ số tổng hợp có thể giữ 30 ngày. Đây là đề xuất sản phẩm, phải được thực hiện và công bố rõ, không phải một cam kết hiện có.

## 10.4. Security testing gates

SAST/dependency audit, SBOM, malformed workbook fuzzing, zipbomb tests, CSV injection tests, URI lifecycle tests, Android backup inspection, logs inspection, MASVS storage/platform/privacy checks, cloud key exposure tests nếu có cloud.

## 10.5. Tuân thủ và pháp lý

Đánh giá quy định bảo vệ dữ liệu áp dụng theo thị trường triển khai trước khi xử lý tài liệu có dữ liệu cá nhân và trước khi truyền cloud. Không tuyên bố ISO/SOC2/GDPR/VN-law compliance nếu chưa có đánh giá, bằng chứng và quy trình tương ứng.


# 11. Test Strategy, test cases và quality gates

## 11.1. Phương pháp kiểm thử

- Unit: policy parser/canonicalizer/compare state, unicode/timezone/locale, duplicate keys.
- Property-based: symmetry `compare(a,b)` tương thích đảo A/B, determinism, idempotent normalization; điều kiện tiên quyết rõ.
- Golden fixtures: cùng dataset đã biết mọi diff; so report JSON normalized bỏ timestamps.
- Metamorphic: đảo thứ tự hàng **không** thay đổi semantic results ở key-mode; đổi style **không** ảnh hưởng content result.
- Integration: adapters XLSX/CSV/JSON, file corrupt, password protected, 1900/1904 dates.
- Instrumentation: SAF, permissions, process death/restart, storage low, sharing/export.
- Performance: corpus nhiều hàng/cột/sharedStrings, timing distributions p50/p95, max RSS/heap, cold/hot run.
- Security: Excel injection, zipbomb, XML entity, fuzz corpus, malicious formulas, privacy logs.
- OCR: CER, table reconstruction, manual review workflow, same screenshot vs original.

## 11.2. Các test case ưu tiên

| ID | Dữ liệu A | Dữ liệu B | Kỳ vọng |
|---|---|---|---|
| TC-01 | 8.5 numeric | '8,5' string | EQUIVALENT **nếu** locale vi-VN và decimal field |
| TC-02 | '00123' | 123 numeric | DIFFERENT khi identifier |
| TC-03 | 0 | blank | DIFFERENT by default |
| TC-04 | false boolean | 'Không' | EQUIVALENT chỉ với alias configured |
| TC-05 | '01/02/26' | '2026-02-01' | UNRESOLVED khi format date 2-digit year/locale không rõ |
| TC-06 | 100000.00 | 100000 | EQUIVALENT nếu decimal ignores scale |
| TC-07 | Key duplicated | two records same key | UNRESOLVED alignment, no silent first-match |
| TC-08 | rows reordered | same rows | EXACT/EQUIVALENT no changes in key-mode |
| TC-09 | formula `=SUM(A1:A2)` | formula `=A1+A2` | formula changed; values can match |
| TC-10 | archive 1KB→1GB | no other | rejected with safe error |
| TC-11 | input `=HYPERLINK(...)` | report CSV/XLSX | exported as safe text not executable formula |
| TC-12 | OCR '85' | source '8.5' | needs review / unresolved until confirmed |
| TC-13 | schema new column | schema old | FIELD_ADDED |
| TC-14 | Excel 1900/1904 date serial | same date | equivalent after date-system decode |
| TC-15 | 10% | 0.1 | equivalent under percent policy only |
| TC-16 | Policy changed between runs | same file hashes | different policy_digest, separate report revision |

## 11.3. Release gates

Gate 0: parser PoC trên Android thật; Gate 1: unit coverage tập trung critical policies >= 90% branch trên core (mục tiêu nội bộ, không đại diện correctness); Gate 2: các golden fixtures đạt 100%; Gate 3: security tests critical pass; Gate 4: performance benchmark thiết bị mục tiêu; Gate 5: smoke test signed release; Gate 6: release approval và rollback test.

## 11.4. Dataset đánh giá

Ít nhất 3 lớp: (a) synthetic controlled, (b) open datasets không chứa PII, (c) dữ liệu thực đã ẩn danh và có quyền sử dụng. Label truth độc lập; không lấy output engine làm ground truth. Công bố confidence interval nếu đánh giá mô hình OCR/heuristics; đừng chỉ nêu 'độ chính xác 99%' thiếu mẫu số.


# 12. Build, CI/CD, phát hành và bảo trì

## 12.1. Môi trường

`dev` (mock/fixtures), `qa` (signed internal, non-production data), `prod` (release signed). Mỗi environment có applicationId suffix rõ ràng; OCR cloud feature flag off-by-default, dùng secret backend độc lập.

## 12.2. Pipeline đề xuất

`PR -> Gradle format/lint -> build/test unit -> dependency+license+SAST scan -> instrumentation CI/device farm -> benchmark nightly -> signed staging APK -> UAT -> release tag -> signed AAB/APK -> staged rollout -> monitor crash/error -> rollback if necessary`.

- Build reproducible ở mức Gradle dependency lock, artifact hash, SBOM, checksum.
- Signing key tuyệt đối không commit repo; dùng secret manager/secured signing pipeline; key rotation/backup có người chịu trách nhiệm.
- Kiểm tra target SDK policy tại thời điểm Play submit, không giữ giả định cố định từ tài liệu.
- Bản APK cho học phần có thể phát trực tiếp, Play phát hành dùng AAB theo yêu cầu store tương ứng.

## 12.3. Versioning & migrations

App Semantic Versioning; engine/policy/report schema có version riêng. Thay đổi cách hiểu datatype có thể là breaking semantic change dù UI version chỉ minor; migration report phải có cảnh báo và không rewrite lịch sử silently.

## 12.4. Rollback

Rollback APK/AAB chỉ là một phần: bản cũ có thể không đọc Room schema mới. Migration phải forward compatible hoặc rollback plan thông qua backup đã mã hóa. Android app trên store không phải lúc nào downgrade tự động được; chuẩn bị hotfix và disable cloud feature từ server nếu dùng cloud.

## 12.5. Monitoring/KPI dashboard

Các số đo có privacy approval: `success_rate`, `crash_free_sessions`, `time_to_preview`, `time_to_compare`, `OOM_count`, `format_failure_rate`, `unresolved_rate`, `export_failure_rate`, `OCR_review_rate`, `cloud_api_cost_per_document` (chỉ khi bật). Không đưa bảng nội dung hay full path vào dashboard.


# 13. Runbook vận hành, bảo trì và xử lý sự cố

## 13.1. Runbook thông thường

| Sự cố | Triệu chứng | Xác minh | Xử lý |
|---|---|---|---|
| SAF_REVOKED | không đọc được file cũ | URI grant còn hiệu lực? | cho chọn lại; không ghi đè |
| PARSER_UNSUPPORTED | file nhận sai format | inspect magic/MIME | hiển thị hỗ trợ, yêu cầu export phù hợp |
| ZIP_BOMB_DETECTED | fail trong parser | compression/limits | cách ly/từ chối; không tắt guardrails |
| OOM_RISK | tiến độ chậm, crash | memory baseline, file characteristics | giảm sheet/range, streaming, cap file |
| DUPLICATE_KEY | nhiều dòng cùng key | xem key profile | user chọn khóa ghép/chế độ multiset |
| AMBIGUOUS_LOCALE | '1,234' parse khó | locale profile | bắt buộc xác nhận policy |
| OCR_LOW_QUALITY | lệch cột/cell | overlay vs original | crop/rotate/chụp lại/manual edit |
| DIFF_UNEXPECTED | kết quả lạ sau update | hash+policy+engine version | replay golden fixture / rollback engine logic |
| EXPORT_FAILED | xuất không thành công | free storage/SAF grant | retry idempotent, temp cleanup |
| CLOUD_COST_SPIKE | OCR tăng phí | usage dashboard | throttle/disable cloud via feature flag |

## 13.2. Nhóm severity và response

SEV-1: lộ dữ liệu hoặc xóa nguồn; dừng phát hành/kích hoạt chế độ an toàn, điều tra, xử lý thông báo tuân thủ. SEV-2: diff sai hệ thống trên tập dữ liệu hợp lệ; rollback/hotfix, đánh dấu báo cáo bị ảnh hưởng. SEV-3: lỗi import một format ít phổ biến, workaround manual export. Các thời hạn phản ứng cần xác định theo nhân lực thực tế thay vì tùy tiện cam kết SLA 24/7.

## 13.3. Incident playbook

1. Triage error code + app/engine/policy version (không copy input nhạy cảm vào ticket). 2. Xin phép dùng anonymized reproduction. 3. Reproduce bằng fixtures. 4. Root cause, severity, affected versions. 5. Fix + regression tests. 6. Roll forward có versioned release note. 7. Nếu logic diff sai, đánh dấu invalid reports và hỗ trợ chạy lại.

## 13.4. Retention & disaster recovery

Tệp gốc giữ nguyên tại nơi người dùng chọn. Session local chỉ giữ manifest/hash/config nếu có thể; cache sensitive TTL và xóa có thể kiểm chứng. Export report là bản sao do người dùng quản lý, không thể thu hồi tự động sau khi chia sẻ. Khôi phục config từ backup có versioning; tính toán lại báo cáo khi source vẫn còn quyền truy cập.

## 13.5. Lịch bảo trì

Hàng tuần: dependency vulnerabilities, crash trend, parse error spikes. Hàng tháng: Android OS compatibility, SDK licensing/version checks, golden fixtures. Mỗi release: signing, schema migration, performance, privacy review. Khi đổi OCR API: cập nhật model/version và chạy lại đánh giá corpus.


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


# 16. Nguồn kỹ thuật, thuật ngữ, giới hạn xác minh

## 16.1. Nguồn tài liệu kỹ thuật chính thức (kiểm tra ngày 22/10/2026)

[R1] Android App architecture recommendations, https://developer.android.com/topic/architecture/recommendations . Separation of concerns, UI/data/domain layers, coroutines, Compose, testing.

[R2] Android Storage Access Framework, https://developer.android.com/guide/topics/providers/document-provider . User-selected document access and persistable URI permissions.

[R3] Apache POI HSSF/XSSF/SXSSF overview, https://poi.apache.org/components/spreadsheet/ . Event reader và memory trade-off.

[R4] Apache POI limitations, https://poi.apache.org/components/spreadsheet/limitations.html . Giới hạn workbook và bộ nhớ.

[R5] Apache POI configuration / ZipSecureFile, https://poi.apache.org/components/configuration.html . Zipbomb guardrails.

[R6] Apache Tika supported formats, https://tika.apache.org/docs/4.0.x/formats.html . OOXML, ODF, legacy Office extraction background; không suy ra Android compatibility từ đây.

[R7] Google ML Kit Text Recognition Android, https://developers.google.com/ml-kit/vision/text-recognition/v2/android . OCR models và dependencies.

[R8] ML Kit supported languages, https://developers.google.com/ml-kit/vision/text-recognition/v2/languages . Tiếng Việt Latin.

[R9] Microsoft Azure Document Intelligence Layout, https://learn.microsoft.com/azure/ai-services/document-intelligence/prebuilt/layout . Table extraction, file and size constraints.

[R10] Google Document AI Layout Parser, https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk . Layout and supported formats; cloud feature is optional.

[R11] OWASP MASVS, https://mas.owasp.org/MASVS/ . Security controls for mobile apps.

[R12] OWASP CSV injection, https://owasp.org/www-community/attacks/CSV_Injection . Protection of spreadsheet export.

[R13] Room migrations, https://developer.android.com/training/data-storage/room/migrating-db-versions . Schema/migration tests.

[R14] RFC 4180, https://www.rfc-editor.org/rfc/rfc4180 . CSV formats / MIME type.

## 16.2. Thuật ngữ

`Workbook`: tệp bảng tính; `Worksheet`: sheet; `Schema`: cột và các thuộc tính; `Field`: trường/cột logic; `Record`: bản ghi/hàng logic; `Physical dtype`: kiểu lưu trữ; `Semantic dtype`: loại ý nghĩa nghiệp vụ; `Canonicalization`: quy về biểu diễn có quy tắc; `Provenance`: truy nguồn chính xác; `Unresolved`: không đủ căn cứ để kết luận; `OCR`: nhận dạng chữ trong ảnh; `Layout parsing`: xác định cấu trúc tài liệu; `PoC`: thử nghiệm khả thi kỹ thuật; `SLO`: mục tiêu mức độ dịch vụ; `RACI`: phân vai chịu trách nhiệm/phê duyệt/tham vấn/nhận tin.

## 16.3. Căn cứ và giả định

Nguồn ban đầu là yêu cầu đề tài số 3 do người dùng cung cấp: so sánh hai file Excel, thống kê giống/khác, chỉ rõ sai khác, đọc ảnh chụp, đóng gói file cài đặt. Các chức năng mở rộng dtype, chuẩn hóa ngữ nghĩa, kiến trúc và vận hành là **đề xuất thiết kế của tài liệu này**, không phải yêu cầu đã được khách hàng/giảng viên duyệt. Không phải tất cả công nghệ đề cập đã được POC, đo hiệu năng, xác nhận giá dịch vụ hay tích hợp thực tế.
