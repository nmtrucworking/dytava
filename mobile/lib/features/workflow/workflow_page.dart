import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
import '../../l10n/app_localizations.dart';
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
    flow.receipt = null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => AnimatedBuilder(
          animation: flow,
          builder: (context, _) => SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ExportScreenView(
                  flow: flow,
                  exportKind: _exportKind,
                  selection: _selection,
                  scopeConfirmed: _scopeConfirmed,
                  onKindChanged: (kind) => update(() {
                    _exportKind = kind;
                    _scopeConfirmed = false;
                    flow.receipt = null;
                  }),
                  onSelectionChanged: (selection) => update(() {
                    _selection = selection;
                    _scopeConfirmed = false;
                    flow.receipt = null;
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

  void _applyPresetToFlow(String presetId) {
    final policy = switch (presetId) {
      'financial-reconcile-v1' => const WebComparisonPolicy(
        trimText: true,
        caseSensitiveText: false,
        preserveLeadingZeros: false,
      ),
      'inventory-sku-strict' => const WebComparisonPolicy(
        trimText: false,
        caseSensitiveText: true,
        preserveLeadingZeros: true,
      ),
      _ => const WebComparisonPolicy(
        trimText: true,
        caseSensitiveText: false,
        preserveLeadingZeros: true,
      ),
    };
    final mode = presetId == 'inventory-sku-strict'
        ? MatchingMode.key
        : MatchingMode.positional;
    flow.configure(
      flow.config.copyWith(
        mode: mode,
        modeConfirmed: true,
        webPolicy: policy,
        policyConfirmed: true,
      ),
    );
  }

  String _appBarTitle(BuildContext context) {
    final hasExplicitLocale = Localizations.of<AppLocalizations>(context, AppLocalizations) != null;
    final l10n = hasExplicitLocale
        ? context.l10n
        : (flow.screen == WorkflowScreen.ocrReview
            ? AppLocalizations(const Locale('vi'))
            : context.l10n);
    if (_auxView == _AuxiliaryView.history) return l10n.titleHistory;
    if (_auxView == _AuxiliaryView.presets) return l10n.titlePresets;
    if (_auxView == _AuxiliaryView.settings) return l10n.titleSettings;
    if (flow.screen == WorkflowScreen.ocrReview) {
      final ref = flow.slot(flow.activeSide).artifact?.privateRef ?? '';
      final ocrSession = OcrCaptureService.session(ref);
      if (ocrSession != null) {
        return switch (ocrSession.stage) {
          OcrPipelineStage.preprocess => l10n.ocrStagePreprocess,
          OcrPipelineStage.recognizing => l10n.ocrStageRecognizing,
          OcrPipelineStage.gridStructure ||
          OcrPipelineStage.cellReview =>
            l10n.ocrStageReview,
        };
      }
      return l10n.titleOcr;
    }
    final titles = [
      l10n.titleHome,
      l10n.titleImport,
      l10n.titlePreview,
      l10n.titleOcr,
      l10n.titleMapping,
      l10n.titleReview,
      l10n.titleComparing,
      l10n.titleResults,
      l10n.titleDetail,
      l10n.titleExport,
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
                                context.l10n.appSubtitle,
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
                    _appBarTitle(context),
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
                        tooltip: context.l10n.back,
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
                      tooltip: context.l10n.comparisonSettingsTooltip,
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
              if (!isRootHome &&
                  !isOcrScreen &&
                  flow.screen != WorkflowScreen.progress &&
                  _auxView == _AuxiliaryView.none)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: _MoreSessionPopoverButton(
                      flow: flow,
                      onGoHome: () => _go(WorkflowScreen.home),
                      onExitApp: () async {
                        await flow.closeSession();
                        await SystemNavigator.pop();
                      },
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
                  duration: const Duration(milliseconds: 280),
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
                          begin: const Offset(0, 0.025),
                          end: Offset.zero,
                        ).animate(curved),
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.985,
                            end: 1.0,
                          ).animate(curved),
                          child: child,
                        ),
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
                                context.l10n.isVietnamese
                                    ? 'Chạm để đối chiếu'
                                    : 'Tap to compare',
                                style: DytavaTypography.titleLarge.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.isVietnamese
                                    ? 'Chọn hai tệp để bắt đầu'
                                    : 'Select two files to begin',
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
          flow: flow,
          selectedPreset: _selectedPolicyPreset,
          onSelectPreset: (id) {
            setState(() => _selectedPolicyPreset = id);
            _applyPresetToFlow(id);
          },
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
              child: WorkflowSectionCard(
                children: [
                  WorkflowInfoBanner(
                    text: context.l10n.sourcesChangedRevalidate,
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
              label: context.l10n.backToSources,
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

/// Nút More mở Popover radial:
/// - Bình thường biểu tượng 3 chấm đứng thẳng 0 độ (0°), khi mở popover xoay mượt sang 45 độ (45°), khi đóng xoay về 0 độ.
/// - Khi mở popover: Icon `+` xuất hiện trước tiên ở góc trên phải,
///   3 icons còn lại (Thoát ứng dụng / Power ở trên cùng bên trái, Chuyển ngôn ngữ / Globe ở giữa, Về trang chủ / Home ở dưới cùng)
///   lần lượt xuất hiện theo đường tròn từ trên xuống dưới.
class _MoreSessionPopoverButton extends StatefulWidget {
  final WorkflowController flow;
  final VoidCallback onGoHome;
  final Future<void> Function() onExitApp;

  const _MoreSessionPopoverButton({
    required this.flow,
    required this.onGoHome,
    required this.onExitApp,
  });

  @override
  State<_MoreSessionPopoverButton> createState() =>
      _MoreSessionPopoverButtonState();
}

class _MoreSessionPopoverButtonState extends State<_MoreSessionPopoverButton> {
  bool _isOpen = false;

  Future<void> _openPopover(BuildContext context) async {
    final buttonBox = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    Offset anchor = const Offset(340, 88);
    if (buttonBox != null && overlayBox != null) {
      final pos = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      anchor = Offset(
        pos.dx + buttonBox.size.width,
        pos.dy + buttonBox.size.height + 10,
      );
    }

    setState(() => _isOpen = true);
    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          barrierLabel: 'Dismiss more menu',
          transitionDuration: const Duration(milliseconds: 440),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (routeContext, animation, secondaryAnimation) {
            return _RadialMorePopoverOverlay(
              flow: widget.flow,
              anchor: anchor,
              animation: animation,
              onDismiss: () => Navigator.of(routeContext).pop(),
              onGoHome: () {
                Navigator.of(routeContext).pop();
                widget.onGoHome();
              },
              onExitApp: () async {
                Navigator.of(routeContext).pop();
                await widget.onExitApp();
              },
            );
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _isOpen ? const Color(0xFFEDF7F0) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: _isOpen ? const Color(0xFFB7DFC6) : const Color(0xFFE2EAE5),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isOpen ? 0.08 : 0.04),
            blurRadius: _isOpen ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('more-popover-trigger'),
          customBorder: const CircleBorder(),
          onTap: () {
            DytavaAudioFeedback.playClick();
            _openPopover(context);
          },
          child: Tooltip(
            message: 'Session actions',
            child: Center(
              child: AnimatedRotation(
                turns: _isOpen ? 0.125 : 0.0, // 0° khi đóng, 45° (1/8 vòng) khi mở
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: _isOpen
                      ? DytavaColors.primaryDark
                      : const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialMorePopoverOverlay extends StatelessWidget {
  final WorkflowController flow;
  final Offset anchor;
  final Animation<double> animation;
  final VoidCallback onDismiss;
  final VoidCallback onGoHome;
  final Future<void> Function() onExitApp;

  const _RadialMorePopoverOverlay({
    required this.flow,
    required this.anchor,
    required this.animation,
    required this.onDismiss,
    required this.onGoHome,
    required this.onExitApp,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    const double cardWidth = 188;
    const double cardHeight = 184;
    final double right = (screenSize.width - anchor.dx).clamp(
      12.0,
      math.max(12.0, screenSize.width - cardWidth - 12.0),
    );
    final double top = anchor.dy.clamp(
      56.0,
      math.max(56.0, screenSize.height - cardHeight - 24.0),
    );

    // 1. Khung nền kính mờ
    final cardOpacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    final cardScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Icon + xuất hiện đầu tiên
    final plusAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.04, 0.36, curve: Curves.easeOutBack),
    );

    // 3. 3 icons còn lại lần lượt xuất hiện theo đường tròn từ trên xuống:
    // (1) Power / Close session (trên cùng của cung tròn)
    final item1Anim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.22, 0.58, curve: Curves.easeOutBack),
    );
    // (2) Language toggle (giữa cung tròn)
    final item2Anim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.38, 0.76, curve: Curves.easeOutBack),
    );
    // (3) Home (dưới cùng của cung tròn)
    final item3Anim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.54, 0.96, curve: Curves.easeOutBack),
    );

    // Tâm đường tròn là vị trí icon + ở góc trên phải của thẻ (bán kính R ≈ 104px đều nhau)
    const Offset plusCenter = Offset(142, 46);
    const Offset powerCenter = Offset(38, 46);
    const Offset langCenter = Offset(66, 108);
    const Offset homeCenter = Offset(142, 144);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: top,
            right: right,
            width: cardWidth,
            height: cardHeight,
            child: AnimatedBuilder(
              animation: Listenable.merge([animation, flow]),
              builder: (context, _) {
                final isVi = flow.locale.languageCode == 'vi';
                final langCodeLabel = isVi ? 'VN' : 'EN';
                return FadeTransition(
                  opacity: cardOpacity,
                  child: ScaleTransition(
                    scale: cardScale,
                    alignment: Alignment.topRight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14532D).withValues(alpha: 0.14),
                            blurRadius: 28,
                            spreadRadius: 1,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEAF5EE).withValues(alpha: 0.88),
                                  const Color(0xFFDDF0E4).withValues(alpha: 0.82),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.92),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Đường dẫn cung tròn trang trí mảnh tinh tế nối từ tâm
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _RadialArcGuidePainter(
                                        progress: item3Anim.value.clamp(0.0, 1.0),
                                      ),
                                    ),
                                  ),
                                ),

                                // Icon 1 (Top-left of arc): Power / Exit app
                                _buildArcAnimatedItem(
                                  origin: plusCenter,
                                  target: powerCenter,
                                  progress: item1Anim.value,
                                  size: const Size(48, 48),
                                  child: Semantics(
                                    button: true,
                                    label: context.l10n.exitApp,
                                    child: _PopoverCircularActionButton(
                                      buttonKey: const ValueKey('popover-close-session'),
                                      tooltip: context.l10n.exitApp,
                                      onTap: () {
                                        DytavaAudioFeedback.playClick();
                                        onExitApp();
                                      },
                                      child: const _PowerGlyph(),
                                    ),
                                  ),
                                ),

                                // Icon 2 (Middle of arc): Switch Language (Globe + VN/EN)
                                _buildArcAnimatedItem(
                                  origin: plusCenter,
                                  target: langCenter,
                                  progress: item2Anim.value,
                                  size: const Size(68, 48),
                                  child: Semantics(
                                    button: true,
                                    label: context.l10n.languageTitle,
                                    child: _PopoverCircularActionButton(
                                      buttonKey: const ValueKey('app-language-toggle'),
                                      tooltip: context.l10n.languageTitle,
                                      isPill: true,
                                      onTap: () {
                                        DytavaAudioFeedback.playClick();
                                        flow.toggleLocale();
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const _GlobeGlyph(),
                                          const SizedBox(width: 3),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 1),
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 180),
                                              transitionBuilder: (child, anim) =>
                                                  ScaleTransition(
                                                    scale: anim,
                                                    child: FadeTransition(
                                                      opacity: anim,
                                                      child: child,
                                                    ),
                                                  ),
                                              child: Text(
                                                langCodeLabel,
                                                key: ValueKey(langCodeLabel),
                                                style: const TextStyle(
                                                  fontFamily: DytavaTypography.primaryFont,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF14633A),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Icon 3 (Bottom of arc): Home
                                _buildArcAnimatedItem(
                                  origin: plusCenter,
                                  target: homeCenter,
                                  progress: item3Anim.value,
                                  size: const Size(48, 48),
                                  child: Semantics(
                                    button: true,
                                    label: context.l10n.titleHome,
                                    child: _PopoverCircularActionButton(
                                      buttonKey: const ValueKey('popover-home'),
                                      tooltip: context.l10n.titleHome,
                                      onTap: !flow.busy
                                          ? () {
                                              DytavaAudioFeedback.playClick();
                                              onGoHome();
                                            }
                                          : null,
                                      child: const _HomeReturnGlyph(),
                                    ),
                                  ),
                                ),

                                // Anchor Icon + (Appears first at top-right)
                                Positioned(
                                  left: plusCenter.dx - 25,
                                  top: plusCenter.dy - 25,
                                  width: 50,
                                  height: 50,
                                  child: Opacity(
                                    opacity: plusAnim.value.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: 0.4 + 0.6 * plusAnim.value.clamp(0.0, 1.15),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE5F3EA).withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF14532D).withValues(alpha: 0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            key: const ValueKey('popover-plus'),
                                            borderRadius: BorderRadius.circular(15),
                                            onTap: () {
                                              DytavaAudioFeedback.playClick();
                                              onDismiss();
                                            },
                                            child: const Center(
                                              child: _PlusGlyph(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Di chuyển icon dọc theo cung tròn từ [origin] (icon +) tới vị trí [target] theo chiều từ trên xuống
  Widget _buildArcAnimatedItem({
    required Offset origin,
    required Offset target,
    required double progress,
    required Size size,
    required Widget child,
  }) {
    final p = progress.clamp(0.0, 1.12);
    final opacity = progress.clamp(0.0, 1.0);

    // Quỹ đạo cung tròn quét từ đỉnh (góc pi) xuống vị trí đích trên cung tròn quanh tâm origin
    final dx = target.dx - origin.dx;
    final dy = target.dy - origin.dy;
    final targetRadius = math.sqrt(dx * dx + dy * dy);
    final targetAngle = math.atan2(dy, dx);
    const startAngle = math.pi;

    final currentAngle = startAngle + (targetAngle - startAngle) * p;
    final currentRadius = targetRadius * (0.28 + 0.72 * p);

    final cx = origin.dx + currentRadius * math.cos(currentAngle);
    final cy = origin.dy + currentRadius * math.sin(currentAngle);

    return Positioned(
      left: cx - size.width / 2,
      top: cy - size.height / 2,
      width: size.width,
      height: size.height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.45 + 0.55 * p,
          child: child,
        ),
      ),
    );
  }
}

class _PopoverCircularActionButton extends StatelessWidget {
  final Key buttonKey;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;
  final bool isPill;

  const _PopoverCircularActionButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.isPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(isPill ? 18 : 24),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RadialArcGuidePainter extends CustomPainter {
  final double progress;
  const _RadialArcGuidePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromCircle(center: const Offset(142, 46), radius: 100);
    canvas.drawArc(
      rect,
      math.pi,
      -math.pi * 0.5 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialArcGuidePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PlusGlyph extends StatelessWidget {
  const _PlusGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _PlusGlyphPainter(),
    );
  }
}

class _PlusGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14633A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 3), Offset(cx, size.height - 3), paint);
    canvas.drawLine(Offset(3, cy), Offset(size.width - 3, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PowerGlyph extends StatelessWidget {
  const _PowerGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _PowerGlyphPainter(),
    );
  }
}

class _PowerGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14633A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2 + 1.5;
    final r = size.width * 0.37;

    // Vạch thẳng đứng ở đỉnh
    canvas.drawLine(Offset(cx, 3.0), Offset(cx, cy - 1.5), paint);

    // Cung tròn hở ở đỉnh
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const gapAngle = 0.62;
    canvas.drawArc(
      rect,
      -math.pi / 2 + gapAngle,
      2 * math.pi - 2 * gapAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlobeGlyph extends StatelessWidget {
  const _GlobeGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _GlobeGlyphPainter(),
    );
  }
}

class _GlobeGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14633A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.40;

    // Đường tròn ngoài
    canvas.drawCircle(center, r, paint);
    // Kinh tuyến elip dọc
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.05, height: r * 2),
      paint,
    );
    // Trục dọc
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(center.dx, center.dy + r),
      paint,
    );
    // Vĩ tuyến ngang
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon ngôi nhà kèm mũi tên quay về chuẩn theo ảnh thiết kế
class _HomeReturnGlyph extends StatelessWidget {
  const _HomeReturnGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _HomeReturnGlyphPainter(),
    );
  }
}

class _HomeReturnGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14633A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Đường viền ngôi nhà mở góc phải dưới cho mũi tên đi vào
    final housePath = Path()
      ..moveTo(w * 0.82, h * 0.46)
      ..lineTo(w * 0.82, h * 0.36)
      ..lineTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.16, h * 0.38)
      ..lineTo(w * 0.16, h * 0.80)
      ..quadraticBezierTo(w * 0.16, h * 0.86, w * 0.22, h * 0.86)
      ..lineTo(w * 0.44, h * 0.86)
      ..lineTo(w * 0.44, h * 0.56)
      ..quadraticBezierTo(w * 0.44, h * 0.52, w * 0.48, h * 0.52)
      ..lineTo(w * 0.60, h * 0.52);
    canvas.drawPath(housePath, paint);

    // Mũi tên hướng sang trái ở góc phải dưới
    final arrowLine = Path()
      ..moveTo(w * 0.86, h * 0.72)
      ..lineTo(w * 0.56, h * 0.72);
    canvas.drawPath(arrowLine, paint);

    final arrowHead = Path()
      ..moveTo(w * 0.67, h * 0.61)
      ..lineTo(w * 0.55, h * 0.72)
      ..lineTo(w * 0.67, h * 0.83);
    canvas.drawPath(arrowHead, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
