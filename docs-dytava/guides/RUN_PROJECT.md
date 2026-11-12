# Dytava — Hướng dẫn cài đặt, chạy và kiểm thử dự án

**Mã tài liệu:** DY-OPS-001  
**Phiên bản:** 1.0 — 11/11/2026  
**Repository:** https://github.com/nmtrucworking/dytava  
**Nhánh đối chiếu:** `main`  
**Tình trạng xác minh:** Đã đối chiếu cấu trúc và cấu hình mã nguồn GitHub; **chưa thực thi** trên một máy có Flutter/Dart và Node.js 24.

> **Phạm vi:** Đây là tài liệu để lập trình viên khởi chạy **Flutter Mobile**, **Pure Dart Core** và **Web/Express** trong môi trường phát triển. Không phải tài liệu xác nhận sản phẩm đã hoàn thiện hoặc bản phát hành đã được kiểm thử.

## 1. Tổng quan kiến trúc chạy

| Thành phần | Đường dẫn | Công nghệ | Lệnh chính | Trạng thái phạm vi |
|---|---|---|---|---|
| Flutter Mobile | `mobile/` | Flutter + Dart | `flutter run` | PoC so sánh **hai giá trị ngữ nghĩa** |
| Semantic Core | `packages/excelcompare_core/` | Pure Dart | `dart test` | Engine PoC, một phần các semantic types |
| Web + Express | Gốc repo, `web/`, `server/` | Node.js + Express + SQLite | `npm run dev` | Ứng dụng Web và API riêng |
| Tài liệu thiết kế | `docs-dytava/` | Markdown, sơ đồ, đặc tả | Không chạy trực tiếp | Nhiều chức năng là mục tiêu thiết kế |

**Quan trọng:** Flutter demo hiện dùng `mobile/lib/main.dart` để so sánh hai giá trị A/B. Mã nguồn ghi rõ **chưa đọc Excel/CSV hoặc xuất báo cáo trong mobile**. Web có pipeline độc lập; chạy Web không đồng nghĩa chạy mobile. Flutter demo không cần khởi động Express server.

### Scope mới và capability đang chạy

[Quyết định 12/11/2026](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) bổ sung 1 GB/source,
PDF diff hợp nhất và PDF report template Dytava. Các lệnh chạy hiện tại chưa enable
toàn scope đó: Web vẫn áp 10 MiB/tệp (UI ghi “10 MB”), có CSV/JSON và template PDF preview/CLI; mobile chưa có file import/export. Xem [renderer](../specs/report/RENDERER.md) và chạy `npm run report:render` để tạo PDF mẫu.
[Report spec](../specs/report/README.md), [NFR](../requirements/NFR.md) và
[LARGE/REP acceptance](../testing/EXPANDED_SCOPE_ACCEPTANCE.md) định nghĩa phần cần triển khai.
Không tăng hằng số giới hạn rồi coi như đã chạy được 1 GB.

## 2. Điều kiện tiên quyết

### 2.1. Dùng chung

- Git
- Internet khi cài package và tải Android SDK/Gradle lần đầu
- Terminal và IDE (Visual Studio Code hoặc Android Studio)
- Clone **toàn bộ monorepo**, vì `mobile/pubspec.yaml` tham chiếu package ở `../packages/excelcompare_core`

### 2.2. Flutter/Android

- Flutter SDK phù hợp **Dart SDK `^3.13.7`** đang khai báo trong `mobile/pubspec.yaml`. Không suy ra mọi phiên bản Flutter 3.x đều tương thích.
- Android Studio, Android SDK, Android SDK Platform Tools, emulator (nếu chạy giả lập).
- Android toolchain hoạt động theo kết quả `flutter doctor -v`.
- Android build cấu hình Java 17 source/target, Android Gradle Plugin 9.1.0 và Gradle wrapper 9.3.1 theo repository. Khi lỗi build, kiểm tra JDK mà Gradle thực tế sử dụng.
- Một emulator Android hoặc điện thoại Android bật **Developer options > USB debugging**.
- Repository hiện chứa `mobile/android/`, **chưa chứa thư mục `mobile/ios/`**. Không coi iOS là nền tảng sẵn sàng chạy chỉ từ README.

### 2.3. Web/Express

- **Node.js >= 24.0.0** theo `package.json` (README gốc hiện ghi 20+, mâu thuẫn với engine constraint).
- npm đi kèm Node 24.
- Port `3000` khả dụng (hoặc đổi `PORT` và `APP_ORIGIN` nhất quán).

## 3. Tải mã nguồn

