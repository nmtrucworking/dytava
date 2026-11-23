import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/workflow_composition.dart';
import '../../application/workflow_controller.dart';
import '../../design_system/design_system.dart';
import '../../domain/workflow.dart';
import '../../infrastructure/file_upload_service.dart';
import '../../ocr/domain/ocr_session.dart';
import '../../ocr/infrastructure/ocr_capture_service.dart';
import 'screens/home_screen_view.dart';
import 'screens/mapping_and_policy_view.dart';
import 'screens/preview_and_ocr_view.dart';
import 'screens/progress_view.dart';
import 'screens/results_and_detail_view.dart';
import 'screens/source_selection_view.dart';
import 'widgets/workflow_common_widgets.dart';

/// Khu vực tiện ích phụ trợ (không cạnh tranh với quy trình đối chiếu 4 bước)
enum _AuxiliaryView { none, history, presets, settings }

/// Dytava mobile navigation and comparison workflow.
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

  /// Số lượng phiên so sánh đã lưu để hiển thị chính xác trên header lịch sử
  int? _historyCount;

  @override
  void initState() {
    super.initState();
    flow = widget.controller ?? createMobileWorkflow();
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
      case WorkflowScreen.preview:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.ocrReview:
        final ref = flow.slot(flow.activeSide).artifact?.privateRef ?? '';
        final ocrSession = OcrCaptureService.session(ref);
        if (ocrSession != null &&
            (ocrSession.stage == OcrPipelineStage.gridStructure ||
                ocrSession.stage == OcrPipelineStage.cellReview)) {
          ocrSession.returnToPreprocess();
          setState(() {});
          return;
        }
        _go(WorkflowScreen.sources);
      case WorkflowScreen.mapping:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.policy:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.progress:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.results:
        _go(WorkflowScreen.sources);
      case WorkflowScreen.detail || WorkflowScreen.export:
        _go(WorkflowScreen.results);
    }
  }

  // ==========================================
  // UX OPTIMIZATIONS: Fast-Track Actions
  // ==========================================

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
        mappingConfirmed: mappings.isNotEmpty || flow.structuralWorkbookOnly,
      ),
    );
  }

  void _applyApprovedConfigAndRun() {
    var updated = flow.config.copyWith(
      mappingConfirmed:
          flow.config.mappings.isNotEmpty || flow.structuralWorkbookOnly,
      modeConfirmed: true,
      policyConfirmed: true,
      directionConfirmed: true,
    );
    flow.configure(updated);
    if (flow.startBlockers.isEmpty && !flow.busy) {
      setState(() => _auxView = _AuxiliaryView.none);
      flow.runComparison();
    }
  }

  Future<void> _quickConfirmAllAndRun() async {
    _applyApprovedConfigAndRun();
  }

  Future<void> _switchSheetsAndCompare({String? sheetA, String? sheetB}) async {
    setState(() => _quickProcessing = true);
    try {
      if (sheetA != null) {
        final slotA = flow.slot(SourceSide.a);
        if (slotA.artifact != null) {
          MobileFileUploadService.selectSheet(
            slotA.artifact!.privateRef,
            sheetA,
          );
          await flow.selectSource(
            SourceSide.a,
            slotA.artifact!.format,
            slotA.artifact!.privateRef,
            slotA.artifact!.label,
          );
          await flow.importSource(SourceSide.a);
          final slotNowA = flow.slot(SourceSide.a);
          if (slotNowA.state == InputState.needsReview) {
            await flow.confirmImport(
              SourceSide.a,
              expectedBinding: slotNowA.binding,
            );
          }
        }
      }
      if (sheetB != null) {
        final slotB = flow.slot(SourceSide.b);
        if (slotB.artifact != null) {
          MobileFileUploadService.selectSheet(
            slotB.artifact!.privateRef,
            sheetB,
          );
          await flow.selectSource(
            SourceSide.b,
            slotB.artifact!.format,
            slotB.artifact!.privateRef,
            slotB.artifact!.label,
          );
          await flow.importSource(SourceSide.b);
          final slotNowB = flow.slot(SourceSide.b);
          if (slotNowB.state == InputState.needsReview) {
            await flow.confirmImport(
              SourceSide.b,
              expectedBinding: slotNowB.binding,
            );
          }
        }
      }
      if (flow.inputsReady) {
        flow.analyzeAndPropose();
        if (flow.proposal != null) {
          flow.applyProposal(run: false);
        } else {
          _autoMapFields();
        }
        _applyApprovedConfigAndRun();
      }
    } finally {
      if (mounted) setState(() => _quickProcessing = false);
    }
  }

  Future<void> _openExport() async {
    _scopeConfirmed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => AnimatedBuilder(
          animation: flow,
          builder: (context, _) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ExportScreenView(
                flow: flow,
                exportKind: _exportKind,
                selection: _selection,
                scopeConfirmed: _scopeConfirmed,
                onKindChanged: (kind) => update(() {
                  _exportKind = kind;
                  _scopeConfirmed = false;
                }),
                onSelectionChanged: (selection) => update(() {
                  _selection = selection;
                  _scopeConfirmed = false;
                }),
                onScopeConfirmedChanged: (value) =>
                    update(() => _scopeConfirmed = value),
                onRunExportPreview: () =>
                    flow.exportResult(ExportRequest(_exportKind, _selection)),
                onBackToResults: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
        ),
      ),
    );
    if (flow.exportState?.active == true) await flow.cancelExport();
  }

  void _compareAutomatically() {
    if (!flow.inputsReady || flow.busy) return;
    final policy = flow.config.webPolicy;
    flow.analyzeAndPropose();
    flow.applyProposal(run: false);
    flow.configure(flow.config.copyWith(webPolicy: policy));
    _autoMapFields();
    _applyApprovedConfigAndRun();
  }

  String _appBarTitle() {
    if (_auxView == _AuxiliaryView.history) return 'Recent comparisons';
    if (_auxView == _AuxiliaryView.presets) return 'Mẫu quy tắc';
    if (_auxView == _AuxiliaryView.settings) return 'App settings';
    if (flow.screen == WorkflowScreen.ocrReview) {
      final ref = flow.slot(flow.activeSide).artifact?.privateRef ?? '';
      final ocrSession = OcrCaptureService.session(ref);
      if (ocrSession != null) {
        return switch (ocrSession.stage) {
          OcrPipelineStage.preprocess => 'Chọn vùng bảng',
          OcrPipelineStage.recognizing => 'Đang quét bảng',
          OcrPipelineStage.gridStructure ||
          OcrPipelineStage.cellReview =>
            'Kiểm tra bảng',
        };
      }
      return 'OCR review';
    }
    const titles = [
      'Dytava',
      'Import files',
      'File preview',
      'OCR review',
      'Column mapping',
      'Review comparison',
      'Comparing files',
      'Comparison results',
      'Change details',
      'Export report',
    ];
    return titles[flow.screen.index];
  }

  @override
  Widget build(BuildContext context) {
    final isRootHome =
        flow.screen == WorkflowScreen.home && _auxView == _AuxiliaryView.none;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tự động nhận diện màn hình lớn (Desktop / Web / Tablet >= 600dp), nhưng không bóp khung 9:16 khi thiết bị xoay ngang (landscape)
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final isLargeScreen = constraints.maxWidth >= 600 && !isLandscape;

        final isOcrScreen =
            flow.screen == WorkflowScreen.ocrReview &&
            _auxView == _AuxiliaryView.none;

        final scaffold = Scaffold(
          backgroundColor: DytavaColors.background,
          appBar: AppBar(
            toolbarHeight: isRootHome ? 48 : (isOcrScreen ? 48 : 44),
            titleSpacing: isRootHome ? 16 : 6,
            title: isRootHome
                ? Row(
                    children: [
                      SvgPicture.asset(
                        'assets/dytava/figma/home-logo.svg',
                        width: 24,
                        height: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Dytava',
                                style: DytavaTypography.titleLarge.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Excel Compare',
                                style: DytavaTypography.bodySmall.copyWith(
                                  fontSize: 10.5,
                                  color: DytavaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    _appBarTitle(),
                    style: DytavaTypography.titleLarge.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
            backgroundColor: DytavaColors.background,
            elevation: 0,
            leadingWidth: 46,
            leading: isRootHome || flow.screen == WorkflowScreen.progress
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Center(
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: flow.busy ? null : _back,
                        style: IconButton.styleFrom(
                          backgroundColor: DytavaColors.primaryLight,
                          padding: EdgeInsets.zero,
                          fixedSize: const Size(32, 32),
                          minimumSize: const Size(32, 32),
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: DytavaColors.primary,
                        ),
                      ),
                    ),
                  ),
            actions: [
              if (isRootHome)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: IconButton(
                      tooltip: 'Comparison settings',
                      onPressed: () =>
                          setState(() => _auxView = _AuxiliaryView.settings),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F2),
                        padding: EdgeInsets.zero,
                        fixedSize: const Size(32, 32),
                        minimumSize: const Size(32, 32),
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              if (_auxView == _AuxiliaryView.history)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Text(
                      _historyCount == null
                          ? (flow.lastSavedSession == null && !flow.resultCurrent
                              ? 'No saved comparisons'
                              : 'Saved comparisons')
                          : (_historyCount == 0
                              ? 'No saved comparisons'
                              : '$_historyCount saved comparison${_historyCount == 1 ? '' : 's'}'),
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (!isRootHome &&
                  !isOcrScreen &&
                  flow.screen != WorkflowScreen.progress &&
                  _auxView == _AuxiliaryView.none)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: PopupMenuButton<String>(
                        tooltip: 'Session actions',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: Color(0xFF334155),
                        ),
                        onSelected: (action) async {
                          if (action == 'home') {
                            _go(WorkflowScreen.home);
                          } else {
                            await flow.closeSession();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'home',
                            enabled: !flow.busy,
                            child: const Text('Home'),
                          ),
                          PopupMenuItem(
                            value: 'close',
                            enabled: flow.usable && !flow.busy,
                            child: const Text('Close comparison'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Stack(
            children: [
              if (isRootHome)
                Positioned(
                  left: -75,
                  bottom: -10,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.1,
                      child: SvgPicture.asset(
                        'assets/dytava/figma/home-decoration.svg',
                        width: 171,
                        height: 157,
                      ),
                    ),
                  ),
                ),
              SafeArea(
                bottom: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.topCenter,
                      children: <Widget>[...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${flow.screen.name}-aux-${_auxView.name}'),
                    child: _buildScreenContent(constraints),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: isRootHome
              ? Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 20),
                  child: SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(1) > 1.3
                        ? 276
                        : 236,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Tap to compare',
                                style: DytavaTypography.titleLarge.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select two files to begin',
                                style: DytavaTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SvgPicture.asset(
                                'assets/dytava/figma/home-underline.svg',
                                width: 88,
                                height: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: FloatingActionButton(
                            heroTag: 'compare-files',
                            tooltip: 'Compare files',
                            onPressed: () => _go(WorkflowScreen.sources),
                            backgroundColor: DytavaColors.primary,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: SvgPicture.asset(
                              'assets/dytava/figma/compare-action.svg',
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );

        Widget page = scaffold;

        // Căn giữa chuẩn flex-center trên Desktop / Web / Tablet (giữ nguyên chuẩn xác tỉ lệ 9:16 mobile)
        if (isLargeScreen) {
          final targetWidth = (constraints.maxHeight * 9 / 16).clamp(
            380.0,
            480.0,
          );
          page = Container(
            color: DytavaColors.warmSurface,
            alignment: Alignment.center,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: targetWidth,
                  maxHeight: constraints.maxHeight,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: DytavaColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: DytavaColors.subtleBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: scaffold,
                ),
              ),
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: DytavaColors.background,
          ),
          child: PopScope(
            canPop: isRootHome && !flow.busy,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_back());
            },
            child: page,
          ),
        );
      },
    );
  }

  Widget _buildScreenContent(BoxConstraints constraints) {
    final padHorizontal = constraints.maxWidth < 350 ? 20.0 : 24.0;
    final isRootHome =
        flow.screen == WorkflowScreen.home && _auxView == _AuxiliaryView.none;

    if (_auxView == _AuxiliaryView.history) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padHorizontal, vertical: 8),
        child: WorkflowSessionHistoryView(
          flow: flow,
          onCountChanged: (count) {
            if (mounted && _historyCount != count) {
              setState(() => _historyCount = count);
            }
          },
          onOpenResults: () => _go(WorkflowScreen.results),
          onStartNewComparison: () => _go(WorkflowScreen.sources),
          onRestoreSession: (id) async {
            final ok = await flow.restoreSavedSession(id);
            if (ok) _go(WorkflowScreen.results);
          },
        ),
      );
    }
    if (_auxView == _AuxiliaryView.presets) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: padHorizontal, vertical: 12),
        child: WorkflowLearnAndPresetsView(
          selectedPreset: _selectedPolicyPreset,
          onSelectPreset: (id) => setState(() => _selectedPolicyPreset = id),
        ),
      );
    }
    if (_auxView == _AuxiliaryView.settings) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: padHorizontal, vertical: 12),
        child: WorkflowSettingsView(
          flow: flow,
          onOpenPresets: () =>
              setState(() => _auxView = _AuxiliaryView.presets),
        ),
      );
    }

    if (const {
          WorkflowScreen.mapping,
          WorkflowScreen.policy,
        }.contains(flow.screen) &&
        !flow.inputsReady) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padHorizontal),
              child: const WorkflowSectionCard(
                children: [
                  WorkflowInfoBanner(
                    text:
                        'Nguồn đã thay đổi; cần xác thực lại trước khi cấu hình.',
                    iconAsset: DytavaIcons.warning,
                    color: DytavaColors.unresolved,
                    bgColor: DytavaColors.softAmber,
                  ),
                ],
              ),
            ),
          ),
          StickyBottomBar(
            child: WorkflowSecondaryButton(
              label: 'Về nguồn A/B',
              iconAsset: DytavaIcons.back,
              onPressed: () => _go(WorkflowScreen.sources),
            ),
          ),
        ],
      );
    }

    if (const {
          WorkflowScreen.results,
          WorkflowScreen.detail,
          WorkflowScreen.export,
        }.contains(flow.screen) &&
        !flow.resultCurrent) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padHorizontal),
              child: const WorkflowSectionCard(
                children: [
                  WorkflowInfoBanner(
                    text:
                        'Kết quả đã mất hiệu lực. Hãy xác thực nguồn và so sánh lại.',
                    iconAsset: DytavaIcons.error,
                    color: DytavaColors.different,
                    bgColor: DytavaColors.softRed,
                  ),
                ],
              ),
            ),
          ),
          StickyBottomBar(
            child: WorkflowSecondaryButton(
              label: 'Về nguồn A/B',
              iconAsset: DytavaIcons.back,
              onPressed: () => _go(WorkflowScreen.sources),
            ),
          ),
        ],
      );
    }

    Widget content;

    switch (flow.screen) {
      case WorkflowScreen.home:
        content = SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padHorizontal, 0, padHorizontal, 96),
          child: HomeScreenView(
            flow: flow,
            quickProcessing: _quickProcessing,
            onStartNewSession: () => _go(WorkflowScreen.sources),
            onResumeSession: _resumeCurrentSession,
            onViewHistory: () =>
                setState(() => _auxView = _AuxiliaryView.history),
            onCloseSession: () async {
              await flow.closeSession();
              if (mounted) setState(() => _auxView = _AuxiliaryView.none);
            },
          ),
        );
      case WorkflowScreen.sources:
        content = SourceSelectionView(
          flow: flow,
          quickProcessing: _quickProcessing,
          onOpenPreview: (side) => _go(WorkflowScreen.preview, side: side),
          onContinueMapping: () => _go(WorkflowScreen.mapping),
          onContinueToProposal: _compareAutomatically,
        );
      case WorkflowScreen.preview:
        content = PreviewScreenView(
          flow: flow,
          onOpenOcrReview: () =>
              _go(WorkflowScreen.ocrReview, side: flow.activeSide),
          onBackToSources: () => _go(WorkflowScreen.sources),
        );
      case WorkflowScreen.ocrReview:
        final source = flow.slot(flow.activeSide);
        if (_reviewBinding != source.binding) {
          _reviewBinding = source.binding;
          _reviewed.clear();
        }
        final cells = source.review?.cells ?? const <ReviewCell>[];
        content = OcrReviewScreenView(
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
          onFinalizedSession: () {
            if (mounted) {
              _go(WorkflowScreen.sources, side: source.side);
            }
          },
          onSelectAnotherImage: () {
            if (mounted) {
              _go(WorkflowScreen.sources, side: source.side);
            }
          },
          onStageChanged: () {
            if (mounted) setState(() {});
          },
        );
      case WorkflowScreen.mapping:
        content = MappingScreenView(
          flow: flow,
          onAutoMap: _autoMapFields,
          onContinuePolicy: () => _go(WorkflowScreen.policy),
        );
      case WorkflowScreen.policy:
        content = PolicyScreenView(
          flow: flow,
          onQuickConfirmAndRun: _quickConfirmAllAndRun,
        );
      case WorkflowScreen.progress:
        content = ProgressScreenView(
          flow: flow,
          onBackToPolicyOrSources: () => _go(
            flow.inputsReady ? WorkflowScreen.policy : WorkflowScreen.sources,
          ),
        );
      case WorkflowScreen.results:
        content = ResultsScreenView(
          flow: flow,
          resultViewTab: _resultViewTab,
          onResultViewTabChanged: (idx) =>
              setState(() => _resultViewTab = idx),
          onOpenDetail: (cellId) =>
              _go(WorkflowScreen.detail, cellId: cellId),
          onOpenExport: _openExport,
          onSwitchSheetsAndCompare: _switchSheetsAndCompare,
        );
      case WorkflowScreen.detail:
        content = DifferenceDetailScreenView(
          flow: flow,
          onSelectCellId: (id) => setState(() => flow.detailId = id),
          onBackToResults: () => _go(WorkflowScreen.results),
        );
      case WorkflowScreen.export:
        content = SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: padHorizontal, vertical: 12),
          child: ExportScreenView(
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
        );
    }

    if (flow.screen == WorkflowScreen.mapping ||
        flow.screen == WorkflowScreen.policy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padHorizontal, 6, padHorizontal, 6),
            child: DytavaGuidedStepHeader(screen: flow.screen),
          ),
          if (flow.issue != null && _auxView == _AuxiliaryView.none)
            Padding(
              padding: EdgeInsets.fromLTRB(padHorizontal, 0, padHorizontal, 6),
              child: Semantics(
                liveRegion: true,
                child: WorkflowIssueList(issues: [flow.issue!]),
              ),
            ),
          Expanded(child: content),
        ],
      );
    }

    if (flow.issue != null &&
        _auxView == _AuxiliaryView.none &&
        !isRootHome &&
        flow.screen != WorkflowScreen.ocrReview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padHorizontal, 6, padHorizontal, 6),
            child: Semantics(
              liveRegion: true,
              child: WorkflowIssueList(issues: [flow.issue!]),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }
}
