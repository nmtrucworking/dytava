import 'package:flutter/material.dart';

import 'design_system/design_system.dart';
import 'application/workflow_controller.dart';
import 'features/workflow/workflow_page.dart';

void main() => runApp(const ExcelCompareApp());

class ExcelCompareApp extends StatelessWidget {
  const ExcelCompareApp({super.key, this.controller});
  final WorkflowController? controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dytava — So sánh dữ liệu',
    theme: DytavaTheme.lightTheme,
    home: WorkflowPage(controller: controller),
  );
}
