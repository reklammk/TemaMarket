import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'pages/splash_screen_page.dart';
import 'pages/auth_page.dart';
import 'pages/customer_storefront_page.dart';
import 'pages/courier_panel_page.dart';
import 'pages/merchant_panel_page.dart';
import 'pages/admin_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initNotification();
  } catch (e) {
    // Bildirim servisi başlatılamazsa uygulamayı çökertme
    debugPrint('Notification init error: $e');
  }
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
        fontFamily: 'Plus Jakarta Sans',
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
          onOpenAdmin: () => setState(() => _currentRoute = 'admin'),
          onOpenMerchant: () => setState(() => _currentRoute = 'merchant'),
          onOpenCourier: () => setState(() => _currentRoute = 'courier'),
          onLogout: _handleLogout,
        );
    }
  }
}
