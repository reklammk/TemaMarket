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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDC2626),
          primary: const Color(0xFFDC2626),
          onPrimary: Colors.white,
          secondary: const Color(0xFF0F172A),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Color(0x1A000000),
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF1F5F9),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          side: BorderSide.none,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFF1F5F9), space: 1),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
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
        return AuthPage(
          onLoginSuccess: _handleLoginSuccess,
          onClose: () => setState(() => _currentRoute = 'storefront'),
        );
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
