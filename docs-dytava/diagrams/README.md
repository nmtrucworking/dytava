# Sơ đồ kiến trúc

> **Source of truth toàn hệ thống:** [Software Architecture Document](../architecture/ARCHITECTURE.md) (target app, module boundaries, dataflow, actual-vs-target). File DOT bên dưới chỉ là nguồn sơ đồ pipeline Input hiện hành, **không** phải kiến trúc toàn ứng dụng hoặc evidence code chạy.

[architecture.dot](architecture.dot) là nguồn hiện hành, thể hiện FileAccess → Preflight (1 GB/source) → streaming/spill FormatAdapter → SourceTable streams, state/gate A/B, reviewed OCR Android P0, Pure Dart Core và CSV/JSON/hai PDF. Scratch/indexes/PDF temp theo session được nối riêng. [architecture.svg](architecture.svg) được render từ DOT để xem trực tiếp. Luồng này là thiết kế DRAFT, không là evidence adapter đã triển khai.

[flutter_architecture.png](flutter_architecture.png) là hình baseline Flutter 2.2 dùng trong Master cũ, không phải bản render đồng bộ của architecture.dot. Không dùng hình cũ để xác định contract Input hiện hành.

Scope mở rộng theo [EXP-ADR](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md); [NFR](../requirements/NFR.md) sở hữu budgets, [Report spec](../specs/report/README.md) sở hữu output/template. DOT/SVG là bản tóm tắt mục tiêu, không là runtime evidence.
