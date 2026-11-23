import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';

/// Các hàm tiện ích và thành phần giao diện dùng chung cho tầng Presentation của Workflow.
abstract final class WorkflowUiHelpers {
  static String formatEnumName(Enum value) =>
      value == MatchingMode.orderedSequence
      ? 'Căn chỉnh chuỗi (chèn/xóa)'
      : value.name
            .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
            .toUpperCase();

  static String remediationForIssue(WorkflowIssue issue) {
    final code = issue.code.toUpperCase();
    if (code.contains('KEY')) {
      return 'Hướng xử lý: Chọn ít nhất 1 cột khóa kiểu IDENTIFIER và xác nhận chế độ ghép hàng.';
    }
    if (code.contains('MAP')) {
      return 'Hướng xử lý: Ghép ít nhất 1 cặp cột 1:1 giữa Nguồn A và Nguồn B rồi bấm xác nhận ánh xạ.';
    }
    if (code.contains('POLICY') || code.contains('RULE')) {
      return 'Hướng xử lý: Kiểm tra kiểu dữ liệu từng cột và đánh dấu xác nhận toàn bộ policy.';
    }
    if (code.contains('DIRECTION')) {
      return 'Hướng xử lý: Chọn chiều đối chiếu (A → B hoặc B → A) và đánh dấu xác nhận.';
    }
    if (code.contains('OCR') || code.contains('REVIEW')) {
      return 'Hướng xử lý: Mở màn hình Review để duyệt đầy đủ từng ô nhận dạng trước khi tiếp tục.';
    }
    if (code.contains('DUPLICATE')) {
      return 'Hướng xử lý: Hai tệp A và B hoàn toàn giống nhau. Hãy chọn bản cập nhật khác nếu bạn muốn tìm sai khác.';
    }
    return 'Hướng xử lý: Kiểm tra lại trạng thái nguồn dữ liệu hoặc thử nạp lại nguồn hợp lệ.';
  }
}

