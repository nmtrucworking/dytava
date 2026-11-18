import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../app/workflow_composition.dart';
import '../../application/workflow_controller.dart';
import '../../design_system/design_system.dart';
import '../../domain/workflow.dart';
import 'screens/home_screen_view.dart';
import 'screens/mapping_and_policy_view.dart';
import 'screens/preview_and_ocr_view.dart';
import 'screens/progress_view.dart';
import 'screens/results_and_detail_view.dart';
import 'screens/source_selection_view.dart';
import 'widgets/workflow_common_widgets.dart';

/// Khu vực tiện ích phụ trợ (không cạnh tranh với quy trình đối chiếu 4 bước)
enum _AuxiliaryView { none, history, presets, settings }

/// Giao diện ứng dụng di động Dytava thiết kế theo kiến trúc Guided Mobile Workflow:
/// - Tách điều hướng ứng dụng khỏi các bước workflow (loại bỏ thanh 5 tab trang trí cố định).
/// - Trang chủ tập trung vào một CTA chính ("So sánh mới") và "Phiên hiện tại — Tiếp tục phiên so sánh".
/// - Mỗi màn hình trong luồng 4 bước (`Nguồn → Cấu hình → So sánh → Kết quả`) tập trung vào một thao tác chính.
/// - Tích hợp đồng bộ `BrandIcon` và `BrandIllustration` theo trạng thái nghiệp vụ.
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

  /// Màn hình tiện ích phụ trợ khi mở từ Trang chủ hoặc AppBar
  _AuxiliaryView _auxView = _AuxiliaryView.none;

  /// Chế độ hiển thị bảng đầy đủ trên SCR-08:
  /// 0: Sheet Diff (2 Bảng), 1: Theo danh sách ô
  int _resultViewTab = 0;

  /// Mẫu quy tắc đang chọn trong mục Mẫu quy tắc
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
        if (flow.screen != WorkflowScreen.home &&
            _auxView != _AuxiliaryView.none) {
          _auxView = _AuxiliaryView.none;
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

  void _go(WorkflowScreen screen, {SourceSide? side, String? cellId}) {
    if (screen == WorkflowScreen.export) _scopeConfirmed = false;
    setState(() {
      _auxView = _AuxiliaryView.none;
    });
    flow.navigate(screen, side: side, cellId: cellId);
  }

  void _resumeCurrentSession() {
    setState(() => _auxView = _AuxiliaryView.none);
    if (flow.resultCurrent) {
      flow.navigate(WorkflowScreen.results);
    } else if (flow.inputsReady) {
      flow.navigate(
        flow.config.mappingConfirmed
            ? WorkflowScreen.policy
            : WorkflowScreen.mapping,
      );
    } else {
      flow.navigate(WorkflowScreen.sources);
    }
  }

  Future<void> _back() async {
    if (flow.busy) return;
    if (_auxView != _AuxiliaryView.none) {
      setState(() => _auxView = _AuxiliaryView.none);
      return;
    }
    switch (flow.screen) {
      case WorkflowScreen.home:
        return;
      case WorkflowScreen.sources:
        flow.navigate(WorkflowScreen.home);
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
      setState(() => _auxView = _AuxiliaryView.none);
      flow.runComparison();
    }
  }

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

  Future<void> _oneTapQuickRun() async {
    await _quickPrepareBoth();
    if (!flow.inputsReady) return;
    _autoMapFields();
    _applyApprovedConfigAndRun();
  }

  String _appBarTitle() {
    if (_auxView == _AuxiliaryView.history) return 'Phiên hiện tại';
    if (_auxView == _AuxiliaryView.presets) return 'Mẫu quy tắc';
    if (_auxView == _AuxiliaryView.settings) return 'Cài đặt & bảo mật';
    const titles = [
      'Dytava',
      'Chọn nguồn A/B',
      'Kiểm tra nguồn',
      'Duyệt dữ liệu OCR',
      'Ánh xạ cột',
      'Xác nhận cấu hình',
      'Tiến trình',
      'Kết quả đối chiếu',
      'Chi tiết sai khác',
      'Xuất báo cáo',
    ];
    return titles[flow.screen.index];
  }

  @override
  Widget build(BuildContext context) {
    final isRootHome =
        flow.screen == WorkflowScreen.home && _auxView == _AuxiliaryView.none;

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
                  icon: const BrandIcon(DytavaIcons.back, size: 20),
                ),
          actions: [
            if (isRootHome) ...[
              IconButton(
                tooltip: 'Phiên trong bộ nhớ',
                onPressed: () =>
                    setState(() => _auxView = _AuxiliaryView.history),
                icon: const Icon(Icons.history_rounded),
              ),
              PopupMenuButton<_AuxiliaryView>(
                tooltip: 'Thêm tùy chọn',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (view) =>
                    setState(() => _auxView = view),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _AuxiliaryView.presets,
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Mẫu quy tắc'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _AuxiliaryView.settings,
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Cài đặt & bảo mật'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (!isRootHome)
              IconButton(
                tooltip: 'Về trang chủ',
                onPressed: flow.busy
                    ? null
                    : () {
                        setState(() => _auxView = _AuxiliaryView.none);
                        flow.navigate(WorkflowScreen.home);
                      },
                icon: const BrandIcon(DytavaIcons.navHome, size: 20),
              ),
            if (flow.screen != WorkflowScreen.home)
              IconButton(
                tooltip: 'Đóng phiên và dọn dữ liệu mẫu',
                onPressed: flow.usable
                    ? () async {
                        await flow.closeSession();
                        if (mounted) {
                          setState(() => _auxView = _AuxiliaryView.none);
                        }
                      }
                    : null,
                icon: const BrandIcon(DytavaIcons.close, size: 20),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Bố cục thích ứng theo kích thước thiết bị (320dp / 360dp / 412dp / tablet >= 600dp)
              final width = constraints.maxWidth;
              final horizontalPadding = width < 350
                  ? 12.0
                  : (width >= 600 ? 24.0 : 16.0);
              final maxContentWidth = width >= 680 ? 960.0 : 640.0;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: ListView(
                    key: ValueKey('${flow.screen.name}-aux-${_auxView.name}'),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    children: [
                      if (_auxView == _AuxiliaryView.none &&
                          flow.screen != WorkflowScreen.home)
                        DytavaGuidedStepHeader(screen: flow.screen),
                      if (flow.issue != null && _auxView == _AuxiliaryView.none)
                        Semantics(
                          liveRegion: true,
                          child: WorkflowIssueList(issues: [flow.issue!]),
                        ),
                      ..._buildActiveContent(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActiveContent() {
    if (_auxView == _AuxiliaryView.history) {
      return [
        WorkflowSessionHistoryView(
          flow: flow,
          onOpenResults: () => _go(WorkflowScreen.results),
          onQuickRun: _oneTapQuickRun,
        ),
      ];
    }
    if (_auxView == _AuxiliaryView.presets) {
      return [
        WorkflowLearnAndPresetsView(
          selectedPreset: _selectedPolicyPreset,
          onSelectPreset: (id) => setState(() => _selectedPolicyPreset = id),
        ),
      ];
    }
    if (_auxView == _AuxiliaryView.settings) {
      return const [WorkflowSettingsView()];
    }
    return _buildWorkflowScreenContent();
  }

  List<Widget> _buildWorkflowScreenContent() {
    if (const {
          WorkflowScreen.mapping,
          WorkflowScreen.policy,
        }.contains(flow.screen) &&
        !flow.inputsReady) {
      return [
        WorkflowSectionCard(
          children: [
            const WorkflowInfoBanner(
              text: 'Nguồn đã thay đổi; cần xác thực lại trước khi cấu hình.',
              iconAsset: DytavaIcons.warning,
              color: DytavaColors.unresolved,
              bgColor: DytavaColors.softAmber,
            ),
            const SizedBox(height: 12),
            WorkflowPrimaryButton(
              label: 'Về nguồn A/B',
              iconAsset: DytavaIcons.back,
              onPressed: () => _go(WorkflowScreen.sources),
            ),
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
        WorkflowSectionCard(
          children: [
            const WorkflowInfoBanner(
              text:
                  'Kết quả đã mất hiệu lực. Hãy xác thực nguồn và so sánh lại.',
              iconAsset: DytavaIcons.error,
              color: DytavaColors.different,
              bgColor: DytavaColors.softRed,
            ),
            const SizedBox(height: 12),
            WorkflowPrimaryButton(
              label: 'Về nguồn A/B',
              iconAsset: DytavaIcons.back,
              onPressed: () => _go(WorkflowScreen.sources),
            ),
          ],
        ),
      ];
    }

    switch (flow.screen) {
      case WorkflowScreen.home:
        return [
          HomeScreenView(
            flow: flow,
            quickProcessing: _quickProcessing,
            onStartNewSession: () => _go(WorkflowScreen.sources),
            onQuickRun: _oneTapQuickRun,
            onResumeSession: _resumeCurrentSession,
            onCloseSession: () async {
              await flow.closeSession();
              if (mounted) setState(() => _auxView = _AuxiliaryView.none);
            },
          ),
        ];
      case WorkflowScreen.sources:
        return [
          SourceSelectionView(
            flow: flow,
            quickProcessing: _quickProcessing,
            onQuickPrepareBoth: _quickPrepareBoth,
            onOpenPreview: (side) => _go(WorkflowScreen.preview, side: side),
            onContinueMapping: () => _go(WorkflowScreen.mapping),
          ),
        ];
      case WorkflowScreen.preview:
        return [
          PreviewScreenView(
            flow: flow,
            onOpenOcrReview: () =>
                _go(WorkflowScreen.ocrReview, side: flow.activeSide),
            onBackToSources: () => _go(WorkflowScreen.sources),
          ),
        ];
      case WorkflowScreen.ocrReview:
        final source = flow.slot(flow.activeSide);
        if (_reviewBinding != source.binding) {
          _reviewBinding = source.binding;
          _reviewed.clear();
        }
        final cells = source.review?.cells ?? const <ReviewCell>[];
        return [
          OcrReviewScreenView(
            flow: flow,
            reviewedCells: _reviewed,
            onToggleCell: (cellId) => setState(() {
              _reviewed.contains(cellId)
                  ? _reviewed.remove(cellId)
                  : _reviewed.add(cellId);
            }),
            onReviewAll: () => setState(() {
              _reviewed.addAll(cells.map((c) => c.id));
            }),
            onConfirmReviewed: () async {
              await flow.confirmImport(
                source.side,
                expectedBinding: source.binding,
                reviewedCells: Set.of(_reviewed),
              );
              if (mounted) {
                _go(WorkflowScreen.preview, side: source.side);
              }
            },
          ),
        ];
      case WorkflowScreen.mapping:
        return [
          MappingScreenView(
            flow: flow,
            onAutoMap: _autoMapFields,
            onContinuePolicy: () => _go(WorkflowScreen.policy),
          ),
        ];
      case WorkflowScreen.policy:
        return [
          PolicyScreenView(
            flow: flow,
            onQuickConfirmAndRun: _quickConfirmAllAndRun,
          ),
        ];
      case WorkflowScreen.progress:
        return [
          ProgressScreenView(
            flow: flow,
            onBackToPolicyOrSources: () => _go(
              flow.inputsReady ? WorkflowScreen.policy : WorkflowScreen.sources,
            ),
          ),
        ];
      case WorkflowScreen.results:
        return [
          ResultsScreenView(
            flow: flow,
            resultViewTab: _resultViewTab,
            onResultViewTabChanged: (idx) =>
                setState(() => _resultViewTab = idx),
            onOpenDetail: (cellId) =>
                _go(WorkflowScreen.detail, cellId: cellId),
            onOpenExport: () => _go(WorkflowScreen.export),
          ),
        ];
      case WorkflowScreen.detail:
        return [
          DifferenceDetailScreenView(
            flow: flow,
            onSelectCellId: (id) => setState(() => flow.detailId = id),
            onBackToResults: () => _go(WorkflowScreen.results),
          ),
        ];
      case WorkflowScreen.export:
        return [
          ExportScreenView(
            flow: flow,
            exportKind: _exportKind,
            selection: _selection,
            scopeConfirmed: _scopeConfirmed,
            onKindChanged: (kind) => setState(() {
              _exportKind = kind;
              _scopeConfirmed = false;
            }),
            onSelectionChanged: (sel) => setState(() {
              _selection = sel;
              _scopeConfirmed = false;
            }),
            onScopeConfirmedChanged: (val) =>
                setState(() => _scopeConfirmed = val),
            onRunExportPreview: () =>
                flow.exportResult(ExportRequest(_exportKind, _selection)),
            onBackToResults: () => _go(WorkflowScreen.results),
          ),
        ];
    }
  }
}
