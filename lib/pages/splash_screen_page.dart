import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SplashScreenPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreenPage({super.key, required this.onFinish});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  bool _isDisposed = false;
  bool _finishedCalled = false;

  @override
  void initState() {
    super.initState();
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}

    // Güvenli başlatma: Ekran çizildikten sonra videoyu başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _initVideo();
      }
    });

    // Zaman aşımı: Video uzun sürerse veya yüklenemezse zorla geç
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !_isDisposed && !_finishedCalled) {
        _finish();
      }
    });
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/videos/tema_splash.mp4');
      _controller = controller;

      await controller.initialize();

      if (_isDisposed || !mounted) {
        await controller.pause();
        await controller.dispose();
        _controller = null;
        return;
      }

      controller.addListener(() {
        if (_isDisposed || !mounted || _finishedCalled) return;
        try {
          if (controller.value.isInitialized &&
              controller.value.position >= controller.value.duration &&
              controller.value.duration > Duration.zero) {
            _finish();
          }
        } catch (_) {}
      });

      await controller.setVolume(1.0);
      await controller.setLooping(false);
      await controller.play();

      if (mounted && !_isDisposed) {
        setState(() => _isVideoReady = true);
      }
    } catch (e) {
      debugPrint('Splash video error: $e');
      if (mounted && !_isDisposed && !_finishedCalled) {
        _finish();
      }
    }
  }

  void _finish() {
    if (_finishedCalled) return;
    _finishedCalled = true;

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    if (_controller != null) {
      final c = _controller;
      _controller = null;
      try {
        c?.pause();
        c?.dispose();
      } catch (e) {
        debugPrint('Dispose error: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _finish,
        child: SizedBox.expand(
          child: (_isVideoReady && _controller != null && _controller!.value.isInitialized)
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1080,
                    height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1920,
                    child: VideoPlayer(_controller!),
                  ),
                )
              : _buildFallbackSplash(),
        ),
      ),
    );
  }

  Widget _buildFallbackSplash() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF450A0A),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                  blurRadius: 50,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Image.asset(
              'assets/logo.png',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => const Icon(Icons.shopping_basket, size: 60, color: Color(0xFFDC2626)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'TEMA MARKET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Spacer(flex: 3),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
