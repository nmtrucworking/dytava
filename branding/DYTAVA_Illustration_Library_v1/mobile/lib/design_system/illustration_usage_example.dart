import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dytava_illustrations.dart';

class DytavaEmptyView extends StatelessWidget {
  const DytavaEmptyView({super.key, this.onImport});
  final VoidCallback? onImport;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          label: 'Chưa có tệp dữ liệu',
          child: SvgPicture.asset(
            DytavaIllustrations.emptyFiles,
            width: 256, height: 256,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('Chưa có tệp dữ liệu', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Chọn hai tệp để bắt đầu so sánh.',
             textAlign: TextAlign.center,
             style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.file_open),
            label: const Text('Nhập tệp')),
      ]),
    ),
  );
}
