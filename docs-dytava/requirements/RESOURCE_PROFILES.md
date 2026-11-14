---
document_id: DYT-NFR-RP-001
version: 1.0.0
status: DRAFT
owner: NFR performance role
reviewer: Device benchmark review role; assignee pending
updated: 2026-11-13
contract_version: RP-1
calibration_state: CALIBRATION_REQUIRED
---

# Resource profiles và benchmark contract

Extension nguồn của [NFR §3/5](NFR.md), không là throughput/RAM claim. **RP-1 định nghĩa đầy đủ cách cấu hình và kiểm tra profile; các instance device-specific chưa có số đo nên chưa được enable.** Source product limit vẫn 1.000.000.000 byte/source. Thiếu profile finite hợp lệ phải CONFIG_INVALID, không tự dùng profile nhỏ lịch sử.

## 1. Profile identity và enable gate

Profile instance gồm profile_id=`large-input-v1`, revision, contract_version=RP-1, platform/device class (RAM/OS/ABI), supported format/type/mode/capability versions, engine/adapter/renderer compatibility, limit_map, measurement_method/version, calibration_fixture_hashes, raw benchmark evidence refs, approved_by/review_ref và state `DESIGN_ONLY|CALIBRATING|ENABLED|REVOKED`.

Revision bất biến; digest=CFG-1 của effective profile không chứa chính digest. ENABLED yêu cầu tất cả dimensions của path resolved, consistent equations, positive boundary corpus pass, malformed/cancel/disk pressure tests pass, actual device evidence và review. Chỉ metadata/profile JSON valid không đủ. Runtime telemetry phải chứa profile_id/revision, observed/limit/stage cho fail reason, không raw data.

CALIBRATING profile có finite candidate values được thử nghiệm trong internal `CALIBRATION_TEST` harness, với explicit build gate và safety guards đầy đủ; chưa cần pass/evidence của chính run sắp đo. Candidate values/raw outcomes được lưu như dữ liệu thí nghiệm, không coi là SLO hoặc enabled production limits. User comparison chỉ nhận ENABLED profile. Fixture-only profiles giữ test identity riêng, không quảng cáo hỗ trợ1GB.

## 2. Typed dimensions bắt buộc

`Bytes/Count/DurationMs` là exact unsigned integers, không floating/infinity/null ở enabled dimension; `Ratio` là positive rational numerator/denominator. Unknown trước inspect khác unbounded policy: unknown workload estimates vẫn chịu finite hard limit. “Not applicable” chỉ cho disabled format/mode có validator guard rõ.

Limits của enabled components phải >0; max_attempts/max_active_workers≥1, merge_fan_in≥2. Giá trị0 không là “unlimited”; chỉ explicit disabled/not-applicable dimension được bỏ qua bởi capability guard. Observed counters/input cardinality vẫn có thể0 hợp lệ, khác limit values.

| Dimension group | Required limits / units | Consistency/action |
| --- | --- | --- |
| Source | max_source_bytes=1.000.000.000 mỗi source; max_full_scans count | actual bytes check; không lower source cap để gọi hỗ trợ1GB |
| ZIP/XML | max_total_expanded_bytes, max_entry_expanded_bytes, max_entries, max_expansion_ratio, max_xml_depth | Runtime increment trước allocation; unsafe→reject, CRC/integrity contract không bỏ |
| Tokens/cells | max_token_bytes, max_cell_bytes, max_key_bytes, max_decimal_digits/exponent magnitude, max_fields_per_record | Không truncate; adapter workload bounds được công bố, không kế thừa cap nhỏ toàn sản phẩm |
| Batch/queue | max_batch_bytes/records, max_inflight_bytes, max_queue_batches, max_message_bytes, control_reserved_bytes | Reserve before allocate; min count và byte caps; control path reserve riêng |
| Sampling | max_sample_records, max_sample_bytes | First ordinals deterministic, byte/count limits cùng áp dụng; không cấp READY từ sample |
| Process memory | process_soft_bytes, process_hard_bytes, native_reserve_bytes, UI_reserve_bytes, parser/SST/style/cache caps | soft<hard; summed allocation ceilings+reserves≤process_hard; whole-process sampling guard |
| Disk | max_scratch_bytes, max_WAL_bytes, max_sort_run_bytes, minimum_free_disk_reserve_bytes, max_pending_output_bytes | Account source/spool/index/results/WAL/output overlap; runtime free-space check |
| Merge/index | max_open_runs, merge_fan_in, sort_buffer_bytes, max_bucket_metadata_bytes, max_candidate_refs_bytes | fan_in≥2, <=open-run/file-handle budget; bucket member cursors spill |
| Matching work | total_candidate_evaluations, total_similarity_tokens/bytes, total_dp_states, max_segment_dp_states, max_traceback_bytes | Counters cumulative job, per-segment≤total; no per-segment reset to evade total |
| Writer/query | max_transaction_rows/bytes/ms, max_writer_backlog_bytes, max_query_page_rows/bytes, max_cursor_lease_ms | Bounded transaction/read lifetime; keyset page limit capped by both bytes/rows |
| Runtime | max_active_workers, max_chunk_work_units, max_chunk_ms, max_attempts, per_stage_elapsed_ms, inactivity_watchdog_ms | Finite retries; chunks yield control; stage limits format/workload-specific, không60s old total |
| Cancel | max_cancel_observe_ms, max_cancel_stop_ms, max_cancel_cleanup_ms | Record each component; overdue→controlled failure, no false ACK |
| OCR | max_width/height/pixels, max_decoded_bitmap_bytes, max_ocr_tokens/cells, review_batch_bytes | Check dimensions before decode; source size không thay pixel guard |
| Highlight | max_highlight_cell_bytes/tokens, max_highlight_dp_states | Omit highlight với reason, không thay semantic verdict |
| Export | max_layout_band_bytes, max_font_cache_bytes, max_page_buffer_bytes, max_output_bytes/pages, max_publish_ms | Output bounds độc lập source cap; full required corpus không silent filter/truncate |

