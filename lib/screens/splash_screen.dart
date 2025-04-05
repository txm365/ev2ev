import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(3500.ms);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A2463),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EV2EV',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Color.fromRGBO(173, 216, 230, 0.7),
                  )
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 1000.ms)
                .scale()
                .then()
                .shake(),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color.fromRGBO(144, 238, 144, 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  
                  ...List.generate(3, (index) {
                    return Container(
                      width: 180 - (index * 40),
                      height: 180 - (index * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color.fromRGBO(144, 238, 144, 0.2),
                          width: 1,
                        ),
                      ),
                    );
                  }),
                  
                  Transform.rotate(
                    angle: 0,
                    child: Container(
                      width: 90,
                      height: 2,
                      color: Colors.greenAccent,
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .rotate(
                          duration: 2000.ms,
                          begin: 0,
                          end: 2 * pi,
                          curve: Curves.linear,
                        ),
                  ),
                  
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent,
                    ),
                  ),
                  
                  ...List.generate(8, (index) {
                    final angle = (index * (pi / 4));
                    return Positioned(
                      left: 90 + 70 * cos(angle),
                      top: 90 + 70 * sin(angle),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            duration: 1000.ms,
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.5, 1.5),
                            delay: (index * 100).ms,
                            curve: Curves.easeOut,
                          )
                          .then()
                          .fadeOut(duration: 500.ms),
                    );
                  }),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Column(
              children: [
                const Text(
                  'Locating Charging Stations...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1000.ms),
                
                const SizedBox(height: 20),
                
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.5)),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 0,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.lightBlueAccent,
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .scaleX(
                            duration: 5000.ms,
                            begin: 0,
                            end: 1,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}