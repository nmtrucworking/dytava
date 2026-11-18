import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../app/workflow_composition.dart';
import '../../application/workflow_controller.dart';
import '../../design_system/design_system.dart';
import '../../domain/workflow.dart';
import '../diagnostics/compare_demo_page.dart';
import '../shared/text_difference_evidence.dart';

/// Giao diện ứng dụng di động Dytava hoàn chỉnh:
/// - Thanh điều hướng 5 Tab (DytavaBottomNavBar): Trang chủ, So sánh, Lịch sử, Học tập, Cài đặt
/// - Hệ thống UI Components chuẩn Brand Showcase v2.0 (Result Card, Policy Card, File Card, Feature Grid, Filter Tabs)
/// - Bảng đối chiếu 2 Sheets (DytavaSheetDiffView — Hợp nhất A↔B & Song song 2 Sheets A|B) thay cho so sánh từng ô rời rạc.
class WorkflowPage extends StatefulWidget {
  const WorkflowPage({super.key, this.controller});
  final WorkflowController? controller;
  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage>
    with WidgetsBindingObserver {
  late final WorkflowController flow;
  ImportBinding? _reviewBinding;
  final Set<String> _reviewed = {};
  ExportKind _exportKind = ExportKind.jsonReport;
  ExportSelection _selection = ExportSelection.fullComparison;
  bool _scopeConfirmed = false;
  bool _quickProcessing = false;

  /// Tab hiện tại trên Bottom Navigation Bar:
  /// 0: Trang chủ, 1: So sánh, 2: Lịch sử, 3: Học tập, 4: Cài đặt
  int _bottomTab = 0;

  /// Chế độ hiển thị kết quả trên SCR-08:
  /// 0: Sheet Diff (2 Bảng), 1: Danh sách ô, 2: Cấu trúc
  int _resultViewTab = 0;

  /// Mẫu quy tắc đang chọn trong tab Học tập / Quy tắc
  String _selectedPolicyPreset = 'academic-records-v1';

  @override
  void initState() {
    super.initState();
    flow = widget.controller ?? createDemoWorkflow();
    flow.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        if (flow.screen != WorkflowScreen.home && _bottomTab == 0) {
          _bottomTab = 1;
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      for (final side in SourceSide.values) {
        if (flow.slot(side).busy) unawaited(flow.cancelImport(side));
      }
      unawaited(flow.cancelComparison());
      unawaited(flow.cancelExport());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    flow.removeListener(_refresh);
    if (widget.controller == null) flow.dispose();
    super.dispose();
  }

  String _name(Enum value) => value.name
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
      .toUpperCase();

  Widget _text(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text, style: DytavaTypography.bodyMedium),
  );

  Widget _button(String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: DytavaColors.primary,
          foregroundColor: DytavaColors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: DytavaTypography.labelLarge),
      ),
    ),
  );

  Widget _check(String label, bool checked, ValueChanged<bool>? action) =>
      Padding(
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
            onChanged: action == null ? null : (value) => action(value ?? false),
          ),
        ),
      );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text,
      style: DytavaTypography.titleLarge.copyWith(
        color: DytavaColors.textPrimary,
      ),
    ),
  );

  Widget _card({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color color = DytavaColors.white,
    Border? border,
  }) => Container(
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

  Widget _infoBox(
    String text, {
    IconData icon = Icons.info_outline,
    Color color = DytavaColors.secondary,
    Color bgColor = DytavaColors.softBlue,
  }) => Container(
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
        Icon(icon, size: 20, color: color),
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

  String _remediationForIssue(WorkflowIssue issue) {
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

  Widget _issues(Iterable<WorkflowIssue> issues) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final issue in issues)
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: DytavaColors.different,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${issue.code}: ${issue.message}',
                      style: DytavaTypography.bodySmall.copyWith(
                        color: DytavaColors.different,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  _remediationForIssue(issue),
                  style: DytavaTypography.bodySmall.copyWith(
                    color: DytavaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _statusPill(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
    ),
  );

  Widget _inputStateBadge(InputState state) {
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
    return _statusPill(label, color, bg);
  }

  Widget _stepIndicator() {
    final currentStep = switch (flow.screen) {
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
    final stepDetailTitle = switch (flow.screen) {
      WorkflowScreen.home => 'Bắt đầu phiên',
      WorkflowScreen.sources => 'Bước 1/4 · Chọn & kiểm tra Nguồn A/B',
      WorkflowScreen.preview => 'Bước 1/4 · Xem trước & xác nhận bảng nguồn',
      WorkflowScreen.ocrReview => 'Bước 1/4 · Duyệt từng ô OCR mẫu',
      WorkflowScreen.mapping => 'Bước 2/4 · Ánh xạ cột 1:1 giữa A và B',
      WorkflowScreen.policy => 'Bước 2/4 · Xác nhận khóa, policy & chiều so sánh',
      WorkflowScreen.progress => 'Bước 3/4 · Đang thực thi đối chiếu',
      WorkflowScreen.results => 'Bước 4/4 · Kết quả đối chiếu & Sheet Diff',
      WorkflowScreen.detail => 'Bước 4/4 · Kiểm tra chi tiết bằng chứng ô',
      WorkflowScreen.export => 'Bước 4/4 · Xem trước & xuất báo cáo JSON',
    };
    final steps = [
      (1, 'Nguồn', Icons.folder_open),
      (2, 'Cấu hình', Icons.tune),
      (3, 'So sánh', Icons.compare_arrows),
      (4, 'Sheet Diff', Icons.grid_on),
    ];
    return Semantics(
      container: true,
      label: 'Tiến độ phiên so sánh: $stepDetailTitle',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentStep == steps[i].$1
                                ? DytavaColors.primary
                                : (currentStep > steps[i].$1
                                      ? DytavaColors.softBlue
                                      : DytavaColors.background),
                            border: Border.all(
                              color: currentStep >= steps[i].$1
                                  ? DytavaColors.primary
                                  : DytavaColors.border,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: currentStep > steps[i].$1
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: DytavaColors.primary,
                                )
                              : Icon(
                                  steps[i].$3,
                                  size: 14,
                                  color: currentStep == steps[i].$1
                                      ? DytavaColors.white
                                      : DytavaColors.textSecondary,
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

  void _go(WorkflowScreen screen, {SourceSide? side, String? cellId}) {
    if (screen == WorkflowScreen.export) _scopeConfirmed = false;
    setState(() {
      _bottomTab = screen == WorkflowScreen.home ? 0 : 1;
    });
    flow.navigate(screen, side: side, cellId: cellId);
  }

  void _onSelectBottomTab(int index) {
    if (flow.busy) return;
    setState(() {
      _bottomTab = index;
    });
    if (index == 0) {
      // Tab Trang chủ
      if (flow.screen != WorkflowScreen.home) {
        flow.navigate(WorkflowScreen.home);
      }
    } else if (index == 1) {
      // Tab So sánh 2 Sheets
      if (flow.screen == WorkflowScreen.home) {
        if (flow.resultCurrent) {
          flow.navigate(WorkflowScreen.results);
        } else {
          flow.navigate(WorkflowScreen.sources);
        }
      }
    }
  }

  Future<void> _back() async {
    if (flow.busy) return;
    if (_bottomTab >= 2) {
      setState(() => _bottomTab = flow.screen == WorkflowScreen.home ? 0 : 1);
      return;
    }
    switch (flow.screen) {
      case WorkflowScreen.home:
        return;
      case WorkflowScreen.sources:
        await flow.closeSession();
        if (mounted) setState(() => _bottomTab = 0);
      case WorkflowScreen.preview || WorkflowScreen.ocrReview:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.mapping:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.policy:
        _go(WorkflowScreen.mapping);
      case WorkflowScreen.progress:
        _go(WorkflowScreen.policy);
      case WorkflowScreen.results:
        _go(WorkflowScreen.policy);
      case WorkflowScreen.detail || WorkflowScreen.export:
        _go(WorkflowScreen.results);
    }
  }

  // ==========================================
  // UX OPTIMIZATIONS: Fast-Track Actions
  // ==========================================

  /// Tự động nạp và kiểm tra cả 2 nguồn mẫu về trạng thái PREVIEW_READY
  Future<void> _quickPrepareBoth() async {
    setState(() => _quickProcessing = true);
    try {
      for (final side in SourceSide.values) {
        if (flow.slot(side).artifact == null) {
          await flow.selectSource(
            side,
            SourceFormat.csv,
            side == SourceSide.a ? 'fixture:a' : 'fixture:b',
            'sample.csv',
          );
        }
        if (flow.slot(side).state == InputState.selected) {
          await flow.importSource(side);
        }
        final s = flow.slot(side);
        if (s.state == InputState.needsReview && s.review!.cells.isEmpty) {
          await flow.confirmImport(side, expectedBinding: s.binding);
        }
      }
    } finally {
      if (mounted) setState(() => _quickProcessing = false);
    }
  }

  /// Tự động ghép 1:1 các cột có cùng ID/Label giữa A và B
  void _autoMapFields() {
    final a = flow.slot(SourceSide.a).snapshot;
    final b = flow.slot(SourceSide.b).snapshot;
    if (a == null || b == null) return;
    final mappings = <FieldMapping>[];
    for (final fa in a.fields) {
      final matches = b.fields.where(
        (fb) => fb.id == fa.id || fb.label == fa.label,
      );
      if (matches.isNotEmpty) {
        mappings.add(FieldMapping(fa.id, matches.first.id));
      }
    }
    final rules = Map<String, FieldRule>.of(flow.config.rules);
    for (final m in mappings) {
      rules.putIfAbsent(
        m.fieldA,
        () => FieldRule(
          type: m.fieldA == 'id'
              ? SemanticType.identifier
              : SemanticType.decimal,
        ),
      );
    }
    flow.configure(
      flow.config.copyWith(
        mappings: mappings,
        rules: rules,
        mappingConfirmed: mappings.isNotEmpty,
      ),
    );
  }

  /// Áp dụng cấu hình đã được người dùng phê duyệt và khởi chạy đối chiếu
  void _applyApprovedConfigAndRun() {
    var updated = flow.config.copyWith(
      mappingConfirmed: flow.config.mappings.isNotEmpty,
      modeConfirmed: true,
      policyConfirmed: true,
      directionConfirmed: true,
    );
    if (updated.mode == MatchingMode.key && updated.keys.isEmpty) {
      final defaultKey = updated.mappings.any((m) => m.fieldA == 'id')
          ? 'id'
          : (updated.mappings.isNotEmpty
                ? updated.mappings.first.fieldA
                : null);
      if (defaultKey != null) {
        updated = updated.copyWith(keys: [defaultKey]);
      }
    }
    flow.configure(updated);
    if (flow.startBlockers.isEmpty && !flow.busy) {
      setState(() => _bottomTab = 1);
      flow.runComparison();
    }
  }

  /// Kiểm soát xác nhận cấu hình (P0):
  /// - Nếu cấu hình đã được phê duyệt đầy đủ, cho phép chạy ngay.
  /// - Nếu còn hạng mục chưa xác nhận (mode / policy / direction), mở màn hình
  ///   Xác nhận cấu hình tổng hợp để người dùng kiểm tra khóa ghép, chính sách chuẩn hóa
  ///   và chiều so sánh trước khi xác nhận chạy lần này.
  Future<void> _quickConfirmAllAndRun() async {
    final cfg = flow.config;
    final alreadyApproved =
        cfg.mappingConfirmed &&
        cfg.modeConfirmed &&
        cfg.policyConfirmed &&
        cfg.directionConfirmed &&
        (cfg.mode != MatchingMode.key || cfg.keys.isNotEmpty);

    if (alreadyApproved) {
      _applyApprovedConfigAndRun();
      return;
    }

    final approvedThisTime = await showDytavaConfigConfirmationSheet(
      context: context,
      config: cfg,
    );
    if (approvedThisTime == true && mounted) {
      _applyApprovedConfigAndRun();
    }
  }

  /// Trải nghiệm toàn bộ luồng so sánh 2 Sheets từ Home với cấu hình mẫu đã phê duyệt (`academic-records-v1`)
  Future<void> _oneTapQuickRun() async {
    await _quickPrepareBoth();
    if (!flow.inputsReady) return;
    _autoMapFields();
    _applyApprovedConfigAndRun();
  }

  String _appBarTitle() {
    if (_bottomTab == 2) return 'Dytava · Lịch sử phiên';
    if (_bottomTab == 3) return 'Dytava · Học tập & Quy tắc';
    if (_bottomTab == 4) return 'Dytava · Cài đặt';
    const titles = [
      'Bắt đầu',
      'Nguồn A/B',
      'Kiểm tra nguồn',
      'Review OCR mẫu',
      'Ánh xạ cột',
      'Xác nhận cấu hình',
      'Tiến trình',
      'Sheet Diff (2 Bảng)',
      'Chi tiết ô',
      'Xuất báo cáo',
    ];
    return 'Dytava · ${titles[flow.screen.index]}';
  }

  @override
  Widget build(BuildContext context) {
    final isRootHome = flow.screen == WorkflowScreen.home && _bottomTab == 0;
    return PopScope(
      canPop: isRootHome && !flow.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: DytavaColors.background,
        appBar: AppBar(
          title: Text(_appBarTitle(), style: DytavaTypography.titleLarge),
          backgroundColor: DytavaColors.white,
          elevation: 0,
          leading: isRootHome
              ? null
              : IconButton(
                  tooltip: 'Quay lại',
                  onPressed: flow.busy ? null : _back,
                  icon: const Icon(Icons.arrow_back),
                ),
          actions: [
            if (flow.screen != WorkflowScreen.home)
              IconButton(
                tooltip: 'Đóng phiên và dọn dữ liệu mẫu',
                onPressed: flow.usable
                    ? () async {
                        await flow.closeSession();
                        if (mounted) setState(() => _bottomTab = 0);
                      }
                    : null,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        bottomNavigationBar: DytavaBottomNavBar(
          currentIndex: _bottomTab,
          onTap: _onSelectBottomTab,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: ValueKey('${flow.screen.name}-tab-$_bottomTab'),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_bottomTab <= 1 && flow.screen != WorkflowScreen.home)
                    _stepIndicator(),
                  if (flow.issue != null && _bottomTab <= 1)
                    Semantics(liveRegion: true, child: _issues([flow.issue!])),
                  ..._activeTabContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _activeTabContent() {
    if (_bottomTab == 2) return _historyTab();
    if (_bottomTab == 3) return _learnTab();
    if (_bottomTab == 4) return _settingsTab();
    return _content();
  }

  List<Widget> _content() {
    if (const {
          WorkflowScreen.mapping,
          WorkflowScreen.policy,
        }.contains(flow.screen) &&
        !flow.inputsReady) {
      return [
        _card(
          children: [
            _infoBox(
              'Nguồn đã thay đổi; cần xác thực lại trước khi cấu hình.',
              color: DytavaColors.unresolved,
              bgColor: DytavaColors.softAmber,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
            _button('Về nguồn A/B', () => _go(WorkflowScreen.sources)),
          ],
        ),
      ];
    }
    if (const {
          WorkflowScreen.results,
          WorkflowScreen.detail,
          WorkflowScreen.export,
        }.contains(flow.screen) &&
        !flow.resultCurrent) {
      return [
        _card(
          children: [
            _infoBox(
              'Kết quả đã mất hiệu lực. Hãy xác thực nguồn và so sánh lại.',
              color: DytavaColors.different,
              bgColor: DytavaColors.softRed,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 12),
            _button('Về nguồn A/B', () => _go(WorkflowScreen.sources)),
          ],
        ),
      ];
    }
    return switch (flow.screen) {
      WorkflowScreen.home => _home(),
      WorkflowScreen.sources => _sources(),
      WorkflowScreen.preview => _preview(),
      WorkflowScreen.ocrReview => _ocr(),
      WorkflowScreen.mapping => _mapping(),
      WorkflowScreen.policy => _policy(),
      WorkflowScreen.progress => _progress(),
      WorkflowScreen.results => _results(),
      WorkflowScreen.detail => _detail(),
      WorkflowScreen.export => _export(),
    };
  }

  List<Widget> _home() => [
    // Thẻ Fast-Track: Trải nghiệm Sheet Diff 2 Sheets 1 chạm
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x202563EB),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grid_on, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sheet Diff 2 Bảng tính (1 chạm)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Tự động nạp Sheet A & Sheet B, ghép cột và mở bảng Sheet Diff',
                      style: TextStyle(fontSize: 11, color: Color(0xFFDBEAFE)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _quickProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DytavaColors.primary,
                      ),
                    )
                  : const Icon(Icons.play_arrow, size: 20),
              onPressed: _quickProcessing ? null : _oneTapQuickRun,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: DytavaColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: Text(
                _quickProcessing
                    ? 'Đang tự động xử lý 2 Sheets...'
                    : 'Trải nghiệm nhanh (1 chạm)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    // Nếu đã có kết quả trong phiên, hiển thị DytavaResultCard ngay trên Trang chủ
    if (flow.resultCurrent && flow.result != null) ...[
      DytavaResultCard(
        fileA: flow.slot(SourceSide.a).artifact?.label ?? 'Sheet A',
        fileB: flow.slot(SourceSide.b).artifact?.label ?? 'Sheet B',
        totalPairs: flow.result!.cells.length,
        equivalentCount: flow.result!.count(DecisionStatus.equivalent),
        differentCount: flow.result!.count(DecisionStatus.different),
        unresolvedCount: flow.result!.count(DecisionStatus.unresolved),
        onTap: () => _go(WorkflowScreen.results),
      ),
      const SizedBox(height: 12),
    ],
    _card(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DytavaColors.softBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const DytavaAsset(DytavaIcons.compare, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dytava Mobile',
                    style: DytavaTypography.titleMedium,
                  ),
                  Text(
                    'Đối chiếu 2 Sheets chuyên sâu (UDG 3.1)',
                    style: DytavaTypography.bodySmall.copyWith(
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _heading('So sánh hai nguồn dữ liệu'),
        _text(
          'Bản triển khai flow: nhập 2 bảng (Sheets), review, ánh xạ cột, xác nhận policy, đối chiếu dạng Sheet Diff 2 Sheets và preview báo cáo.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: DytavaColors.softGreen,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: DytavaColors.exact.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.security, size: 18, color: DytavaColors.exact),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Xử lý tại thiết bị; không tự tải dữ liệu lên mạng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DytavaColors.exact,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _button('So sánh mới (dữ liệu mẫu)', () => _go(WorkflowScreen.sources)),
      ],
    ),
    // Lưới tính năng chính (Core Feature Grid chuẩn Brand Showcase)
    _card(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Nhóm tính năng chính (Core Modules)',
          style: DytavaTypography.titleMedium,
        ),
        const SizedBox(height: 12),
        DytavaFeatureGrid(
          items: [
            DytavaFeatureItem(
              label: 'Sheet Diff\n2 Bảng',
              iconAsset: DytavaIcons.compare,
              bgColor: DytavaColors.softGreen,
              onTap: _oneTapQuickRun,
            ),
            DytavaFeatureItem(
              label: 'OCR\nẢnh → Bảng',
              iconAsset: DytavaIcons.ocr,
              bgColor: DytavaColors.softPurple,
              onTap: () => _go(WorkflowScreen.sources),
            ),
            DytavaFeatureItem(
              label: 'Nhập\n2 Sheets',
              iconAsset: DytavaIcons.importData,
              bgColor: DytavaColors.softBlue,
              onTap: () => _go(WorkflowScreen.sources),
            ),
            DytavaFeatureItem(
              label: 'Ánh xạ\nCột 1:1',
              iconAsset: DytavaIcons.mapping,
              bgColor: DytavaColors.softPurple,
              onTap: () {
                if (flow.inputsReady) {
                  _go(WorkflowScreen.mapping);
                } else {
                  _go(WorkflowScreen.sources);
                }
              },
            ),
            DytavaFeatureItem(
              label: 'Mẫu\nQuy tắc',
              iconAsset: DytavaIcons.saveRule,
              bgColor: DytavaColors.softPurple,
              onTap: () => setState(() => _bottomTab = 3),
            ),
            DytavaFeatureItem(
              label: 'Lịch sử\nPhiên',
              iconAsset: DytavaIcons.history,
              bgColor: DytavaColors.softBlue,
              onTap: () => setState(() => _bottomTab = 2),
            ),
            DytavaFeatureItem(
              label: 'Học tập\n& Chuẩn',
              iconAsset: DytavaIcons.learn,
              bgColor: DytavaColors.softPurple,
              onTap: () => setState(() => _bottomTab = 3),
            ),
            DytavaFeatureItem(
              label: 'Cài đặt\nHệ thống',
              iconAsset: DytavaIcons.settings,
              bgColor: DytavaColors.softBlue,
              onTap: () => setState(() => _bottomTab = 4),
            ),
          ],
        ),
      ],
    ),
    _card(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 20,
              color: DytavaColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ghi chú phạm vi (Scope Notice)',
                style: DytavaTypography.titleMedium.copyWith(
                  color: DytavaColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _text(
          'Flow sử dụng bộ dữ liệu cục bộ có sẵn. Chưa đọc tệp Excel/CSV/TSV thật, chưa OCR ảnh, chưa lưu báo cáo và chưa bật profile 1 GB. Không có dữ liệu nào được tải lên mạng bởi flow mẫu.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CompareDemoPage()),
            ),
            child: const Text('Mở thử nghiệm so sánh hai giá trị'),
          ),
        ),
      ],
    ),
  ];

  // ==========================================
  // TAB 2: LỊCH SỬ PHIÊN (HISTORY TAB)
  // ==========================================
  List<Widget> _historyTab() => [
    _card(
      children: [
        _heading('Lịch sử đối soát trong phiên'),
        _text(
          'Theo chính sách bảo mật P0, ứng dụng chỉ giữ kết quả của phiên đang mở trong bộ nhớ tạm và tự động dọn sạch khi đóng phiên.',
        ),
        const SizedBox(height: 12),
        if (flow.resultCurrent && flow.result != null) ...[
          DytavaHistoryCard(
            title:
                '${flow.slot(SourceSide.a).artifact?.label ?? 'Sheet A'} ↔ ${flow.slot(SourceSide.b).artifact?.label ?? 'Sheet B'}',
            subtitle:
                '${flow.result!.matchedRecords} hàng ghép • ${flow.result!.cells.length} cặp ô • ${flow.result!.count(DecisionStatus.different)} khác biệt',
            badgeText: 'HIỆN HÀNH',
            onTap: () => _go(WorkflowScreen.results),
          ),
          DytavaResultCard(
            fileA: flow.slot(SourceSide.a).artifact?.label ?? 'sample.csv (A)',
            fileB: flow.slot(SourceSide.b).artifact?.label ?? 'sample.csv (B)',
            totalPairs: flow.result!.cells.length,
            equivalentCount: flow.result!.count(DecisionStatus.equivalent),
            differentCount: flow.result!.count(DecisionStatus.different),
            unresolvedCount: flow.result!.count(DecisionStatus.unresolved),
            onTap: () => _go(WorkflowScreen.results),
          ),
          const SizedBox(height: 12),
          _button(
            'Mở bảng Sheet Diff 2 Sheets hiện hành',
            () => _go(WorkflowScreen.results),
          ),
        ] else ...[
          const DytavaEmptyState(),
          const SizedBox(height: 12),
          _button('Chạy Sheet Diff 2 Bảng mẫu ngay', _oneTapQuickRun),
        ],
      ],
    ),
  ];

  // ==========================================
  // TAB 3: HỌC TẬP & MẪU QUY TẮC (LEARN & POLICIES TAB)
  // ==========================================
  List<Widget> _learnTab() => [
    _card(
      children: [
        _heading('Mẫu quy tắc chuẩn hóa (Policy Presets)'),
        _text(
          'Các bộ quy tắc chuẩn hóa định dạng số thập phân, khoảng trắng, định danh và sai số tuyệt đối cho Sheet Diff.',
        ),
        const SizedBox(height: 8),
        DytavaPolicyCard(
          policyId: 'academic-records-v1',
          subtitle: 'v1.0.0 • 2 trường • Khóa: id • Dấu thập phân A(.) / B(,)',
          active: _selectedPolicyPreset == 'academic-records-v1',
          onTap: () => setState(() => _selectedPolicyPreset = 'academic-records-v1'),
        ),
        DytavaPolicyCard(
          policyId: 'financial-reconcile-v1',
          subtitle: 'v1.0.0 • Đối soát kế toán • Sai số tuyệt đối: 0.01',
          active: _selectedPolicyPreset == 'financial-reconcile-v1',
          onTap: () =>
              setState(() => _selectedPolicyPreset = 'financial-reconcile-v1'),
        ),
        DytavaPolicyCard(
          policyId: 'inventory-sku-strict',
          subtitle: 'v1.0.0 • Mã SKU strict identifier • Giữ số 0 đầu (00123)',
          active: _selectedPolicyPreset == 'inventory-sku-strict',
          onTap: () =>
              setState(() => _selectedPolicyPreset = 'inventory-sku-strict'),
        ),
      ],
    ),
    _card(
      children: [
        _heading('Quy chuẩn 4 trạng thái trên Sheet Diff'),
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
        _text('• EXACT: Trùng khớp cả biểu diễn thô và giá trị ngữ nghĩa.'),
        _text(
          '• EQUIVALENT: Khác biểu diễn (ví dụ 8.5 và 8,5) nhưng bằng nhau theo quy tắc chuẩn hóa đã xác nhận.',
        ),
        _text('• DIFFERENT: Hai ô khác biệt giá trị sau khi chuẩn hóa.'),
        _text(
          '• UNRESOLVED: Chưa đủ căn cứ kết luận (ví dụ lỗi kiểu dữ liệu abc vs 9, hoặc trùng/rỗng khóa).',
        ),
      ],
    ),
  ];

  // ==========================================
  // TAB 4: CÀI ĐẶT (SETTINGS TAB)
  // ==========================================
  List<Widget> _settingsTab() => [
    _card(
      children: [
        _heading('Cài đặt đối chiếu & Quyền riêng tư'),
        _infoBox(
          'Chế độ Offline-First: Mọi dữ liệu bảng tính và ảnh OCR đều được xử lý cục bộ trên thiết bị.',
          icon: Icons.verified_user_outlined,
          color: DytavaColors.exact,
          bgColor: DytavaColors.softGreen,
        ),
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.grid_view, color: DytavaColors.primary),
          title: const Text('Giao diện kết quả mặc định'),
          subtitle: const Text('Sheet Diff 2 Sheets (Hợp nhất & Song song)'),
          trailing: _statusPill(
            'Đang bật',
            DytavaColors.exact,
            DytavaColors.exactBg,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.layers_outlined, color: DytavaColors.purple),
          title: const Text('Kiến trúc thực thi'),
          subtitle: const Text('UDG 3.1 • 8 Core Activities • 10 Screens'),
          trailing: _statusPill(
            'v0.2.0',
            DytavaColors.primary,
            DytavaColors.softBlue,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _sources() => [
    _infoBox(
      'Mỗi nguồn có trạng thái riêng. Thay nguồn làm mất hiệu lực ánh xạ và kết quả liên quan.',
      icon: Icons.shield_outlined,
      color: DytavaColors.primary,
      bgColor: DytavaColors.softBlue,
    ),
    if (!flow.inputsReady)
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          icon: _quickProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.auto_awesome,
                  color: DytavaColors.primary,
                  size: 18,
                ),
          label: const Text(
            'Tự động chuẩn bị nhanh cả 2 nguồn (1 chạm)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: DytavaColors.primary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: DytavaColors.softBlue,
            side: const BorderSide(color: DytavaColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _quickProcessing ? null : _quickPrepareBoth,
        ),
      ),
    for (final side in SourceSide.values) ...[
      _card(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: side == SourceSide.a
                      ? DytavaColors.primary
                      : DytavaColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  side.name.toUpperCase(),
                  style: const TextStyle(
                    color: DytavaColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading('Nguồn ${side.name.toUpperCase()}'),
                    Text(
                      side == SourceSide.a
                          ? 'Sheet A (Bảng tham chiếu)'
                          : 'Sheet B (Bảng đối chiếu)',
                      style: DytavaTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              _inputStateBadge(flow.slot(side).state),
            ],
          ),
          const Divider(height: 20),
          // Sử dụng DytavaFileCard chuẩn nhận diện khi đã chọn nguồn
          if (flow.slot(side).artifact != null)
            DytavaFileCard(
              fileName: flow.slot(side).artifact!.label,
              metaText:
                  '${flow.slot(side).artifact!.format.name.toUpperCase()} • ${flow.slot(side).snapshot != null ? '${flow.slot(side).snapshot!.records.length} hàng' : _name(flow.slot(side).state)}',
              format: flow.slot(side).artifact!.format,
              verified: flow.slot(side).ready,
              onTap: flow.slot(side).busy
                  ? null
                  : () => _go(WorkflowScreen.preview, side: side),
            ),
          Row(
            children: [
              DytavaAsset(
                flow.slot(side).artifact?.format.isImage == true
                    ? DytavaIcons.filePng
                    : DytavaIcons.fileCsv,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _text(
                  '${flow.slot(side).artifact?.label ?? 'Chưa chọn'} · ${_name(flow.slot(side).state)}${flow.slot(side).cancelling ? ' · Đang dọn dữ liệu tạm' : ''}',
                ),
              ),
            ],
          ),
          if (flow.slot(side).issue != null) _issues([flow.slot(side).issue!]),
          const SizedBox(height: 12),
          if (flow.slot(side).state == InputState.selected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: Text(
                    'Kiểm tra nhanh ${side.name.toUpperCase()} (1 chạm)',
                  ),
                  onPressed: flow.slot(side).busy
                      ? null
                      : () => flow.importSource(side),
                ),
              ),
            ),
          if (flow.slot(side).state == InputState.needsReview &&
              flow.slot(side).review!.cells.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    'Xác nhận nhanh phạm vi ${side.name.toUpperCase()} (1 chạm)',
                  ),
                  onPressed: () => flow.confirmImport(
                    side,
                    expectedBinding: flow.slot(side).binding,
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                onPressed: flow.slot(side).busy
                    ? null
                    : () => flow.selectSource(
                        side,
                        SourceFormat.csv,
                        side == SourceSide.a ? 'fixture:a' : 'fixture:b',
                        'sample.csv',
                      ),
                label: Text(
                  flow.slot(side).artifact == null
                      ? 'Chọn bảng mẫu ${side.name.toUpperCase()}'
                      : 'Thay bảng mẫu ${side.name.toUpperCase()}',
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                onPressed:
                    flow.slot(side).busy ||
                        flow
                                .slot(
                                  side == SourceSide.a
                                      ? SourceSide.b
                                      : SourceSide.a,
                                )
                                .artifact
                                ?.format
                                .isImage ==
                            true
                    ? null
                    : () => flow.selectSource(
                        side,
                        SourceFormat.png,
                        'fixture:image-a',
                        'sample-image.png',
                      ),
                label: Text('Chọn OCR giả lập ${side.name.toUpperCase()}'),
              ),
              if (flow.slot(side).artifact != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  onPressed: flow.slot(side).busy
                      ? null
                      : () => _go(WorkflowScreen.preview, side: side),
                  label: Text('Kiểm tra ${side.name.toUpperCase()}'),
                ),
              if (flow.slot(side).artifact != null)
                TextButton.icon(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: DytavaColors.different,
                  ),
                  onPressed: () => flow.resetSource(side),
                  label: Text(
                    'Xóa ${side.name.toUpperCase()}',
                    style: const TextStyle(color: DytavaColors.different),
                  ),
                ),
            ],
          ),
          if (flow.slot(side).busy) ...[
            const SizedBox(height: 8),
            _button(
              'Hủy nhập ${side.name.toUpperCase()}',
              flow.slot(side).cancelling ? null : () => flow.cancelImport(side),
            ),
          ],
        ],
      ),
    ],
    const SizedBox(height: 8),
    _button(
      'Tiếp tục ánh xạ cột',
      flow.inputsReady ? () => _go(WorkflowScreen.mapping) : null,
    ),
    if (!flow.inputsReady)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: _text('Cần cả A và B ở PREVIEW_READY trước khi ánh xạ.'),
        ),
      ),
  ];

  List<Widget> _preview() {
    final source = flow.slot(flow.activeSide);
    return [
      _card(
        children: [
          Row(
            children: [
              Expanded(
                child: _heading(
                  'Nguồn ${source.side.name.toUpperCase()} · ${source.artifact?.label ?? 'Chưa chọn'}',
                ),
              ),
              _inputStateBadge(source.state),
            ],
          ),
          _text(_name(source.state)),
          if (source.issue != null) _issues([source.issue!]),
          if (source.busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            _button(
              'Hủy nhập nguồn',
              source.cancelling ? null : () => flow.cancelImport(source.side),
            ),
          ],
          if (source.state == InputState.selected ||
              source.state == InputState.failed ||
              source.state == InputState.cancelled) ...[
            const SizedBox(height: 12),
            _button(
              source.state == InputState.selected
                  ? 'Kiểm tra nguồn mẫu'
                  : 'Thử lại nhập nguồn',
              source.state == InputState.failed &&
                      source.issue?.retryable != true
                  ? null
                  : () => flow.importSource(source.side),
            ),
          ],
          if (source.state == InputState.needsReview &&
              source.review!.cells.isEmpty) ...[
            const SizedBox(height: 12),
            _button(
              'Xác nhận phạm vi và header mẫu',
              () => flow.confirmImport(
                source.side,
                expectedBinding: source.binding,
              ),
            ),
          ],
          if (source.state == InputState.needsReview &&
              source.review!.cells.isNotEmpty) ...[
            const SizedBox(height: 12),
            _button(
              'Review từng ô OCR mẫu',
              () => _go(WorkflowScreen.ocrReview, side: source.side),
            ),
          ],
        ],
      ),
      if (source.ready) ...[
        _card(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: DytavaColors.exact,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã xác thực toàn bộ fixture · ${source.snapshot!.records.length} hàng. Đây không phải bằng chứng parser tệp thật.',
                    style: DytavaTypography.titleMedium.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hiển thị dưới dạng Bảng trang tính (Spreadsheet Grid Preview)
            DytavaSheetPreviewTable(
              sheetTitle:
                  'Sheet ${source.side.name.toUpperCase()} (${source.artifact?.label ?? 'sample.csv'})',
              fields: source.snapshot!.fields,
              records: source.snapshot!.records,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => flow.changeImportConfig(
                  source.side,
                  ImportConfiguration(
                    ocrRevision: source.config.ocrRevision + 1,
                  ),
                ),
                child: const Text('Đổi cấu hình nhập mẫu'),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      _button(
        'Trở về nguồn A/B',
        source.busy ? null : () => _go(WorkflowScreen.sources),
      ),
    ];
  }

  List<Widget> _ocr() {
    final source = flow.slot(flow.activeSide);
    if (_reviewBinding != source.binding) {
      _reviewBinding = source.binding;
      _reviewed.clear();
    }
    final cells = source.review?.cells ?? const <ReviewCell>[];
    return [
      _card(
        color: DytavaColors.softAmber,
        border: Border.all(
          color: DytavaColors.unresolved.withValues(alpha: 0.4),
        ),
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: DytavaColors.unresolved,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OCR Giả lập',
                  style: DytavaTypography.titleMedium.copyWith(
                    color: DytavaColors.unresolved,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _text(
            'OCR GIẢ LẬP · Chưa có ảnh, geometry, crop hoặc bộ nhận dạng thật. Review này chỉ kiểm tra điều kiện của flow.',
          ),
        ],
      ),
      _card(
        children: [
          Row(
            children: [
              Expanded(child: _heading('Danh sách ô cần review')),
              const SizedBox(width: 8),
              _statusPill(
                '${_reviewed.length}/${cells.length} ô',
                DytavaColors.primary,
                DytavaColors.softBlue,
              ),
            ],
          ),
          _text(
            'Đã xác nhận ${_reviewed.length}/${cells.length} ô. Confidence không thay thế review.',
          ),
          const Divider(height: 20),
          if (cells.isNotEmpty && _reviewed.length < cells.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Chọn duyệt nhanh toàn bộ ô OCR'),
                onPressed: () => setState(() {
                  _reviewed.addAll(cells.map((c) => c.id));
                }),
              ),
            ),
          for (final cell in cells)
            _check(
              '${cell.id}: ${cell.recognizedText}',
              _reviewed.contains(cell.id),
              (checked) => setState(() {
                checked ? _reviewed.add(cell.id) : _reviewed.remove(cell.id);
              }),
            ),
          const SizedBox(height: 12),
          _button(
            'Xác nhận các ô đã review',
            cells.isNotEmpty && cells.every((c) => _reviewed.contains(c.id))
                ? () async {
                    await flow.confirmImport(
                      source.side,
                      expectedBinding: source.binding,
                      reviewedCells: Set.of(_reviewed),
                    );
                    if (mounted) {
                      _go(WorkflowScreen.preview, side: source.side);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await flow.changeImportConfig(
                  source.side,
                  ImportConfiguration(
                    ocrRevision: source.config.ocrRevision + 1,
                  ),
                );
                await flow.importSource(source.side);
              },
              child: const Text('Giả lập đổi crop/layout, xóa review cũ'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _mapping() {
    final a = flow.slot(SourceSide.a).snapshot!;
    final b = flow.slot(SourceSide.b).snapshot!;
    final config = flow.config;
    final chosen = {for (final m in config.mappings) m.fieldA: m.fieldB};
    return [
      _infoBox(
        'Ghép cột 1:1 bằng Field ID giữa Sheet A và Sheet B. Cột không ghép được ghi nhận như thay đổi cấu trúc.',
        icon: Icons.link,
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.auto_fix_high,
                  size: 16,
                  color: DytavaColors.primary,
                ),
                label: const Text(
                  'Tự động ghép cột cùng tên',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DytavaColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: DytavaColors.softBlue,
                  side: const BorderSide(color: DytavaColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _autoMapFields,
              ),
            ),
          ],
        ),
      ),
      _card(
        children: [
          _heading('Ánh xạ các cột (Sheet A ↔ Sheet B)'),
          for (final f in a.fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonFormField<String>(
                key: ValueKey('mapping-${f.id}-${chosen[f.id]}'),
                initialValue: chosen[f.id] ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'A: ${f.label} (${f.id}) → B',
                  prefixIcon: const Icon(Icons.compare_arrows, size: 20),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Không ghép')),
                  for (final target in b.fields)
                    DropdownMenuItem(
                      value: target.id,
                      enabled: !chosen.entries.any(
                        (m) => m.key != f.id && m.value == target.id,
                      ),
                      child: Text('${target.label} (${target.id})'),
                    ),
                ],
                onChanged: (value) {
                  final mappings = config.mappings
                      .where((m) => m.fieldA != f.id)
                      .toList();
                  if (value != null && value.isNotEmpty) {
                    mappings.add(FieldMapping(f.id, value));
                  }
                  final rules = Map<String, FieldRule>.of(config.rules);
                  rules.putIfAbsent(
                    f.id,
                    () => FieldRule(
                      type: f.id == 'id'
                          ? SemanticType.identifier
                          : SemanticType.decimal,
                    ),
                  );
                  flow.configure(
                    config.copyWith(
                      mappings: mappings,
                      rules: rules,
                      mappingConfirmed: false,
                      policyConfirmed: false,
                      modeConfirmed: false,
                      keys: [],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          _check(
            'Xác nhận ánh xạ hiện hành',
            config.mappingConfirmed,
            config.mappings.isEmpty
                ? null
                : (checked) => flow.configure(
                    config.copyWith(mappingConfirmed: checked),
                  ),
          ),
          const SizedBox(height: 12),
          _button(
            'Tiếp tục cấu hình so sánh',
            config.mappingConfirmed ? () => _go(WorkflowScreen.policy) : null,
          ),
        ],
      ),
    ];
  }

  void _rule(String field, FieldRule value) => flow.configure(
    flow.config.copyWith(
      rules: {...flow.config.rules, field: value},
      policyConfirmed: false,
      modeConfirmed: false,
    ),
  );

  List<Widget> _policy() {
    final config = flow.config;
    final allConfirmed =
        config.mappingConfirmed &&
        config.modeConfirmed &&
        config.policyConfirmed &&
        config.directionConfirmed;
    return [
      _card(
        color: DytavaColors.softBlue,
        border: Border.all(
          color: DytavaColors.primary.withValues(alpha: 0.35),
        ),
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: DytavaColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tóm tắt cấu hình đối chiếu',
                  style: DytavaTypography.titleMedium.copyWith(
                    color: DytavaColors.primary,
                  ),
                ),
              ),
              _statusPill(
                allConfirmed ? 'Đã phê duyệt' : 'Cần xác nhận',
                allConfirmed ? DytavaColors.exact : DytavaColors.unresolved,
                allConfirmed ? DytavaColors.softGreen : DytavaColors.softAmber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _text(
            '• Khóa ghép: ${_name(config.mode)}${config.mode == MatchingMode.key ? ' (${config.keys.isEmpty ? 'chưa chọn' : config.keys.join(' → ')})' : ''}\n'
            '• Chính sách chuẩn hóa: ${config.mappings.length} cột ánh xạ (${config.policyConfirmed ? 'đã xác nhận' : 'chưa xác nhận'})\n'
            '• Chiều so sánh: ${config.direction == ComparisonDirection.aToB ? 'A → B' : 'B → A'} (${config.directionConfirmed ? 'đã xác nhận' : 'chưa xác nhận'})',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: Icon(
                allConfirmed ? Icons.play_arrow : Icons.fact_check,
                size: 20,
              ),
              label: Text(
                allConfirmed
                    ? 'Chạy nhanh với cấu hình đã duyệt'
                    : 'Xem tóm tắt & Xác nhận cấu hình',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: DytavaColors.primary,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _quickConfirmAllAndRun,
            ),
          ),
        ],
      ),
      _card(
        children: [
          _heading('Ghép hàng giữa 2 Sheets'),
          DropdownButtonFormField<MatchingMode>(
            key: ValueKey(config.mode),
            initialValue: config.mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chế độ'),
            items: [
              for (final mode in MatchingMode.values)
                DropdownMenuItem(value: mode, child: Text(_name(mode))),
            ],
            onChanged: (mode) {
              if (mode != null) {
                flow.configure(
                  config.copyWith(mode: mode, modeConfirmed: false, keys: []),
                );
              }
            },
          ),
          if (config.mode == MatchingMode.key) ...[
            const SizedBox(height: 10),
            _infoBox(
              'Chọn khóa theo thứ tự. Khóa phải là IDENTIFIER, không trim hoặc tolerance. Null/trùng được giữ unresolved, không tự ghép.',
              icon: Icons.vpn_key_outlined,
            ),
            for (final m in config.mappings)
              _check('Khóa: ${m.fieldA}', config.keys.contains(m.fieldA), (
                checked,
              ) {
                final keys = config.keys.where((k) => k != m.fieldA).toList();
                if (checked) keys.add(m.fieldA);
                flow.configure(
                  config.copyWith(keys: keys, modeConfirmed: false),
                );
              }),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DytavaColors.softBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tuple khóa: ${config.keys.join(' → ')}',
                style: DytavaTypography.dataMedium.copyWith(
                  color: DytavaColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _check(
            'Xác nhận chế độ và khóa',
            config.modeConfirmed,
            (checked) =>
                flow.configure(config.copyWith(modeConfirmed: checked)),
          ),
        ],
      ),
      _card(
        children: [
          _heading('Policy từng cột'),
          for (final m in config.mappings) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cột ${m.fieldA} ↔ ${m.fieldB} · kiểu ban đầu là gợi ý',
                    style: DytavaTypography.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SemanticType>(
                    key: ValueKey(
                      'type-${m.fieldA}-${config.rules[m.fieldA]?.type}',
                    ),
                    initialValue: config.rules[m.fieldA]?.type,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Kiểu ${m.fieldA}'),
                    items: [
                      for (final type in SemanticType.values)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (type) {
                      if (type != null) _rule(m.fieldA, FieldRule(type: type));
                    },
                  ),
                  if (config.rules[m.fieldA] case final FieldRule rule) ...[
                    _check(
                      'Trim ${m.fieldA}',
                      rule.trim,
                      (checked) => _rule(
                        m.fieldA,
                        FieldRule(
                          type: rule.type,
                          trim: checked,
                          separatorA: rule.separatorA,
                          separatorB: rule.separatorB,
                          tolerance: rule.tolerance,
                        ),
                      ),
                    ),
                    if (rule.type == SemanticType.decimal ||
                        rule.type == SemanticType.percentage) ...[
                      for (final side in SourceSide.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              'separator-${m.fieldA}-${side.name}-${side == SourceSide.a ? rule.separatorA : rule.separatorB}',
                            ),
                            initialValue: side == SourceSide.a
                                ? rule.separatorA
                                : rule.separatorB,
                            decoration: InputDecoration(
                              labelText:
                                  'Dấu thập phân ${m.fieldA} / ${side.name.toUpperCase()}',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '.',
                                child: Text('Chấm (.)'),
                              ),
                              DropdownMenuItem(
                                value: ',',
                                child: Text('Phẩy (,)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _rule(
                                  m.fieldA,
                                  FieldRule(
                                    type: rule.type,
                                    trim: rule.trim,
                                    tolerance: rule.tolerance,
                                    separatorA: side == SourceSide.a
                                        ? value
                                        : rule.separatorA,
                                    separatorB: side == SourceSide.b
                                        ? value
                                        : rule.separatorB,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      TextFormField(
                        key: ValueKey('tolerance-${m.fieldA}'),
                        initialValue: rule.tolerance,
                        decoration: InputDecoration(
                          labelText: 'Sai số tuyệt đối ${m.fieldA}',
                        ),
                        onChanged: (value) => _rule(
                          m.fieldA,
                          FieldRule(
                            type: rule.type,
                            trim: rule.trim,
                            separatorA: rule.separatorA,
                            separatorB: rule.separatorB,
                            tolerance: value,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _check(
            'Xác nhận toàn bộ policy',
            config.policyConfirmed,
            (checked) =>
                flow.configure(config.copyWith(policyConfirmed: checked)),
          ),
        ],
      ),
      _card(
        children: [
          _heading('Chiều so sánh'),
          DropdownButtonFormField<ComparisonDirection>(
            key: ValueKey(config.direction),
            initialValue: config.direction,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chiều'),
            items: const [
              DropdownMenuItem(
                value: ComparisonDirection.aToB,
                child: Text('A → B'),
              ),
              DropdownMenuItem(
                value: ComparisonDirection.bToA,
                child: Text('B → A'),
              ),
            ],
            onChanged: (direction) {
              if (direction != null) {
                flow.configure(
                  config.copyWith(
                    direction: direction,
                    directionConfirmed: false,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 6),
          _text(
            config.direction == ComparisonDirection.aToB
                ? 'Chỉ ở B: thêm. Chỉ ở A: thiếu.'
                : 'Chỉ ở A: thêm. Chỉ ở B: thiếu.',
          ),
          const SizedBox(height: 6),
          _check(
            'Xác nhận chiều so sánh',
            config.directionConfirmed,
            (checked) =>
                flow.configure(config.copyWith(directionConfirmed: checked)),
          ),
        ],
      ),
      if (flow.startBlockers.isNotEmpty)
        _card(
          color: DytavaColors.softRed,
          children: [_issues(flow.startBlockers)],
        ),
      const SizedBox(height: 8),
      _button(
        'Chạy so sánh mẫu',
        flow.startBlockers.isEmpty && !flow.busy ? flow.runComparison : null,
      ),
    ];
  }

  List<Widget> _progress() => [
    _card(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Trạng thái: ${_name(flow.jobState)}',
                      style: DytavaTypography.titleMedium,
                    ),
                  ),
                  Text(
                    flow.phase,
                    style: DytavaTypography.bodySmall.copyWith(
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (flow.jobState.active)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: flow.progressTotal != null && flow.progressTotal! > 0
                  ? flow.progressDone / flow.progressTotal!
                  : null,
              minHeight: 8,
              backgroundColor: DytavaColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DytavaColors.primary,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '${flow.progressDone} / ${flow.progressTotal ?? 'chưa xác định'}',
            style: DytavaTypography.dataMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (flow.jobState.active)
          _button(
            'Hủy so sánh',
            flow.jobState == JobState.cancelling ? null : flow.cancelComparison,
          ),
        if (!flow.jobState.active)
          _button(
            flow.inputsReady ? 'Trở lại cấu hình' : 'Về nguồn A/B',
            () => _go(
              flow.inputsReady ? WorkflowScreen.policy : WorkflowScreen.sources,
            ),
          ),
        if (flow.jobState == JobState.failed ||
            flow.jobState == JobState.cancelled) ...[
          const SizedBox(height: 8),
          _button(
            'Thử lại so sánh',
            flow.startBlockers.isEmpty ? flow.runComparison : null,
          ),
        ],
      ],
    ),
  ];

  Widget _filterChips() {
    final res = flow.result;
    if (res == null) return const SizedBox.shrink();
    final items = <(DecisionStatus?, String, Color, Color)>[
      (
        null,
        'Tất cả (${res.cells.length})',
        DytavaColors.primary,
        DytavaColors.softBlue,
      ),
      (
        DecisionStatus.different,
        'Khác biệt (${res.count(DecisionStatus.different)})',
        DytavaColors.different,
        DytavaColors.differentBg,
      ),
      (
        DecisionStatus.unresolved,
        'Chưa kết luận (${res.count(DecisionStatus.unresolved)})',
        DytavaColors.unresolved,
        DytavaColors.unresolvedBg,
      ),
      (
        DecisionStatus.equivalent,
        'Tương đương (${res.count(DecisionStatus.equivalent)})',
        DytavaColors.equivalent,
        DytavaColors.equivalentBg,
      ),
      (
        DecisionStatus.exact,
        'Trùng khớp (${res.count(DecisionStatus.exact)})',
        DytavaColors.exact,
        DytavaColors.exactBg,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (status, label, color, bg) in items)
            FilterChip(
              selected: flow.resultFilter == status,
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: flow.resultFilter == status
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: flow.resultFilter == status
                    ? color
                    : DytavaColors.textPrimary,
              ),
              backgroundColor: DytavaColors.white,
              selectedColor: bg,
              checkmarkColor: color,
              side: BorderSide(
                color: flow.resultFilter == status ? color : DytavaColors.border,
              ),
              onSelected: (_) => flow.filterResults(status),
            ),
        ],
      ),
    );
  }

  List<Widget> _results() {
    final result = flow.result!;
    final priorityCells = result.cells
        .where(
          (c) =>
              c.decision.status == DecisionStatus.different ||
              c.decision.status == DecisionStatus.unresolved,
        )
        .toList();
    final labelA = flow.slot(SourceSide.a).artifact?.label ?? 'Nguồn A';
    final labelB = flow.slot(SourceSide.b).artifact?.label ?? 'Nguồn B';

    return [
      _card(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DytavaColors.softGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: DytavaColors.exact,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading('COMPLETED · Kết quả bộ dữ liệu mẫu'),
                    Text(
                      '$labelA ↔ $labelB · Chiều: ${result.plan.config.direction == ComparisonDirection.aToB ? 'A → B' : 'B → A'}',
                      style: DytavaTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              _statusPill(
                'Hoàn thành',
                DytavaColors.exact,
                DytavaColors.softGreen,
              ),
            ],
          ),
          const Divider(height: 20),
          _text(
            'Ô ghép: ${result.cells.length} · Hàng ghép: ${result.matchedRecords}',
          ),
          const SizedBox(height: 12),
          // Hàng 1 (Ưu tiên cao — P1): Khác biệt & Chưa kết luận
          Row(
            children: [
              _metricBox(
                'DIFFERENT: ${result.count(DecisionStatus.different)}',
                result.count(DecisionStatus.different),
                'Ô khác biệt',
                DytavaColors.different,
                DytavaColors.differentBg,
              ),
              const SizedBox(width: 8),
              _metricBox(
                'UNRESOLVED: ${result.count(DecisionStatus.unresolved)}',
                result.count(DecisionStatus.unresolved),
                'Chưa kết luận',
                DytavaColors.unresolved,
                DytavaColors.unresolvedBg,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Hàng 2 (Bổ trợ — P1): Trùng khớp & Tương đương
          Row(
            children: [
              _metricBox(
                'EXACT: ${result.count(DecisionStatus.exact)}',
                result.count(DecisionStatus.exact),
                'Trùng khớp',
                DytavaColors.exact,
                DytavaColors.exactBg,
              ),
              const SizedBox(width: 8),
              _metricBox(
                'EQUIVALENT: ${result.count(DecisionStatus.equivalent)}',
                result.count(DecisionStatus.equivalent),
                'Tương đương',
                DytavaColors.equivalent,
                DytavaColors.equivalentBg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DytavaColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _text(
              'Exact: ${result.exactRate == null ? 'N/A' : '${(result.exactRate! * 100).toStringAsFixed(1)}%'} · Đồng thuận: ${result.agreementRate == null ? 'N/A' : '${(result.agreementRate! * 100).toStringAsFixed(1)}%'} · Mẫu số: ${result.cells.length} ô',
            ),
          ),
        ],
      ),
      // Khu vực Data-first UX (Mục 4): "Các khác biệt cần kiểm tra"
      if (priorityCells.isNotEmpty)
        _card(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.priority_high_rounded,
                  color: DytavaColors.different,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _heading(
                    'Các khác biệt cần kiểm tra (${priorityCells.length})',
                  ),
                ),
              ],
            ),
            _text(
              'Kiểm tra nhanh các ô Khác biệt hoặc Chưa kết luận trước khi mở toàn bộ bảng đối chiếu.',
            ),
            const SizedBox(height: 8),
            for (final pCell in priorityCells.take(5))
              DytavaPriorityDiffCard(
                cell: pCell,
                onQuickBottomSheet: () => showDytavaCellDetailBottomSheet(
                  context: context,
                  cell: pCell,
                  onOpenFullDetail: () =>
                      _go(WorkflowScreen.detail, cellId: pCell.id),
                ),
                onInspectDetail: () =>
                    _go(WorkflowScreen.detail, cellId: pCell.id),
              ),
          ],
        ),
      if (result.structural.isNotEmpty || result.unresolvedRecords.isNotEmpty)
        _card(
          children: [
            _heading('Cấu trúc (thống kê riêng)'),
            for (final s in result.structural)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: DytavaColors.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _text(
                  '${s.kind} · ${s.side.name.toUpperCase()} · ${s.recordId}',
                ),
              ),
            for (final g in result.unresolvedRecords)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: DytavaColors.softAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _text(
                  '${g.reason} · A: ${g.recordsA.length}, B: ${g.recordsB.length} hàng chưa ghép',
                ),
              ),
          ],
        ),
      _card(
        children: [
          _heading('Xem bảng đối chiếu đầy đủ'),
          _text(
            'Mở bảng cuộn ngang với cột định danh cố định và các hàng được ghép tương ứng.',
          ),
          const SizedBox(height: 8),
          // Thanh TabBar chọn góc nhìn: Sheet Diff (2 Bảng) vs Theo ô
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DytavaFilterTabs(
              tabs: const ['Sheet Diff (2 Bảng)', 'Theo danh sách ô'],
              selectedIndex: _resultViewTab,
              onChanged: (idx) => setState(() => _resultViewTab = idx),
            ),
          ),
          _filterChips(),
          DropdownButtonFormField<DecisionStatus?>(
            key: ValueKey('filter-${flow.resultFilter}'),
            initialValue: flow.resultFilter,
            decoration: const InputDecoration(labelText: 'Lọc trạng thái ô'),
            items: [
              const DropdownMenuItem<DecisionStatus?>(
                value: null,
                child: Text('Tất cả'),
              ),
              for (final s in DecisionStatus.values)
                DropdownMenuItem(value: s, child: Text(_name(s))),
            ],
            onChanged: flow.filterResults,
          ),
          const SizedBox(height: 12),
          // Chế độ mặc định (_resultViewTab == 0): Bảng đối chiếu 2 Sheets (Sheet Diff 2 Sheets)
          if (_resultViewTab == 0)
            DytavaSheetDiffView(
              result: result,
              visibleCells: flow.visibleCells,
              onSelectCell: (cellId) =>
                  _go(WorkflowScreen.detail, cellId: cellId),
            )
          else
            for (final cell in flow.visibleCells)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: DytavaColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: DytavaColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(
                      '${cell.mapping.fieldA}: ${_name(cell.decision.status)}',
                      style: DytavaTypography.titleMedium,
                    ),
                    subtitle: Text(
                      'A: ${cell.a.rawLexeme ?? '[${cell.a.kind.name}]'} · B: ${cell.b.rawLexeme ?? '[${cell.b.kind.name}]'}',
                      style: DytavaTypography.dataMedium,
                    ),
                    trailing: _decisionBadge(cell.decision.status),
                    onTap: () => _go(WorkflowScreen.detail, cellId: cell.id),
                  ),
                ),
              ),
          const SizedBox(height: 10),
          _text(
            'Trang ${flow.page + 1} · ${flow.selectedCells.length} ô trong bộ lọc. Summary phía trên là toàn bộ kết quả.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: flow.page > 0 ? () => flow.turnPage(-1) : null,
                  child: const Text('Trang trước'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      (flow.page + 1) * WorkflowController.pageSize <
                          flow.selectedCells.length
                      ? () => flow.turnPage(1)
                      : null,
                  child: const Text('Trang sau'),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      _button('Xuất / xem trước báo cáo', () => _go(WorkflowScreen.export)),
    ];
  }

  Widget _metricBox(
    String fullLabel,
    int count,
    String subLabel,
    Color color,
    Color bgColor,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullLabel,
            style: DytavaTypography.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: DytavaTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _decisionBadge(DecisionStatus status) => switch (status) {
    DecisionStatus.exact => DytavaStatusBadge.exact(),
    DecisionStatus.equivalent => DytavaStatusBadge.equivalent(),
    DecisionStatus.different => DytavaStatusBadge.different(),
    DecisionStatus.unresolved => DytavaStatusBadge.unresolved(),
  };

  Widget _diffNavigation(CellDifference current) {
    final list = flow.selectedCells;
    final index = list.indexWhere((c) => c.id == current.id);
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < list.length - 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DytavaColors.border),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Trước'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: hasPrev
                ? () => setState(() => flow.detailId = list[index - 1].id)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Khác biệt ${index >= 0 ? index + 1 : 1}/${list.length}',
                style: DytavaTypography.titleMedium.copyWith(fontSize: 13),
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Sau'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: hasNext
                ? () => setState(() => flow.detailId = list[index + 1].id)
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _detail() {
    final cell = flow.result!.cells.firstWhere((c) => c.id == flow.detailId);
    return [
      _diffNavigation(cell),
      _card(
        children: [
          Row(
            children: [
              Expanded(
                child: _heading(
                  '${cell.mapping.fieldA} ↔ ${cell.mapping.fieldB}',
                ),
              ),
              const SizedBox(width: 8),
              _decisionBadge(cell.decision.status),
            ],
          ),
          _text(
            '${_name(cell.decision.status)} · Hàng ${cell.rowA} ↔ ${cell.rowB}',
          ),
        ],
      ),
      for (final side in SourceSide.values) ...[
        _card(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: side == SourceSide.a
                        ? DytavaColors.primary
                        : DytavaColors.secondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    side.name.toUpperCase(),
                    style: const TextStyle(
                      color: DytavaColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _heading('Nguồn ${side.name.toUpperCase()}'),
                ),
              ],
            ),
            const Divider(height: 16),
            _text(
              'Physical kind: ${(side == SourceSide.a ? cell.a : cell.b).kind.name}',
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                'Raw: ${(side == SourceSide.a ? cell.a : cell.b).rawLexeme ?? '[không có lexeme]'}',
                style: DytavaTypography.dataMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _text(
              'Canonical: ${(side == SourceSide.a ? cell.decision.left : cell.decision.right)?.label ?? '[không đủ căn cứ]'}',
            ),
            _text(
              'Vị trí fixture: ${side == SourceSide.a ? cell.locationA ?? '[không có reference]' : cell.locationB ?? '[không có reference]'}',
            ),
          ],
        ),
      ],
      if (cell.a.rawLexeme != null &&
          cell.b.rawLexeme != null &&
          cell.a.rawLexeme != cell.b.rawLexeme)
        _card(
          children: [
            _heading('Đối chiếu trực quan chuỗi'),
            TextDifferenceEvidence(a: cell.a.rawLexeme!, b: cell.b.rawLexeme!),
          ],
        ),
      _card(
        children: [
          _heading('Căn cứ quyết định (Rationale)'),
          _text('Nguyên nhân: ${DytavaPriorityDiffCard.summarizeCause(cell)}'),
          _text('Rule: ${cell.decision.ruleId}'),
          if (cell.decision.reason != null)
            _text('Reason: ${cell.decision.reason!.name}'),
        ],
      ),
      const SizedBox(height: 8),
      _button('Trở về kết quả', () => _go(WorkflowScreen.results)),
    ];
  }

  List<Widget> _export() => [
    _card(
      color: DytavaColors.softBlue,
      border: Border.all(color: DytavaColors.primary.withValues(alpha: 0.3)),
      children: [
        Row(
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              color: DytavaColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bảo mật xuất báo cáo',
                style: DytavaTypography.titleMedium.copyWith(
                  color: DytavaColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _text(
          'Báo cáo có thể chứa dữ liệu nguồn. Bản flow chỉ tạo preview JSON trong bộ nhớ, chưa lưu/chia sẻ tệp.',
        ),
      ],
    ),
    _card(
      children: [
        _heading('Cấu hình xuất báo cáo'),
        DropdownButtonFormField<ExportKind>(
          initialValue: _exportKind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Đầu ra'),
          items: [
            for (final kind in ExportKind.values)
              DropdownMenuItem(
                value: kind,
                child: Text(
                  '${_name(kind)}${flow.exporter.supports(kind) ? ' (preview mẫu)' : ' (chưa hỗ trợ)'}',
                ),
              ),
          ],
          onChanged: flow.busy
              ? null
              : (kind) {
                  if (kind != null) {
                    setState(() {
                      _exportKind = kind;
                      _scopeConfirmed = false;
                    });
                  }
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExportSelection>(
          initialValue: _selection,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Phạm vi'),
          items: const [
            DropdownMenuItem(
              value: ExportSelection.fullComparison,
              child: Text('Toàn bộ'),
            ),
            DropdownMenuItem(
              value: ExportSelection.differencesOnly,
              child: Text('Chỉ sai khác + unresolved'),
            ),
          ],
          onChanged: flow.busy
              ? null
              : (selection) {
                  if (selection != null) {
                    setState(() {
                      _selection = selection;
                      _scopeConfirmed = false;
                    });
                  }
                },
        ),
        const SizedBox(height: 12),
        _check(
          'Xác nhận định dạng và phạm vi preview',
          _scopeConfirmed,
          flow.busy ? null : (value) => setState(() => _scopeConfirmed = value),
        ),
        if (!flow.exporter.supports(_exportKind))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _text(
              'Capability chưa được bật. Chọn JSON để kiểm tra preview mẫu.',
            ),
          ),
        const SizedBox(height: 12),
        _button(
          'Tạo preview JSON mẫu',
          _scopeConfirmed && flow.exporter.supports(_exportKind) && !flow.busy
              ? () => flow.exportResult(ExportRequest(_exportKind, _selection))
              : null,
        ),
        if (flow.exportState != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: _text('Preview attempt: ${_name(flow.exportState!)}'),
            ),
          ),
        if (flow.exportState?.active == true) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          _button(
            'Hủy preview',
            flow.exportState == ExportState.cancelling
                ? null
                : flow.cancelExport,
          ),
        ],
      ],
    ),
    if (flow.receipt != null)
      _card(
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: DytavaColors.exact,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preview hoàn tất · Không có tệp được xuất.',
                  style: DytavaTypography.titleMedium.copyWith(
                    color: DytavaColors.exact,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DytavaColors.darkNavy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              flow.receipt!.previewText,
              style: const TextStyle(
                fontFamily: DytavaTypography.dataFont,
                fontSize: 12,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    const SizedBox(height: 8),
    _button(
      'Trở về kết quả',
      flow.busy ? null : () => _go(WorkflowScreen.results),
    ),
  ];
}