/// Thẻ chứa nội dung phân nhóm chuẩn Mobile UI Pattern của Dytava
class WorkflowSectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Border? border;
  final EdgeInsetsGeometry? margin;

  const WorkflowSectionCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.color = DytavaColors.white,
    this.border,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border:
            border ?? Border.all(color: DytavaColors.subtleBorder, width: 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// Khung thông báo ngữ cảnh sử dụng `BrandIcon` SVG
class WorkflowInfoBanner extends StatelessWidget {
  final String text;
  final String iconAsset;
  final Color color;
  final Color bgColor;

  const WorkflowInfoBanner({
    super.key,
    required this.text,
    this.iconAsset = DytavaIcons.info,
    this.color = DytavaColors.secondary,
    this.bgColor = DytavaColors.softBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandIcon(iconAsset, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: DytavaTypography.bodyMedium.copyWith(
                color: DytavaColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Danh sách lỗi/cảnh báo tích hợp `BrandIllustration.issue(...)` và hướng dẫn khắc phục rõ ràng
class WorkflowIssueList extends StatelessWidget {
  final Iterable<WorkflowIssue> issues;
  final bool showIllustration;

  const WorkflowIssueList({
    super.key,
    required this.issues,
    this.showIllustration = true,
  });

  @override
  Widget build(BuildContext context) {
    final issueList = issues.toList();
    if (issueList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < issueList.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: DytavaColors.softRed,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: DytavaColors.different.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIllustration && i == 0) ...[
                  BrandIllustration.issue(issueList[i], size: 24),
                  const SizedBox(width: 8),
                ] else ...[
                  const BrandIcon(DytavaIcons.error, size: 16),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issueList[i].message,
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.different,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nhãn trạng thái nhỏ gọn
class WorkflowStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final String? iconAsset;

  const WorkflowStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            BrandIcon(iconAsset!, size: 13),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu trạng thái nạp nguồn sử dụng `DytavaIcons.forInputState`
class WorkflowInputStateBadge extends StatelessWidget {
  final InputState state;

  const WorkflowInputStateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (state) {
      InputState.unselected => (
        'Chưa chọn',
        DytavaColors.textSecondary,
        DytavaColors.background,
      ),
      InputState.selected => (
        'Đã chọn',
        DytavaColors.purple,
        DytavaColors.softPurple,
      ),
      InputState.preflighting => (
        'Kiểm tra...',
        DytavaColors.secondary,
        DytavaColors.softBlue,
      ),
      InputState.parsing => (
        'Phân tích...',
        DytavaColors.secondary,
        DytavaColors.softBlue,
      ),
      InputState.needsReview => (
        'Cần review',
        DytavaColors.unresolved,
        DytavaColors.softAmber,
      ),
      InputState.previewReady => (
        'Hợp lệ',
        DytavaColors.exact,
        DytavaColors.softGreen,
      ),
      InputState.failed => (
        'Lỗi đọc',
        DytavaColors.different,
        DytavaColors.softRed,
      ),
      InputState.cancelled => (
        'Đã hủy',
        DytavaColors.textMuted,
        DytavaColors.background,
      ),
    };
    return WorkflowStatusPill(
      label: label,
      color: color,
      bg: bg,
      iconAsset: DytavaIcons.forInputState(state),
    );
  }
}

/// Ô đánh dấu xác nhận chuẩn vùng chạm 48dp
class WorkflowCheckTile extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  const WorkflowCheckTile({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: checked ? DytavaColors.softBlue : DytavaColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: checked ? DytavaColors.primary : DytavaColors.border,
            width: checked ? 1.5 : 1,
          ),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          activeColor: DytavaColors.primary,
          title: Text(
            label,
            style: DytavaTypography.bodyMedium.copyWith(
              color: DytavaColors.textPrimary,
              fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          value: checked,
          onChanged: onChanged == null
              ? null
              : (value) => onChanged!(value ?? false),
        ),
      ),
    );
  }
}

/// Thanh tác vụ dính chân trang (Sticky Bottom Bar) cho Mobile UX
/// Đảm bảo các nút hành động chính (Primary/Secondary Action) luôn nổi cố định ở đáy màn hình,
/// không bị cuộn theo nội dung trang, kèm hiệu ứng bóng mờ và viền ngăn cách sắc nét.
class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 350;
    final horizontalPad = isCompact ? 16.0 : 24.0;
    return Container(
      decoration: BoxDecoration(
        color: DytavaColors.background,
        border: const Border(
          top: BorderSide(color: DytavaColors.subtleBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: padding ?? EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 8),
      child: SafeArea(
        top: false,
        child: child,
      ),
    );
  }
}

/// Bố cục màn hình Workflow với thanh nút hành động Sticky ở chân trang.
/// Tự động thích ứng:
/// - Khi màn hình có chiều cao giới hạn (trong app chuẩn): Phần nội dung cuộn khi cần (`Expanded` + `SingleChildScrollView`),
///   sử dụng `ClampingScrollPhysics` để không bị scroll khi nội dung vừa vặn màn hình.
/// - Nút bấm dính cố định (`StickyBottomBar`) ở chân trang.
/// - Khi bị bọc trong Scrollable ngoài (ví dụ trong widget test): Tự động hiển thị dạng Column không flex để tránh lỗi unbounded height.
class WorkflowScreenLayout extends StatelessWidget {
  final Widget content;
  final Widget? bottomBar;
  final EdgeInsetsGeometry contentPadding;
  final ScrollPhysics physics;

  const WorkflowScreenLayout({
    super.key,
    required this.content,
    this.bottomBar,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
    this.physics = const ClampingScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: physics,
                  padding: contentPadding,
                  child: content,
                ),
              ),
              ?bottomBar,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: contentPadding,
                child: content,
              ),
              ?bottomBar,
            ],
          );
        }
      },
    );
  }
}

