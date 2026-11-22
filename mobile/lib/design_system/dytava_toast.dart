import 'dart:async';

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

/// Hệ thống thông báo Top Push Notification (Sleek Floating Pill)
/// chuẩn Precision Workspace v3.2. Hiển thị ở đỉnh màn hình, tự động ẩn,
/// hỗ trợ vuốt lên để đóng và kích thước tinh gọn.
class DytavaToast {
  DytavaToast._();

  static OverlayEntry? _activeEntry;

  /// Đóng thông báo đang hiển thị (nếu có)
  static void dismiss() {
    if (_activeEntry != null) {
      if (_activeEntry!.mounted) {
        _activeEntry!.remove();
      }
      _activeEntry = null;
    }
  }

  /// Hiển thị thông báo nổi ở đỉnh màn hình (Top Push Notification)
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    DytavaToastType type = DytavaToastType.info,
    Duration duration = const Duration(milliseconds: 2800),
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

    dismiss();

    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback an toàn cho môi trường test hoặc không có Overlay
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
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
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopToastWidget(
        message: message,
        title: title,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
        },
        duration: duration,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
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

class _TopToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final DytavaToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopToastWidget({
    required this.message,
    this.title,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Dismissible(
                  key: const ValueKey('dytava_top_toast'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _dismissed = true;
                    _timer?.cancel();
                    widget.onDismiss();
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: _DytavaToastCard(
                      message: widget.message,
                      title: widget.title,
                      type: widget.type,
                      actionLabel: widget.actionLabel,
                      onAction: () {
                        _dismiss();
                        widget.onAction?.call();
                      },
                      onClose: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
        DytavaColors.limePrimary.withValues(alpha: 0.35),
      ),
      DytavaToastType.error => (
        Icons.error_rounded,
        DytavaColors.differenceCoral,
        DytavaColors.differenceCoral.withValues(alpha: 0.45),
      ),
      DytavaToastType.warning => (
        Icons.warning_amber_rounded,
        DytavaColors.amber,
        DytavaColors.amber.withValues(alpha: 0.35),
      ),
      DytavaToastType.info => (
        Icons.info_rounded,
        DytavaColors.white,
        DytavaColors.subtleBorder.withValues(alpha: 0.25),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF21D2422),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DytavaColors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: title != null && title!.isNotEmpty
                        ? DytavaColors.white.withValues(alpha: 0.85)
                        : DytavaColors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DytavaColors.limePrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: DytavaColors.limePrimary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: DytavaColors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
