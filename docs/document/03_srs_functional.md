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
