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
