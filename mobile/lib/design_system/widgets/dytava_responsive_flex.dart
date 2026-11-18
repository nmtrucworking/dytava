import 'package:flutter/material.dart';

import '../dytava_colors.dart';

/// Component Thẻ Nổi (Floating Card) chuẩn Precision Workspace v3.2
/// Tối ưu không gian, phân tách lớp thị giác với viền mỏng và bóng đổ đa tầng
class DytavaFloatingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final VoidCallback? onTap;

  const DytavaFloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? DytavaColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: DytavaColors.subtleBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F1A1C),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x050F1A1C),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Bố cục Responsive Flex thích ứng cho 3-4 thành phần:
/// - Khi chiều rộng >= [breakpoint]: Render tất cả thành phần trên 1 dòng duy nhất.
/// - Khi chiều rộng < [breakpoint]: Render chia thành 2 hàng cân đối (2x2 hoặc tỉ lệ tối ưu).
class DytavaResponsiveGroup extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  final double spacing;
  final double runSpacing;

  const DytavaResponsiveGroup({
    super.key,
    required this.children,
    this.breakpoint = 400,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();

        // Nếu chỉ có 1 hoặc 2 phần tử, hoặc chiều rộng >= breakpoint: Render trên 1 dòng
        if (children.length <= 2 || constraints.maxWidth >= breakpoint) {
          return Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        // Trường hợp 3 thành phần trên màn hình hẹp: Hàng 1 (1 phần tử chính full width), Hàng 2 (2 phần tử chia đôi)
        if (children.length == 3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              children[0],
              SizedBox(height: runSpacing),
              Row(
                children: [
                  Expanded(child: children[1]),
                  SizedBox(width: spacing),
                  Expanded(child: children[2]),
                ],
              ),
            ],
          );
        }

        // Trường hợp 4 thành phần trên màn hình hẹp: Lưới 2x2 cân đối
        if (children.length == 4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: children[0]),
                  SizedBox(width: spacing),
                  Expanded(child: children[1]),
                ],
              ),
              SizedBox(height: runSpacing),
              Row(
                children: [
                  Expanded(child: children[2]),
                  SizedBox(width: spacing),
                  Expanded(child: children[3]),
                ],
              ),
            ],
          );
        }

        // Fallback Wrap linh hoạt cho các trường hợp khác
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children,
        );
      },
    );
  }
}
