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
