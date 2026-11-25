# Real SPSS OCR regression fixture

User-supplied files, tested on 25/11/2026 (Vietnam time):

- `spss_tables.jpg`: original 1327 × 805 image containing Coefficients and Collinearity Diagnostics. SHA-256: `c24061a3855d57717cc52196bbdd24289a0d288bc0a61422cbe53f5483f6115b`.
- `collinearity_diagnostics.xlsx`: original reference workbook, 11 columns, two merged header levels and seven data rows. SHA-256: `8a6926aadc75946637c77506e8047a32dd90ff1bdb9e09e129b1f43dfd658aa5`.
- `collinearity_mlkit_tokens.json`: actual Android ML Kit output captured before small-text enhancement, from the crop `(30, 440)–(1210, 790)`. These are recorded SDK tokens, not a hand-built simulation or expected values.

The workbook is the reference for the lower table only. Tests do not infer missing values from statistical relationships or fill down the Model column.

## Run

From `mobile/`:

```sh
flutter test test/ocr
python3 tool/run_ocr_device_test.py --device emulator-5554
```

The device command requires a running Android device/emulator (or a supported iOS device ID). It supplies fixture bytes through a temporary Dart define file; test images are not production assets. Device workflow tests use an in-memory database.

## Findings and repairs

- Actual lower-table tokens produced 18 columns instead of 11 because left-aligned headers and right-aligned values were treated as separate columns. Column inference now uses dense row anchors.
- A wrapped leaf header lost `Condition` above `Index`. Leaf labels in the same column are retained while spanning group captions are removed.
- The upper Coefficients table kept three title/group-caption lines as data (11 extracted rows instead of eight). Caption pruning now handles several consecutive caption lines and distinguishes wrapped groups from wrapped leaf labels.
- ML Kit joined `DimensionEigenvalue` across a border. The adapter separates elements only when SDK symbol geometry provides a large gap; it preserves all recognized characters. SDKs without symbol boxes keep the original text for review.
- The workbook importer counted its second header level as a data record (eight instead of seven). Explicit vertical/horizontal merges now identify and flatten the two header levels to leaf column names.
- Failed recognition/crop retries left approved cells reusable. New attempts immediately invalidate the old grid and receipts; failures cannot finalize old results.
- Missing decimal punctuation can have high model confidence. Column-format warnings highlight suspicious numeric text without changing it, and OCR review displays every risk type.

## Measured lower-table recognition

Android 15 / API 35 arm64 emulator, bundled Latin ML Kit, plugin `google_mlkit_text_recognition` 1.0.3. Table region explicitly selected; automatic selection of one of the two tables is not being measured.

| Recognition input | Correct data cells / 77 | Correct populated numeric cells / 71 |
| --- | ---: | ---: |
| Original resolution, after structural repairs | 51 / 77 | 45 / 71 |
| 2× cubic enlargement, contrast enabled (selected) | 71 / 77 | 65 / 71 |
| 3× cubic enlargement, contrast enabled | 68 / 77 | 62 / 71 |
| 2× cubic enlargement, contrast disabled | 53 / 77 | 47 / 71 |

Values are compared using this fixture's explicit decimal-comma convention. The 77 data cells include six intentionally blank Model cells. This is one image, not an estimate of general OCR accuracy. Header correctness is checked separately.

Six lower-table numeric cells still require explicit review:

| Dimension | Column | Raw recognized text | Reference value |
| --- | --- | --- | --- |
| 2 | GC | `„00` | 0 |
| 3 | Eigenvalue | `013` | 0.013 |
| 5 | (Constant) | `10` | 0.1 |
| 7 | AN | `13` | 0.13 |
| 7 | DV | `„88` | 0.88 |
| 7 | TN | `38` | 0.38 |

The native test requires warnings on misread cells and at least 71/77 correct data cells before review. It then **simulates human corrections** and decimal display normalization, checks that raw text and source geometry survive, imports the reviewed table, and compares all 77 cells with the original workbook. Success after that simulated review is not 100% automatic OCR accuracy.

The second native case selects the Coefficients region `(30, 25)–(1045, 400)` and verifies nine columns, one header row, seven data rows, the Beta leaf header, and the intentionally blank Beta/Tolerance/VIF cells of the Constant row. It does not claim numeric accuracy for the upper table because the supplied workbook contains only the lower table.

Final validation: `flutter test` passed all 121 mobile tests, the device runner passed both native integration cases, and `flutter analyze` reported no issues. Eight new host regression tests cover the actual token capture, merged workbook headers, wrapped captions, SDK symbol gaps, coordinate mapping, numeric warnings and failed retries.