Tại terminal:

```bash
git clone https://github.com/nmtrucworking/dytava.git
cd dytava
git status --short
```

Nếu đã clone:

```bash
git pull origin main
```

Chạy các nhóm lệnh bên dưới **tại đúng thư mục**. Không chạy `flutter run` ở thư mục gốc và không chạy `npm run dev` trong `mobile/`.

## 4. Chạy Flutter Mobile trên Android

### 4.1. Kiểm tra toolchain

```bash
flutter --version
dart --version
flutter doctor -v
```

Nếu `flutter doctor` thông báo Android licenses chưa chấp nhận:

```bash
flutter doctor --android-licenses
```

Khắc phục lỗi do SDK/Android Studio trước khi thực hiện bước build.

### 4.2. Cài dependencies và kiểm tra thiết bị

Từ thư mục gốc repo:

```bash
cd mobile
flutter pub get
flutter devices
flutter emulators
```

Nếu chưa có thiết bị, dùng Android Studio > **Device Manager** > tạo và bật một Android Virtual Device (AVD), hoặc kết nối điện thoại Android đã bật USB debugging.

Có thể chạy emulator bằng Flutter khi đã có emulator ID:

```bash
flutter emulators --launch <emulator_id>
```

> Thay `<emulator_id>` bằng ID lấy từ `flutter emulators`; không nhập dấu ngoặc nhọn như một phần của ID.

### 4.3. Chạy ứng dụng

```bash
flutter run
```

Nếu có nhiều thiết bị:

```bash
flutter run -d <device_id>
```

Ví dụ chỉ định ID thực tế do `flutter devices` in ra. Khi chạy trong terminal, thông thường `r` thực hiện hot reload, `R` hot restart, `q` dừng ứng dụng.

### 4.4. Kiểm thử nhanh giao diện PoC

Sau khi màn hình **ExcelCompare — Semantic PoC** hiện ra:

1. Xác nhận ô A mặc định có `8.5`, ô B mặc định có `8,5`.
2. Giữ semantic dtype `decimal`.
3. Nhấn **So sánh**.
4. Kỳ vọng trạng thái hiển thị `EQUIVALENT` (theo widget test hiện có).

Đây là smoke test cho logic so sánh giá trị, **không phải kiểm thử nhập workbook, ánh xạ cột hoặc xuất báo cáo**.

### 4.5. Analyze và unit/widget test

```bash
flutter analyze
flutter test
```

Kiểm thử có trong `mobile/test/widget_test.dart` kiểm tra màn hình và trường hợp `8.5` / `8,5`.

### 4.6. Build Android APK

```bash
flutter build apk --debug
```

Đường dẫn đầu ra thông dụng:

```text
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

Với bản release:

```bash
flutter build apk --release
```

**Cảnh báo:** `mobile/android/app/build.gradle` hiện có `applicationId = 'com.example.dytava'` và `release.signingConfig = signingConfigs.debug`. Đây chưa phải cấu hình ký phát hành chính thức. Không phân phối bản release như sản phẩm production trước khi thiết lập application ID, keystore và signing phù hợp.

## 5. Chạy Pure Dart Semantic Core

Mở terminal mới tại thư mục gốc:

```bash
cd packages/excelcompare_core
dart pub get
dart analyze
dart test
```

Gói này là **proof of concept** cho một số semantic types (IDENTIFIER, FREE_TEXT, DECIMAL, BOOLEAN, PERCENTAGE), chưa phải implementation đầy đủ của đặc tả Core. Tài liệu nguồn: `packages/excelcompare_core/README.md`.

## 6. Chạy Web và Express Backend

### 6.1. Chuẩn bị môi trường

Từ **thư mục gốc** `dytava/` (không phải `web/`):

```bash
node --version
npm --version
cp .env.example .env
npm ci
```

`npm ci` dùng lockfile của repo, phù hợp cho thiết lập có thể tái lập. Có thể dùng `npm install` khi chủ động cần cập nhật lockfile.

Các giá trị mặc định quan trọng trong `.env.example`:

```dotenv
NODE_ENV=development
HOST=127.0.0.1
PORT=3000
APP_ORIGIN=http://localhost:3000
DATABASE_PATH=./data/dytava.sqlite
TRUST_PROXY=0
SESSION_DAYS=7
HISTORY_RETENTION_DAYS=30
ALLOW_REGISTRATION=true
```

> Không đưa `.env` chứa thông tin bí mật lên Git. Với cấu hình phát triển mặc định, backend sử dụng SQLite tại `data/dytava.sqlite`; thư mục và migrations được tạo/chạy khi server khởi động.

### 6.2. Khởi động development

```bash
npm run dev
```

Script hiện tại chạy `node scripts/build.js && node --watch server/index.js`:
- Biên dịch và sao chép Web assets vào `dist/` **một lần lúc khởi động**.
- Theo dõi thay đổi của tiến trình Node backend; **không nên hiểu là frontend HMR đầy đủ**.
- Mở Web: http://localhost:3000
- Kiểm tra API: http://localhost:3000/api/health

Lệnh xác minh health:

```bash
curl http://127.0.0.1:3000/api/health
```

Phản hồi dự kiến của handler hiện có:

```json
{"status":"ok","version":"1.0.0"}
```

### 6.3. Chạy không có Node watch

```bash
npm run build
npm start
```

Không sử dụng `npm start` trước khi build: `server/index.js` kiểm tra sự tồn tại của `dist/index.html` và sẽ báo lỗi khi file này chưa có.

### 6.4. Tạo tài khoản quản trị

Trong terminal riêng, tại thư mục gốc:

```bash
npm run admin:create
```

Nhập email, tên và mật khẩu **tối thiểu 12 ký tự** theo prompt. Script cũng hỗ trợ `ADMIN_EMAIL`, `ADMIN_NAME`, `ADMIN_PASSWORD` từ environment, nhưng tránh để mật khẩu trong lệnh shell lưu history.

**Không nhầm** giao diện Web quản trị (`/#/admin/...`) với một chức năng Flutter Mobile.

