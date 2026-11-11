# Sơ đồ kiến trúc

[architecture.dot](architecture.dot) là nguồn hiện hành, thể hiện FileAccess → Preflight → FormatAdapter → SourceTable, state/gate A/B và ranh giới Pure Dart Core. [architecture.svg](architecture.svg) được render từ DOT để xem trực tiếp. Luồng này là thiết kế DRAFT, không là evidence adapter đã triển khai.

[flutter_architecture.png](flutter_architecture.png) là hình baseline Flutter 2.2 dùng trong Master cũ, không phải bản render đồng bộ của architecture.dot. Không dùng hình cũ để xác định contract Input hiện hành.
