import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';

/// Các hàm tiện ích và thành phần giao diện dùng chung cho tầng Presentation của Workflow.
abstract final class WorkflowUiHelpers {
  static String formatEnumName(Enum value) => value.name
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
    return 'Hướng xử lý: Kiểm tra lại trạng thái nguồn dữ liệu hoặc thử nạp lại nguồn hợp lệ.';
  }
}

/// Thẻ chứa nội dung phân nhóm chuẩn Mobile UI Pattern của Dytava
class WorkflowSectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Border? border;

  const WorkflowSectionCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.color = DytavaColors.white,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: DytavaColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
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
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DytavaColors.softRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DytavaColors.different.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIllustration && i == 0) ...[
                  BrandIllustration.issue(issueList[i], size: 44),
                  const SizedBox(width: 10),
                ] else ...[
                  const BrandIcon(DytavaIcons.error, size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${issueList[i].code}: ${issueList[i].message}',
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.different,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        WorkflowUiHelpers.remediationForIssue(issueList[i]),
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textPrimary,
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
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DytavaColors.primary,
            foregroundColor: DytavaColors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconAsset != null) ...[
                BrandIcon(iconAsset!, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, style: DytavaTypography.labelLarge)),
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
  final WorkflowScreen screen;

  const DytavaGuidedStepHeader({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    final currentStep = switch (screen) {
      WorkflowScreen.home => 0,
      WorkflowScreen.sources ||
      WorkflowScreen.preview ||
      WorkflowScreen.ocrReview => 1,
      WorkflowScreen.mapping || WorkflowScreen.policy => 2,
      WorkflowScreen.progress => 3,
      WorkflowScreen.results ||
      WorkflowScreen.detail ||
      WorkflowScreen.export => 4,
    };
    final stepDetailTitle = switch (screen) {
      WorkflowScreen.home => 'Bắt đầu phiên',
      WorkflowScreen.sources => 'Bước 1/4 · Chọn & kiểm tra Nguồn A/B',
      WorkflowScreen.preview => 'Bước 1/4 · Xem trước & xác nhận bảng nguồn',
      WorkflowScreen.ocrReview => 'Bước 1/4 · Duyệt từng ô OCR mẫu',
      WorkflowScreen.mapping => 'Bước 2/4 · Ghép cột tương ứng giữa A và B',
      WorkflowScreen.policy => 'Bước 2/4 · Quy tắc chuẩn hóa & chiều so sánh',
      WorkflowScreen.progress => 'Bước 3/4 · Đang thực thi đối chiếu',
      WorkflowScreen.results => 'Bước 4/4 · Kết quả đối chiếu & sai khác',
      WorkflowScreen.detail => 'Bước 4/4 · Chi tiết bằng chứng từng ô',
      WorkflowScreen.export => 'Bước 4/4 · Xem trước & xuất báo cáo',
    };
    const steps = [
      (1, 'Nguồn', DytavaIcons.importData),
      (2, 'Cấu hình', DytavaIcons.policy),
      (3, 'So sánh', DytavaIcons.compareProgress),
      (4, 'Kết quả', DytavaIcons.compareTable),
    ];

    return Semantics(
      container: true,
      label: 'Tiến độ phiên so sánh: $stepDetailTitle',
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DytavaColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DytavaColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: currentStep > steps[i].$1 - 1
                            ? DytavaColors.primary
                            : DytavaColors.border,
                      ),
                    ),
                  Flexible(
                    flex: 2,
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentStep == steps[i].$1
                                ? DytavaColors.softBlue
                                : (currentStep > steps[i].$1
                                      ? DytavaColors.softGreen
                                      : DytavaColors.background),
                            border: Border.all(
                              color: currentStep > steps[i].$1
                                  ? DytavaColors.exact
                                  : (currentStep == steps[i].$1
                                        ? DytavaColors.primary
                                        : DytavaColors.border),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: BrandIcon(
                            currentStep > steps[i].$1
                                ? DytavaIcons.check
                                : steps[i].$3,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            steps[i].$2,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: currentStep == steps[i].$1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: currentStep == steps[i].$1
                                  ? DytavaColors.primary
                                  : DytavaColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DytavaColors.softBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'DYTAVA / PHIÊN SO SÁNH · $stepDetailTitle',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DytavaColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giao diện phụ trợ: Lịch sử phiên trong bộ nhớ tạm (chỉ hiển thị phiên đang mở theo chính sách P0)
class WorkflowSessionHistoryView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onOpenResults;
  final VoidCallback onQuickRun;

  const WorkflowSessionHistoryView({
    super.key,
    required this.flow,
    required this.onOpenResults,
    required this.onQuickRun,
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
                const BrandIcon(DytavaIcons.history, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Phiên đối chiếu trong bộ nhớ tạm',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Theo chính sách bảo mật P0, ứng dụng chỉ giữ kết quả của phiên đang mở trong bộ nhớ tạm và tự động dọn sạch khi đóng phiên.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (flow.resultCurrent && flow.result != null) ...[
              DytavaHistoryCard(
                title:
                    '${flow.slot(SourceSide.a).artifact?.label ?? 'Sheet A'} ↔ ${flow.slot(SourceSide.b).artifact?.label ?? 'Sheet B'}',
                subtitle:
                    '${flow.result!.matchedRecords} hàng ghép • ${flow.result!.cells.length} cặp ô • ${flow.result!.count(DecisionStatus.different)} khác biệt',
                badgeText: 'HIỆN HÀNH',
                onTap: onOpenResults,
              ),
              DytavaResultCard(
                fileA:
                    flow.slot(SourceSide.a).artifact?.label ?? 'sample.csv (A)',
                fileB:
                    flow.slot(SourceSide.b).artifact?.label ?? 'sample.csv (B)',
                totalPairs: flow.result!.cells.length,
                equivalentCount: flow.result!.count(DecisionStatus.equivalent),
                differentCount: flow.result!.count(DecisionStatus.different),
                unresolvedCount: flow.result!.count(DecisionStatus.unresolved),
                onTap: onOpenResults,
              ),
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: 'Mở bảng Sheet Diff 2 Sheets hiện hành',
                iconAsset: DytavaIcons.compareTable,
                onPressed: onOpenResults,
              ),
            ] else ...[
              const DytavaEmptyState(
                illustrationAsset: DytavaIllustrations.emptyHistory,
                title: 'Chưa có phiên hoàn tất',
                message:
                    'Bắt đầu phiên mới hoặc chạy trải nghiệm nhanh để xem kết quả tại đây.',
              ),
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: 'Chạy Sheet Diff 2 Bảng mẫu ngay',
                iconAsset: DytavaIcons.play,
                onPressed: onQuickRun,
              ),
            ],
          ],
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
  const WorkflowSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                BrandIllustration.securityLocal(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cài đặt đối chiếu & Quyền riêng tư',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const WorkflowInfoBanner(
              text:
                  'Chế độ Offline-First: Mọi dữ liệu bảng tính và ảnh OCR đều được xử lý cục bộ trên thiết bị.',
              iconAsset: DytavaIcons.shield,
              color: DytavaColors.exact,
              bgColor: DytavaColors.softGreen,
            ),
            const Divider(height: 24),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: BrandIcon(DytavaIcons.compareTable, size: 24),
              title: Text('Giao diện kết quả mặc định'),
              subtitle: Text('Sheet Diff 2 Sheets (Hợp nhất & Song song)'),
              trailing: WorkflowStatusPill(
                label: 'Đang bật',
                color: DytavaColors.exact,
                bg: DytavaColors.exactBg,
                iconAsset: DytavaIcons.check,
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: BrandIcon(DytavaIcons.policy, size: 24),
              title: Text('Kiến trúc thực thi'),
              subtitle: Text(
                'UDG 3.1 • Guided Mobile Workflow • Brand Assets v2.0',
              ),
              trailing: WorkflowStatusPill(
                label: 'v0.3.0',
                color: DytavaColors.primary,
                bg: DytavaColors.softBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