Limits còn phụ thuộc calibration không được điền bằng số suy đoán. Điều này là dữ liệu cấu hình triển khai cần đo, không phải thiếu nhánh hành vi thiết kế. Enabled profile phải liệt kê actual values trong registry/evidence về sau; công việc docs không tạo một instance ENABLED.

## 3. Governor behavior đã chốt

Before stage: compute worst admitted working-set reservations của active components, kiểm disk headroom; estimates unknown→incremental accounting với conservative admission, không unlimited read. Reserve byte credits trước allocation; payload vượt single-item bound reject/structured unresolved chỉ khi semantic contract cho phép, không split token làm mất nghĩa.

Soft pressure: stop admitting workers/batches, drain writer/consumers, evict verified reusable cache, spill theo selected strategy. Không thay comparison policy/key/scope hoặc bỏ cells. Hard pressure: stop before next allocation/work unit; rollback staging hoặc bounded abstention vùng đã counted; Input EOF thiếu→no READY. OS kill/OOM không phải cơ chế hard-limit bình thường cần rely.

Time budget theo stage/cumulative work, inactivity watchdog reset khi meaningful work counter tiến lên, không reset chỉ từ heartbeat/progress text. Background/suspend duration ghi riêng; không giả `DateTime.now` clock jumps thành elapsed, dùng monotonic clock. Cancel control reserve luôn có credit dù data queue full.

Disk reserve kiểm runtime; available space giảm vì app khác vẫn abort có lý do. Flush/close output có thể tăng peak; resource release chỉ khi file/cursor consumer xong. Không xóa active snapshot để “dọn disk” giữa export. NUM budgets thay đổi→profile revision/new job; không source content tự sửa budgets.

## 4. Accounting và complexity

RAM peak gồm UI+all isolates+parser/SST/styles+canonical/candidate/DP/traceback+DB cache+messages+renderer/fonts+native/runtime overhead. Tránh đếm trùng shared pages khi đọc RSS/PSS; evidence nêu phương pháp. Disk peak gồm source copies+decompressed/parsed stores+sort/index runs+ledgers/traces+WAL/journal+pending outputs+reserve, tính lifetime overlap hai sources.

Stage complexity tham chiếu [layered review §14](../project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md) và execution choice tại [matching](../specs/engine/03_candidate_alignment.md). P0 KEY external sort comparison work O(R log R) cộng bytes/I/O, POSITIONAL sequential; không guarantee linear toàn pipeline. ORDERED n=m500k có250 tỷ states nếu full DP, nên never enabled thiếu total-state/traceback caps.

## 5. Measurement protocol

Stage spans: read/preflight, parse, validate/freeze, view build, canonicalize, index, align, diff, audit/publish, first result page, export layout/write/verify/publish, cleanup. Record overlap, không cộng stage durations thành total nếu chạy đồng thời. Time-to-first provisional preview khác time-to-READY; human review time riêng.

Evidence minimum: device model/chipset/RAM/OS/ABI/free disk, build/SDK/engine/adapter/parser/policy/encoding/profile/template/font versions, source SHA256/exact bytes/generator seed/mutations, cold/warm conditions, run_id, raw samples, measurement tool/version, peak RSS/PSS/heap/native nếu available, scratch/WAL/output high-water marks, bytes/cells/records per stage, index probes/cache misses, candidate/DP counters, cancel latency breakdown, correctness/coverage/unresolved counts và logs redacted.

Thiết bị Android4GB/6GB theo NFR cần reference models thật tại calibration, không tự gắn model chưa test. Battery/thermal/background/network conditions ghi rõ. Mỗi workload warm-up riêng và cold/warm runs không trộn. Khởi đầu tối thiểu5 exploratory runs theo v3, sau đó sample count cho tail được chọn theo variability; không claim p95 ổn định từ5 samples. Công bố raw sample count và percentile estimator; regression cần paired fixtures/build conditions.

## 6. Calibration và release decision

1. Correctness oracle độc lập, fixture seed/hash và change log trước benchmark; không dùng engine output làm oracle.
2. Probe bounded workload shapes: narrow/wide/sparse, high SST cardinality, long text, all-different, duplicate skew, two1GB sources, full PDF, malicious expansion và resource failure.
3. Collect peaks/liveness, chọn per-component ceilings và reserves; replay combined worst overlap để kiểm admission equations.
4. Run holdout boundary/full export/cancel/disk-full/no-cloud corpus; chỉ pass sau full EOF/count/provenance/result/output reconciliation.
5. Review values/version/device compatibility và enable profile; nếu device không đạt ghi capability unsupported trên device, không quảng cáo1GB chỉ vì reject an toàn.

Pass/fail theo NFR và LARGE/REP/UDG test registries; chưa có throughput/RAM/cancel threshold empirical trong lần docs này. Performance targets cũ≤3s small preview giữ TARGET, không đổi thành measured. Numeric calibration/APK/device evidence vẫn là release tasks, không “đóng” bằng docs.
