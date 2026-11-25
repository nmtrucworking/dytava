import 'dart:async' show unawaited;

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';
import '../../workflow/widgets/workflow_common_widgets.dart';

/// Giao diện phụ trợ: Mẫu quy tắc chuẩn hóa & Giải thích 4 trạng thái quyết định (Chuẩn Mobile-First Dytava Visual)
class WorkflowLearnAndPresetsView extends StatelessWidget {
  final WorkflowController? flow;
  final String selectedPreset;
  final ValueChanged<String> onSelectPreset;

  const WorkflowLearnAndPresetsView({
    super.key,
    this.flow,
    required this.selectedPreset,
    required this.onSelectPreset,
  });

  void _selectAndNotify(
    BuildContext context,
    String id,
    String title,
  ) {
    DytavaAudioFeedback.playClick();
    onSelectPreset(id);
    final isVi = context.l10n.isVietnamese;
    DytavaToast.success(
      context,
      isVi
          ? 'Đã áp dụng mẫu quy tắc "$title" cho cấu hình đối chiếu.'
          : 'Applied rule preset "$title" to comparison settings.',
      title: isVi ? 'Đã chọn mẫu quy tắc' : 'Rule preset applied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isVi = l10n.isVietnamese;

    final presets = [
      (
        id: 'academic-records-v1',
        title: isVi ? 'Bảng điểm & Hồ sơ đào tạo' : 'Academic & Training Records',
        subtitle: isVi
            ? 'Chuẩn hóa dấu thập phân giữa hệ thống Việt Nam (dấu phẩy) và Quốc tế (dấu chấm), tự động cắt khoảng trắng dư.'
            : 'Normalizes decimal separators between dot (.) and comma (,) formats and trims surrounding whitespaces.',
        tags: isVi
            ? ['Khóa: ID', 'Thập phân A(.) / B(,)', 'Cắt khoảng trắng']
            : ['Key: ID', 'Decimal A(.) / B(,)', 'Trim spaces'],
      ),
      (
        id: 'financial-reconcile-v1',
        title: isVi ? 'Đối soát Tài chính & Kế toán' : 'Financial & Accounting Reconcile',
        subtitle: isVi
            ? 'Đối chiếu sổ cái, báo cáo doanh thu và hóa đơn với dung sai làm tròn số thập phân 0.01.'
            : 'Reconciles ledgers, revenue sheets, and invoices with a 0.01 rounding tolerance.',
        tags: isVi
            ? ['Dung sai: ±0.01', 'Số thập phân', 'Không phân biệt hoa/thường']
            : ['Tolerance: ±0.01', 'Decimal numbers', 'Case insensitive'],
      ),
      (
        id: 'inventory-sku-strict',
        title: isVi ? 'Danh mục Kho & Mã định danh SKU' : 'Inventory & Strict SKU Identifiers',
        subtitle: isVi
            ? 'So khớp nghiêm ngặt từng ký tự mã hàng hóa, bảo toàn số 0 đứng đầu (00123 ≠ 123) và phân biệt chữ hoa/thường.'
            : 'Strict character matching for product codes, preserving leading zeros (00123 ≠ 123) and text case.',
        tags: isVi
            ? ['Giữ số 0 đầu', 'Phân biệt hoa/thường', 'Khớp chính xác']
            : ['Keep leading zeros', 'Case sensitive', 'Strict match'],
      ),
    ];

    final statusItems = [
      (
        badge: DytavaStatusBadge.exact(),
        title: isVi ? 'Trùng khớp hoàn toàn' : 'Exact Match',
        desc: isVi
            ? 'Hai ô giống hệt nhau cả về chuỗi ký tự gốc lẫn giá trị ngữ nghĩa.'
            : 'Both cells are identical in raw text representation and semantic value.',
        bg: const Color(0xFFF4FAF6),
        border: const Color(0xFFD0E6D8),
      ),
      (
        badge: DytavaStatusBadge.equivalent(),
        title: isVi ? 'Tương đương ngữ nghĩa' : 'Semantic Equivalent',
        desc: isVi
            ? 'Khác cách biểu diễn (ví dụ 8.5 và 8,5 hoặc khoảng trắng) nhưng bằng nhau sau chuẩn hóa.'
            : 'Different raw formatting (e.g. 8.5 vs 8,5 or spaces) but equal after normalization.',
        bg: const Color(0xFFF6FBF4),
        border: const Color(0xFFD8E8D2),
      ),
      (
        badge: DytavaStatusBadge.different(),
        title: isVi ? 'Khác biệt giá trị' : 'Value Difference',
        desc: isVi
            ? 'Hai ô có giá trị khác nhau thực sự sau khi đã áp dụng bộ quy tắc chuẩn hóa.'
            : 'Cells contain genuinely different values after applying normalization rules.',
        bg: const Color(0xFFFEF7F6),
        border: const Color(0xFFF5D0CA),
      ),
      (
        badge: DytavaStatusBadge.unresolved(),
        title: isVi ? 'Cần xem xét (Chưa kết luận)' : 'Needs Review (Unresolved)',
        desc: isVi
            ? 'Xung đột kiểu dữ liệu (ví dụ chữ vs số) hoặc khóa bị trùng/rỗng, không tự ý suy diễn.'
            : 'Data type conflict (e.g. text vs number) or duplicate/missing keys; no match is guessed.',
        bg: const Color(0xFFFFFBF2),
        border: const Color(0xFFF7E2B8),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DytavaFadeSlide.staggered(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E5332), Color(0xFF187246)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F5B38).withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome_mosaic_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'MẪU QUY TẮC ĐỐI CHIẾU' : 'COMPARISON RULE PRESETS',
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVi
                            ? 'Chuẩn hóa dữ liệu tự động'
                            : 'Automated Data Normalization',
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVi
                            ? 'Chạm vào mẫu bên dưới để áp dụng ngay cho phiên đối chiếu.'
                            : 'Tap a preset below to apply it directly to your comparison.',
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DytavaFadeSlide.staggered(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              isVi ? 'BỘ QUY TẮC CÓ SẴN' : 'AVAILABLE PRESETS',
              style: DytavaTypography.labelSmall.copyWith(
                color: DytavaColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        for (var i = 0; i < presets.length; i++)
          DytavaFadeSlide.staggered(
            index: i + 2,
            child: DytavaPolicyCard(
              key: ValueKey('preset-card-${presets[i].id}'),
              policyId: presets[i].id,
              title: presets[i].title,
              subtitle: presets[i].subtitle,
              tags: presets[i].tags,
              active: selectedPreset == presets[i].id,
              onTap: () => _selectAndNotify(
                context,
                presets[i].id,
                presets[i].title,
              ),
            ),
          ),
        const SizedBox(height: 8),
        DytavaFadeSlide.staggered(
          index: 5,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              isVi ? 'Ý NGHĨA TRẠNG THÁI ĐỐI CHIẾU' : 'COMPARISON VERDICT GUIDE',
              style: DytavaTypography.labelSmall.copyWith(
                color: DytavaColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 6,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < statusItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusItems[i].bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusItems[i].border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                statusItems[i].title,
                                style: const TextStyle(
                                  fontFamily: DytavaTypography.primaryFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            statusItems[i].badge,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusItems[i].desc,
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            height: 1.38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Giao diện phụ trợ: Cài đặt & Quyền riêng tư (Nâng cấp theo thiết kế P1 · 11 App settings)
class WorkflowSettingsView extends StatefulWidget {
  const WorkflowSettingsView({
    super.key,
    required this.flow,
    required this.onOpenPresets,
  });
  final WorkflowController flow;
  final VoidCallback onOpenPresets;

  @override
  State<WorkflowSettingsView> createState() => _WorkflowSettingsViewState();
}

class _WorkflowSettingsViewState extends State<WorkflowSettingsView> {
  int _storageBytes = 0;
  int _activeMemoryBytes = 0;
  int _savedSessionCount = 0;
  bool _loadingStorage = true;

  WorkflowController get flow => widget.flow;

  @override
  void initState() {
    super.initState();
    _refreshStorageInfo();
  }

  @override
  void didUpdateWidget(covariant WorkflowSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow != widget.flow) {
      _refreshStorageInfo();
    }
  }

  Future<void> _refreshStorageInfo() async {
    try {
      final bytes = await flow.getPersistentStorageUsageBytes();
      final ramBytes = flow.getActiveSessionMemoryBytes();
      final count = await flow.countSavedSessions();
      if (mounted) {
        setState(() {
          _storageBytes = bytes;
          _activeMemoryBytes = ramBytes;
          _savedSessionCount = count;
          _loadingStorage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStorage = false);
      }
    }
  }

  String _activeCompareModeBadge(AppLocalizations l10n) {
    return switch (flow.config.mode) {
      MatchingMode.positional => l10n.quickBadge,
      MatchingMode.key => l10n.isVietnamese ? 'Theo khóa' : 'By Key',
      MatchingMode.orderedSequence =>
        l10n.isVietnamese ? 'Tuần tự' : 'Sequence',
    };
  }

  String _activeCompareModeSubtitle(AppLocalizations l10n) {
    return switch (flow.config.mode) {
      MatchingMode.positional => l10n.compareModeDesc,
      MatchingMode.key =>
        l10n.isVietnamese
            ? 'Khớp bản ghi theo cột khóa định danh (ID, Mã, SKU).'
            : 'Match records using identifier key columns (ID, Code, SKU).',
      MatchingMode.orderedSequence =>
        l10n.isVietnamese
            ? 'Căn chỉnh chuỗi tuần tự tự động phát hiện dòng chèn/xóa.'
            : 'Sequence alignment detecting inserted and deleted rows.',
    };
  }

  String _activeComparisonRulesSummary(AppLocalizations l10n) {
    final p = flow.config.webPolicy;
    final parts = <String>[
      l10n.isVietnamese ? 'Chỉ giá trị' : 'Values only',
      p.caseSensitiveText
          ? (l10n.isVietnamese ? 'Phân biệt hoa/thường' : 'Case sensitive')
          : (l10n.isVietnamese ? 'Không phân biệt hoa/thường' : 'Ignore case'),
      p.trimText
          ? (l10n.isVietnamese ? 'Bỏ khoảng trắng' : 'Trim spaces')
          : (p.preserveLeadingZeros
                ? (l10n.isVietnamese ? 'Giữ số 0 đầu' : 'Keep leading zeros')
                : (l10n.isVietnamese ? 'Không dung sai' : 'No tolerance')),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storageLabel = _loadingStorage
        ? '…'
        : WorkflowController.formatStorageBytes(_storageBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DytavaFadeSlide.staggered(
          index: 0,
          child: _buildBrandHeader(context),
        ),
        DytavaFadeSlide.staggered(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(l10n.sectionLanguage),
              _languageTile(context),
            ],
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(l10n.sectionComparison),
              _compareModeTile(context),
            ],
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 3,
          child: _actionTile(
            key: const ValueKey('settings-comparison-rules-tile'),
            title: l10n.comparisonRulesSetting,
            subtitle: _activeComparisonRulesSummary(l10n),
            trailing: _circleIconBadge(Icons.tune_rounded),
            onTap: () => _rules(context),
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 4,
          child: _actionTile(
            key: const ValueKey('settings-rule-presets-tile'),
            title: l10n.rulePresetsSetting,
            subtitle: l10n.rulePresetsDesc,
            trailing: _circleIconBadge(Icons.tune_rounded),
            onTap: widget.onOpenPresets,
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(l10n.sectionDeviceData),
              _actionTile(
                key: const ValueKey('settings-local-storage-tile'),
                title: l10n.localStorageSetting,
                subtitle: l10n.localStorageDesc,
                trailing: Text(
                  storageLabel,
                  key: const ValueKey('settings-local-storage-value'),
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DytavaColors.primary,
                  ),
                ),
                onTap: () => _openLocalStorageSheet(context),
              ),
            ],
          ),
        ),
        DytavaFadeSlide.staggered(
          index: 6,
          child: _actionTile(
            key: const ValueKey('settings-privacy-tile'),
            title: l10n.privacySetting,
            subtitle: l10n.privacyShortDesc,
            trailing: _circleIconBadge(Icons.menu_book_rounded),
            onTap: () => _openPrivacySheet(context),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EC),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14532D).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/dytava/figma/launch-mark.svg',
              width: 46,
              height: 42,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dytava',
            style: TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Color(0xFF165B33),
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.appSubtitle} · v0.1.0',
            style: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D6A4F),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              key: const ValueKey('settings-help-support-button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                DytavaAudioFeedback.playClick();
                _openHelpSupportSheet(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.helpAndSupport,
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DytavaColors.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: DytavaColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTile(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.languageTitle,
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.languageSubtitle,
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _languagePillButton(
                    key: const ValueKey('settings-language-en'),
                    label: 'English',
                    selected: !l10n.isVietnamese,
                    onTap: () => flow.setLocale(const Locale('en')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _languagePillButton(
                    key: const ValueKey('settings-language-vi'),
                    label: 'Tiếng Việt',
                    selected: l10n.isVietnamese,
                    onTap: () => flow.setLocale(const Locale('vi')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _languagePillButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 44,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE3F2E8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? const Color(0xFFC8E3D2) : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            DytavaAudioFeedback.playClick();
            onTap();
          },
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? const Color(0xFF166534)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compareModeTile(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('settings-compare-mode-tile'),
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              DytavaAudioFeedback.playClick();
              _openCompareModeSheet(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.compareModeSetting,
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF7F0),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF107C41,
                              ).withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _activeCompareModeBadge(l10n),
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: DytavaColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _activeCompareModeSubtitle(l10n),
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIconBadge(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7F0),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 19,
        color: const Color(0xFF166534),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Text(
      text,
      style: DytavaTypography.labelSmall.copyWith(
        color: DytavaColors.primary,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _actionTile({
    Key? key,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: key,
          onTap: onTap == null
              ? null
              : () {
                  DytavaAudioFeedback.playClick();
                  onTap();
                },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _openCompareModeSheet(BuildContext context) async {
    final l10n = context.l10n;
    var selectedMode = flow.config.mode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.compareModeSetting,
                  style: DytavaTypography.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.isVietnamese
                      ? 'Chọn phương thức ghép cặp hàng mặc định khi đối chiếu hai bảng tính.'
                      : 'Choose the default row matching mode when comparing two spreadsheets.',
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final option in [
                  (
                    MatchingMode.positional,
                    '${l10n.quickBadge} (${l10n.byPosition})',
                    l10n.compareModeDesc,
                  ),
                  (
                    MatchingMode.key,
                    l10n.byKeyColumn,
                    l10n.isVietnamese
                        ? 'Khớp bản ghi qua cột khóa định danh (ID, Mã, SKU).'
                        : 'Match records using primary key columns (ID, Code, SKU).',
                  ),
                  (
                    MatchingMode.orderedSequence,
                    l10n.sequenceAlignment,
                    l10n.isVietnamese
                        ? 'Căn chỉnh chuỗi tuần tự LCS để nhận diện hàng chèn/xóa.'
                        : 'Align ordered sequences (LCS) to detect inserted/deleted rows.',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selectedMode == option.$1
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF8FAF9),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => updateSheet(() => selectedMode = option.$1),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedMode == option.$1
                                  ? DytavaColors.primary
                                  : const Color(0xFFE2E8F0),
                              width: selectedMode == option.$1 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.$2,
                                      style: TextStyle(
                                        fontFamily: DytavaTypography.primaryFont,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: selectedMode == option.$1
                                            ? DytavaColors.primaryDark
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      option.$3,
                                      style: const TextStyle(
                                        fontFamily: DytavaTypography.primaryFont,
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedMode == option.$1)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: DytavaColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                WorkflowPrimaryButton(
                  label: l10n.saveSettings,
                  onPressed: () {
                    flow.configure(
                      flow.config.copyWith(
                        mode: selectedMode,
                        modeConfirmed: true,
                      ),
                    );
                    Navigator.pop(sheetContext);
                    if (mounted) setState(() {});
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLocalStorageSheet(BuildContext context) async {
    unawaited(_refreshStorageInfo());
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          final hasActiveInMemory = _activeMemoryBytes > 0 ||
              SourceSide.values.any((s) => flow.slot(s).artifact != null);
          final hasPersistentData = _storageBytes > 0 || _savedSessionCount > 0;
          final hasAnyData = hasPersistentData || hasActiveInMemory;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.isVietnamese ? 'Lưu trữ & dữ liệu' : 'Storage & data',
                    style: DytavaTypography.displayMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.localStorageDesc,
                    style: DytavaTypography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  // 1. Persistent storage (SQLite on disk)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DytavaColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DytavaColors.subtleBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.isVietnamese
                                        ? 'Lưu trữ bền vững (Persistent storage)'
                                        : 'Persistent storage',
                                    style: const TextStyle(
                                      fontFamily: DytavaTypography.primaryFont,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.isVietnamese
                                        ? 'Các phiên đối chiếu và báo cáo đã lưu'
                                        : 'Saved comparisons and reports',
                                    style: const TextStyle(
                                      fontFamily: DytavaTypography.primaryFont,
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              WorkflowController.formatStorageBytes(_storageBytes),
                              key: const ValueKey('storage-sheet-persistent-bytes'),
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: DytavaColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.isVietnamese ? 'Dung lượng đang dùng' : 'Used storage',
                              style: DytavaTypography.bodyMedium,
                            ),
                            Text(
                              WorkflowController.formatStorageBytes(_storageBytes),
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.isVietnamese ? 'Phiên đối chiếu đã lưu' : 'Saved comparisons',
                              style: DytavaTypography.bodyMedium,
                            ),
                            Text(
                              '$_savedSessionCount',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 2. Active session memory (RAM)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isVietnamese
                                    ? 'Bộ nhớ phiên hiện tại (Active session memory)'
                                    : 'Active session memory',
                                style: const TextStyle(
                                  fontFamily: DytavaTypography.primaryFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.isVietnamese
                                    ? 'Dữ liệu làm việc tạm thời (RAM) · Ước tính'
                                    : 'Temporary working data · Estimated',
                                style: const TextStyle(
                                  fontFamily: DytavaTypography.primaryFont,
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          WorkflowController.formatStorageBytes(_activeMemoryBytes),
                          key: const ValueKey('storage-sheet-active-ram-bytes'),
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 3. Data retention & privacy controls
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: DytavaColors.subtleBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2, top: 4, bottom: 4),
                            child: Text(
                              l10n.isVietnamese
                                  ? 'Chính sách lưu giữ dữ liệu (Data retention)'
                                  : 'Data retention',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            key: const ValueKey('storage-auto-save-toggle'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeTrackColor: DytavaColors.primary,
                            title: Text(
                              l10n.isVietnamese
                                  ? 'Tự động lưu lịch sử đối chiếu'
                                  : 'Auto-save comparison history',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              l10n.isVietnamese
                                  ? 'Tối đa ${flow.maxRetainedSessions} phiên gần nhất trên thiết bị'
                                  : 'Keep up to ${flow.maxRetainedSessions} recent sessions on device',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            value: flow.autoSaveHistory,
                            onChanged: (val) {
                              flow.setAutoSaveHistory(val);
                              updateSheet(() {});
                            },
                          ),
                          SwitchListTile.adaptive(
                            key: const ValueKey('storage-persist-raw-toggle'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeTrackColor: DytavaColors.primary,
                            title: Text(
                              l10n.isVietnamese
                                  ? 'Lưu giá trị ô gốc trong SQLite'
                                  : 'Store raw cell values in SQLite',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              l10n.isVietnamese
                                  ? 'Tắt để chỉ lưu thống kê tổng hợp (chế độ bảo mật cao)'
                                  : 'Turn off to store summary counts only (strict privacy)',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            value: flow.persistRawCellValues,
                            onChanged: (val) {
                              flow.setPersistRawCellValues(val);
                              updateSheet(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('settings-clear-local-storage-button'),
                    onPressed: hasAnyData
                        ? () async {
                            await flow.clearAllSavedSessions();
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            await _refreshStorageInfo();
                            if (context.mounted) {
                              DytavaToast.success(
                                context,
                                l10n.isVietnamese
                                    ? 'Đã xóa toàn bộ dữ liệu lịch sử lưu trữ cục bộ.'
                                    : 'Cleared all saved local comparison history.',
                                title: l10n.localStorageSetting,
                              );
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF64748B),
                      minimumSize: const Size(48, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    label: Text(
                      l10n.isVietnamese ? 'Xóa dữ liệu đã lưu' : 'Clear saved data',
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPrivacySheet(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _circleIconBadge(Icons.verified_user_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.privacySetting,
                      style: DytavaTypography.displayMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.privacyDesc,
                style: DytavaTypography.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FAF6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0E6D8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isVietnamese
                          ? '• Xử lý 100% trên thiết bị (On-device): Bảng tính và ảnh chụp OCR được phân tích trực tiếp trong bộ nhớ cục bộ, không tải lên máy chủ đám mây.'
                          : '• 100% On-device processing: Spreadsheets and OCR images are analyzed directly on your device without cloud uploads.',
                      style: DytavaTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.isVietnamese
                          ? '• Kiểm soát dữ liệu lưu trữ: Lịch sử phiên đối chiếu lưu trong SQLite cục bộ và có thể xóa bất cứ lúc nào tại mục Lưu trữ cục bộ.'
                          : '• Full storage control: Comparison history is stored in local SQLite and can be cleared anytime in Local storage.',
                      style: DytavaTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.isVietnamese
                          ? '• Chia sẻ chủ động: Báo cáo CSV/JSON chỉ được xuất và lưu khi bạn chủ động chọn vị trí trên thiết bị.'
                          : '• Explicit sharing only: CSV/JSON reports are only saved when you explicitly choose a destination on your device.',
                      style: DytavaTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              WorkflowPrimaryButton(
                label: l10n.done,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHelpSupportSheet(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _circleIconBadge(Icons.help_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.helpAndSupport,
                      style: DytavaTypography.displayMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.isVietnamese
                    ? 'Hướng dẫn nhanh quy trình đối chiếu bảng tính chính xác với Dytava:'
                    : 'Quick guide to spreadsheet comparison with Dytava:',
                style: DytavaTypography.bodyLarge,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DytavaColors.subtleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isVietnamese
                          ? '1. Chọn Tệp gốc (A) và Tệp cập nhật (B) định dạng XLSX, CSV, TSV, JSON hoặc quét bảng qua OCR.'
                          : '1. Select Original File (A) and Updated File (B) in XLSX, CSV, TSV, JSON, or scan a table via OCR.',
                      style: DytavaTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.isVietnamese
                          ? '2. Tùy chỉnh Cài đặt so khớp (Tự động khớp, theo Cột khóa ID, hoặc Khớp tuần tự).'
                          : '2. Customize Matching settings (Auto match, By key column, or Sequence alignment).',
                      style: DytavaTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.isVietnamese
                          ? '3. Xem kết quả theo danh sách thẻ sai khác hoặc bảng đối chiếu song song và xuất báo cáo CSV/JSON.'
                          : '3. Inspect differences in card list or side-by-side table view and export CSV/JSON reports.',
                      style: DytavaTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              WorkflowSecondaryButton(
                label: l10n.rulePresetsSetting,
                icon: Icons.tune_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onOpenPresets();
                },
              ),
              WorkflowPrimaryButton(
                label: l10n.done,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rules(BuildContext context) async {
    final l10n = context.l10n;
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
                Text(
                  l10n.isVietnamese ? 'Cài đặt đối chiếu' : 'Comparison settings',
                  style: DytavaTypography.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.chooseWhatCounts,
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                Material(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          l10n.ignoreCase,
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: Text(
                          l10n.isVietnamese
                              ? 'Coi “Excel” và “excel” là bằng nhau.'
                              : 'Treat “Excel” and “excel” as equal.',
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
                        title: Text(
                          l10n.ignoreWhitespace,
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: Text(
                          l10n.isVietnamese
                              ? 'Bỏ qua khoảng trắng xung quanh văn bản.'
                              : 'Ignore spaces around text.',
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
                        title: Text(
                          l10n.isVietnamese ? 'Giữ số 0 ở đầu' : 'Preserve leading zeros',
                          style: DytavaTypography.titleSmall,
                        ),
                        subtitle: Text(
                          l10n.isVietnamese
                              ? 'Phân biệt rõ “001” với “1”.'
                              : 'Keep “001” distinct from “1”.',
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
                Text(
                  l10n.isVietnamese
                      ? 'Các quy tắc này áp dụng cho phiên hiện tại.'
                      : 'These rules apply to the current session.',
                  style: DytavaTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                WorkflowPrimaryButton(
                  label: l10n.saveSettings,
                  onPressed: () {
                    flow.configure(flow.config.copyWith(webPolicy: policy));
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
