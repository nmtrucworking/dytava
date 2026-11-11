# Input fixtures — 0.1.0 DRAFT

Dữ liệu minh họa để kiểm tra contract, không có dữ liệu người thật. Không fixture nào quyết định defaults sản phẩm hay chứng minh Flutter adapter support.

| File | Mục đích / expected |
| --- | --- |
| [sample_a.csv](sample_a.csv), [sample_b.csv](sample_b.csv) | UTF-8 không BOM, LF, comma, double-quote escape, header record 1; mỗi bên 3 data rows × 4 fields |
| [input_manifest.example.json](input_manifest.example.json) | Hai artifact A/B; bytes/size/SHA-256 khớp đúng hai CSV; access_ref fixture-local |
| [import_config.example.json](import_config.example.json) | Cấu hình explicit cùng scope/dialect/header cho hai nguồn; không mapping/key/locale semantic |
| [source_tables.expected.json](source_tables.expected.json) | Oracle parsed tables viết theo contract; raw cells đều csvText, giữ zeros/multiline/empty |
| [acceptance_registry.json](acceptance_registry.json) | INP-TC-001–040; mỗi case có procedure/expected/traceability; tất cả PLANNED |

Manifest envelope (không phải một schema thứ sáu) yêu cầu schema_version=0.1.0, session_id, artifacts đúng hai entries A/B có IDs riêng. Validator dùng input_artifact schema cho từng entry và kiểm tra cross-file binding. resource_profile_ref=fixture-only-small-v1 là tên kiểm tra ví dụ nhỏ, không phải profile đã benchmark cho runtime Android.

Expected Input:

- Header: id, name, amount, note; field IDs f1–f4, source_index 1–4.
- Record 2 có id `00123`; amount A `8,5`, B `8.50`, đều giữ text. Không tự kết luận tương đương ở tầng Input.
- Record 2 note có newline trong quoted field: source line=2, end_line=3, record=2, field=4. Record 3 nằm physical line 4, record 4 nằm line 5.
- Record 3 id `00007`, amount `0` vẫn text; note rỗng là EMPTY_STRING, không MISSING/BLANK/JSON_NULL.
- Record 4 note `x,y` là một field; id A `00009`, B `00010`.
- row_count=3 không gồm header; sheet_name=null; capability TABULAR_VALUES_ONLY; không Excel coordinates/formulas/styles giả.

Nếu sau này kiểm thử Comparison, phải cung cấp policy riêng: key id xác nhận, A_TO_B explicit, amount DECIMAL với decimal_separator A=`,` và B=`.`. Khi đó mới có thể kỳ vọng 00123 amount EQUIVALENT, 00009 removed và 00010 added. Các kết quả đó không thuộc expected parsed output và không được runner Input tính thay Core. Ví dụ policy academic-records v2 ở project dùng nhãn cột khác, không áp dụng trực tiếp cho fixture này.

source_tables.expected.json là oracle minh họa; adapter_id=fixture-authoring không là parser thật. Verifier dùng Python CSV reader để kiểm tra oracle/bytes/provenance; đây là fixture QA, không phải test Dart adapter. Các payload inline khác (JSON/XLSX/OCR/security/lifecycle) và device matrix nằm trong [acceptance spec](../09_acceptance_tests.md), chưa có binary corpus/execution evidence.
