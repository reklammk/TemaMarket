import 'dart:math' as math;
import 'package:flutter/material.dart';

/// TEMA Market animasyonlu logo widget'ı.
/// CustomPainter ile logoyu adım adım çizer:
///   1. Kırmızı dikdörtgen zemini büyür
///   2. "TEMA" yazısı soldan kayarak girer
///   3. Alttaki "Market" yazısı soldan kayarak girer
///   4. Logo pulsing/glow efekti ile tamamlanır
class TemaLogoPainter extends StatefulWidget {
  final double size;
  final VoidCallback? onComplete;
  final bool loop;

  const TemaLogoPainter({
    super.key,
    this.size = 200,
    this.onComplete,
    this.loop = false,
  });

  @override
  State<TemaLogoPainter> createState() => _TemaLogoPainterState();
}

class _TemaLogoPainterState extends State<TemaLogoPainter>
    with TickerProviderStateMixin {
  // ─── Aşama 1: Kırmızı kutu ölçeklenir ───
  late AnimationController _boxController;
  late Animation<double> _boxScale;
  late Animation<double> _boxOpacity;

  // ─── Aşama 2: "TEMA" yazısı kayar ───
  late AnimationController _temaController;
  late Animation<double> _temaSlide;
  late Animation<double> _temaOpacity;

  // ─── Aşama 3: "Market" yazısı kayar ───
  late AnimationController _marketController;
  late Animation<double> _marketSlide;
  late Animation<double> _marketOpacity;

  // ─── Aşama 4: Shine / sweep efekti ───
  late AnimationController _shineController;
  late Animation<double> _shineProgress;

  // ─── Aşama 5: Pulsing glow halkası ───
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // Kutu ölçeği
    _boxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _boxScale = CurvedAnimation(parent: _boxController, curve: Curves.easeOutBack);
    _boxOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _boxController,
        curve: const Interval(0, 0.3, curve: Curves.easeIn),
      ),
    );

    // TEMA metni
    _temaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _temaSlide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _temaController, curve: Curves.easeOutCubic),
    );
    _temaOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _temaController, curve: Curves.easeIn),
    );

    // Market metni
    _marketController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _marketSlide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _marketController, curve: Curves.easeOutCubic),
    );
    _marketOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _marketController, curve: Curves.easeIn),
    );

    // Shine sweep
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shineProgress = Tween<double>(begin: -0.2, end: 1.2).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // Pulse glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // 1. Kutu büyür
    await _boxController.forward();
    if (!mounted) return;

    // 2. TEMA yazısı girer
    await _temaController.forward();
    if (!mounted) return;

    // 3. Market yazısı girer (50ms gecikmeli)
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await _marketController.forward();
    if (!mounted) return;

    // 4. Shine efekti
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _shineController.forward();
    if (!mounted) return;

    // 5. Pulse (loop)
    if (widget.loop) {
      _pulseController.repeat(reverse: true);
    } else {
      await _pulseController.forward();
    }

    if (mounted) widget.onComplete?.call();
  }

  @override
  void dispose() {
    _boxController.dispose();
    _temaController.dispose();
    _marketController.dispose();
    _shineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * 0.42; // Logo oranı ~2.38:1

    return AnimatedBuilder(
      animation: Listenable.merge([
        _boxController,
        _temaController,
        _marketController,
        _shineController,
        _pulseController,
      ]),
      builder: (context, _) {
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Glow halkası ──
              Positioned.fill(
                child: Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(w * 0.06),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(
                            alpha: _pulseOpacity.value * 0.7,
                          ),
                          blurRadius: w * 0.15,
                          spreadRadius: w * 0.04,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Kırmızı zemin kutusu ──
              ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.05),
                child: Transform.scale(
                  scale: _boxScale.value,
                  child: Opacity(
                    opacity: _boxOpacity.value,
                    child: Container(
                      width: w,
                      height: h,
                      color: const Color(0xFFDC2626),
                      child: Stack(
                        children: [
                          // Hafif gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.12),
                                ],
                              ),
                            ),
                          ),

                          // ── "TEMA" yazısı ──
                          Positioned(
                            left: w * 0.06 +
                                _temaSlide.value * w * 0.4,
                            top: h * 0.10,
                            child: Opacity(
                              opacity: _temaOpacity.value.clamp(0.0, 1.0),
                              child: Text(
                                'TEMA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: h * 0.52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: w * 0.003,
                                  height: 1.0,
                                  fontFamily: 'Plus Jakarta Sans',
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      offset: const Offset(1, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── "Market" yazısı (küçük, altta) ──
                          Positioned(
                            left: w * 0.06 +
                                _marketSlide.value * w * 0.35,
                            bottom: h * 0.12,
                            child: Opacity(
                              opacity: _marketOpacity.value.clamp(0.0, 1.0),
                              child: Text(
                                'Market',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: h * 0.26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: w * 0.001,
                                  height: 1.0,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                            ),
                          ),

                          // ── Shine sweep efekti ──
                          if (_shineController.isAnimating ||
                              _shineController.value > 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ShinePainter(
                                  progress: _shineProgress.value,
                                  width: w,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shine / lens flare efekti için CustomPainter
class _ShinePainter extends CustomPainter {
  final double progress;
  final double width;

  _ShinePainter({required this.progress, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1.2) return;

    final x = size.width * progress;
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.35),
        Colors.white.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final shineWidth = size.width * 0.25;
    final rect = Rect.fromLTWH(x - shineWidth / 2, 0, shineWidth, size.height);

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;

    canvas.save();
    canvas.skew(math.tan(-math.pi / 8), 0); // italik shine
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.progress != progress;
}

/// AppBar için canlı, vektörel ve animasyonlu TEMA Logo widget'ı
class HeaderTemaLogo extends StatefulWidget {
  final bool isSanalMarket;

  const HeaderTemaLogo({super.key, this.isSanalMarket = true});

  @override
  State<HeaderTemaLogo> createState() => _HeaderTemaLogoState();
}

class _HeaderTemaLogoState extends State<HeaderTemaLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String labelText = widget.isSanalMarket ? 'sanalmarket' : 'Market';

    return AnimatedBuilder(
      animation: _pulseScale,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── TEMA Kırmızı Rozeti (Ölçek animasyonlu & parlak gölgeli) ──
            Transform.scale(
              scale: _pulseScale.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF2A55), // Parlak Kırmızı-Pembe
                      Color(0xFFDC2626), // Ana TEMA Kırmızısı
                      Color(0xFF991B1B), // Derin Kırmızı
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'TEMA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── sanalmarket / Market Metni ──
            Text(
              labelText,
              style: TextStyle(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.4,
                shadows: [
                  Shadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

