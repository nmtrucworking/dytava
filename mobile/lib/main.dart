import 'package:flutter/material.dart';

import 'design_system/design_system.dart';
import 'features/workflow/workflow_page.dart';

void main() => runApp(const ExcelCompareApp());

class ExcelCompareApp extends StatelessWidget {
  const ExcelCompareApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dytava — So sánh dữ liệu',
    theme: DytavaTheme.lightTheme,
    home: const WorkflowPage(),
  );
}