### 6.5. Kiểm thử Web

```bash
npm test
npm run check
```

Để chạy Playwright E2E (cần cài Chromium theo Playwright):

```bash
npx playwright install chromium
npm run test:e2e
```

`npm run test:e2e` sử dụng server kiểm thử ở `127.0.0.1:4317`, khởi động tự động bởi Playwright; không cần chạy `npm run dev` riêng cho quy trình E2E.

## 7. Checklist nghiệm thu môi trường

- [ ] `git status --short` không hiển thị thay đổi ngoài dự kiến.
- [ ] `flutter --version` cho thấy Dart SDK đáp ứng ràng buộc `^3.13.7`.
- [ ] `flutter doctor -v` xác nhận Android toolchain khả dụng.
- [ ] `flutter pub get` thành công khi đứng trong `mobile/`.
- [ ] `flutter devices` có thiết bị Android được chọn.
- [ ] `flutter run` mở được **Semantic PoC**.
- [ ] `flutter test` và `flutter analyze` hoàn tất (ghi nhận cả cảnh báo nếu có).
- [ ] `dart test` hoàn tất trong `packages/excelcompare_core/`.
- [ ] `node --version` đáp ứng `>=24.0.0`.
- [ ] `npm ci`, `npm run build`, `npm test` hoàn tất.
- [ ] `npm run dev` mở được trang Web.
- [ ] `/api/health` trả về trạng thái `ok`.

> Không điền “Đạt” cho mục nào nếu chưa chạy lệnh thực tế. Lưu phiên bản SDK và log cùng ngày kiểm thử.

## 8. Xử lý lỗi thường gặp

| Triệu chứng | Nguyên nhân cần kiểm tra | Hướng xử lý |
|---|---|---|
| `flutter: command not found` | Flutter SDK chưa cài hoặc PATH chưa đúng | Cài Flutter SDK, thêm `flutter/bin` vào PATH, mở terminal mới |
| Dart SDK không tương thích | `mobile/pubspec.yaml` yêu cầu `^3.13.7` | Dùng bản Flutter stable có Dart SDK tương ứng; kiểm tra `flutter --version` |
| `flutter pub get` không tìm được `excelcompare_core` | Chỉ copy riêng thư mục `mobile/` | Clone toàn bộ repo; đảm bảo `packages/excelcompare_core/` nằm cạnh `mobile/` |
| `No devices found` | Emulator chưa mở hoặc thiết bị không được nhận | Kiểm tra Device Manager, USB debugging, `flutter devices`, `adb devices` |
| Android/Gradle build fail | JDK, Android SDK, AGP hoặc Gradle không tương thích | Kiểm tra `flutter doctor -v`, `flutter build apk -v`, JDK Gradle và phiên bản Gradle wrapper; không thay phiên bản tùy tiện |
| `npm` báo `EBADENGINE` | Node.js thấp hơn phiên bản yêu cầu | Nâng Node.js lên 24+ |
| `Chạy npm run build trước khi khởi động.` | `dist/index.html` chưa được tạo | Chạy `npm run build` từ thư mục gốc |
| `EADDRINUSE` tại port 3000 | Port đã được ứng dụng khác sử dụng | Dừng process trùng port hoặc đổi đồng bộ `PORT` và `APP_ORIGIN` trong `.env` |
| `APP_ORIGIN ... không hợp lệ` | Giá trị origin có dấu `/` cuối hoặc cấu hình HTTPS production sai | Ví dụ development đúng: `http://localhost:3000` |
| `npm run dev` nhưng frontend không cập nhật | Script chỉ build frontend một lần | Chạy lại `npm run dev` hoặc `npm run build` |
| Kỳ vọng thấy nút nhập XLSX trong Flutter | Phiên bản mobile hiện là PoC | Kiểm tra phạm vi nguồn; tính năng đọc XLSX chưa có trong `mobile/lib/main.dart` |
| `flutter build ios` không chạy | Repo chưa có thư mục `mobile/ios/` | Chưa coi iOS là mục tiêu sẵn sàng; muốn bổ sung phải thực hiện tác vụ cấu hình nền tảng riêng và đánh giá trên macOS/Xcode |

