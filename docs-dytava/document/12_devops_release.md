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
