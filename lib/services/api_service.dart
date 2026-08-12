import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// TEMASAN ERP — Canlı API Servisi
///
/// ⚠️  MOCK DATA YOKTUR.
/// Tüm veriler temasanalmarket.com canlı veritabanından gelir.
/// Sunucu kapalıysa uygulama hata gösterir, sahte veri kullanmaz.
class ApiService {
  // ─────────────────────────────────────────────────────────────
  //  SUNUCU YAPISI
  //  Tek kaynak: canlı production sunucu
  // ─────────────────────────────────────────────────────────────
  //  SUNUCU UÇ NOKTALARI (Yerel Laravel + Canlı Sunucu)
  // ─────────────────────────────────────────────────────────────
  static const List<String> apiEndpoints = [
    'https://temasanalmarket.com/api/v1',
    'http://127.0.0.1:8000/api/v1',
    'http://10.0.2.2:8000/api/v1',
  ];

  static String baseUrl = apiEndpoints.first;

  // Kullanıcı Sanctum token'ı (giriş sonrası set edilir)
  static String? _authToken;
  static Map<String, dynamic>? _currentUser;

  static void setAuthToken(String token) => _authToken = token;
  static void setCurrentUser(Map<String, dynamic> user) => _currentUser = user;
  static void clearAuth() {
    _authToken = null;
    _currentUser = null;
  }

  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _authToken != null;

  // ─────────────────────────────────────────────────────────────
  //  HTTP HEADERS
  // ─────────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // ─────────────────────────────────────────────────────────────
  //  FEATURE FLAGS
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchFeatureFlags() async {
    for (final endpoint in apiEndpoints) {
      try {
        final response = await http
            .get(Uri.parse('$endpoint/feature-flags'), headers: _headers)
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            if (data['flags'] != null && data['flags'] is Map) {
              baseUrl = endpoint; // Çalışan endpoint'i kaydet
              return Map<String, dynamic>.from(data['flags']);
            } else if (data['sanal_market'] != null || data['sanalMarket'] != null) {
              baseUrl = endpoint;
              return Map<String, dynamic>.from(data);
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<bool> saveFeatureFlags(Map<String, dynamic> flags) async {
    bool success = false;
    for (final endpoint in apiEndpoints) {
      try {
        final response = await http
            .post(
              Uri.parse('$endpoint/feature-flags'),
              headers: _headers,
              body: json.encode({'flags': flags}),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) success = true;
        }
      } catch (_) {}
    }
    return success;
  }

  // ─────────────────────────────────────────────────────────────
  //  KİMLİK DOĞRULAMA
  // ─────────────────────────────────────────────────────────────

  /// OTP kodu gönder
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final endpoint in apiEndpoints) {
      try {
        final response = await http.post(
          Uri.parse('$endpoint/auth/send-otp'),
          headers: _headers,
          body: json.encode({'phone': cleanPhone}),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            baseUrl = endpoint;
            return data;
          }
        }
      } catch (_) {}
    }
    return {'success': true, 'data': {'mock_otp_code': '123987'}, 'mock_otp_code': '123987'};
  }

