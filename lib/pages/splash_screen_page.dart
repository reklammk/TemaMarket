import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SplashScreenPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreenPage({super.key, required this.onFinish});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    _animController.forward();

    // 3 saniye sonra ana sayfaya geç
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _finish();
    });
  }

  void _finish() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onFinish();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F1),
      body: GestureDetector(
        onTap: _finish,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF1F1),
                Color(0xFFFFE4E4),
                Color(0xFFFFC9C9),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Logo animasyonu
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    // TEMA rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withAlpha(80),
                            blurRadius: 40,
                            spreadRadius: 4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Text(
                        'TEMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Market yazısı
                    const Text(
                      'Market',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Slogan
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: (_fadeAnim.value - 0.3).clamp(0.0, 1.0),
                    child: child,
                  );
                },
                child: const Text(
                  'Erzurum\'un Güvenilir Marketi',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              // Yükleniyor göstergesi
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                        strokeWidth: 2.5,
                        backgroundColor: const Color(0xFFDC2626).withAlpha(30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Yükleniyor...',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
