import 'package:flutter/material.dart';

import 'dytava_audio_feedback.dart';

/// Hiệu ứng Fade In, Slide Up và Scale nhẹ mượt mà, tôn trọng MediaQuery.disableAnimations
class DytavaFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final double beginScale;
  final Curve curve;

  const DytavaFadeSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 10),
    this.beginScale = 0.985,
    this.curve = Curves.easeOutCubic,
  });

  /// Helper tạo hiệu ứng xuất hiện tuần tự (staggered) theo chỉ mục
  factory DytavaFadeSlide.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration stepDelay = const Duration(milliseconds: 45),
    Duration duration = const Duration(milliseconds: 280),
    Offset offset = const Offset(0, 10),
    double beginScale = 0.985,
  }) {
    final cappedIndex = index.clamp(0, 10);
    return DytavaFadeSlide(
      key: key,
      delay: stepDelay * cappedIndex,
      duration: duration,
      offset: offset,
      beginScale: beginScale,
      child: child,
    );
  }

  @override
  State<DytavaFadeSlide> createState() => _DytavaFadeSlideState();
}

class _DytavaFadeSlideState extends State<DytavaFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _started = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (_disableAnimations) {
      _controller.value = 1.0;
      _started = true;
      return;
    }
    if (!_started) {
      _started = true;
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disableAnimations) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Micro-interaction Scale Tap: Co nhẹ khi nhấn và phát âm thanh tương tác
class DytavaTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool enableFeedback;

  const DytavaTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.duration = const Duration(milliseconds: 110),
    this.enableFeedback = true,
  });

  @override
  State<DytavaTapScale> createState() => _DytavaTapScaleState();
}

class _DytavaTapScaleState extends State<DytavaTapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse();
    if (widget.enableFeedback) {
      DytavaAudioFeedback.playClick();
    }
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Widget hiệu ứng Pulse nhẹ nhàng cho trạng thái đang thực thi
class DytavaPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const DytavaPulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<DytavaPulse> createState() => _DytavaPulseState();
}

class _DytavaPulseState extends State<DytavaPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

/// Animated Counter: Hiển thị số tăng dần từ 0 đến đích mượt mà
class DytavaCountUpText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String suffix;
  final String prefix;

  const DytavaCountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.suffix = '',
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toInt()}$suffix',
          style: style,
        );
      },
    );
  }
}
