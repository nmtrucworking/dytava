import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design_system/design_system.dart';
import 'application/workflow_controller.dart';
import 'app/workflow_composition.dart';
import 'features/workflow/workflow_page.dart';
import 'features/workflow/screens/launch_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ExcelCompareApp());
}

class ExcelCompareApp extends StatefulWidget {
  const ExcelCompareApp({
    super.key,
    this.controller,
    this.locale,
  });

  final WorkflowController? controller;
  final Locale? locale;

  @override
  State<ExcelCompareApp> createState() => _ExcelCompareAppState();
}

class _ExcelCompareAppState extends State<ExcelCompareApp> {
  WorkflowController? _internalController;
  WorkflowController get _effectiveController =>
      widget.controller ?? (_internalController ??= createMobileWorkflow());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = _effectiveController;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final activeLocale = widget.locale ?? flow.locale;
        return MaterialApp(
          title: 'Dytava — Excel Compare',
          debugShowCheckedModeBanner: false,
          theme: DytavaTheme.lightTheme,
          locale: activeLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: widget.controller == null
              ? DytavaLaunchScreen(child: WorkflowPage(controller: flow))
              : WorkflowPage(controller: flow),
        );
      },
    );
  }
}
