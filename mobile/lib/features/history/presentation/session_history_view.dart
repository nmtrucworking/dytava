import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';

/// Giao diện phụ trợ: Lịch sử phiên so sánh (phân trang, xóa từng mục & xóa tất cả)
class WorkflowSessionHistoryView extends StatefulWidget {
  final WorkflowController flow;
  final VoidCallback onOpenResults;
  final VoidCallback? onStartNewComparison;
  final ValueChanged<String>? onRestoreSession;
  final ValueChanged<int>? onCountChanged;

  const WorkflowSessionHistoryView({
    super.key,
    required this.flow,
    required this.onOpenResults,
    this.onStartNewComparison,
    this.onRestoreSession,
    this.onCountChanged,
  });

  @override
  State<WorkflowSessionHistoryView> createState() =>
      _WorkflowSessionHistoryViewState();
}

class _WorkflowSessionHistoryViewState extends State<WorkflowSessionHistoryView> {
  static const int _pageSize = 5;
  int _currentPage = 1;
  int _totalCount = 0;
  List<SavedSessionSummary> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPage(page: 1);
  }

  @override
  void didUpdateWidget(covariant WorkflowSessionHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow != widget.flow) {
      _loadPage(page: _currentPage);
    }
  }

  Future<void> _loadPage({int page = 1}) async {
    final count = await widget.flow.countSavedSessions();
    final maxPage = (count / _pageSize).ceil().clamp(1, 999999);
    final targetPage = page.clamp(1, maxPage);
    final offset = (targetPage - 1) * _pageSize;
    final items = await widget.flow.getRecentSavedSessions(
      limit: _pageSize,
      offset: offset,
    );

    if (mounted) {
      setState(() {
        _totalCount = count;
        _currentPage = targetPage;
        _sessions = items;
        _loading = false;
      });
      widget.onCountChanged?.call(count);
    }
  }

  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) {
      return 'Today, $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $timeStr';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = months[date.month - 1];
      return '$m ${date.day}, $timeStr';
    }
  }

  Future<bool> _confirmDeleteItem(BuildContext context, SavedSessionSummary session) async {
    final l10n = context.l10n;
    final label = session.labelA.isNotEmpty ? session.labelA : (l10n.isVietnamese ? 'Phiên đối chiếu' : 'Comparison session');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.deleteComparisonTitle,
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.deleteComparisonContent(label),
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-item'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.clearAllHistoryTitle,
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.clearAllHistoryContent,
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-clear-all'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.flow.clearAllSavedSessions();
      await _loadPage(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _sessions.isEmpty && _totalCount == 0) {
      return const SizedBox.shrink();
    }

    if (_totalCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.l10n.isVietnamese
                    ? 'Chưa có đối chiếu đã lưu'
                    : 'No saved comparisons',
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/dytava/figma/recent-empty-illustration.webp',
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        context.l10n.noComparisonsYet,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.noComparisonsSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => widget.onStartNewComparison != null
                      ? widget.onStartNewComparison!()
                      : widget.flow.navigate(WorkflowScreen.sources),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DytavaColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    context.l10n.newComparison,
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final totalPages = (_totalCount / _pageSize).ceil().clamp(1, 999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.savedComparisonsCount(_totalCount),
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              InkWell(
                key: const Key('history-clear-all-button'),
                onTap: () => _confirmClearAll(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_sweep_outlined,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.clearAll,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final s = _sessions[index];
              return Dismissible(
                key: ValueKey(s.sessionId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.delete,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (_) => _confirmDeleteItem(context, s),
                onDismissed: (_) async {
                  await widget.flow.deleteSavedSession(s.sessionId);
                  await _loadPage(page: _currentPage);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F2EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'X',
                          style: TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF107C41),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF6FAF7),
                                Color(0xFFE4F2E9),
                                Color(0xFFBDE0C9),
                              ],
                              stops: [0.0, 0.55, 1.0],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                if (widget.onRestoreSession != null) {
                                  widget.onRestoreSession!(s.sessionId);
                                } else {
                                  await widget.flow.restoreSavedSession(s.sessionId);
                                  widget.onOpenResults();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.labelA.isNotEmpty
                                                ? s.labelA
                                                : (context.l10n.isVietnamese
                                                      ? 'Phiên đối chiếu'
                                                      : 'Comparison Session'),
                                            style: const TextStyle(
                                              fontFamily: DytavaTypography.primaryFont,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_outlined,
                                                size: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  _formatSessionDate(s.createdAt),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: DytavaTypography.primaryFont,
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                '·',
                                                style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.layers_outlined,
                                                size: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  context.l10n.workbooksCount(2),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: DytavaTypography.primaryFont,
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      splashRadius: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        final ok = await _confirmDeleteItem(context, s);
                                        if (ok) {
                                          await widget.flow.deleteSavedSession(s.sessionId);
                                          await _loadPage(page: _currentPage);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (totalPages > 1)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: _currentPage > 1
                        ? () => _loadPage(page: _currentPage - 1)
                        : null,
                    color: const Color(0xFF334155),
                    disabledColor: const Color(0xFFCBD5E1),
                    splashRadius: 18,
                  ),
                  const SizedBox(width: 4),
                  for (int p = 1; p <= totalPages; p++) ...[
                    InkWell(
                      onTap: () => _loadPage(page: p),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p == _currentPage
                              ? DytavaColors.primary
                              : const Color(0xFFF1F5F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 13,
                            fontWeight: p == _currentPage
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: p == _currentPage
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    if (p < totalPages) const SizedBox(width: 6),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: _currentPage < totalPages
                        ? () => _loadPage(page: _currentPage + 1)
                        : null,
                    color: const Color(0xFF334155),
                    disabledColor: const Color(0xFFCBD5E1),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