Trước khi dùng các lệnh dọn cache như `flutter clean`, nên lưu log lỗi và thử cách sửa ít xâm lấn trước. Không xóa cơ sở dữ liệu `data/` nếu có dữ liệu cần giữ.

## 9. Ghi log thực nghiệm cho tiểu luận

Để viết **Chương 4.1 — Môi trường phát triển**, **Chương 4.6 — Đóng gói/triển khai** và **Phụ lục F — Hướng dẫn cài đặt và sử dụng**, ghi lại tối thiểu:

| Bằng chứng | Nội dung cần ghi |
|---|---|
| Cấu hình thiết bị | OS, chip/CPU, RAM, Android API, tên thiết bị hoặc emulator |
| Flutter/Dart | Kết quả `flutter --version`, `dart --version`, `flutter doctor -v` |
| Android build | Kết quả `flutter build apk --debug`, đường dẫn APK và dung lượng |
| Functional demo | Ảnh màn hình PoC, cặp A/B được thử, loại semantic, kết quả hiển thị |
| Kiểm thử tự động | Số test chạy, passed/failed, lệnh và thời điểm |
| Web/API | Node version, URL local, phản hồi `/api/health`, ảnh Web |
| Giới hạn | Chức năng đang chạy thực tế so với chức năng mới ở bản thiết kế |

Đề xuất bố cục phụ lục báo cáo: **F.1 Điều kiện tiên quyết; F.2 Cấu hình Android; F.3 Khởi chạy Flutter; F.4 Khởi chạy Web/API; F.5 Kiểm thử và build APK; F.6 Troubleshooting; F.7 Kết quả và bằng chứng thực nghiệm.**

## 10. Vị trí tài liệu nguồn trong repository

- [`README.md`](https://github.com/nmtrucworking/dytava/blob/main/README.md): giới thiệu dự án và lệnh chạy cơ bản.
- [`package.json`](https://github.com/nmtrucworking/dytava/blob/main/package.json): Node engine và scripts thực tế.
- [`mobile/pubspec.yaml`](https://github.com/nmtrucworking/dytava/blob/main/mobile/pubspec.yaml): Dart SDK, Flutter packages và assets.
- [`mobile/lib/main.dart`](https://github.com/nmtrucworking/dytava/blob/main/mobile/lib/main.dart): phạm vi mobile PoC đang triển khai.
- [`mobile/android/app/build.gradle`](https://github.com/nmtrucworking/dytava/blob/main/mobile/android/app/build.gradle): Android package và signing hiện tại.
- [`server/config.js`](https://github.com/nmtrucworking/dytava/blob/main/server/config.js): cấu hình Web/API.
- [`docs-dytava/README.md`](https://github.com/nmtrucworking/dytava/blob/main/docs-dytava/README.md): chỉ mục tài liệu thiết kế, không thay thế hướng dẫn chạy.
- [`packages/excelcompare_core/README.md`](https://github.com/nmtrucworking/dytava/blob/main/packages/excelcompare_core/README.md): phạm vi Semantic Core PoC.

---

**Đề xuất vị trí trong repo:** `docs-dytava/guides/RUN_PROJECT.md`, với đường dẫn từ `README.md` và `docs-dytava/README.md`. Tài liệu này là bản biên soạn đối chiếu source; cần ghi nhận kết quả thực thi thực tế để chuyển trạng thái sang “đã xác minh”.
