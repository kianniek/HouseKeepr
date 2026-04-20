import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StartupSplashHost extends StatefulWidget {
  const StartupSplashHost({
    super.key,
    required this.appReady,
    required this.child,
  });

  final bool appReady;
  final Widget child;

  @override
  State<StartupSplashHost> createState() => _StartupSplashHostState();
}

class _StartupSplashHostState extends State<StartupSplashHost> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        SplashSequence(
          appReady: widget.appReady,
          onCompleted: () {
            if (!mounted || _dismissed) return;
            setState(() => _dismissed = true);
          },
        ),
      ],
    );
  }
}

class SplashSequence extends StatefulWidget {
  const SplashSequence({
    super.key,
    required this.appReady,
    required this.onCompleted,
  });

  final bool appReady;
  final VoidCallback onCompleted;

  @override
  State<SplashSequence> createState() => _SplashSequenceState();
}

class _SplashSequenceState extends State<SplashSequence>
    with TickerProviderStateMixin {
  static const String _assetPath = 'assets/HouseKeeprAnimationLottie.json';

  late final AnimationController _lottieController = AnimationController(
    vsync: this,
  );

  // This controller is only for the visual "zoom & fade" transition out.
  late final AnimationController _exitTransitionController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _lottieController.addStatusListener(_handleLottieStatus);
    _exitTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) widget.onCompleted();
    });
  }

  void _handleLottieStatus(AnimationStatus status) {
    // Only act when the Lottie reaches its natural end
    if (status == AnimationStatus.completed) {
      if (widget.appReady) {
        _startExitTransition();
      } else {
        // Loop the animation from the start because the app is still loading
        _lottieController.forward(from: 0);
      }
    }
  }

  void _startExitTransition() {
    if (_isExiting) return;
    if (!mounted) return;
    setState(() => _isExiting = true);
    _exitTransitionController.forward();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _exitTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _lottieController,
        _exitTransitionController,
      ]),
      builder: (context, _) {
        final exitProgress = Curves.easeInOutQuart.transform(
          _exitTransitionController.value,
        );

        final double opacityProgress = ((exitProgress - 0.8) / 0.2).clamp(
          0.0,
          1.0,
        );
        final double scaleProgress = ((exitProgress - 0.2) / 0.8).clamp(
          0.0,
          1.0,
        );
        final double opacity = 1.0 - opacityProgress;

        final double scale = 1.0 + (scaleProgress * 100.0);

        final Color splashPrimary = Theme.of(context).colorScheme.primary;
        final Color tintColor = splashPrimary.computeLuminance() < 0.5
            ? Theme.of(context).colorScheme.onSurface
            : splashPrimary;

        final Color animatedColor = Color.lerp(
          tintColor,
          Colors.black,
          scaleProgress,
        )!;

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  // Maintains your specific sizing logic
                  width: MediaQuery.of(context).size.width * 0.62,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      animatedColor,
                      BlendMode.srcIn,
                    ),
                    child: Lottie.asset(
                      _assetPath,
                      controller: _lottieController,
                      fit: BoxFit.contain,
                      onLoaded: (composition) {
                        // DETERMINISTIC: Sets duration to exactly what the JSON defines
                        _lottieController.duration = composition.duration;
                        _lottieController.forward();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
