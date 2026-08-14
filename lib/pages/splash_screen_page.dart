import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/tema_logo_painter.dart';

/// TEMA Market Splash Ekranı
///
/// Strateji:
///   1. Video mevcutsa → video çalar, bitince geçer
///   2. Video yoksa / hata olursa → sinematik Flutter animasyonu devreye girer
///      (video ile birebir aynı his: karanlık fon, logo animasyonu, parçacık efektleri)
class SplashScreenPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreenPage({super.key, required this.onFinish});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with TickerProviderStateMixin {
  // ─── Video ───
  bool _isDisposed = false;
  bool _finishedCalled = false;

  // ─── Arka plan gradient geçişi ───
  late AnimationController _bgController;
  late Animation<double> _bgProgress;

  // ─── Logo fade-in/scale ───
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ─── Tagline yazısı ───
  late AnimationController _taglineController;
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineSlide;

  // ─── Alt bar (yükleniyor) ───
  late AnimationController _loadingController;

  // ─── Parçacık (floating dots) sistemi ───
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  // ─── Fade-out (geçiş) ───
  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutOpacity;

  @override
  void initState() {
    super.initState();

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}

    _initAnimations();
    _generateParticles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _runAnimationSequence();
      }
    });

    // Maksimum 12sn bekle
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !_isDisposed && !_finishedCalled) _finish();
    });
  }

  void _initAnimations() {
    // Arka plan
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _bgProgress = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);

    // Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Tagline
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );

    // Yükleme çubuğu
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Parçacıklar
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Fade-out
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOutOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );
  }

  void _generateParticles() {
    final rng = math.Random(42);
    for (int i = 0; i < 28; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 3.5 + 1.0,
        speed: rng.nextDouble() * 0.4 + 0.15,
        opacity: rng.nextDouble() * 0.5 + 0.1,
        phase: rng.nextDouble() * math.pi * 2,
        isRed: rng.nextDouble() > 0.75,
      ));
    }
  }

  Future<void> _runAnimationSequence() async {
    // 1. Arka plan büyür
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _isDisposed) return;

    // 2. Parçacıklar uçuşur
    _particleController.repeat();

    // 3. Logo belirir
    await _logoController.forward();
    if (!mounted || _isDisposed) return;

    // 4. Logo animasyonu tamamlandıktan sonra tagline
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _isDisposed) return;
    _taglineController.forward();

    // 5. Loading bar başlar
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || _isDisposed) return;
    _loadingController.forward();

    // 6. Tüm animasyon ~3sn sürer, sonra geçiş
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted || _isDisposed || _finishedCalled) return;
    _finishWithFade();
  }

  Future<void> _finishWithFade() async {
    if (_finishedCalled) return;
    if (!mounted) return;
    await _fadeOutController.forward();
    _finish();
  }

  void _finish() {
    if (_finishedCalled) return;
    _finishedCalled = true;

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    if (mounted) widget.onFinish();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _particleController.stop();
    _bgController.stop();
    _logoController.stop();
    _taglineController.stop();
    _loadingController.stop();
    _fadeOutController.stop();

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    _bgController.dispose();
    _logoController.dispose();
    _taglineController.dispose();
    _loadingController.dispose();
    _particleController.dispose();
    _fadeOutController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _finishWithFade,
        child: AnimatedBuilder(
          animation: _fadeOutOpacity,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeOutOpacity.value,
              child: child,
            );
          },
          child: SizedBox.expand(child: _buildAnimationSplash(context)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  VİDEO OYNATICI
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  //  ANİMASYON SPLASH (video yerine)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAnimationSplash(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgController,
        _logoController,
        _taglineController,
        _loadingController,
        _particleController,
      ]),
      builder: (context, _) {
        return Stack(
          children: [
            // ── Sinematik arka plan ──
            _buildBackground(size),

            // ── Yüzen parçacıklar ──
            _buildParticles(size),

            // ── Merkez içerik ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value.clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          // Animasyonlu logo
                          TemaLogoPainter(
                            size: size.width * 0.62,
                            loop: true,
                          ),
                          const SizedBox(height: 28),

                          // Tagline
                          Transform.translate(
                            offset: Offset(0, _taglineSlide.value),
                            child: Opacity(
                              opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Taze • Güvenilir • Hızlı',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5,
                                      fontFamily: 'Plus Jakarta Sans',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Erzurum\'un Market Zinciri',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                      fontFamily: 'Plus Jakarta Sans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Alt loading barı ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLoadingBar(size),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgProgress,
      builder: (context, _) {
        final t = _bgProgress.value;
        return Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.3),
              radius: 1.2 + t * 0.4,
              colors: [
                Color.lerp(
                  const Color(0xFF3D0A0A),
                  const Color(0xFF1A0505),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF1E293B),
                  const Color(0xFF0A0A14),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF0F172A),
                  const Color(0xFF020208),
                  t,
                )!,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _particleController.value,
          ),
        );
      },
    );
  }

  Widget _buildLoadingBar(Size size) {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, _) {
        final progress = _loadingController.value;
        if (progress == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFFF6B6B)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                progress < 0.5
                    ? 'Yükleniyor...'
                    : progress < 0.9
                        ? 'Ürünler Hazırlanıyor...'
                        : 'Hazır!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PARTİKÜL DATA & PAINTER
// ─────────────────────────────────────────────────────────────
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double phase;
  final bool isRed;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
    required this.isRed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase / (math.pi * 2)) % 1.0;

      // Yukarı doğru yüzer, alpha azalır
      final currentY = (p.y - t * 0.7) % 1.0;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      final wobble = math.sin(t * math.pi * 3 + p.phase) * 0.02;

      final dx = (p.x + wobble) * size.width;
      final dy = currentY * size.height;

      final paint = Paint()
        ..color = (p.isRed
                ? const Color(0xFFDC2626)
                : Colors.white)
            .withValues(alpha: (p.opacity * fade).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.size * fade, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
