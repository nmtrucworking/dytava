---
document_id: DYT-UDG-GEO-001
version: 1.0.0
status: DRAFT
owner: Algorithm geometry role
reviewer: Input and semantic review roles; assignees pending
updated: 2026-11-13
---

# Geometry, axis và mapping — L3

## 1. Scope và identity

P0 một selected table/scope mỗi source theo FR-002. Source snapshots thuộc [ISC-1](../input/11_streaming_snapshot_contract.md); ở đây chỉ định nghĩa logical geometry view. `ScopeView` gồm snapshot_id, scope_id, bounds/header refs, orientation, field_map_revision, merge_policy, selected physical cells/row filters và view digest. Source coordinates không thay đổi khi transpose hoặc sort.

`record_id = opaque identity(snapshot_id, scope_id, logical ordinal)`; ordinal được freeze sau scope/header/orientation confirmations. Mỗi physical cell chỉ đóng góp tối đa một lần cho một logical field trong scope, trừ explicit group-anchor reference. Header/group refs là metadata, không cộng thành nhiều data cells trong summary. Một record nhiều source spans phải giữ tất cả refs, không chọn một ô giả đại diện.

Roadmap multi-scope: overlap trong cùng aggregate run bị reject `REGION_OVERLAP` trước freeze. Muốn compare cùng cell trong hai scope phải tạo hai comparisons riêng, không cộng kết quả như một population. Không có P0 “cho overlap rồi tự deduplicate”.

## 2. Sheet/field mapping

Explicit user mapping đứng đầu; exact name/normalized name/header signature chỉ tạo proposal. Không kết luận sheet removed/added nếu còn unmatched candidate chưa được user giải quyết trong batch extension. P0 sheet inventory phục vụ chọn một scope, không tự chạy mọi sheet.

Field mapping là bijection giữa field IDs của hai frozen scopes; logical_field_id ổn định trong mapping revision, order theo confirmed map. Unmapped fields xuất structural events riêng. Không ghép theo header text khi có duplicate headers; user chọn field ID/source coordinate. Thay mapping invalidates plan/canonical schema, không đổi raw snapshot.

## 3. Axis và confidence policy

P0 không có numeric auto-accept threshold: **mọi orientation/key/mapping proposal đều NEEDS_CONFIRMATION**, kể cả proposal duy nhất. Vì vậy không còn δ chưa hiệu chỉnh nằm trên đường quyết định P0. Unknown/insufficient samples không trở thành score 0 hay confidence 1.

Proposal ranking dùng feature vector có version `GF-1`, không gọi là probability:

| Feature | Định nghĩa trên deterministic sample | Missing handling |
| --- | --- | --- |
| type_consistency | Với từng candidate field, max count một raw-kind family / nonmissing count; mean các fields có dữ liệu | Field không có nonmissing→null; không impute |
| header_separation | Tỷ lệ nonempty labels trong selected header, kèm duplicate-label count | Header chưa confirm→proposal feature only |
| key_uniqueness_sample | Distinct strict candidate keys / valid sampled records; kèm null/duplicate counts | Không đủ lexical evidence→null; không chứng minh global uniqueness |
| occupancy | Observed nonmissing cells / sampled logical slots | Sparse zero-slot→null; không dense allocate |
| timeline_consistency | Số adjacent temporal tokens hợp lệ tăng/giảm nhất quán / số adjacent pairs đủ parse profile | Parse profile chưa explicit→null; không dùng entropy suy nghĩa |

Sample: các record ordinals đầu tiên theo source order trong cả sample-record và sample-byte budgets RP-1; không random nondeterministic. Ranking lexicographic theo `(type_consistency desc, header nonempty ratio desc, duplicate labels asc, occupancy desc)`, null sau values; display cả vector/sample bounds. Tie giữ cả proposals; stable ID order chỉ ổn định UI, không chọn identity. Key/timeline là explanations riêng, không lén cast temporal tokens.

Auto-accept extension chỉ được đề xuất lại bằng ADR/version mới với labeled training/calibration/holdout corpus, false-accept/coverage targets và device/resource profile. Không bật bằng cách thêm một số 0.85 vào config hiện tại.

## 4. Merge policies

`anchorOnly` mặc định: merged range value ở top-left anchor, covered positions là `MERGED_REFERENCE`, không tự thành duplicated data values. `visualOnly` giữ layout metadata, compare raw physical cells. `propagateForGrouping` chỉ được bật trên field group key được confirm: đọc anchor dưới dạng reference, trace ghi anchor/range/policy; không copy raw value vào từng covered cell, không áp cho arbitrary measure fields.

Validate ranges: endpoints ordered/in bounds, no conflicting overlaps; anchor existence/loss ghi rõ. Dùng disk index sorted theo row-start/col-start; stream sweep với active ranges trong byte budget. Active set lớn spill disk; cache không đủ thì indexed lookup O(log G + hits), không claim O(1). Malformed overlap/range rejects structure trước snapshot/view freeze.

## 5. Logical cursor và transpose

Row-oriented view đọc SOURCE_ORDINAL từ raw store, projection theo mapped fields. Column-oriented view tạo external ordered references `(logical_record_ordinal, logical_field_id, physical_ref, value_ref)` bằng bounded sort; logical record cursor đọc sequential references. Không xoay dense matrix; payload cells vẫn ở raw store, cache bounded, batch fetch theo locality. Build cost/scratch/extra passes phải ghi trong plan estimates và metrics.

`view_cursor` binding: snapshot_id, scope/view digest, orientation, mapping_revision, projection, last logical ordinal. Transpose thay view/cursor IDs; SourceRef không đổi. Wide sparse sheet chỉ generate missing cells cho selected mapped fields khi diff yêu cầu, không enumerate declared full sheet rectangle.

## 6. Error/cancel và examples

Cancel khi build view đóng cursor/sort runs và discard staging refs; không publish view một phần. Invalid header/overlap/orientation binding là blocking review/config issue, không tự chọn hướng khác. Group-anchor không có evidence → field unresolved, không forward-fill giả.

Examples: chèn hàng đầu bảng làm coordinate shift nhưng không tự MOVED; hai header “Mã” cần user chọn IDs; merge A2:A10 group “Nhóm 1” chỉ tạo group references nếu policy confirm; timeline ngang được gợi ý COLUMN nhưng phải confirm. Test plan [UDG-TC-007/008](../../testing/UDG_CONTRACT_ACCEPTANCE.md), v3 F10/F11/F12/F13/F22/F24.