/// Nút bấm chính chiều rộng đầy đủ (tối thiểu 48×48dp)
class WorkflowPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? iconAsset;

  const WorkflowPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed == null
              ? null
              : () {
                  DytavaAudioFeedback.playClick();
                  onPressed!();
                },
          style: FilledButton.styleFrom(
            backgroundColor: DytavaColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF64748B),
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          child: Row(
            children: [
              if (iconAsset != null) const SizedBox(width: 26),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: DytavaTypography.labelLarge.copyWith(
                    fontSize: 15,
                    color: onPressed == null
                        ? DytavaColors.textSecondary
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (iconAsset != null) ...[
                const SizedBox(width: 8),
                BrandIcon(
                  iconAsset!,
                  size: 18,
                  color: onPressed == null
                      ? DytavaColors.textSecondary
                      : Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút bấm phụ (Secondary Action: Trở về, Quay lại, Hủy, Thao tác bổ trợ)
class WorkflowSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final IconData? icon;

  const WorkflowSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconAsset,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  DytavaAudioFeedback.playClick();
                  onPressed!();
                },
          style: OutlinedButton.styleFrom(
            backgroundColor: DytavaColors.surface,
            foregroundColor: DytavaColors.textPrimary,
            side: const BorderSide(
              color: DytavaColors.subtleBorder,
              width: 1.0,
            ),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: DytavaColors.textPrimary),
                const SizedBox(width: 8),
              ] else if (iconAsset != null) ...[
                BrandIcon(iconAsset!, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: DytavaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh tiến trình 4 bước Guided Mobile Workflow (`Nguồn → Cấu hình → So sánh → Kết quả`)
/// Sử dụng `BrandIcon` SVG chính thức của Dytava.
class DytavaGuidedStepHeader extends StatelessWidget {
  const DytavaGuidedStepHeader({super.key, required this.screen});
  final WorkflowScreen screen;
  @override
  Widget build(BuildContext context) {
    final step = screen == WorkflowScreen.mapping ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 2; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? DytavaColors.primary
                          : DytavaColors.primaryLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ADVANCED COMPARE · STEP $step OF 2',
            style: DytavaTypography.labelSmall.copyWith(
              color: DytavaColors.primary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final label = session.labelA.isNotEmpty ? session.labelA : 'Comparison session';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete comparison?',
          style: TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$label" from your comparison history?',
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear all history?',
          style: TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'All saved comparison sessions will be permanently removed. This action cannot be undone.',
          style: TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
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
            child: const Text('Clear all'),
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
                      const Text(
                        'No comparisons yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Compare two spreadsheets to find changes,\nreview differences, and save your results here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                  child: const Text(
                    '+ New Comparison',
                    style: TextStyle(
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
        // Top action bar: session count and Clear All button
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_totalCount saved comparison${_totalCount == 1 ? '' : 's'}',
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Clear all',
                        style: TextStyle(
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

        // Session list
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF1F8F4), Color(0xFFE4F2EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD6E8DC), width: 1.0),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (widget.onRestoreSession != null) {
                          widget.onRestoreSession!(s.sessionId);
                        } else {
                          await widget.flow.restoreSavedSession(s.sessionId);
                          widget.onOpenResults();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F3E9),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.labelA.isNotEmpty ? s.labelA : 'Comparison Session',
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
                                      Text(
                                        _formatSessionDate(s.createdAt),
                                        style: const TextStyle(
                                          fontFamily: DytavaTypography.primaryFont,
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
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
                                      const Text(
                                        '2 workbooks',
                                        style: TextStyle(
                                          fontFamily: DytavaTypography.primaryFont,
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
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
                                color: Color(0xFF94A3B8),
                              ),
                              splashRadius: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final ok = await _confirmDeleteItem(context, s);
                                if (ok) {
                                  await widget.flow.deleteSavedSession(s.sessionId);
                                  await _loadPage(page: _currentPage);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF107C41),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Pagination Bar
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p == _currentPage
                              ? DytavaColors.primary
                              : const Color(0xFFF1F5F2),
                          borderRadius: BorderRadius.circular(8),
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

/// Giao diện phụ trợ: Mẫu quy tắc chuẩn hóa & Giải thích 4 trạng thái quyết định
class WorkflowLearnAndPresetsView extends StatelessWidget {
  final String selectedPreset;
  final ValueChanged<String> onSelectPreset;

  const WorkflowLearnAndPresetsView({
    super.key,
    required this.selectedPreset,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.saveRule, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mẫu quy tắc chuẩn hóa (Policy Presets)',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Các bộ quy tắc chuẩn hóa định dạng số thập phân, khoảng trắng, định danh và sai số tuyệt đối.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 10),
            DytavaPolicyCard(
              policyId: 'academic-records-v1',
              subtitle:
                  'v1.0.0 • 2 trường • Khóa: id • Dấu thập phân A(.) / B(,)',
              active: selectedPreset == 'academic-records-v1',
              onTap: () => onSelectPreset('academic-records-v1'),
            ),
            DytavaPolicyCard(
              policyId: 'financial-reconcile-v1',
              subtitle: 'v1.0.0 • Đối soát kế toán • Sai số tuyệt đối: 0.01',
              active: selectedPreset == 'financial-reconcile-v1',
              onTap: () => onSelectPreset('financial-reconcile-v1'),
            ),
            DytavaPolicyCard(
              policyId: 'inventory-sku-strict',
              subtitle:
                  'v1.0.0 • Mã SKU strict identifier • Giữ số 0 đầu (00123)',
              active: selectedPreset == 'inventory-sku-strict',
              onTap: () => onSelectPreset('inventory-sku-strict'),
            ),
          ],
        ),
        WorkflowSectionCard(
          children: [
            Center(
              child: BrandIllustration.onboarding(
                DytavaIllustrations.onboardingCompare,
                maxHeight: 84,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ý nghĩa 4 trạng thái đối chiếu',
              style: DytavaTypography.titleLarge.copyWith(
                color: DytavaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DytavaStatusBadge.exact(),
                DytavaStatusBadge.equivalent(),
                DytavaStatusBadge.different(),
                DytavaStatusBadge.unresolved(),
                DytavaStatusBadge.added(),
                DytavaStatusBadge.removed(),
              ],
            ),
            const Divider(height: 24),
            Text(
              '• Trùng khớp (EXACT): Giống nhau cả ký tự gốc và giá trị ngữ nghĩa.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '• Tương đương (EQUIVALENT): Khác cách viết (ví dụ 8.5 và 8,5) nhưng bằng nhau sau khi chuẩn hóa.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '• Khác biệt (DIFFERENT): Hai ô có giá trị khác nhau sau khi chuẩn hóa.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '• Chưa kết luận (UNRESOLVED): Không đủ căn cứ kết luận (ví dụ lỗi kiểu dữ liệu abc vs 9, hoặc trùng/rỗng khóa).',
              style: DytavaTypography.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

/// Giao diện phụ trợ: Cài đặt & Quyền riêng tư
class WorkflowSettingsView extends StatelessWidget {
  const WorkflowSettingsView({
    super.key,
    required this.flow,
    required this.onOpenPresets,
  });
  final WorkflowController flow;
  final VoidCallback onOpenPresets;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label('COMPARISON'),
      _tile(
        'Compare mode',
        'Quick Compare',
        'Propose mappings; confirm uncertain matches.',
      ),
      _tile(
        'Comparison rules',
        'Configure ›',
        'Values, spaces and text case.',
        onTap: () => _rules(context),
      ),
      _tile(
        'Rule presets',
        'View ›',
        'Explore the available comparison rules.',
        onTap: onOpenPresets,
      ),
      _label('DEVICE & DATA'),
      _tile(
        'Session storage',
        'In memory',
        'Data is cleared when you close the comparison.',
      ),
      _tile(
        'Privacy',
        'On this device',
        'Files are processed locally. Reports save to a location you choose.',
      ),
      _label('ABOUT DYTAVA'),
      _tile('Dytava', 'Version 1.0.0', 'Two spreadsheets. One clear view.'),
    ],
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 12),
    child: Text(
      text,
      style: DytavaTypography.labelSmall.copyWith(
        color: DytavaColors.primary,
        fontSize: 11,
      ),
    ),
  );
  Widget _tile(
    String title,
    String value,
    String subtitle, {
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(title, style: DytavaTypography.titleSmall),
                  Text(
                    value,
                    style: DytavaTypography.bodyMedium.copyWith(
                      color: DytavaColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: DytavaTypography.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _rules(BuildContext context) async {
    var policy = flow.config.webPolicy;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Comparison settings',
                  style: DytavaTypography.displayMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose what counts as a difference.',
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                Material(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Ignore text case',
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Treat “Excel” and “excel” as equal.',
                          style: DytavaTypography.bodySmall,
                        ),
                        value: !policy.caseSensitiveText,
                        onChanged: (v) => update(
                          () => policy = WebComparisonPolicy(
                            trimText: policy.trimText,
                            caseSensitiveText: !v,
                            preserveLeadingZeros: policy.preserveLeadingZeros,
                            caseSensitiveIdentifier:
                                policy.caseSensitiveIdentifier,
                            distinctNullZero: policy.distinctNullZero,
                            treatOrdinalAsMetadata:
                                policy.treatOrdinalAsMetadata,
                          ),
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16, height: 1),
                      SwitchListTile(
                        title: const Text(
                          'Trim spaces',
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Ignore spaces around text.',
                          style: DytavaTypography.bodySmall,
                        ),
                        value: policy.trimText,
                        onChanged: (v) => update(
                          () => policy = WebComparisonPolicy(
                            trimText: v,
                            caseSensitiveText: policy.caseSensitiveText,
                            preserveLeadingZeros: policy.preserveLeadingZeros,
                            caseSensitiveIdentifier:
                                policy.caseSensitiveIdentifier,
                            distinctNullZero: policy.distinctNullZero,
                            treatOrdinalAsMetadata:
                                policy.treatOrdinalAsMetadata,
                          ),
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16, height: 1),
                      SwitchListTile(
                        title: const Text(
                          'Preserve leading zeros',
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Keep “001” distinct from “1”.',
                          style: DytavaTypography.bodySmall,
                        ),
                        value: policy.preserveLeadingZeros,
                        onChanged: (v) => update(
                          () => policy = WebComparisonPolicy(
                            trimText: policy.trimText,
                            caseSensitiveText: policy.caseSensitiveText,
                            preserveLeadingZeros: v,
                            caseSensitiveIdentifier:
                                policy.caseSensitiveIdentifier,
                            distinctNullZero: policy.distinctNullZero,
                            treatOrdinalAsMetadata:
                                policy.treatOrdinalAsMetadata,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'These rules apply to the current session.',
                  style: DytavaTypography.bodySmall,
                ),
                WorkflowPrimaryButton(
                  label: 'Save settings',
                  onPressed: () {
                    flow.configure(flow.config.copyWith(webPolicy: policy));
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
