import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system/design_system.dart';
import 'application/workflow_controller.dart';
import 'features/workflow/workflow_page.dart';
import 'features/workflow/screens/launch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ExcelCompareApp());
}

class ExcelCompareApp extends StatelessWidget {
  const ExcelCompareApp({super.key, this.controller});
  final WorkflowController? controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dytava — Excel Compare',
    debugShowCheckedModeBanner: false,
    theme: DytavaTheme.lightTheme,
    home: controller == null
        ? const DytavaLaunchScreen(child: WorkflowPage())
        : WorkflowPage(controller: controller),
  );
}
