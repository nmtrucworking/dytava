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
