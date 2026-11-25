import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';

export '../../history/presentation/session_history_view.dart';
export '../../settings/presentation/settings_and_presets_view.dart';

/// Các hàm tiện ích và thành phần giao diện dùng chung cho tầng Presentation của Workflow.
abstract final class WorkflowUiHelpers {
  static String formatEnumName(Enum value, [AppLocalizations? l10n]) {
    final loc = l10n ?? AppLocalizations.current;
    return value == MatchingMode.orderedSequence
        ? (loc.isVietnamese ? 'Căn chỉnh chuỗi (chèn/xóa)' : 'Sequence alignment (insert/delete)')
        : value.name
              .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
              .toUpperCase();
  }

  static String remediationForIssue(WorkflowIssue issue, [AppLocalizations? l10n]) {
    final loc = l10n ?? AppLocalizations.current;
    final code = issue.code.toUpperCase();
    if (code.contains('KEY')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Chọn ít nhất 1 cột khóa kiểu IDENTIFIER và xác nhận chế độ ghép hàng.'
          : 'Action: Choose at least one IDENTIFIER key column and confirm row matching mode.';
    }
    if (code.contains('MAP')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Ghép ít nhất 1 cặp cột 1:1 giữa Nguồn A và Nguồn B rồi bấm xác nhận ánh xạ.'
          : 'Action: Pair at least one 1:1 column pair between Source A and Source B, then confirm mapping.';
    }
    if (code.contains('POLICY') || code.contains('RULE')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Kiểm tra kiểu dữ liệu từng cột và đánh dấu xác nhận toàn bộ policy.'
          : 'Action: Check column data types and confirm all policies.';
    }
    if (code.contains('DIRECTION')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Chọn chiều đối chiếu (A → B hoặc B → A) và đánh dấu xác nhận.'
          : 'Action: Choose comparison direction (A → B or B → A) and confirm.';
    }
    if (code.contains('OCR') || code.contains('REVIEW')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Mở màn hình Review để duyệt đầy đủ từng ô nhận dạng trước khi tiếp tục.'
          : 'Action: Open the Review screen to inspect all recognized cells before proceeding.';
    }
    if (code.contains('DUPLICATE')) {
      return loc.isVietnamese
          ? 'Hướng xử lý: Hai tệp A và B hoàn toàn giống nhau. Hãy chọn bản cập nhật khác nếu bạn muốn tìm sai khác.'
          : 'Action: File A and File B are identical. Choose a different updated file if you wish to find differences.';
    }
    return loc.isVietnamese
        ? 'Hướng xử lý: Kiểm tra lại trạng thái nguồn dữ liệu hoặc thử nạp lại nguồn hợp lệ.'
        : 'Action: Check source data status or re-import valid sources.';
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
