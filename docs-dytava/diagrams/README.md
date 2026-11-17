# Sơ đồ kiến trúc

> **Source of truth toàn hệ thống:** [Software Architecture Document](../architecture/ARCHITECTURE.md) (target app, module boundaries, dataflow, actual-vs-target). File DOT bên dưới chỉ là nguồn sơ đồ pipeline Input hiện hành, **không** phải kiến trúc toàn ứng dụng hoặc evidence code chạy.

[architecture.dot](architecture.dot) là nguồn hiện hành, thể hiện FileAccess → Preflight (1 GB/source) → streaming/spill FormatAdapter → SourceTable streams, state/gate A/B, reviewed OCR Android P0, Pure Dart Core và CSV/JSON/hai PDF. Scratch/indexes/PDF temp theo session được nối riêng. [architecture.svg](architecture.svg) được render từ DOT để xem trực tiếp. Luồng này là thiết kế DRAFT, không là evidence adapter đã triển khai.

[flutter_architecture.png](flutter_architecture.png) là hình baseline Flutter 2.2 dùng trong Master cũ, không phải bản render đồng bộ của architecture.dot. Không dùng hình cũ để xác định contract Input hiện hành.

Scope mở rộng theo [EXP-ADR](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md); [NFR](../requirements/NFR.md) sở hữu budgets, [Report spec](../specs/report/README.md) sở hữu output/template. DOT/SVG là bản tóm tắt mục tiêu, không là runtime evidence.

## Activity ứng dụng mobile

[MOBILE_ACTIVITIES.md](MOBILE_ACTIVITIES.md) chứa tám sơ đồ activity bằng Mermaid theo PRD/SRS và UDG3.1: hành trình tổng quan, import A/B, OCR review, xác nhận plan, KEY/POSITIONAL matching, cell verdict, query/export và cancel/recovery. Mỗi sơ đồ có liên kết tới owner contracts; mô tả Android P0 mục tiêu, không phải trạng thái code đã triển khai.

## Sequence, state và các mô hình bổ sung

| Tài liệu | Nội dung |
| --- | --- |
| [MOBILE_SEQUENCES.md](MOBILE_SEQUENCES.md) | 8 sequence: import, OCR, plan/invalidation, worker/staging/publish, query/detail, export, cancel/protocol và recovery/leases |
| [MOBILE_STATES.md](MOBILE_STATES.md) | 3 máy trạng thái độc lập cho Input slot, comparison job và export attempt |
| [MOBILE_MODELS.md](MOBILE_MODELS.md) | 11 mô hình: context/use cases, components/ports, class, logical ERD, deployment, UDG layers, geometry, signatures/cache, resource/lease, extension gates và release evidence |
| [MOBILE_DIAGRAM_COVERAGE.md](MOBILE_DIAGRAM_COVERAGE.md) | Truy vết 18 FR, 12 Input requirements, 19 NFR, ADRs và 30 UDG gaps; ranh giới docs QA/runtime verification |
| [mobile-diagrams.baseline.json](mobile-diagrams.baseline.json) | Fingerprints nguồn hiện hành và danh sách 30 Mermaid/SVG; không là approval hoặc test evidence |

Nguồn chỉnh sửa nằm trong các Mermaid blocks; SVG đặt tại `mobile-activities/`, `mobile-sequences/`, `mobile-states/`, `mobile-models/`. Dùng [renderer/checker](../../scripts/render-mobile-diagrams.mjs) theo hướng dẫn trong coverage để phát hiện source drift, diagram stale, syntax hoặc link lỗi. Không đổi owner contracts chỉ để khớp sơ đồ; không dùng archive Master/UDG3.0 ghi đè contracts hiện hành.
