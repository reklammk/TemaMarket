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
    // Tam ekran immersive mod
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}

    // Güvenli yükleme: İlk frame çizildikten sonra video başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _initVideo();
      }
    });

    // Güvenlik zaman aşımı: 10 saniye sonra zorla geç
    Future.delayed(const Duration(seconds: 10), () {
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
      debugPrint('Splash video init error: $e');
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
      final controllerToDispose = _controller;
      _controller = null;
      try {
        controllerToDispose?.pause();
        controllerToDispose?.dispose();
      } catch (e) {
        debugPrint('Error disposing splash controller: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _finish, // Ekrana tıklayarak da geçilebilir
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
          const Text(
            'Market',
            style: TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 36,
              fontWeight: FontWeight.w700,
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
