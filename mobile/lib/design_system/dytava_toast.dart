import 'package:flutter/material.dart';

import 'dytava_audio_feedback.dart';
import 'dytava_colors.dart';
import 'dytava_typography.dart';

enum DytavaToastType {
  success,
  error,
  warning,
  info,
}

/// Hệ thống thông báo Toast (Floating Pill Toast) chuẩn Precision Workspace v3.2
class DytavaToast {
  DytavaToast._();

  /// Hiển thị Toast thông báo nổi với hiệu ứng âm thanh và rung
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    DytavaToastType type = DytavaToastType.info,
    Duration duration = const Duration(milliseconds: 3000),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // Phát âm thanh và haptic tương ứng
    switch (type) {
      case DytavaToastType.success:
        DytavaAudioFeedback.playSuccess();
        break;
      case DytavaToastType.error:
        DytavaAudioFeedback.playError();
        break;
      case DytavaToastType.warning:
      case DytavaToastType.info:
        DytavaAudioFeedback.playToast();
        break;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        content: _DytavaToastCard(
          message: message,
          title: title,
          type: type,
          actionLabel: actionLabel,
          onAction: () {
            messenger.hideCurrentSnackBar();
            onAction?.call();
          },
          onClose: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Helper nhanh cho thông báo Thành công
  static void success(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: DytavaToastType.success);
  }

  /// Helper nhanh cho thông báo Lỗi
  static void error(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: DytavaToastType.error);
  }

  /// Helper nhanh cho thông báo Thông tin
  static void info(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: DytavaToastType.info);
  }

  /// Helper nhanh cho thông báo Cảnh báo
  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: DytavaToastType.warning);
  }
}

class _DytavaToastCard extends StatelessWidget {
  final String message;
  final String? title;
  final DytavaToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _DytavaToastCard({
    required this.message,
    this.title,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, borderColor) = switch (type) {
      DytavaToastType.success => (
        Icons.check_circle_rounded,
        DytavaColors.limePrimary,
        DytavaColors.limePrimary.withValues(alpha: 0.4),
      ),
      DytavaToastType.error => (
        Icons.error_rounded,
        DytavaColors.differenceCoral,
        DytavaColors.differenceCoral.withValues(alpha: 0.5),
      ),
      DytavaToastType.warning => (
        Icons.warning_amber_rounded,
        DytavaColors.amber,
        DytavaColors.amber.withValues(alpha: 0.4),
      ),
      DytavaToastType.info => (
        Icons.info_rounded,
        DytavaColors.white,
        DytavaColors.subtleBorder.withValues(alpha: 0.3),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DytavaColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: DytavaColors.white,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: title != null
                        ? DytavaColors.white.withValues(alpha: 0.85)
                        : DytavaColors.white,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: DytavaColors.limePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: DytavaColors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
