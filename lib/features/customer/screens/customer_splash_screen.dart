import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/widgets/animated_tuk_tuk.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class WelcomeSplashGate extends StatefulWidget {
  const WelcomeSplashGate({
    super.key,
    required this.child,
  });

  final Widget child;

  static var _shownThisSession = false;

  @override
  State<WelcomeSplashGate> createState() => _WelcomeSplashGateState();
}

class _WelcomeSplashGateState extends State<WelcomeSplashGate> {
  late var _showSplash = !WelcomeSplashGate._shownThisSession;

  void _finishSplash() {
    WelcomeSplashGate._shownThisSession = true;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return CustomerSplashScreen(onFinished: _finishSplash);
    }

    return widget.child;
  }
}

class CustomerSplashScreen extends StatefulWidget {
  const CustomerSplashScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<CustomerSplashScreen> createState() => _CustomerSplashScreenState();
}

class _CustomerSplashScreenState extends State<CustomerSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _driveAnimation;
  late final Animation<double> _textAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _driveAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.82, curve: Curves.easeInOutCubic),
    );

    _textAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.78, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.86, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final vehicleWidth = size.width * 0.44;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _driveAnimation.value;
        final startX = -vehicleWidth * 1.1;
        final endX = size.width * 0.5 - vehicleWidth * 0.5;
        final vehicleX = startX + (endX - startX) * progress;
        final animationTime = _controller.value * 3.4;

        return Opacity(
          opacity: _fadeAnimation.value,
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _SplashBackground(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: size.height * 0.3,
                  child: CustomPaint(
                    painter: _RoadPainter(roadOffset: progress * size.width * 1.6),
                    size: Size(size.width, size.height * 0.3),
                  ),
                ),
                Positioned(
                  left: vehicleX,
                  bottom: size.height * 0.23,
                  child: AnimatedTukTuk(
                    width: vehicleWidth,
                    animationTime: animationTime,
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: size.height * 0.08,
                  child: Opacity(
                    opacity: _textAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _textAnimation.value) * 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.welcomeMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppBrandAssets.brandNavy,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.appTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppBrandAssets.brandTealDark,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiagonalBrandPainter(),
      size: Size.infinite,
    );
  }
}

class _DiagonalBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = AppBrandAssets.brandGold.withValues(alpha: 0.14);
    final teal = Paint()..color = AppBrandAssets.brandTeal.withValues(alpha: 0.1);

    final goldPath = Path()
      ..moveTo(0, size.height * 0.52)
      ..lineTo(size.width, size.height * 0.34)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(goldPath, gold);

    final tealPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.56)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(tealPath, teal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.roadOffset});

  final double roadOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final surfacePaint = Paint()..color = AppBrandAssets.brandSurface;
    canvas.drawRect(Offset.zero & size, surfacePaint);

    final edgePaint = Paint()
      ..color = AppBrandAssets.brandTeal.withValues(alpha: 0.22)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.08),
      Offset(size.width, size.height * 0.08),
      edgePaint,
    );

    final dashPaint = Paint()
      ..color = AppBrandAssets.brandTeal.withValues(alpha: 0.45)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const dashWidth = 22.0;
    const dashGap = 16.0;
    final y = size.height * 0.42;
    var x = -(roadOffset % (dashWidth + dashGap));

    while (x < size.width + dashWidth) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), dashPaint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.roadOffset != roadOffset;
  }
}

class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge({
    super.key,
    this.size = 96,
    this.borderRadius = 20,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        AppBrandAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
