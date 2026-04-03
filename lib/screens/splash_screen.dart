// lib/screens/splash_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse ring around the icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slow rotation for the outer decorative ring
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _navigateAfterDelay();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(3800.ms);
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Deep dark gradient — professional, modern
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // deep navy
              Color(0xFF1B2838), // dark steel
              Color(0xFF0D2137), // dark teal-navy
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background decorative circles ────────────────────────────
            Positioned(
              top: -size.width * 0.3,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.width * 0.4,
              left: -size.width * 0.3,
              child: Container(
                width: size.width * 1.0,
                height: size.width * 1.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated logo area ──────────────────────────────────
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer slowly-rotating dashed ring
                        AnimatedBuilder(
                          animation: _rotateController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateController.value * 2 * pi,
                              child: child,
                            );
                          },
                          child: CustomPaint(
                            size: const Size(170, 170),
                            painter: _DashedCirclePainter(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                              dashCount: 24,
                            ),
                          ),
                        ),

                        // Pulsing middle ring
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF81C784).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // Inner glow circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF4CAF50).withValues(alpha: 0.25),
                                const Color(0xFF4CAF50).withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        // Electric bolt icon
                        const Icon(
                          Icons.electric_bolt,
                          size: 64,
                          color: Color(0xFF81C784),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 300.ms)
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.0, 1.0),
                              duration: 600.ms,
                              delay: 300.ms,
                              curve: Curves.elasticOut,
                            ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 40),

                  // ── Brand name ──────────────────────────────────────────
                  const Text(
                    'EV2EV',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 500.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 700.ms,
                        delay: 500.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 10),

                  // ── Tagline ─────────────────────────────────────────────
                  const Text(
                    'Peer-to-Peer Energy Trading',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF81C784),
                      letterSpacing: 2.5,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 900.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 700.ms,
                        delay: 900.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 80),

                  // ── Progress bar ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 3,
                            child: const LinearProgressIndicator(
                              backgroundColor: Color(0xFF1E3A2F),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF4CAF50),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 1200.ms),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Initialising...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF546E7A),
                            letterSpacing: 1.5,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 1400.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Version tag bottom ───────────────────────────────────────
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: const Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF37474F),
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 1600.ms),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom painter for the dashed outer ring ───────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;

  const _DashedCirclePainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dashAngle = (2 * pi) / dashCount;
    final gapFraction = 0.4; // 40% gap between dashes

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashCount != dashCount;
}