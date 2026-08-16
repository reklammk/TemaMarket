import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// TEMA Market canlı API istemcisi.
///
/// Production derlemelerinde yalnızca HTTPS kullanılır. Yerel geliştirme için:
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://temasanalmarket.com/api',
  );

  static final String baseUrl = _configuredBaseUrl.endsWith('/')
      ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
      : _configuredBaseUrl;

  static String? _authToken;
  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn =>
      _authToken != null && _authToken!.isNotEmpty && _currentUser != null;

  static void setAuthToken(String token) => _authToken = token;
  static void setCurrentUser(Map<String, dynamic> user) => _currentUser = user;

  static void clearAuth() {
    _authToken = null;
    _currentUser = null;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  static void _ensureEndpointIsAllowed() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw const ApiException('API adresi geçersiz.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ApiException(
        'Güvenli olmayan API adresi release sürümünde kullanılamaz.',
      );
    }
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _ensureEndpointIsAllowed();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = {..._headers, ...?extraHeaders};

    try {
      late http.Response response;
      final encodedBody = body == null ? null : json.encode(body);
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        default:
          throw ApiException('Desteklenmeyen HTTP yöntemi: $method');
      }

      Map<String, dynamic> decoded;
      try {
        final raw = json.decode(response.body);
        if (raw is! Map) {
          throw const FormatException('Response is not an object');
        }
        decoded = Map<String, dynamic>.from(raw);
      } on FormatException {
        throw ApiException(
          'Sunucu geçersiz bir yanıt döndürdü.',
          response.statusCode,
        );
      }

      final successStatus =
          response.statusCode >= 200 && response.statusCode < 300;
      if (!successStatus || decoded['success'] == false) {
        if (response.statusCode == 401 && path != '/auth/verify-otp') {
          clearAuth();
        }
        throw ApiException(
          decoded['message']?.toString() ?? 'İşlem gerçekleştirilemedi.',
          response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi. Lütfen tekrar deneyin.');
    } on ApiException {
      rethrow;
    } catch (error) {
      debugPrint('API request failed: $method $path — $error');
      throw const ApiException(
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  static List<dynamic> _dataList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data == null) return [];
    if (data is! List) {
      throw const ApiException('Sunucu liste yerine geçersiz veri döndürdü.');
    }
    return List<dynamic>.from(data);
  }

  static Map<String, dynamic> _dataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const ApiException('Sunucu geçersiz veri döndürdü.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> fetchFeatureConfiguration() async {
    return _request(
      'GET',
      '/feature-flags',
      timeout: const Duration(seconds: 5),
    );
  }

  static Future<Map<String, dynamic>?> fetchFeatureFlags() async {
    final response = await fetchFeatureConfiguration();
    final flags = response['flags'];
    if (flags is! Map) {
      throw const ApiException('Özellik ayarları geçersiz.');
    }
    return Map<String, dynamic>.from(flags);
  }

  static Future<Map<String, dynamic>> saveFeatureFlags(
      Map<String, dynamic> flags) async {
    return _request(
      'POST',
      '/feature-flags',
      body: {'flags': flags},
    );
  }

  static Future<Map<String, dynamic>> sendOtp(
    String phone, {
    required String role,
    required bool privacyAcknowledged,
    bool smsConsent = false,
  }) {
    return _request(
      'POST',
      '/auth/send-otp',
      body: {
        'phone': phone,
        'role': role,
        'privacy_acknowledged': privacyAcknowledged,
        'sms_consent': smsConsent,
      },
    );
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    required String expectedRole,
  }) async {
    final response = await _request(
      'POST',
      '/auth/verify-otp',
      body: {'phone': phone, 'code': code},
    );
    final token = response['token']?.toString();
    final rawUser = response['user'];
    if (token == null || token.length < 32 || rawUser is! Map) {
      throw const ApiException('Sunucu geçerli bir oturum oluşturmadı.');
    }
    final user = Map<String, dynamic>.from(rawUser);
    if (user['role']?.toString() != expectedRole) {
      throw const ApiException(
        'Hesap rolü seçilen giriş türüyle eşleşmiyor.',
        403,
      );
    }
    setAuthToken(token);
    setCurrentUser(user);
    return {'user': user, 'token': token};
  }

  static Future<void> logout() async {
    try {
      if (_authToken != null) {
        await _request(
          'POST',
          '/auth/logout',
          timeout: const Duration(seconds: 5),
        );
      }
    } finally {
      clearAuth();
    }
  }

  static Future<void> deleteAccount() async {
    if (!isLoggedIn) {
      throw const ApiException('Hesabı silmek için oturum açmanız gerekiyor.');
    }

    await _request(
      'POST',
      '/user/account/delete',
      body: const {'confirmation': 'DELETE_ACCOUNT'},
      timeout: const Duration(seconds: 20),
    );
    clearAuth();
  }

  static Future<List<dynamic>> fetchProducts({
    String? category,
    String? search,
    int? branchId,
  }) async {
    final query = <String, String>{};
    if (category != null && category != 'Tümü') {
      query['sub_brand'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
    return _dataList(await _request('GET', '/products', query: query));
  }

  static Future<List<dynamic>> fetchCampaigns() async =>
      _dataList(await _request('GET', '/campaigns'));

  static Future<List<dynamic>> fetchBranches() async =>
      _dataList(await _request('GET', '/branches'));

  static Future<Map<String, dynamic>> updateProfilePreferences({
    required bool smsConsent,
  }) async {
    final response = await _request(
      'POST',
      '/user/profile/update',
      body: {'sms_consent': smsConsent},
    );
    final userRaw = response['user'];
    if (userRaw is! Map) {
      throw const ApiException('Profil güncellenemedi.');
    }
    final user = Map<String, dynamic>.from(userRaw);
    setCurrentUser(user);
    return user;
  }

  static Future<Map<String, dynamic>> lookupCustomerByPhone(
    String phone,
  ) async {
    return _dataMap(await _request(
      'GET',
      '/customer/lookup',
      query: {'phone': phone},
    ));
  }

  static Future<Map<String, dynamic>> awardPoints({
    required String phone,
    required int points,
    required String type,
    String? description,
  }) async {
    return _dataMap(await _request(
      'POST',
      '/customer/award-points',
      body: {
        'phone': phone,
        'points': points,
        'type': type,
        'description': description,
      },
    ));
  }

  static String createIdempotencyKey() {
    final random = Random.secure();
    final nonce = List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'order-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  static Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderPayload, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? createIdempotencyKey();
    final response = await _request(
      'POST',
      '/orders',
      body: {...orderPayload, 'idempotency_key': key},
      extraHeaders: {'X-Idempotency-Key': key},
      timeout: const Duration(seconds: 20),
    );
    return _dataMap(response);
  }

  static Future<Map<String, dynamic>> fetchDashboardMetrics() async =>
      _dataMap(await _request('GET', '/admin/metrics'));

  static Future<Map<String, dynamic>> fetchLoyaltyRules() async =>
      _dataMap(await _request('GET', '/loyalty/rules'));

  static Future<bool> updateLoyaltyRules(
    Map<String, dynamic> rules,
  ) async {
    final response = await _request('PUT', '/loyalty/rules', body: rules);
    return response['success'] == true;
  }

  static Future<List<dynamic>> fetchCouriers({int? branchId}) async {
    final query = <String, String>{};
    if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
    return _dataList(await _request('GET', '/couriers', query: query));
  }

  static Future<List<dynamic>> fetchOrders({
    String? status,
    int? branchId,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
    return _dataList(await _request('GET', '/orders', query: query));
  }

  static Future<bool> updateOrderStatus(int orderId, String status) async {
    final response = await _request(
      'PATCH',
      '/orders/$orderId/status',
      body: {'status': status},
    );
    return response['success'] == true;
  }

  static Future<bool> assignCourier(int orderId, int courierId) async {
    final response = await _request(
      'POST',
      '/orders/assign-courier',
      body: {'order_id': orderId, 'courier_id': courierId},
    );
    return response['success'] == true;
  }

  static Future<bool> updateProductStock(int productId, int stock) async {
    final response = await _request(
      'POST',
      '/products/update-stock',
      body: {'product_id': productId, 'stock': stock},
    );
    return response['success'] == true;
  }

  static Future<bool> healthCheck() async {
    try {
      final response = await _request(
        'GET',
        '/health',
        timeout: const Duration(seconds: 5),
      );
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