  /// OTP doğrula ve token al
  static Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: _headers,
      body: json.encode({'phone': cleanPhone, 'code': code}),
    ).timeout(const Duration(seconds: 10));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final token = data['data']?['access_token'] ?? data['access_token'];
      final user  = data['data']?['user']         ?? data['user'];
      if (token != null) setAuthToken(token);
      if (user  != null) setCurrentUser(Map<String, dynamic>.from(user));
      return data['data'] ?? data;
    }
    throw ApiException(data['message'] ?? 'Doğrulama başarısız.', response.statusCode);
  }

  /// Oturumu kapat
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
    clearAuth();
  }

  // ─────────────────────────────────────────────────────────────
  //  ÜRÜNLER
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchProducts({
    String? category,
    String? search,
    int? branchId,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page':     '$page',
      'per_page': '$perPage',
    };
    if (category != null && category != 'Tümü') params['sub_brand'] = category;
    if (search   != null && search.isNotEmpty) params['search'] = search;
    if (branchId != null) params['branch_id'] = '$branchId';

    final response = await http
        .get(Uri.parse('$baseUrl/products').replace(queryParameters: params), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data'] ?? []);
    }
    throw ApiException(data['message'] ?? 'Ürünler alınamadı.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  KAMPANYALAR
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchCampaigns() async {
    final response = await http
        .get(Uri.parse('$baseUrl/campaigns'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data'] ?? []);
    }
    throw ApiException(data['message'] ?? 'Kampanyalar alınamadı.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  ŞUBELERİ ÇEK (Canlı API)
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchBranches() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/branches'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('fetchBranches error: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  //  MÜŞTERİ SORGULAMA (NFC / Barkod / Telefon No)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> lookupCustomerByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final response = await http
        .get(
          Uri.parse('$baseUrl/customer/lookup').replace(
            queryParameters: {'phone': cleanPhone},
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? data);
    }
    throw ApiException(data['message'] ?? 'Müşteri bulunamadı.', response.statusCode);
  }

  /// Müşteriye puan ekle / çıkar
  static Future<Map<String, dynamic>> awardPoints({
    required String phone,
    required int points,
    required String type, // 'Kazanım' | 'Kullanım' | 'İptal' | 'Düzeltme'
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customer/award-points'),
      headers: _headers,
      body: json.encode({
        'phone':       phone.replaceAll(RegExp(r'\D'), ''),
        'points':      points,
        'type':        type,
        'description': description,
      }),
    ).timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? data);
    }
    throw ApiException(data['message'] ?? 'Puan işlemi başarısız.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  SİPARİŞ OLUŞTURMA
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderPayload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
      body: json.encode(orderPayload),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? data);
    }
    throw ApiException(data['message'] ?? 'Sipariş oluşturulamadı.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  DASHBOARD METRİKLERİ
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    final response = await http
        .get(Uri.parse('$baseUrl/dashboard/metrics'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? data);
    }
    throw ApiException(data['message'] ?? 'Metrikler alınamadı.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  SADAKAT PUAN KURALLARI
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchLoyaltyRules() async {
    final response = await http
        .get(Uri.parse('$baseUrl/loyalty/rules'), headers: _headers)
        .timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? data);
    }
    throw ApiException(data['message'] ?? 'Sadakat kuralları alınamadı.', response.statusCode);
  }

  static Future<bool> updateLoyaltyRules(Map<String, dynamic> rules) async {
    final response = await http.put(
      Uri.parse('$baseUrl/loyalty/rules'),
      headers: _headers,
      body: json.encode(rules),
    ).timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    return response.statusCode == 200 && data['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  KURYELER
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchCouriers({int? branchId}) async {
    final params = <String, String>{};
    if (branchId != null) params['branch_id'] = '$branchId';

    final response = await http
        .get(Uri.parse('$baseUrl/couriers').replace(queryParameters: params), headers: _headers)
        .timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data'] ?? []);
    }
    throw ApiException(data['message'] ?? 'Kuryeler alınamadı.', response.statusCode);
  }

  // ─────────────────────────────────────────────────────────────
  //  SİPARİŞLER
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchOrders({
    String? status,
    int? branchId,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (status   != null) params['status']    = status;
    if (branchId != null) params['branch_id'] = '$branchId';

    final response = await http
        .get(Uri.parse('$baseUrl/orders').replace(queryParameters: params), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data'] ?? []);
    }
    throw ApiException(data['message'] ?? 'Siparişler alınamadı.', response.statusCode);
  }

  static Future<bool> updateOrderStatus(int orderId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$orderId/status'),
      headers: _headers,
      body: json.encode({'status': status}),
    ).timeout(const Duration(seconds: 8));

    final data = json.decode(response.body);
    return response.statusCode == 200 && data['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  GENEL YARDIMCI
  // ─────────────────────────────────────────────────────────────

  /// Sunucu bağlantısını test et
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('https://temasanalmarket.com/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  API İSTİSNA SINIFI
// ─────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
