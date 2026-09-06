import 'dart:async';

import 'package:flutter/material.dart';

import 'login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const GenzEmployeeMonitoringApp());
}

class GenzEmployeeMonitoringApp extends StatelessWidget {
  const GenzEmployeeMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GENZ Employee Monitoring',

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075F5F),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9F8),
      ),

      // APP STARTS WITH SPLASH SCREEN
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    // AFTER 3 SECONDS -> LOGIN SCREEN
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (
              context,
              animation,
              secondaryAnimation,
              ) {
            return const LoginScreen();
          },
          transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
              ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(
            milliseconds: 600,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF043838),
              Color(0xFF075F5F),
              Color(0xFF08746F),
              Color(0xFF0B8279),
            ],
          ),
        ),

        child: Stack(
          children: [
            // ==================================================
            // BACKGROUND CIRCLES
            // ==================================================

            Positioned(
              top: -160,
              right: -100,
              child: _circle(
                420,
                0.06,
              ),
            ),

            Positioned(
              bottom: -150,
              left: -120,
              child: _circle(
                350,
                0.06,
              ),
            ),

            Positioned(
              top: 170,
              left: 40,
              child: _circle(
                120,
                0.04,
              ),
            ),

            Positioned(
              bottom: 180,
              right: 40,
              child: _circle(
                100,
                0.04,
              ),
            ),

            // ==================================================
            // MAIN CONTENT
            // ==================================================

            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,

                  child: SlideTransition(
                    position: _slideAnimation,

                    child: ScaleTransition(
                      scale: _scaleAnimation,

                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          // ==================================================
                          // LOGO
                          // ==================================================

                          Container(
                            width: 290,
                            height: 180,
                            padding:
                            const EdgeInsets.all(15),

                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(22),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.25),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                  offset:
                                  const Offset(0, 20),
                                ),
                              ],
                            ),

                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,

                              errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                  ) {
                                return const Icon(
                                  Icons.business,
                                  size: 70,
                                  color:
                                  Color(0xFF075F5F),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 38),

                          // ==================================================
                          // TITLE
                          // ==================================================

                          const Text(
                            'Employee Monitoring',
                            textAlign: TextAlign.center,

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ==================================================
                          // SUBTITLE
                          // ==================================================

                          Text(
                            'PRODUCTIVITY & WORKFORCE MANAGEMENT',
                            textAlign: TextAlign.center,

                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.4,
                            ),
                          ),

                          const SizedBox(height: 50),

                          // ==================================================
                          // LOADING
                          // ==================================================

                          const SizedBox(
                            width: 42,
                            height: 42,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                              AlwaysStoppedAnimation<
                                  Color>(
                                Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 17),

                          Text(
                            'Preparing your workspace...',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // FOOTER
            // ==================================================

            Positioned(
              left: 20,
              right: 20,
              bottom: 25,

              child: Text(
                '© 2026 GENZ BPO  •  Secure Workforce Management',
                textAlign: TextAlign.center,

                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(
      double size,
      double opacity,
      ) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}