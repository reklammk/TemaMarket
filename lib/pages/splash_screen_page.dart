import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class SplashScreenPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreenPage({super.key, required this.onFinish});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  late final Player _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    // Tam ekran immersive mod - durum çubuğunu gizle
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _videoController = VideoController(_player);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      await _player.open(Media('asset:///assets/videos/tema_splash.mp4'));
      await _player.setVolume(100); // Ses açık (kullanıcı isteğine göre)

      // Video bitişini dinle → otomatik geçiş
      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _finish();
        }
      });

      // Güvenlik: video 30 saniyeden uzun sürmesi durumunda zorla geç
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) _finish();
      });
    } catch (e) {
      debugPrint('Splash video error: $e');
      // Video yüklenemezse 2 saniye sonra geç
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _finish();
      });
    }
  }

  void _finish() {
    // Sistem UI'yi geri aç
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onFinish();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _finish, // Ekrana tıklayarak da geçilebilir
        child: SizedBox.expand(
          child: Video(
            controller: _videoController,
            // Tam ekran kapla, kırp (cover)
            fit: BoxFit.cover,
            // Kontrol çubuklarını kapat
            controls: NoVideoControls,
          ),
        ),
      ),
    );
  }
}
