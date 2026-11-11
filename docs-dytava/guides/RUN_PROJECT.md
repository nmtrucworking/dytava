# Dytava — Hướng dẫn cài đặt, chạy và kiểm thử dự án

**Mã tài liệu:** DY-OPS-001  
**Phiên bản:** 1.1 — 12/11/2026  
**Repository:** https://github.com/nmtrucworking/dytava  
**Nhánh đối chiếu:** `main`  
**Tình trạng xác minh:** Đã đối chiếu cấu hình repository và hướng dẫn Android chính thức; **chưa xác minh trên máy người dùng**. Hướng dẫn bên dưới không đồng nghĩa đã build/test thành công.

> **Phạm vi:** Quy trình ưu tiên của dự án là **Flutter Mobile trên Android Emulator chạy trực tiếp ở macOS Apple Silicon + VS Code**, **không cài Android Studio và không dùng điện thoại ngoài**. Các phần Pure Dart Core và Web/Express là tùy chọn/độc lập. Đây không phải bằng chứng bản phát hành đã vượt qua kiểm thử.

## 1. Tổng quan kiến trúc chạy

| Thành phần | Đường dẫn | Công nghệ | Lệnh chính | Trạng thái phạm vi |
|---|---|---|---|---|
| Flutter Mobile | `mobile/` | Flutter + Dart | `flutter run` | PoC so sánh **hai giá trị ngữ nghĩa** |
| Semantic Core | `packages/excelcompare_core/` | Pure Dart | `dart test` | Engine PoC, một phần các semantic types |
| Web + Express | Gốc repo, `web/`, `server/` | Node.js + Express + SQLite | `npm run dev` | Ứng dụng Web và API riêng |
| Tài liệu thiết kế | `docs-dytava/` | Markdown, sơ đồ, đặc tả | Không chạy trực tiếp | Nhiều chức năng là mục tiêu thiết kế |

**Quan trọng:** Flutter demo hiện dùng `mobile/lib/main.dart` để so sánh hai giá trị A/B. Mã nguồn ghi rõ **chưa đọc Excel/CSV hoặc xuất báo cáo trong mobile**. Web có pipeline độc lập; chạy Web không đồng nghĩa chạy mobile. Flutter demo không cần khởi động Express server.

## 2. Điều kiện tiên quyết

### 2.1. Dùng chung

- Git
- Internet khi cài package và tải Android SDK/Gradle lần đầu
- Terminal và **Visual Studio Code + extension Flutter/Dart**; không cần cài Android Studio.
- Clone **toàn bộ monorepo**, vì `mobile/pubspec.yaml` tham chiếu package ở `../packages/excelcompare_core`

### 2.2. Flutter/Android — macOS Apple Silicon, không Android Studio

- Mac chip ARM64 (kiểm tra `uname -m` ra `arm64`); có dung lượng lưu trữ để tải SDK, system image, Gradle cache và AVD.
- **Flutter SDK** chứa Dart phù hợp `sdk: ^3.13.7` trong `mobile/pubspec.yaml`. Không mặc định mọi Flutter 3.x đều hợp lệ.
- **VS Code**, các extension **Flutter** và **Dart**; Git và Terminal với zsh.
- **Android SDK Command-line Tools (Mac ARM)** từ Google, **Android SDK Platform-Tools**, **Android Emulator**, **system image ARM64**, và **JDK** tương thích.
- Android trong repo dùng AGP `9.1.0`, Gradle `9.3.1` và Java source/target 17. Kiểm tra JDK mà Gradle sử dụng khi lỗi build; đừng tự ý đổi Gradle/AGP để che lỗi.
- `flutter doctor -v` phải nhận được Android toolchain. **Dòng cảnh báo riêng `Android Studio (not installed)` có thể chấp nhận** nếu toolchain, licenses, emulator đều hoạt động.
- Repo có `mobile/android/`, **chưa có `mobile/ios/`**. Đây là hướng dẫn chạy Android trên emulator, không xác nhận iOS đã chạy.

