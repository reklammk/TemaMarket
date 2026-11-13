import 'package:flutter/material.dart';

/// TEMA Market animasyonlu logo widget'ı (resmi web logosu assets/logo.png ile).
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
  late AnimationController _entryController;
  late Animation<double> _entryScale;
  late Animation<double> _entryOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryScale = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.45, curve: Curves.easeIn),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _pulseScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    try {
      await _entryController.forward().orCancel;
      if (widget.loop) {
        _pulseController.repeat(reverse: true);
      } else {
        await _pulseController.forward().orCancel;
      }
      if (mounted) widget.onComplete?.call();
    } on TickerCanceled {
      // Widget kapatıldığında animasyon normal biçimde iptal edilir.
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * 0.44;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _pulseController]),
      builder: (context, _) {
        return Transform.scale(
          scale: _entryScale.value *
              (_entryController.isCompleted ? _pulseScale.value : 1.0),
          child: Opacity(
            opacity: _entryOpacity.value.clamp(0.0, 1.0),
            child: Container(
              width: w,
              height: h,
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.08,
                vertical: h * 0.14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(
                      alpha: _pulseOpacity.value.clamp(0.0, 1.0),
                    ),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'TEMA MARKET',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
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

/// Üst çubuk için resmi TEMA Marketler Zinciri logosu
class HeaderTemaLogo extends StatelessWidget {
  final bool isSanalMarket;

  const HeaderTemaLogo({super.key, this.isSanalMarket = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/logo.png',
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'TEMA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (isSanalMarket) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'Sanal Market',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
