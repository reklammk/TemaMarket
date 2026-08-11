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
  late VideoPlayerController _controller;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    // Tam ekran immersive mod
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/tema_splash.mp4');
      await _controller.initialize();

      if (!mounted) return;

      setState(() => _isVideoReady = true);

      // Sesi kapat (isteğe göre değiştirilebilir)
      await _controller.setVolume(1.0);
      await _controller.setLooping(false);
      await _controller.play();

      // Video bitişini dinle → otomatik geçiş
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration &&
            _controller.value.duration != Duration.zero &&
            mounted) {
          _finish();
        }
      });

      // Güvenlik: video 30 saniyeden uzun sürmesi durumunda zorla geç
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) _finish();
      });
    } catch (e) {
      debugPrint('Splash video error: $e');
      // Video yüklenemezse 2 saniye sonra animasyonlu fallback ile geç
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _finish();
      });
    }
  }

  void _finish() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onFinish();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_isVideoReady) {
      _controller.dispose();
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
          child: _isVideoReady
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              // Video hazır olana kadar logo splash göster
              : Container(
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
                ),
        ),
      ),
    );
  }
}