Nguồn cài đặt chính thức: [Command-line Tools](https://developer.android.com/studio#command-line-tools-only), [sdkmanager](https://developer.android.com/tools/sdkmanager), [avdmanager](https://developer.android.com/tools/avdmanager), [Emulator CLI](https://developer.android.com/studio/run/emulator-commandline), [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup).

> Google đã giới thiệu giao diện CLI mới `android sdk` / `android emulator`; tài liệu này vẫn sử dụng các lệnh `sdkmanager`, `avdmanager`, `emulator` vì chúng có sẵn trong bộ Android SDK Command-line Tools/Emulator đã lựa chọn và phù hợp với tình huống cài đặt hiện tại.

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

## 4. Chạy Flutter Mobile bằng VS Code + Android Emulator (không Android Studio)

### 4.1. Kiểm tra môi trường trên Mac

Mở Terminal tích hợp trong VS Code (hoặc Terminal macOS):

```bash
uname -m                 # Máy Apple Silicon: arm64
flutter --version        # Kiểm tra Flutter và Dart SDK
dart --version
java -version            # Kiểm tra JDK hiện có
flutter doctor -v
```

Dùng JDK tương thích Android Gradle Plugin của repo. Nếu máy chưa có JDK phù hợp và đã có Homebrew, có thể cài JDK 17:

```bash
brew install --cask temurin@17
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

Không cần cài lại JDK chỉ vì có phiên bản mới hơn nếu build hiện tại hoạt động. Nếu muốn cấu hình Flutter dùng đúng JDK vừa chọn: `flutter config --jdk-dir="$JAVA_HOME"`.

### 4.2. Tải và đặt Android SDK Command-line Tools đúng thư mục

Tải **Command line tools only → Mac (ARM)** tại https://developer.android.com/studio#command-line-tools-only. **Không** cần tải Android Studio; trên Apple Silicon không chọn Mac (Intel). Giải nén gói ZIP (tên ZIP có thể thay đổi theo thời điểm) vào `~/Downloads/dytava-sdk-unpack/` để được `~/Downloads/dytava-sdk-unpack/cmdline-tools/bin/sdkmanager`.

**Trường hợp đã xác nhận trong quá trình cài Dytava:** `sdkmanager` nằm ở `~/Downloads/dytava-sdk-unpack/cmdline-tools/bin/sdkmanager`, nhưng `PATH` lại trỏ đến `~/Library/Android/sdk/cmdline-tools/latest/bin`. Cần di chuyển thư mục giải nén vào `latest`:

```bash
SDK="$HOME/Library/Android/sdk"
SOURCE="$HOME/Downloads/dytava-sdk-unpack/cmdline-tools"
DEST="$SDK/cmdline-tools/latest"
mkdir -p "$SDK/cmdline-tools"

if [ -f "$DEST/bin/sdkmanager" ]; then
  echo "Command-line Tools đã nằm đúng thư mục."
elif [ -d "$SOURCE" ] && [ ! -e "$DEST" ]; then
  mv "$SOURCE" "$DEST"
  echo "Đã chuyển Command-line Tools vào SDK."
else
  echo "Chưa tìm được thư mục nguồn phù hợp hoặc latest đang tồn tại nhưng thiếu sdkmanager."
  find "$SDK" "$HOME/Downloads" -name sdkmanager -type f 2>/dev/null
fi
```

Cấu trúc đúng là:

```text
~/Library/Android/sdk/
└── cmdline-tools/
    └── latest/
        ├── bin/sdkmanager
        ├── bin/avdmanager
        ├── lib/
        └── source.properties
```

Tránh tạo nhầm `cmdline-tools/latest/cmdline-tools/bin/`. Không ghi đè/xóa `latest` nếu đã có cài đặt khác; kiểm tra trước.

### 4.3. Thiết lập ANDROID_HOME và PATH (zsh)

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
rehash

# Kiểm tra cả đường dẫn tuyệt đối và lệnh trong PATH
ls -l "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --version
command -v sdkmanager
sdkmanager --version
```

Nếu chạy thành công, lưu cho các Terminal sau bằng một đoạn idempotent:

```bash
touch "$HOME/.zshrc"
if ! grep -q 'Dytava Android SDK CLI' "$HOME/.zshrc"; then
  cat >> "$HOME/.zshrc" <<'EOF'

# Dytava Android SDK CLI
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
fi
source "$HOME/.zshrc"
```

**Chẩn đoán `zsh: command not found: sdkmanager`:**

```bash
find "$HOME/Library/Android/sdk" "$HOME/Downloads" -name sdkmanager -type f 2>/dev/null
echo "$ANDROID_HOME"
command -v sdkmanager
```

Nếu `find` chỉ trả đường dẫn ở Downloads, sửa bố cục thư mục ở mục 4.2; **chỉ sửa PATH không giải quyết được việc file chưa chuyển sang thư mục SDK**. Nếu lệnh đường dẫn tuyệt đối chạy được nhưng lệnh ngắn không chạy, sửa PATH ở mục 4.3.

### 4.4. Cài Android SDK, Emulator và system image ARM64

Sau khi **`sdkmanager --version` chạy được**, thực hiện:

```bash
sdkmanager --sdk_root="$ANDROID_HOME" --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-36" \
  "build-tools;36.0.0" \
  "system-images;android-35;google_apis;arm64-v8a"
```

- `platform-tools`: gồm `adb`.
- `emulator`: chạy Android ảo.
- `platforms;android-36` và `build-tools;36.0.0`: SDK/build tools ban đầu; nếu Flutter/Gradle yêu cầu phiên bản khác, cài thêm bản phù hợp.
- `system-images;android-35;google_apis;arm64-v8a`: Android 15 API 35 phù hợp Mac ARM64.

Nếu báo package không tìm thấy, xem tên package thực tế bằng `sdkmanager --list` trước khi sửa lệnh.

Đọc và chấp nhận giấy phép khi đồng ý:

```bash
sdkmanager --licenses
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor --android-licenses
flutter doctor -v
```

Trường hợp `flutter doctor` chỉ cảnh báo chưa cài **Android Studio**, có thể bỏ qua cảnh báo IDE đó; **không** bỏ qua lỗi Android toolchain/licensing.

### 4.5. Tạo Android Virtual Device (AVD) hoàn toàn bằng terminal

```bash
avdmanager list device
avdmanager list avd
```

Nếu `Dytava_API35` chưa tồn tại:

```bash
avdmanager create avd \
  -n Dytava_API35 \
  -k "system-images;android-35;google_apis;arm64-v8a"
```

Nếu được hỏi có tạo `custom hardware profile` hay không, có thể nhấn Enter để dùng mặc định. Xác nhận:

```bash
emulator -list-avds
```

Kết quả dự kiến có tên `Dytava_API35`. Không cần điện thoại thật hoặc USB debugging.

### 4.6. Khởi động Emulator và kiểm tra ADB

Mở **Terminal 1**:

```bash
emulator -avd Dytava_API35
```

Giữ cửa sổ emulator và tiến trình này mở. Khi Android khởi động, trong **Terminal 2**:

```bash
adb devices
adb shell getprop sys.boot_completed
flutter devices
```

Kỳ vọng `adb devices` hiển thị `emulator-5554   device` (ID có thể khác) và `sys.boot_completed` là `1` sau khi boot hoàn tất.

Nếu màn hình treo/đen và muốn khởi động không tải snapshot (không xóa dữ liệu người dùng):

```bash
emulator -avd Dytava_API35 -no-snapshot-load
```

Chỉ chạy lệnh đó sau khi đã dừng instance emulator cũ.

### 4.7. Chạy Dytava bằng VS Code

1. Mở VS Code, cài extension **Flutter** (và **Dart**).
2. **File → Open Folder** → chọn `dytava/mobile`.
3. Clone **toàn bộ** repo, không chỉ thư mục `mobile`, vì `../packages/excelcompare_core` là path dependency.
4. Khi emulator đã chạy, terminal trong `mobile/`:

```bash
flutter pub get
flutter analyze
flutter devices
flutter run
```

Nếu có nhiều thiết bị, dùng `flutter run -d <device-id>` với ID cụ thể từ `flutter devices`, ví dụ `flutter run -d emulator-5554` khi ID này có thực.

Trong VS Code có thể thay thế lệnh chạy bằng **Command Palette → Flutter: Select Device → chọn emulator → F5**. Trong Flutter CLI, `r` là hot reload, `R` hot restart và `q` thoát.

**Không chạy `flutter run` ở thư mục gốc monorepo.** Không cần `npm run dev` để chạy Mobile PoC.

### 4.8. Smoke test, analyze và widget test

Giao diện hiện tại trong `mobile/lib/main.dart` là **ExcelCompare — Semantic PoC**:

1. Giá trị A mặc định `8.5`, B mặc định `8,5`.
2. Chọn semantic dtype `decimal`, nhấn **So sánh**.
3. Kỳ vọng trạng thái `EQUIVALENT` theo `mobile/test/widget_test.dart`.

```bash
flutter analyze
flutter test
```

Đây là thử nghiệm so sánh **hai giá trị**; phiên bản Flutter này **chưa nhập XLSX/CSV, OCR hoặc xuất báo cáo**. Không dùng kết quả smoke test thay bằng chứng hoàn thành tính năng Android P0 trong PRD.

### 4.9. Build và cài APK vào emulator

Tại `mobile/`:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`flutter run` vốn đã build/cài/chạy trên emulator; bước `adb install` là tùy chọn. File APK debug dự kiến ở `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

**Chưa phát hành production:** `mobile/android/app/build.gradle` hiện để `applicationId = 'com.example.dytava'` và release dùng `signingConfigs.debug`. Cần cấu hình package ID, keystore và ký phát hành trước khi phân phối.

### 4.10. Các lần chạy sau (đường tắt)

Không cần cài SDK hay tạo AVD lại:

```bash
# Terminal 1
emulator -avd Dytava_API35

# Terminal 2 — khi emulator đã boot
cd /duong-dan-thuc-te/toi/dytava/mobile
flutter run
```

Thay `/duong-dan-thuc-te/toi/dytava/mobile` bằng thư mục clone thật; không tự giả định repo nằm trong `$HOME/dytava`.

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

## 7. Checklist nghiệm thu môi trường (macOS + VS Code + Emulator)

- [ ] `uname -m` trả về `arm64` (trên Apple Silicon).
- [ ] `flutter --version` có Dart SDK tương thích `^3.13.7`.
- [ ] `command -v sdkmanager` trỏ tới `~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager`.
- [ ] `sdkmanager --version`, `adb version`, `emulator -version` chạy được.
- [ ] `flutter doctor -v` không còn lỗi Android toolchain/licensing; cảnh báo không cài Android Studio được phân loại riêng.
- [ ] `emulator -list-avds` có `Dytava_API35`; `adb devices` có thiết bị trạng thái `device`.
- [ ] `flutter pub get`, `flutter analyze`, `flutter test` chạy từ `mobile/`.
- [ ] `flutter run` mở được **ExcelCompare — Semantic PoC** trên Android ảo.
- [ ] `flutter build apk --debug` tạo APK; lưu log/ảnh kết quả thực tế.
- [ ] `dart test` chạy được trong `packages/excelcompare_core/` nếu cần kiểm thử Core riêng.
- [ ] Khi cần Web độc lập: Node.js >=24, `npm ci`, `npm run build`, `npm test`, `npm run dev`, `/api/health`.

> Không đánh dấu Đạt trước khi thực thi trên máy và lưu evidence. Không cần cài Android Studio hoặc kết nối điện thoại để hoàn tất các mục Android Emulator.

## 8. Xử lý lỗi thường gặp

| Triệu chứng | Nguyên nhân cần kiểm tra | Hướng xử lý |
|---|---|---|
| `zsh: command not found: sdkmanager` | Công cụ đang trong `Downloads/dytava-sdk-unpack/cmdline-tools/bin` hoặc PATH sai | Di chuyển nguyên thư mục `cmdline-tools` vào `$ANDROID_HOME/cmdline-tools/latest`, sau đó export PATH; xem 4.2–4.3 |
| `ls .../latest/bin/sdkmanager` không tìm thấy | Cài sai cấu trúc `latest` hoặc chưa giải nén | Dùng `find "$HOME/Library/Android/sdk" "$HOME/Downloads" -name sdkmanager -type f`; kiểm tra `latest/bin` không bị lồng thư mục |
| `sdkmanager` có file nhưng không chạy | PATH, quyền chạy hoặc Java runtime | Thử `"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --version`, `ls -l` và `java -version` |
| `flutter: command not found` | Flutter chưa cài hoặc PATH thiếu | Cài Flutter SDK, thêm `flutter/bin` vào PATH |
| Dart SDK không tương thích | `mobile/pubspec.yaml` yêu cầu `^3.13.7` | Nâng Flutter phù hợp, xác minh `flutter --version` |
| `flutter pub get` không tìm được `excelcompare_core` | Chỉ copy `mobile/` | Clone toàn bộ monorepo, giữ `packages/excelcompare_core/` cạnh `mobile/` |
| `avdmanager` hoặc `emulator` không tìm thấy | Thiếu `cmdline-tools`/`emulator` package hoặc PATH | Chạy `sdkmanager --list`, cài `emulator`, kiểm tra `$ANDROID_HOME/emulator` |
| `No devices found` | Emulator chưa boot hoặc ADB chưa nhận | `emulator -list-avds`, `emulator -avd Dytava_API35`, `adb devices` |
| Emulator màn hình đen | Snapshot/renderer hoặc tăng tốc phần cứng | Đóng emulator cũ rồi thử `emulator -avd Dytava_API35 -no-snapshot-load`; đọc log |
| Android/Gradle build fail | JDK, AGP, Gradle, SDK/NDK xung đột | Ghi log `flutter build apk -v`, kiểm tra JDK Gradle, `flutter doctor -v`; không thay version tùy tiện |
| `flutter doctor` báo Android Studio not installed | IDE không cài theo chủ đích | Chấp nhận cảnh báo IDE **nếu** Android toolchain và licenses đầy đủ |
| `npm` báo `EBADENGINE` | Node.js thấp hơn `>=24` | Nâng Node.js 24+ |
| `Chạy npm run build trước khi khởi động.` | Chưa build `dist/index.html` | Từ gốc monorepo chạy `npm run build` |
| `EADDRINUSE` tại port 3000 | Port bị sử dụng | Dừng process trùng hoặc đổi `PORT` và `APP_ORIGIN` đồng bộ |
| Mong đợi giao diện Flutter nhập Excel/OCR | Mobile hiện chỉ là PoC | Không suy diễn scope từ PRD; kiểm tra `mobile/lib/main.dart` |
| `flutter build ios` thất bại | Repo chưa có `mobile/ios/` | iOS chưa phải target sẵn sàng; triển khai riêng theo kế hoạch P1 |

Trước khi dọn cache hoặc reset AVD, sao lưu log. `-wipe-data` sẽ xóa dữ liệu giả lập và không phải lựa chọn xử lý lỗi mặc định.

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

**Vị trí tài liệu:** `docs-dytava/guides/RUN_PROJECT.md`. Trạng thái là hướng dẫn được đối chiếu từ mã nguồn và tài liệu công cụ; chỉ đánh dấu đã kiểm chứng sau khi chạy trên macOS và lưu log/ảnh kết quả.
