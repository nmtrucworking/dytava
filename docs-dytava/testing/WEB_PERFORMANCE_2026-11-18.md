# Kiểm tra hiệu năng thuật toán web — 18/11/2026

Bản hiện tại xử lý nhanh bảng có dữ liệu giống nhau/khóa ổn định ở mức 1 triệu ô mỗi nguồn trên Apple M5. Chưa có bằng chứng bảo đảm giới hạn 500 MiB/25 triệu ô. Căn chỉnh chuỗi có ngưỡng đổi thuật toán làm giảm độ đúng; cần sửa trước khi coi đây là phương án đáng tin cậy cho bảng lớn.

## Phạm vi và cách đo

- Đo working tree hiện tại, commit nền 5a167b868d731914d02b24ee3868ad07aef204ac; có thay đổi chưa commit của người dùng. SHA-256 của 5 file JS được lưu trong JSON và kiểm tra lại sau khi đo.
- Apple M5, RAM 16 GiB; darwin 25.5.0; Chromium 156.0.8078.4 headless; Node v26.9.0. Không throttle CPU. Không kiểm soát thermal/background workload.
- Build minify bằng esbuild trong thư mục tạm. Dùng handler Worker và renderDualGrid thực tế; API trả lỗi cục bộ. Không gửi tệp ra mạng.
- Fixture tổng hợp xác định bằng generator trong script, không dùng dữ liệu riêng. Mỗi case dùng page/worker mới, warm-up nhỏ + một lượt warm-up case, rồi 5 lượt đo tuần tự. Đây là khảo sát warm-run, không phải p95/SLO hoặc calibration RP-1.
- workMs: thời gian handler Worker trước postMessage. Roundtrip: gửi dữ liệu đến nhận kết quả, bao gồm sao chép hai chiều, không gồm tạo fixture/khởi động Worker/parse đầu vào của case compare. Render: chạy đồng bộ renderDualGrid với trang đầu 100 dòng và bộ lọc ALL; chưa bao gồm layout/paint hoàn chỉnh.
- Parse được đo riêng; XLSX 10.000 dòng là fixture đơn giản, một sheet. Không cộng median các stage thành một số end-to-end.
- Kiểm tra oracle: số ô, số dòng thêm, số ô khác, số dòng parse theo fixture. Chạy npm test: **43/43 passed**. Hai lỗi bổ sung bên dưới chưa được các test hiện tại bao phủ.

## Số đo

Median của 5 lượt, đơn vị ms. Số dòng/cột tính trên **mỗi nguồn**.

| Case | Worker work | Roundtrip | Render trang đầu |
| --- | ---: | ---: | ---: |
| positional-exact-10k | 16.1 | 62.6 | 5.2 |
| positional-exact-100k | 197.1 | 739.0 | 6.9 |
| key-reversed-100k | 268.6 | 825.1 | 9.2 |
| sequence-anchors-100k | 360.0 | 987.8 | 7.4 |
| sequence-no-anchors-1000 | 762.1 | 770.1 | 5.3 |
| sequence-no-anchors-2000 | 3088.7 | 3103.3 | 5.0 |
| sequence-no-anchors-2001 | 25.4 | 39.6 | 4.9 |
| positional-wide-100-columns | 139.7 | 495.3 | 53.2 |
| positional-text-1000-chars | 2491.1 | 2518.1 | 3.3 |
| parse-csv-100k | 91.3 | 150.6 | — |
| parse-xlsx-10k | 260.7 | 266.3 | — |

Các case sequence-no-anchors sửa cột Field1 ở mọi dòng, giữ các cột còn lại. Không còn chữ ký dòng giống hoàn toàn để làm anchor. Case sequence-anchors thêm một dòng giữa bảng. Case text có 1.000 dòng × 2 cột, trong đó một cột văn bản dài 1.000 ký tự thay đổi ký tự cuối. Các case exact/key/wide giữ nguyên nội dung.

## Phát hiện và ưu tiên

### P1 — Căn chỉnh chuỗi đổi sang vị trí khi vượt 4 triệu trạng thái, tạo khác biệt giả

