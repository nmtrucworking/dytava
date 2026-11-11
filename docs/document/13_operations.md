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
