# Dytava Brand Identity & Precision Workspace — Version 3.2 (Official Baseline)

## Nguồn gốc & Hiện trạng phê duyệt
Bản nhận diện thương hiệu này là **chuẩn nhận diện thương hiệu chính thức** của sản phẩm **Dytava** (thuộc dự án `excelcompare`), xác lập chuẩn ngôn ngữ thiết kế:
**DYTAVA — Precision Workspace (Editorial Minimalism × Data Instrument × Native Interaction)**.

- **Trạng thái:** Chính thức (Official Baseline Approved)
- **Phiên bản:** v3.2.0
- **Ngày cập nhật:** 18/11/2026
- **Tagline:** `PRECISION WORKSPACE`
- **Slogan:** "Đối chiếu dữ liệu chính xác, nhanh chóng và rõ ràng." / "Thiết lập quá trình đối chiếu dữ liệu một cách chính xác, linh hoạt và hiệu quả."
- **Triết lý:** Dytava có **ngôn ngữ thiết kế riêng đủ mạnh để người dùng nhận diện sản phẩm mà không cần nhìn logo**. Thẩm mỹ của công cụ phân tích dữ liệu chuyên nghiệp kết hợp trải nghiệm thao tác bản địa mượt mà.

---

## 1. Bản sắc thị giác cốt lõi (Precision Tokens)
```
   dytava.
   PRECISION WORKSPACE
   
   LIME PRIMARY    #C8FF4A   (Lime Primary — hành động chính, active switch, tiến trình nổi bật)
   LIME-600        #86E63A   (Lime-600 — viền active, hover state, điểm nhấn sắc nét)
   OFF-WHITE       #F7F6F2   (Off-white — nền canvas sáng mặc định, bảo vệ thị giác)
   WARM SURFACE    #EDEBE4   (Warm Surface — bề mặt thẻ card, container nhập liệu)
   GRAPHITE        #0F1A1C   (Graphite Dark — khối tiêu điểm, chữ chính, header kỹ thuật)
   GRAPHITE-800    #1B2426   (Graphite-800 — bề mặt tối cho dark mode, status pill nền tối)
   DIFFERENCE      #E97965   (Difference Coral — dữ liệu sai khác, fingerprint alert)
```

---

## 2. Bảng màu chuẩn (Official Palette)
| Tên màu | HEX | Vai trò |
|---|---|---|
| **Lime Primary** | `#C8FF4A` | Màu thương hiệu nhận diện chính, nút CTA dạng Pill, switch active |
| **Lime-600** | `#86E63A` | Điểm nhấn viền active, hover state, chỉ báo tiến trình |
| **Off-white** | `#F7F6F2` | Nền canvas ứng dụng sáng, thanh nhã |
| **Warm Surface** | `#EDEBE4` | Bề mặt container thẻ, vùng tải tệp và ô nhập dữ liệu |
| **Graphite** | `#0F1A1C` | Màu chữ chính trên nền sáng, nền card tiêu điểm, nút phụ |
| **Graphite-800** | `#1B2426` | Bề mặt tối cho Dark Mode, container Focus Diff, status pill nền tối |
| **Difference Coral** | `#E97965` | Dữ liệu sai khác (`DIFFERENT`), dải mật độ sai lệch trên fingerprint |
| **Emerald Green** | `#10B981` | Trạng thái `EXACT` (trùng khớp hoàn toàn 100%), icon Excel xanh lá |
| **Amber Warning** | `#F59E0B` | Cảnh báo đối soát, trạng thái `UNRESOLVED` |
| **Crimson Danger** | `#EF4444` | Nút Xóa, cảnh báo lỗi nghiêm trọng |
| **Subtle Divider** | `#D8D5CC` | Đường viền các thẻ, phân cách bảng tính |

---

## 3. Typography
- **Bộ phối UI:** Precision Workspace Suite.
- **Tiêu đề & Nhấn mạnh:** **Manrope** (500, 600, 700, 800) mang lại cấu trúc hình học hiện đại, sắc sảo.
- **Giao diện & Nội dung:** **Inter (System)** (400, 500, 600, 700) tối ưu cho việc đọc mật độ cao trên mọi kích thước màn hình.
- **Số liệu, mã định danh và diff:** **Inter / Tabular Figures** (`tabular-nums lining-nums`), số có độ rộng cố định.
- **Fallback cục bộ:** `Plus Jakarta Sans` cho Display, `Be Vietnam Pro` cho Interface, `IBM Plex Mono` cho Mono code.

---

## 4. Signature Components (Linh kiện nhận diện độc quyền)
1. **Nút chính (Primary CTA):** Hình viên con nhộng (Pill), nền Lime Primary `#C8FF4A`, chữ Graphite `#0F1A1C` bold, icon mũi tên `→`.
2. **Nút phụ (Secondary):** Hình viên con nhộng (Pill), nền Warm Surface `#EDEBE4` hoặc viền mảnh Graphite.
3. **Status Pill:** Nền tối Graphite-800 `#1B2426`, chữ và chấm tròn phát sáng Lime Primary `#C8FF4A` (`● Đang tiến hành`).
4. **Thẻ tệp (File Card):** Nền Warm Surface `#EDEBE4`, icon Excel xanh lá, hiển thị tên tệp, số dòng và kích thước.
5. **Difference Fingerprint:** Ma trận trực quan hóa vị trí và mật độ sai khác theo từng sheet.
6. **Focus Diff Card:** Thẻ so sánh trực quan giá trị cũ (A) và mới (B) với thao tác vuốt chuyển tiếp mượt mà.