[compare-engine.js:761](../../web/js/compare-engine.js#L761) dùng DP khi lenA × lenB ≤ 4.000.000 và ghép theo vị trí khi vượt ngưỡng. DP có chi phí O(m × n × C), vì mỗi trạng thái tính độ giống của cả dòng. Ma trận Float64 ở ngưỡng 2.000 × 2.000 riêng nó chiếm khoảng 30,5 MiB, chưa gồm dữ liệu/kết quả. Chưa có ngân sách tổng trạng thái cho toàn tác vụ.

Fixture tái hiện: A gồm [ID_i, old i]; B chèn [NEW, new] ở đầu và đổi mọi old i thành new i, giữ ID. Hai cột ID/Value.

| Dòng A/B | Oracle | Kết quả hiện tại |
| --- | --- | --- |
| 1.999 / 2.000 | 1 added, 1.999 exact ID, 1.999 different Value | Đúng |
| 2.000 / 2.001 | 1 added, 2.000 exact ID, 2.000 different Value | 1 added, **0 exact, 4.000 different** |

Case tốc độ 10 cột ở 2.000 dòng mất khoảng 3,09 giây; 2.001 dòng chỉ khoảng 25 ms vì fallback. Đây không phải cải thiện thuật toán giữ nguyên chất lượng. Đề xuất: budget tổng DP/candidate work, tăng chất lượng anchor và dùng thuật toán có giới hạn tài nguyên; nếu không xác định được ghép hàng thì biểu diễn rõ unresolved hoặc yêu cầu chọn khóa, không coi cặp vị trí là cặp đã xác minh.

### P1 — Sao chép toàn bộ bảng/kết quả làm nghẽn main thread và tăng bộ nhớ

[worker-client.js:19](../../web/js/worker-client.js#L19) gửi hai bảng bằng structured clone, Worker trả toàn bộ alignedRows/cellComparisons/report. Với 100.000 × 10 ô exact, median work khoảng 197 ms nhưng roundtrip 739 ms; riêng postMessage phía gửi khoảng 93 ms. Observer ghi nhận long task trên main thread tối đa **289 ms** ở case này (cửa sổ nhận kết quả/render cũng được quan sát).

Engine dùng EXACT_CMP dùng chung giúp giảm allocation cho ô exact, nhưng vẫn giữ object cellComparisons theo từng dòng và mọi kết quả trong RAM. Đề xuất giữ nguồn/kết quả trong Worker, trả summary và trang dữ liệu theo yêu cầu; dùng batch/transferable khi phù hợp. Cần đo peak whole-process memory trước khi công bố năng lực 25 triệu ô.

### P2 — Văn bản dài có chi phí bậc hai và shortcut similarity sai

[compare-engine.js:522](../../web/js/compare-engine.js#L522): Levenshtein chạy O(LA × LB) đến 1.000 ký tự, gọi cho từng ô khác; word diff còn có DP token riêng. Fixture 1.000 ô văn bản thay đổi mất khoảng 2,49 giây tính toán dù bảng chỉ có 2.000 ô.

Vượt 1.000 ký tự, hàm trả abs(lenA − lenB) thay cho edit distance. Hai chuỗi a lặp 1.001 lần và b lặp 1.001 lần bị báo **100% similarity**, dù status vẫn DIFFERENT. Ở độ dài 1.000, similarity đúng là 0%. Đề xuất tính highlight/similarity khi xem ô hoặc trang hiện tại; nếu hết budget thì trả trạng thái “chưa tính”, không dựng một tỷ lệ chính xác giả.

### P2 — Parser và UI chưa có đường xử lý dữ liệu lớn theo lô

[file-parser.js:94](../../web/js/file-parser.js#L94) đọc toàn bộ text/ArrayBuffer; CSV parse toàn bộ trước validate; XLSX load toàn workbook trước giới hạn row/cell của sheet. Đổi sheet sẽ parse lại file. Nhánh sửa OpenXML còn giải nén/tạo ZIP rồi load lại. Giới hạn byte/dòng hiện tại không phải giới hạn bộ nhớ tiến trình.

[app.js:345](../../web/js/app.js#L345) quét toàn bộ alignedRows mỗi lần đổi trang, kể cả ALL. Việc giới hạn DOM ở 100 dòng là hợp lý; bảng rộng vẫn dựng 2 × 100 × số cột ô cùng event handlers. Đề xuất cache chỉ mục bộ lọc, map chỉ số cột, event delegation và đo layout/paint với 500 cột.

[app.js:322](../../web/js/app.js#L322) chốt durationMs trước render và không gồm parse. Nhãn thời gian/telemetry cần thể hiện stage rõ ràng. Timeout hiện tại là 30 giây mỗi lời gọi, không phải đảm bảo hoàn thành mọi input hợp lệ trong 30 giây.

## Kiểm tra tiếp theo

Ưu tiên sửa tính đúng ở fallback và similarity, sau đó giảm bản sao qua Worker và chuyển xử lý chi tiết theo nhu cầu. Kiểm tra lại bằng fixture cũ, thêm bảng nhiều khác biệt, nhiều đoạn DP, khóa lệch, nhiều sheet và bảng 500 cột. Cần đo cold start, peak RSS/heap/native, khả năng hủy, export đầy đủ và thiết bị yếu/Safari/Firefox. Đợt này không đo 500 MiB, 25 triệu ô hoặc hai nguồn 1 GB, không xác nhận các mức đó.

## Tái chạy

Chạy từ gốc repository sau khi cài dependencies và Chromium của Playwright:

```sh
node scripts/benchmark-web.mjs docs-dytava/testing/WEB_PERFORMANCE_2026-11-18.json
```

[Script](../../scripts/benchmark-web.mjs) lưu raw samples, môi trường, hash nguồn và hai diagnostics về độ đúng trong [JSON](WEB_PERFORMANCE_2026-11-18.json). Không sửa file runtime hay limits. Chưa triển khai tối ưu trong đợt kiểm tra này.
