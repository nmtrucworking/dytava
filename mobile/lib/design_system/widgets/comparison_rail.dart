import 'package:flutter/material.dart';

import '../dytava_colors.dart';
import '../dytava_typography.dart';

/// Trạng thái của một node trên Comparison Rail
enum RailNodeStatus {
  unselected,
  preparing,
  needsReview,
  ready,
}

/// Dữ liệu đầu vào cho một luồng trên Comparison Rail
class RailStreamData {
  final String sideTag; // 'A' hoặc 'B'
  final String title;
  final String subtitle;
  final String? format;
  final RailNodeStatus status;
  final VoidCallback? onTap;

  const RailStreamData({
    required this.sideTag,
    required this.title,
    required this.subtitle,
    this.format,
    this.status = RailNodeStatus.unselected,
    this.onTap,
  });
}

/// Thành phần nhận diện cốt lõi: **Comparison Rail**
///
/// Biểu diễn hai nguồn đầu vào A & B như hai luồng dữ liệu kết nối vật lý
/// thuộc cùng một phiên đối chiếu, trạng thái đọc tệp và xác minh hiển thị trực tiếp.
class ComparisonRail extends StatelessWidget {
  final String sessionTitle;
  final String statusLabel;
  final RailStreamData sourceA;
  final RailStreamData sourceB;
  final VoidCallback? onPrimaryAction;
  final String primaryActionLabel;
  final VoidCallback? onSwap;
  final bool isCompact;

  const ComparisonRail({
    super.key,
    this.sessionTitle = 'ACTIVE COMPARISON',
    required this.statusLabel,
    required this.sourceA,
    required this.sourceB,
    this.onPrimaryAction,
    this.primaryActionLabel = 'Tiếp tục thiết lập',
    this.onSwap,
    this.isCompact = false,
  });

  Color _statusColor(RailNodeStatus status) {
    switch (status) {
      case RailNodeStatus.ready:
        return DytavaColors.exact;
      case RailNodeStatus.needsReview:
        return DytavaColors.differenceCoral;
      case RailNodeStatus.preparing:
        return DytavaColors.primary;
      case RailNodeStatus.unselected:
        return DytavaColors.precisionNeutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DytavaColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: DytavaColors.graphite.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Session label & Status badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                sessionTitle,
                style: DytavaTypography.precisionTag.copyWith(
                  letterSpacing: 1.1,
                  fontSize: 10.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DytavaColors.warmCanvas,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: DytavaColors.border, width: 0.8),
                    ),
                    child: Text(
                      statusLabel,
                      style: DytavaTypography.labelSmall.copyWith(
                        color: DytavaColors.graphite,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (onSwap != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      color: DytavaColors.precisionNeutral,
                      tooltip: 'Đảo vai trò A và B',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: onSwap,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rail Stream: Source A -> Connector line -> Source B
          _buildRailNode(context, sourceA),
          _buildRailConnector(),
          _buildRailNode(context, sourceB),

          if (onPrimaryAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onPrimaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: DytavaColors.limePrimary,
                foregroundColor: DytavaColors.graphite,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: DytavaTypography.editorialFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      primaryActionLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRailConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 24,
            color: DytavaColors.railLine,
          ),
          const SizedBox(width: 14),
          Icon(
            Icons.south_rounded,
            size: 14,
            color: DytavaColors.precisionNeutral.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Luồng đối chiếu đồng nhất',
              style: DytavaTypography.bodySmall.copyWith(
                color: DytavaColors.precisionNeutral,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailNode(BuildContext context, RailStreamData stream) {
    final statusColor = _statusColor(stream.status);
    final isReady = stream.status == RailNodeStatus.ready;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: stream.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Node tag circle (A or B)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isReady ? DytavaColors.signalLime : DytavaColors.warmCanvas,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isReady ? DytavaColors.graphite : DytavaColors.border,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  stream.sideTag,
                  style: DytavaTypography.titleMedium.copyWith(
                    color: DytavaColors.graphite,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, and Format chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            stream.title,
                            style: DytavaTypography.titleSmall.copyWith(
                              color: DytavaColors.graphite,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (stream.format != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DytavaColors.warmCanvas,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: DytavaColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              stream.format!.toUpperCase(),
                              style: DytavaTypography.dataSmall.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: DytavaColors.precisionNeutral,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stream.subtitle,
                            style: DytavaTypography.bodySmall.copyWith(
                              color: stream.status == RailNodeStatus.needsReview
                                  ? DytavaColors.differenceCoral
                                  : DytavaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: stream.status == RailNodeStatus.needsReview
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (stream.onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: DytavaColors.precisionNeutral.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
