import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../design_system/design_system.dart';

/// Figma 19:1003. Play the two-second identity timeline once on app launch.
class DytavaLaunchScreen extends StatefulWidget {
  const DytavaLaunchScreen({super.key, required this.child});
  final Widget child;
  @override
  State<DytavaLaunchScreen> createState() => _DytavaLaunchScreenState();
}

class _DytavaLaunchScreenState extends State<DytavaLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _ready = true);
          }
        });
  bool _ready = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ready = true;
    } else if (!_timeline.isAnimating && !_ready) {
      _timeline.forward();
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: DytavaColors.primaryDark,
      ),
      child: Scaffold(
        backgroundColor: DytavaColors.primaryDark,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _timeline,
            builder: (context, _) => LayoutBuilder(
              builder: (context, size) {
                final t = _timeline.value;
                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.05),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _reveal(
                            t,
                            .01,
                            .23,
                            12,
                            Transform.scale(
                              scale: .92 + .08 * _ease(t, .01, .23),
                              child: Container(
                                width: 112,
                                height: 112,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: DytavaColors.primaryLight,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: SvgPicture.asset(
                                  'assets/dytava/figma/launch-mark.svg',
                                  width: 67.84,
                                  height: 61.934,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 33),
                          _reveal(
                            t,
                            .07,
                            .26,
                            8,
                            Text(
                              'Dytava',
                              style: DytavaTypography.displayLarge.copyWith(
                                fontSize: 42,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _reveal(
                            t,
                            .12,
                            .29,
                            6,
                            Text(
                              'Excel Compare',
                              style: DytavaTypography.bodyLarge.copyWith(
                                color: DytavaColors.primaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          _reveal(
                            t,
                            .16,
                            .33,
                            6,
                            Text(
                              'Two spreadsheets. One clear view.',
                              style: DytavaTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: size.maxHeight * .12,
                      child: Opacity(
                        opacity: _ease(t, .26, .40),
                        child: Column(
                          children: [
                            Text(
                              'Opening your workspace',
                              style: DytavaTypography.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 84,
                              child: LinearProgressIndicator(
                                value: .08 + .92 * _ease(t, .26, .57),
                                minHeight: 3,
                                color: DytavaColors.primaryLight,
                                backgroundColor: DytavaColors.primaryDark,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _ease(double t, double start, double end) =>
      Curves.easeOut.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
  Widget _reveal(
    double t,
    double start,
    double end,
    double offset,
    Widget child,
  ) {
    final value = _ease(t, start, end);
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, offset * (1 - value)),
        child: child,
      ),
    );
  }
}
