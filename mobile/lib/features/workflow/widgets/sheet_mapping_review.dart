import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../domain/workflow.dart';
import '../../../domain/workbook_comparison.dart';

import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../domain/workbook_comparison.dart';

/// Thẻ hiển thị và điều chỉnh ánh xạ sheet trong toàn bộ workbook (Precision Workspace v3.2).
/// Khi tất cả sheet đã khớp tự động, thu gọn mặc định thành 1 dòng trạng thái trực quan,
/// cho phép người dùng mở rộng để xem chi tiết các cặp sheet.
class SheetMappingReview extends StatefulWidget {
  const SheetMappingReview({super.key, required this.flow});
  final WorkflowController flow;

  @override
  State<SheetMappingReview> createState() => _SheetMappingReviewState();
}

class _SheetMappingReviewState extends State<SheetMappingReview> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Nếu có sheet chưa ghép, mặc định mở rộng để người dùng thao tác
    _expanded = widget.flow.sheetMapping?.complete == false;
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final plan = flow.sheetMapping;
    if (plan == null) return const SizedBox.shrink();
    final a = workbookTables(flow.slot(SourceSide.a).snapshot!),
        b = workbookTables(flow.slot(SourceSide.b).snapshot!);

    final warnings = {
      ...flow.slot(SourceSide.a).snapshot!.warnings,
      ...flow.slot(SourceSide.b).snapshot!.warnings,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: DytavaColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: plan.complete
              ? DytavaColors.primary.withValues(alpha: 0.15)
              : DytavaColors.unresolved.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      plan.complete
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      size: 18,
                      color: plan.complete
                          ? DytavaColors.primary
                          : DytavaColors.unresolved,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.complete
                                ? 'Đã ghép ${plan.pairs.length} cặp sheet'
                                : 'Cần xác nhận ${plan.unresolvedA.length} cặp sheet',
                            style: DytavaTypography.titleSmall.copyWith(
                              color: DytavaColors.primaryDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${a.length} sheet A · ${b.length} sheet B${plan.complete ? ' · Khớp tự động' : ''}',
                            style: DytavaTypography.bodySmall.copyWith(
                              fontSize: 10,
                              color: DytavaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: DytavaColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 10),
                  for (final pair in plan.pairs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.table_chart_outlined,
                            size: 13,
                            color: DytavaColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pair.label,
                              style: DytavaTypography.bodySmall.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: DytavaColors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: DytavaColors.border),
                            ),
                            child: Text(
                              pair.method,
                              style: const TextStyle(
                                fontSize: 9,
                                color: DytavaColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!plan.complete) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Chọn các cặp còn mơ hồ. Không dùng thứ tự tab để ghép.',
                      style: TextStyle(
                        fontSize: 11,
                        color: DytavaColors.textSecondary,
                      ),
                    ),
                    for (final i in plan.unresolvedA)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            '${flow.slot(SourceSide.a).generation}:${a[i].sheetName}:${flow.sheetOverrides.length}',
                          ),
                          decoration: InputDecoration(
                            labelText: '${a[i].sheetName ?? 'Bảng A'} (A)',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            for (final j in plan.unresolvedB)
                              DropdownMenuItem(
                                value: '$j',
                                child: Text(
                                  b[j].sheetName ?? 'Bảng B',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            const DropdownMenuItem(
                              value: 'NONE',
                              child: Text(
                                'Chỉ có ở A',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: flow.busy
                              ? null
                              : (v) {
                                  if (v != null) {
                                    flow.resolveSheetPair(
                                      a[i].sheetName ?? '',
                                      v == 'NONE'
                                          ? null
                                          : b[int.parse(v)].sheetName ?? '',
                                    );
                                  }
                                },
                        ),
                      ),
                    TextButton(
                      onPressed: flow.busy
                          ? null
                          : () {
                              final namesA = [
                                    for (final i in plan.unresolvedA)
                                      a[i].sheetName ?? '',
                                  ],
                                  namesB = [
                                    for (final j in plan.unresolvedB)
                                      b[j].sheetName ?? '',
                                  ];
                              for (final name in namesA) {
                                flow.resolveSheetPair(name, null);
                              }
                              for (final name in namesB) {
                                flow.resolveSheetPair(null, name);
                              }
                            },
                      child: const Text(
                        'Giữ riêng tất cả sheet chưa ghép',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DytavaColors.softAmber.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 13,
                            color: DytavaColors.unresolved,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              warnings.first,
                              style: const TextStyle(
                                fontSize: 10,
                                color: DytavaColors.unresolved,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
