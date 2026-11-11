# 07. Thiết kế kiến trúc, module và công nghệ

## 7.1. Kiến trúc baseline

**Android-first offline-first**, Clean Architecture / ports-adapters đơn giản: Presentation (Compose + ViewModel) → Domain (UseCases + policies) → Data (Adapters + repositories + Room). Không đặt logic normalize vào UI; engine là Kotlin/JVM thuần để có thể chạy unit test không Android và tái sử dụng trên server/desktop tương lai.

![Sơ đồ kiến trúc](/mnt/data/excelcompare_pd/diagrams/architecture.png)

## 7.2. Module/repository layout

```text
excelcompare/
  app/                    # Android manifest, Compose navigation, DI
  core/model/             # immutable canonical domain types
  core/compare/           # matching, normalization, diff, explanations
  core/policy/            # policy validator, parser profiles, versions
  core/storage/           # local cache, Room, lifecycle
  feature/import/         # picker, sniffer, preview
  feature/mapping/        # field/key mapping UX
  feature/results/        # report query and filters
  feature/ocr/            # optional on-device OCR + review
  adapter/xlsx/           # streaming OOXML read adapter
  adapter/delimited/      # CSV/TSV import/export
  adapter/json/           # JSON/JSONL table adapter
  adapter/legacy-xls/     # optional, after Android proof of concept
  adapter/ods/            # optional independent parser
  export/report/          # report JSON/CSV/XLSX
  benchmark/              # device benchmarks and fuzz corpus
  docs/                   # ADRs, policies, operational runbooks
```

## 7.3. Công nghệ và vai trò - dùng phiên bản qua version catalog khóa tại thời điểm bắt đầu triển khai

| Lớp | Công nghệ | Vai trò / quyết định |
|---|---|---|
| Language/Build | Kotlin, Android Gradle Plugin, Gradle Kotlin DSL, JDK theo AGP | compile, tests, build; pin versions sau compatibility test |
| UI | Jetpack Compose, Material 3, Navigation | màn hình responsive; StateFlow one-way flow |
| Architecture | ViewModel, Coroutines, Flow, Hilt hoặc Koin (chọn một) | job/state/dependency injection |
| Local metadata | Room; Proto DataStore | sessions, policy, diff index và setting |
| Import | Android Storage Access Framework / ContentResolver | scoped read input, no broad storage permission |
| XLSX | Apache POI event API nếu chạy được trên Android; thay thế: OOXML SAX secure custom adapter | tránh memory bloat; require device PoC |
| CSV | Apache Commons CSV hoặc parser RFC4180 | deterministic delim/escaping |
| JSON | kotlinx.serialization / streaming JsonReader | JSON arrays + JSONL |
| OCR | Google ML Kit Text Recognition v2 bundled | on-device tiếng Việt; layout reconstruct riêng |
| Layout OCR Cloud | Azure Document Intelligence `prebuilt-layout` hoặc Google Document AI | optional service side, opt-in consent + proxy |
| Imaging | Android Bitmap/ExifInterface; OpenCV optional | crop, rotate, deskew; no AI training mandatory |
| Security | Android Keystore, encrypted application storage based on threat model | secrets/at rest; network TLS for optional API |
| Observability | structured local logs without PII; optional crash service with consent | non-sensitive telemetry, error aggregation |
| QA | JUnit, Kotest optional, instrumented tests, Compose UI tests, Macrobenchmark | correctness/perf/regr |
| CI/CD | GitHub Actions/Gradle, dependency checks, lint, SBOM, Android signing | controlled releases |

**Important integration risk:** Apache POI là thư viện Java, không thể mặc định mọi artifact XSSF/HSSF chạy ổn định trên mọi Android API/ABI. Cần PoC kiểm chứng minSdk, DEX footprint, dependency conflict, font APIs, memory, reads thực tế. Không ép POI usermodel vào RAM mobile cho workbook lớn.

## 7.4. Dependency rules

`app -> feature -> domain interfaces <- adapters`; domain không import `android.*`, `org.apache.poi.*`, OCR SDK hoặc `androidx.room.*`. Format adapters tuân thủ `TableReader` contract: `sniff, inspect, open(scope), rows(): Flow<Row>, close`, versioned capabilities, cancel-friendly.

## 7.5. Policy update impact

Chỉnh locale/key/mapping có thể làm thay đổi toàn bộ kết quả, do đó phải invalidating diff cache, tăng `config_revision`, lưu prior report for history nhưng không giả là cùng phiên so sánh.
