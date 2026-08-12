import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'pages/splash_screen_page.dart';
import 'pages/auth_page.dart';
import 'pages/customer_storefront_page.dart';
import 'pages/courier_panel_page.dart';
import 'pages/merchant_panel_page.dart';
import 'pages/admin_dashboard_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS ve Android Global Çökme Önleyici (Global Error Handler)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global Flutter Hatası Yakalandı: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Asenkron Hata Yakalandı: $error');
    return true; // Uygulamanın çökmesini engelle
  };

  runApp(const TemasanApp());
}

class TemasanApp extends StatefulWidget {
  const TemasanApp({super.key});

  @override
  State<TemasanApp> createState() => _TemasanAppState();
}

class _TemasanAppState extends State<TemasanApp> {
  Map<String, dynamic>? _currentUser;
  String _currentRoute = 'splash';

  @override
  void initState() {
    super.initState();
    // iOS: Bildirimleri Flutter engine tam yüklendikten SONRA başlat.
    // addPostFrameCallback, UIViewController viewDidLoad'dan sonra çalışır
    // bu sayede flutter_local_notifications'ın erken init crash'i önlenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await NotificationService().initNotification();
        } catch (e) {
          debugPrint('Notification init error: $e');
        }
      });
    });
  }

  void _handleLoginSuccess(Map<String, dynamic> user) {
    setState(() {
      _currentUser = user;
      final role = user['role'];
      if (role == 'SuperAdmin') {
        _currentRoute = 'admin';
      } else if (role == 'Merchant') {
        _currentRoute = 'merchant';
      } else if (role == 'Courier') {
        _currentRoute = 'courier';
      } else {
        _currentRoute = 'storefront';
      }
    });

    NotificationService().showNotification(
      id: 1,
      title: '👋 Hoş Geldiniz!',
      body: '${user['name']} olarak başarıyla giriş yapıldı.',
    );
  }

  void _handleLogout() {
    setState(() {
      _currentUser = null;
      _currentRoute = 'auth';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temasan Sanal Market & ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFDC2626),
        useMaterial3: true,
      ),
      home: _buildCurrentPage(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentRoute) {
      case 'splash':
        return SplashScreenPage(
          onFinish: () => setState(() => _currentRoute = 'storefront'),
        );
      case 'auth':
        return AuthPage(onLoginSuccess: _handleLoginSuccess);
      case 'admin':
        return AdminDashboardPage(
          user: _currentUser,
          onBackToStore: () => setState(() => _currentRoute = 'storefront'),
        );
      case 'merchant':
        return MerchantPanelPage(
          user: _currentUser,
          onBackToStore: () => setState(() => _currentRoute = 'storefront'),
        );
      case 'courier':
        return CourierPanelPage(
          user: _currentUser,
          onBackToStore: () => setState(() => _currentRoute = 'storefront'),
        );
      case 'storefront':
      default:
        return CustomerStorefrontPage(
          user: _currentUser,
          onOpenLogin: () => setState(() => _currentRoute = 'auth'),
          onOpenAdmin: () => setState(() => _currentRoute = 'admin'),
          onOpenMerchant: () => setState(() => _currentRoute = 'merchant'),
          onOpenCourier: () => setState(() => _currentRoute = 'courier'),
          onLogout: _handleLogout,
        );
    }
  }
}
