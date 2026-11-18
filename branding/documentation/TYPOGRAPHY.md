# Dytava Typography — Precision Workspace (v3.2)

Chuẩn kiểu chữ (Typography) chính thức theo hệ thống **DYTAVA — UI MOCKUP SET (Precision Workspace)**:

| Phân cấp | Phông chữ | Trọng số (Weights) | Ứng dụng nghiệp vụ |
| --- | --- | --- | --- |
| **Display / Tiêu đề** | **Manrope** | 500, 600, 700, 800 | Tiêu đề chính, display, hero title, brand heading |
| **Interface / Giao diện** | **Inter (System)** | 400, 500, 600, 700 | Nội dung văn bản, mô tả, nhãn thao tác, menu |
| **Data / Số liệu & Mã** | **Inter (Tabular)** | 400, 500, 600, 700 | Giá trị ô bảng tính, số dòng (`12.480 dòng`), mã định danh (`tabular-nums lining-nums`) |

### Triển khai trên Web
- Tệp cấu hình: `web/css/fonts.css`.
- Biến token CSS:
  - `--font-display: 'Manrope', 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;`
  - `--font-interface: 'Inter', 'Be Vietnam Pro', system-ui, -apple-system, sans-serif;`
  - `--font-data: 'Inter', 'IBM Plex Mono', monospace;`
- Phông chữ trực tuyến nạp từ Google Fonts với bộ ký tự tiếng Việt đầy đủ.
- Đi kèm các tệp WOFF2 dự phòng cục bộ trong `web/assets/fonts/` đảm bảo ứng dụng vận hành 100% khi mất mạng (offline mode).
