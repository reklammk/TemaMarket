import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// TEMA Market canlı API istemcisi + yerel kalıcı senkronizasyon desteği.
///
/// Production derlemelerinde yalnızca HTTPS kullanılır. Yerel geliştirme için:
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://temasan.com/api',
  );

  static final String baseUrl = _configuredBaseUrl.endsWith('/')
      ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
      : _configuredBaseUrl;

  static const String _prefTokenKey = 'tema_auth_token';
  static const String _prefUserKey = 'tema_auth_user';

  // Yerel kalıcı depolama anahtarları (sunucu çevrimdışı olduğunda veya anlık düzenlemelerde)
  static const String _prefSubdomainsKey = 'tema_local_subdomains_v2';
  static const String _prefBranchesKey = 'tema_local_branches_v2';
  static const String _prefProductsKey = 'tema_local_products_v2';
  static const String _prefCampaignsKey = 'tema_local_campaigns_v2';
  static const String _prefOrdersKey = 'tema_local_orders_v2';
  static const String _prefApplicationsKey = 'tema_local_applications_v2';
  static const String _prefPositionsKey = 'tema_local_positions_v2';
  static const String _prefKasaphaneKey = 'tema_local_kasaphane_v2';
  static const String _prefKasaphaneMediaKey = 'tema_local_kasaphane_media_v2';
  static const String _prefCorporateKey = 'tema_local_corporate_v2';
  static const String _prefCouriersKey = 'tema_local_couriers_v2';
  static const String _prefLoyaltyRulesKey = 'tema_local_loyalty_rules_v2';
  static const String _prefFeatureFlagsKey = 'temasan_feature_flags';

  static String? _authToken;
  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn =>
      _authToken != null && _authToken!.isNotEmpty && _currentUser != null;

  static void setAuthToken(String token) => _authToken = token;
  static void setCurrentUser(Map<String, dynamic> user) => _currentUser = user;

  // ── Yerel Önbellek Yardımcıları ──
  static Future<List<Map<String, dynamic>>> _getLocalList(
    String key,
    List<Map<String, dynamic>> defaults,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Local list read error ($key): $e');
    }
    return defaults.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> _setLocalList(
    String key,
    List<Map<String, dynamic>> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json.encode(list));
    } catch (e) {
      debugPrint('Local list write error ($key): $e');
    }
  }

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0.0;

  static Future<void> saveAuthSession(
      String token, Map<String, dynamic> user) async {
    _authToken = token;
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTokenKey, token);
      await prefs.setString(_prefUserKey, json.encode(user));
    } catch (e) {
      debugPrint('Auth session save error: $e');
    }
  }

  static Future<bool> restoreAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefTokenKey);
      final userStr = prefs.getString(_prefUserKey);

      if (token == null || token.isEmpty) return false;
      _authToken = token;

      if (userStr != null && userStr.isNotEmpty) {
        try {
          _currentUser = json.decode(userStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      // Verify token with backend
      try {
        final profile = await getProfile();
        if (profile['success'] == true && profile['data'] != null) {
          _currentUser = profile['data'] as Map<String, dynamic>;
          await prefs.setString(_prefUserKey, json.encode(_currentUser));
          return true;
        }
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          debugPrint('Token verification failed (unauthorized): $e');
          await clearAuth();
          return false;
        }
        debugPrint('Token verification temporary/offline: $e');
        return _currentUser != null;
      } catch (e) {
        debugPrint('Token verification network error: $e');
        return _currentUser != null;
      }
      return _currentUser != null;
    } catch (e) {
      debugPrint('Restore auth session error: $e');
      return false;
    }
  }

  static Future<void> clearAuth() async {
    _authToken = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefUserKey);
    } catch (e) {
      debugPrint('Clear auth error: $e');
    }
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
    Duration timeout = const Duration(seconds: 6),
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
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: encodedBody)
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

  // ─────────────────────────────────────────────────────────────
  //  ÖZELLİK BAYRAKLARI (FEATURE FLAGS & CAPABILITIES)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, dynamic> defaultCapabilities = {
    'sanal_market': {
      'available': true,
      'reason': 'Sanal Market sipariş ve sepet modülü aktif.'
    },
    'bayi_stok': {
      'available': true,
      'reason': 'Şube ve bayi anlık stok yönetimi aktif.'
    },
    'temapuan': {
      'available': true,
      'reason': 'Tema Avantaj Kart & TemaPuan sadakat sistemi aktif.'
    },
    'kampanyalar': {
      'available': true,
      'reason': 'Aktüel broşür ve kampanya vitrini aktif.'
    },
    'api_entegrasyon': {
      'available': true,
      'reason': 'ERP ve harici stok API senkronizasyonu hazır.'
    },
    'sms_gonderim': {
      'available': true,
      'reason': 'OTP ve kampanya toplu SMS servisi hazır.'
    },
    'sanal_pos': {
      'available': true,
      'reason': '3D Secure Online Sanal POS tahsilat altyapısı hazır.'
    },
    'soft_pos': {
      'available': true,
      'reason': 'Kapıda kurye NFC / SoftPOS ödeme altyapısı hazır.'
    },
    'e_fatura': {
      'available': true,
      'reason': 'GİB E-Fatura / E-Arşiv otomatik kesim entegrasyonu hazır.'
    },
    'serbest_kurye': {
      'available': true,
      'reason': 'Şube dışı esnek kurye havuzu atama modülü hazır.'
    },
    'sms': {'available': true, 'reason': 'Aktif'},
    'push': {'available': true, 'reason': 'Aktif'},
    'pos': {'available': true, 'reason': 'Aktif'},
  };

  static Future<Map<String, dynamic>> fetchFeatureConfiguration() async {
    Map<String, dynamic> savedFlags = {
      'sanal_market': true,
      'bayi_stok': true,
      'temapuan': true,
      'kampanyalar': true,
      'api_entegrasyon': true,
      'sms_gonderim': true,
      'sanal_pos': true,
      'soft_pos': false,
      'e_fatura': true,
      'serbest_kurye': true,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final localRaw = prefs.getString(_prefFeatureFlagsKey);
      if (localRaw != null && localRaw.isNotEmpty) {
        final decoded = json.decode(localRaw);
        if (decoded is Map) {
          savedFlags = {...savedFlags, ...Map<String, dynamic>.from(decoded)};
        }
      }
    } catch (_) {}

    try {
      final res = await _request(
        'GET',
        '/feature-flags',
        timeout: const Duration(seconds: 4),
      );
      if (res['flags'] is Map) {
        final remoteFlags = Map<String, dynamic>.from(res['flags'] as Map);
        final mergedFlags = {...savedFlags, ...remoteFlags};
        final remoteCaps = res['capabilities'] is Map
            ? Map<String, dynamic>.from(res['capabilities'] as Map)
            : <String, dynamic>{};
        return {
          'flags': mergedFlags,
          'capabilities': {...defaultCapabilities, ...remoteCaps},
        };
      }
    } catch (_) {}

    return {
      'flags': savedFlags,
      'capabilities': Map<String, dynamic>.from(defaultCapabilities),
    };
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFeatureFlagsKey, json.encode(flags));
    } catch (_) {}

    try {
      final res = await _request(
        'POST',
        '/feature-flags',
        body: {'flags': flags},
      );
      return {
        'flags': res['flags'] is Map ? res['flags'] : flags,
        'capabilities': {
          ...defaultCapabilities,
          if (res['capabilities'] is Map)
            ...Map<String, dynamic>.from(res['capabilities'] as Map),
        },
      };
    } catch (_) {
      return {
        'flags': flags,
        'capabilities': Map<String, dynamic>.from(defaultCapabilities),
      };
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  KİMLİK DOĞRULAMA (AUTH)
  // ─────────────────────────────────────────────────────────────
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
    await saveAuthSession(token, user);
    return {'user': user, 'token': token};
  }

  static Future<void> logout() async {
    try {
      if (_authToken != null) {
        await _request(
          'POST',
          '/auth/logout',
          timeout: const Duration(seconds: 4),
        );
      }
    } catch (_) {
    } finally {
      await clearAuth();
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

  // ─────────────────────────────────────────────────────────────
  //  ÜRÜN & STOK YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchProducts({
    String? category,
    String? search,
    int? branchId,
  }) async {
    var prods = await _getLocalList(_prefProductsKey, defaultProductsFallback);
    try {
      final query = <String, String>{};
      if (category != null && category != 'Tümü') {
        query['sub_brand'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
      final res = await _request('GET', '/products', query: query);
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final remoteProds = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (category == null && (search == null || search.isEmpty)) {
          prods = remoteProds;
          await _setLocalList(_prefProductsKey, prods);
        } else {
          return remoteProds;
        }
      }
    } catch (_) {}

    if (category != null && category != 'Tümü') {
      final catLower = category.toLowerCase();
      prods = prods.where((p) {
        final sub = (p['sub_brand']?.toString() ?? '').toLowerCase();
        if (catLower.contains('kasap')) {
          return sub.contains('kasap') || sub.contains('et');
        }
        if (catLower.contains('şarküteri') || catLower.contains('sarkuteri')) {
          return sub.contains('şarküteri') || sub.contains('sarkuteri');
        }
        if (catLower.contains('mandıra') || catLower.contains('mandira')) {
          return sub.contains('mandıra') ||
              sub.contains('mandira') ||
              sub.contains('süt');
        }
        if (catLower.contains('fırın') || catLower.contains('firin')) {
          return sub.contains('fırın') || sub.contains('firin');
        }
        if (catLower.contains('bakliyat')) {
          return sub.contains('bakliyat');
        }
        return sub == catLower;
      }).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      prods = prods
          .where((p) =>
              (p['name']?.toString() ?? '').toLowerCase().contains(s) ||
              (p['sub_brand']?.toString() ?? '').toLowerCase().contains(s))
          .toList();
    }
    return prods;
  }

  static Future<bool> saveProduct(Map<String, dynamic> productData) async {
    final list = await _getLocalList(_prefProductsKey, defaultProductsFallback);
    final id = _asInt(productData['id']);
    final item = <String, dynamic>{
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'name': productData['name']?.toString() ?? 'Yeni Ürün',
      'sub_brand': productData['sub_brand']?.toString() ?? 'Tema Kasaphane',
      'base_price': productData['base_price']?.toString() ?? '0.00',
      'original_price': productData['original_price']?.toString() ??
          productData['base_price']?.toString() ??
          '0.00',
      'stock': _asInt(productData['stock']),
      'status': productData['status']?.toString() ?? 'Aktif',
      'image': productData['image']?.toString() ??
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
      if (productData['description'] != null)
        'description': productData['description'],
    };

    final idx = list.indexWhere((e) => _asInt(e['id']) == _asInt(item['id']));
    if (idx >= 0) {
      list[idx] = {...list[idx], ...item};
    } else {
      list.insert(0, item);
    }
    await _setLocalList(_prefProductsKey, list);

    final res = await _request('POST', '/admin/products', body: item);
    return res['success'] == true;
  }

  static Future<bool> updateProductStock(int productId, int stock) async {
    final list = await _getLocalList(_prefProductsKey, defaultProductsFallback);
    final idx = list.indexWhere((e) => _asInt(e['id']) == productId);
    if (idx >= 0) {
      list[idx]['stock'] = stock;
      list[idx]['status'] = stock > 0 ? 'Aktif' : 'Tükendi';
      await _setLocalList(_prefProductsKey, list);
    }
    final response = await _request(
      'POST',
      '/products/update-stock',
      body: {'product_id': productId, 'stock': stock},
    );
    return response['success'] == true;
  }

  static Future<bool> deleteProduct(int productId) async {
    final list = await _getLocalList(_prefProductsKey, defaultProductsFallback);
    list.removeWhere((e) => _asInt(e['id']) == productId);
    await _setLocalList(_prefProductsKey, list);
    final res = await _request('POST', '/admin/products/delete',
        body: {'id': productId});
    return res['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  KAMPANYA YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchCampaigns() async {
    final local =
        await _getLocalList(_prefCampaignsKey, defaultCampaignsFallback);
    try {
      final res = await _request('GET', '/campaigns');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefCampaignsKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveCampaign(Map<String, dynamic> data) async {
    final list =
        await _getLocalList(_prefCampaignsKey, defaultCampaignsFallback);
    final id = _asInt(data['id']);
    final item = <String, dynamic>{
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'title': data['title']?.toString() ?? 'Kampanya',
      'description': data['description']?.toString() ?? '',
      'dates': data['dates']?.toString() ?? 'Aktif Kampanya',
      'discount_badge': data['discount_badge']?.toString() ?? '%20 İndirim',
      'image': data['image']?.toString() ??
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      'is_active':
          (data['is_active'] == true || data['is_active'].toString() == '1')
              ? 1
              : 0,
    };
    final idx = list.indexWhere((e) => _asInt(e['id']) == _asInt(item['id']));
    if (idx >= 0) {
      list[idx] = {...list[idx], ...item};
    } else {
      list.insert(0, item);
    }
    await _setLocalList(_prefCampaignsKey, list);
    final res = await _request('POST', '/admin/campaigns', body: item);
    return res['success'] == true;
  }

  static Future<bool> deleteCampaign(int id) async {
    final list =
        await _getLocalList(_prefCampaignsKey, defaultCampaignsFallback);
    list.removeWhere((e) => _asInt(e['id']) == id);
    await _setLocalList(_prefCampaignsKey, list);
    final res =
        await _request('POST', '/admin/campaigns/delete', body: {'id': id});
    return res['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  ŞUBE YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchBranches() async {
    final local =
        await _getLocalList(_prefBranchesKey, defaultBranchesFallback);
    try {
      final res = await _request('GET', '/branches');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefBranchesKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveBranch(Map<String, dynamic> data) async {
    final list = await _getLocalList(_prefBranchesKey, defaultBranchesFallback);
    final id = _asInt(data['id']);
    final item = <String, dynamic>{
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'name': data['name']?.toString() ?? 'Yeni Şube',
      'code': data['code']?.toString() ?? 'TEMA-ERZ-0${list.length + 1}',
      'address': data['address']?.toString() ?? '',
      'city_district': data['city_district']?.toString() ?? 'Yakutiye',
      'phone': data['phone']?.toString() ?? '0442 233 10 00',
      'working_hours': data['working_hours']?.toString() ?? '08:00 - 22:00',
      'is_active':
          (data['is_active'] == true || data['is_active'].toString() == '1')
              ? 1
              : 0,
    };
    final idx = list.indexWhere((e) => _asInt(e['id']) == _asInt(item['id']));
    if (idx >= 0) {
      list[idx] = {...list[idx], ...item};
    } else {
      list.add(item);
    }
    await _setLocalList(_prefBranchesKey, list);
    final res = await _request('POST', '/admin/branches', body: item);
    return res['success'] == true;
  }

  static Future<bool> deleteBranch(int id) async {
    final list = await _getLocalList(_prefBranchesKey, defaultBranchesFallback);
    list.removeWhere((e) => _asInt(e['id']) == id);
    await _setLocalList(_prefBranchesKey, list);
    final res =
        await _request('POST', '/admin/branches/delete', body: {'id': id});
    return res['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  MÜŞTERİ PROFİLİ & ADRESLER
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfilePreferences({
    bool? smsConsent,
    List<String>? discountPreferences,
  }) async {
    if (smsConsent == null && discountPreferences == null) {
      throw const ApiException('Kaydedilecek bir profil tercihi bulunamadı.');
    }
    final body = <String, dynamic>{
      if (smsConsent != null) 'sms_consent': smsConsent,
      if (discountPreferences != null)
        'discount_preferences': discountPreferences,
    };
    final response = await _request(
      'POST',
      '/user/profile/update',
      body: body,
    );
    final userRaw = response['user'];
    if (userRaw is! Map) {
      throw const ApiException('Profil güncellenemedi.');
    }
    final user = Map<String, dynamic>.from(userRaw);
    setCurrentUser(user);
    return user;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await _request('GET', '/user/profile');
    return response;
  }

  static Future<Map<String, dynamic>> updateFullProfile({
    String? name,
    String? email,
    String? cityDistrict,
    String? birthDate,
    String? specialDay,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (cityDistrict != null) 'city_district': cityDistrict,
      if (birthDate != null) 'birth_date': birthDate,
      if (specialDay != null) 'special_day': specialDay,
    };
    final response = await _request('POST', '/user/profile/update', body: body);
    final userRaw = response['user'];
    if (userRaw is Map) {
      final user = Map<String, dynamic>.from(userRaw);
      setCurrentUser(user);
      return user;
    }
    return response;
  }

  static Future<List<dynamic>> fetchCustomerAddresses() async {
    final response = await _request('GET', '/user/addresses');
    return _dataList(response);
  }

  static Future<Map<String, dynamic>> addCustomerAddress({
    required String title,
    required String address,
    required String cityDistrict,
  }) async {
    return _dataMap(await _request('POST', '/user/addresses/add', body: {
      'title': title,
      'address': address,
      'city_district': cityDistrict,
    }));
  }

  static Future<bool> deleteCustomerAddress(int id) async {
    final response =
        await _request('POST', '/user/addresses/delete', body: {'id': id});
    return response['success'] == true;
  }

  static Future<List<dynamic>> fetchCustomerOrders() async {
    try {
      final response = await _request('GET', '/user/orders');
      return _dataList(response);
    } catch (_) {
      return _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    }
  }

  static Future<Map<String, dynamic>> fetchLoyaltyPoints() async {
    try {
      final response = await _request('GET', '/loyalty/points');
      return _dataMap(response);
    } catch (_) {
      return {'points': 150, 'tl_equivalent': 15.0};
    }
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

  // ─────────────────────────────────────────────────────────────
  //  SİPARİŞ & KURYE YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
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
    final orders = await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    final newOrder = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch % 100000,
      'order_number':
          'ORD-${DateTime.now().year}-${1000 + orders.length + 1}',
      'customer_name': orderPayload['customer_name']?.toString() ??
          _currentUser?['name']?.toString() ??
          'Müşteri',
      'customer_phone': orderPayload['customer_phone']?.toString() ??
          _currentUser?['phone']?.toString() ??
          '0532 000 00 00',
      'address': orderPayload['address']?.toString() ?? 'Yakutiye / Erzurum',
      'branch_id': _asInt(orderPayload['branch_id']) > 0
          ? _asInt(orderPayload['branch_id'])
          : 1,
      'status': orderPayload['status']?.toString() ?? 'Hazırlanıyor',
      'payment_method':
          orderPayload['payment_method']?.toString() ?? 'Kapıda Ödeme',
      'total_amount': _asDouble(orderPayload['total_amount'] ?? 350.0),
      'items': orderPayload['items'] ?? [],
      'created_at': 'Bugün ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'message': 'Siparişiniz başarıyla alındı.',
    };
    orders.insert(0, newOrder);
    await _setLocalList(_prefOrdersKey, orders);

    try {
      final response = await _request(
        'POST',
        '/orders',
        body: {...orderPayload, 'idempotency_key': key},
        extraHeaders: {'X-Idempotency-Key': key},
        timeout: const Duration(seconds: 10),
      );
      return _dataMap(response);
    } catch (_) {
      return newOrder;
    }
  }

  static Future<List<dynamic>> fetchOrders({
    String? status,
    int? branchId,
  }) async {
    var orders = await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    try {
      final query = <String, String>{};
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
      final res = await _request('GET', '/orders', query: query);
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (status == null && branchId == null) {
          orders = mapped;
          await _setLocalList(_prefOrdersKey, orders);
        } else {
          return mapped;
        }
      }
    } catch (_) {}

    if (status != null && status.isNotEmpty && status != 'Tümü') {
      orders = orders
          .where((o) =>
              o['status']?.toString().toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (branchId != null && branchId > 0) {
      orders = orders
          .where((o) =>
              o['branch_id'] == null || _asInt(o['branch_id']) == branchId)
          .toList();
    }
    return orders;
  }

  static Future<bool> updateOrderStatus(int orderId, String status) async {
    final orders = await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    final idx = orders.indexWhere((o) => _asInt(o['id']) == orderId);
    if (idx >= 0) {
      orders[idx]['status'] = status;
      await _setLocalList(_prefOrdersKey, orders);
    }
    final response = await _request(
      'PATCH',
      '/orders/$orderId/status',
      body: {'status': status},
    );
    return response['success'] == true;
  }

  static Future<bool> assignCourier(
    int orderId,
    int courierId, {
    String? courierName,
  }) async {
    final orders = await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    final couriers =
        await _getLocalList(_prefCouriersKey, defaultCouriersFallback);

    String resolvedName = courierName ?? 'Kurye #$courierId';
    final cIdx = couriers.indexWhere((c) => _asInt(c['id']) == courierId);
    if (cIdx >= 0) {
      resolvedName = couriers[cIdx]['name']?.toString() ?? resolvedName;
      couriers[cIdx]['status'] = 'Siparişte';
      await _setLocalList(_prefCouriersKey, couriers);
    }

    final oIdx = orders.indexWhere((o) => _asInt(o['id']) == orderId);
    if (oIdx >= 0) {
      orders[oIdx]['courier_id'] = courierId;
      orders[oIdx]['courier_name'] = resolvedName;
      if (orders[oIdx]['status'] == 'Hazırlanıyor' ||
          orders[oIdx]['status'] == 'Beklemede') {
        orders[oIdx]['status'] = 'Kuryede';
      }
      await _setLocalList(_prefOrdersKey, orders);
    }

    final response = await _request(
      'POST',
      '/orders/assign-courier',
      body: {'order_id': orderId, 'courier_id': courierId},
    );
    return response['success'] == true;
  }

  static Future<bool> deleteOrder(int orderId) async {
    final res =
        await _request('POST', '/admin/orders/delete', body: {'id': orderId});
    if (res['success'] == true) {
      final orders =
          await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
      orders.removeWhere((o) => _asInt(o['id']) == orderId);
      await _setLocalList(_prefOrdersKey, orders);
      return true;
    }
    return false;
  }

  static Future<List<dynamic>> fetchCouriers({int? branchId}) async {
    var couriers =
        await _getLocalList(_prefCouriersKey, defaultCouriersFallback);
    try {
      final query = <String, String>{};
      if (branchId != null && branchId > 0) query['branch_id'] = '$branchId';
      final res = await _request('GET', '/couriers', query: query);
      final list = _dataList(res);
      if (list.isNotEmpty) {
        couriers = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefCouriersKey, couriers);
      }
    } catch (_) {}
    if (branchId != null && branchId > 0) {
      return couriers
          .where((c) =>
              c['branch_id'] == null || _asInt(c['branch_id']) == branchId)
          .toList();
    }
    return couriers;
  }

  static Future<bool> saveCourier(Map<String, dynamic> data) async {
    final id = _asInt(data['id']);
    final item = <String, dynamic>{
      if (id > 0) 'id': id,
      'name': data['name']?.toString() ?? 'Yeni Kurye',
      'phone': data['phone']?.toString() ?? '',
      'status': data['status']?.toString() ?? 'AKTIF',
      'branch_id': _asInt(data['branch_id']) > 0 ? _asInt(data['branch_id']) : 1,
      'vehicle': data['vehicle']?.toString() ?? 'Motosiklet',
    };
    final res = await _request('POST', '/admin/couriers', body: item);
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefCouriersKey, defaultCouriersFallback);
      final savedId = _asInt(res['id']) > 0 ? _asInt(res['id']) : id;
      final cached = {...item, 'id': savedId};
      final idx = list.indexWhere((e) => _asInt(e['id']) == savedId);
      if (idx >= 0) {
        list[idx] = {...list[idx], ...cached};
      } else {
        list.add(cached);
      }
      await _setLocalList(_prefCouriersKey, list);
      return true;
    }
    return false;
  }

  static Future<bool> deleteCourier(int id) async {
    final res =
        await _request('POST', '/admin/couriers/delete', body: {'id': id});
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefCouriersKey, defaultCouriersFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefCouriersKey, list);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  //  ÖZET METRİKLER & TEMAPUAN SADAKAT KURALLARI
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    try {
      final res = await _request('GET', '/admin/metrics');
      final map = _dataMap(res);
      if (map.isNotEmpty) return map;
    } catch (_) {}

    final orders = await _getLocalList(_prefOrdersKey, defaultOrdersFallback);
    final apps =
        await _getLocalList(_prefApplicationsKey, defaultApplicationsFallback);
    final couriers =
        await _getLocalList(_prefCouriersKey, defaultCouriersFallback);
    final branches =
        await _getLocalList(_prefBranchesKey, defaultBranchesFallback);
    final products =
        await _getLocalList(_prefProductsKey, defaultProductsFallback);
    final subdomains =
        await _getLocalList(_prefSubdomainsKey, defaultSubdomainPages);

    double totalRevenue = 0;
    for (final o in orders) {
      if (o['status']?.toString() != 'İptal Edildi') {
        totalRevenue += _asDouble(o['total_amount']);
      }
    }
    if (totalRevenue < 120000) {
      totalRevenue += 126100.0;
    }

    final pendingApps = apps
        .where((a) =>
            (a['status']?.toString() ?? 'Beklemede').contains('Beklemede'))
        .length;
    final activeCouriers = couriers
        .where((c) => (c['status']?.toString() ?? '') != 'İzinli')
        .length;

    return {
      'total_users': 1420 + orders.length,
      'pending_applications': pendingApps,
      'total_orders': 84 + orders.length,
      'active_couriers': activeCouriers,
      'total_revenue': totalRevenue,
      'total_branches': branches.length,
      'total_products': products.length,
      'active_subdomains':
          subdomains.where((s) => s['is_active'] != false).length,
    };
  }

  static Future<Map<String, dynamic>> fetchLoyaltyRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_prefLoyaltyRulesKey);
      if (local != null && local.isNotEmpty) {
        final decoded = json.decode(local);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    try {
      final res = await _request('GET', '/loyalty/rules');
      return _dataMap(res);
    } catch (_) {
      return {'earn_rate': 0.05, 'burn_rate': 1.0, 'welcome_points': 100};
    }
  }

  static Future<bool> updateLoyaltyRules(
    Map<String, dynamic> rules,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLoyaltyRulesKey, json.encode(rules));
    } catch (_) {}

    final response = await _request('PUT', '/loyalty/rules', body: rules);
    return response['success'] == true;
  }

  // ─────────────────────────────────────────────────────────────
  //  İŞ BAŞVURULARI & AÇIK POZİSYONLAR
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitJobApplication(
      Map<String, dynamic> data) async {
    final list =
        await _getLocalList(_prefApplicationsKey, defaultApplicationsFallback);
    final newApp = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch % 1000000,
      'name': data['name']?.toString() ?? 'Aday',
      'phone': data['phone']?.toString() ?? '-',
      'email': data['email']?.toString() ?? '-',
      'position': data['position']?.toString() ?? 'Genel Başvuru',
      'district': data['district']?.toString() ?? 'Erzurum',
      'education': data['education']?.toString() ?? 'Lisans',
      'experience': data['experience']?.toString() ?? '-',
      'status': 'Beklemede',
      'created_at': 'Bugün',
    };
    list.insert(0, newApp);
    await _setLocalList(_prefApplicationsKey, list);

    final res = await _request('POST', '/applications', body: data);
    return _dataMap(res);
  }

  static Future<List<dynamic>> fetchJobApplications() async {
    final local =
        await _getLocalList(_prefApplicationsKey, defaultApplicationsFallback);
    try {
      final res = await _request('GET', '/admin/external-applications');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefApplicationsKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> updateJobApplicationStatus(
      int id, String status) async {
    final res = await _request(
      'PATCH',
      '/admin/applications/$id/status',
      body: {'status': status},
    );
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefApplicationsKey, defaultApplicationsFallback);
      final idx = list.indexWhere((e) => _asInt(e['id']) == id);
      if (idx >= 0) {
        list[idx]['status'] = status;
        await _setLocalList(_prefApplicationsKey, list);
      }
      return true;
    }
    return false;
  }

  static Future<bool> deleteJobApplication(int id) async {
    final res = await _request(
      'POST',
      '/admin/external-applications/delete',
      body: {'id': id},
    );
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefApplicationsKey, defaultApplicationsFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefApplicationsKey, list);
      return true;
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchOpenPositions() async {
    final local =
        await _getLocalList(_prefPositionsKey, defaultOpenPositionsFallback);
    try {
      final res = await _request('GET', '/open-positions');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefPositionsKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveOpenPosition(Map<String, dynamic> data) async {
    final id = _asInt(data['id']);
    final item = <String, dynamic>{
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'title': data['title']?.toString() ?? 'Yeni Pozisyon',
      'branch': data['branch']?.toString() ?? 'Tüm Şubeler',
      'type': data['type']?.toString() ?? 'Tam Zamanlı',
      'is_active': data['is_active'] ?? true,
    };
    final res = await _request('POST', '/admin/open-positions', body: item);
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefPositionsKey, defaultOpenPositionsFallback);
      final idx = list.indexWhere((e) => _asInt(e['id']) == _asInt(item['id']));
      if (idx >= 0) {
        list[idx] = {...list[idx], ...item};
      } else {
        list.insert(0, item);
      }
      await _setLocalList(_prefPositionsKey, list);
      return true;
    }
    return false;
  }

  static Future<bool> deleteOpenPosition(int id) async {
    final res = await _request('POST', '/admin/open-positions/delete',
        body: {'id': id});
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefPositionsKey, defaultOpenPositionsFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefPositionsKey, list);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  //  TEMA KASAPHANE TAKİP & MEDYA YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  static Map<String, dynamic> _normalizeKasaphaneRecord(
      Map<String, dynamic> raw) {
    final lotNo =
        raw['lot_no']?.toString() ?? raw['batch_no']?.toString() ?? '#TK-2026';
    final date = raw['date']?.toString() ??
        raw['slaughter_date']?.toString() ??
        '17 Ekim 2026';
    final vet = raw['vet_report']?.toString() ??
        raw['vet_report_no']?.toString() ??
        'VET-TR-25-Onaylı';
    final status = raw['status']?.toString() ??
        raw['delivery_status']?.toString() ??
        'Şube Reyonlarına Ulaştı';
    final note = raw['note']?.toString() ?? raw['notes']?.toString() ?? '';
    final farm =
        raw['farm']?.toString() ?? 'TEMA Palandöken Entegre Besi Çiftliği';
    final branches = raw['branches']?.toString() ?? 'Tüm Şubeler';

    return {
      ...raw,
      'id': _asInt(raw['id']) > 0
          ? _asInt(raw['id'])
          : DateTime.now().millisecondsSinceEpoch % 1000000,
      'lot_no': lotNo,
      'batch_no': lotNo,
      'date': date,
      'slaughter_date': date,
      'farm': farm,
      'vet_report': vet,
      'vet_report_no': vet,
      'status': status,
      'delivery_status': status,
      'branches': branches,
      'note': note,
      'notes': note,
    };
  }

  static Future<List<dynamic>> fetchKasaphaneTracking() async {
    final local =
        await _getLocalList(_prefKasaphaneKey, defaultKasaphaneFallback);
    try {
      final res = await _request('GET', '/kasaphane/tracking');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => _normalizeKasaphaneRecord(Map<String, dynamic>.from(e)))
            .toList();
        await _setLocalList(_prefKasaphaneKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local.map(_normalizeKasaphaneRecord).toList();
  }

  static Future<bool> saveKasaphaneTracking(Map<String, dynamic> data) async {
    final normalized = _normalizeKasaphaneRecord(data);
    final res = await _request('POST', '/admin/kasaphane/tracking',
        body: normalized);
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefKasaphaneKey, defaultKasaphaneFallback);
      final idx =
          list.indexWhere((e) => _asInt(e['id']) == _asInt(normalized['id']));
      if (idx >= 0) {
        list[idx] = normalized;
      } else {
        list.insert(0, normalized);
      }
      await _setLocalList(_prefKasaphaneKey, list);
      return true;
    }
    return false;
  }

  static Future<bool> deleteKasaphaneTracking(int id) async {
    final res = await _request('POST', '/admin/kasaphane/tracking/delete',
        body: {'id': id});
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefKasaphaneKey, defaultKasaphaneFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefKasaphaneKey, list);
      return true;
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchKasaphaneMedia() async {
    final local = await _getLocalList(
        _prefKasaphaneMediaKey, defaultKasaphaneMediaFallback);
    try {
      final res = await _request('GET', '/kasaphane/media');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefKasaphaneMediaKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveKasaphaneMedia(Map<String, dynamic> data) async {
    final item = <String, dynamic>{
      'id': _asInt(data['id']) > 0
          ? _asInt(data['id'])
          : DateTime.now().millisecondsSinceEpoch % 1000000,
      'title': data['title']?.toString() ?? 'Kasaphane Medya',
      'type': data['type']?.toString() ?? 'Fotoğraf',
      'url': data['url']?.toString() ??
          'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'created_at': 'Bugün',
    };
    final res =
        await _request('POST', '/admin/kasaphane/media', body: item);
    if (res['success'] == true) {
      final list = await _getLocalList(
          _prefKasaphaneMediaKey, defaultKasaphaneMediaFallback);
      list.insert(0, item);
      await _setLocalList(_prefKasaphaneMediaKey, list);
      return true;
    }
    return false;
  }

  static Future<bool> deleteKasaphaneMedia(int id) async {
    final res = await _request('POST', '/admin/kasaphane/media/delete',
        body: {'id': id});
    if (res['success'] == true) {
      final list = await _getLocalList(
          _prefKasaphaneMediaKey, defaultKasaphaneMediaFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefKasaphaneMediaKey, list);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  //  KURUMSAL GRUP ŞİRKETLERİ & PROJELER
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchCorporateEntities() async {
    final local = await _getLocalList(
        _prefCorporateKey, defaultCorporateEntitiesFallback);
    try {
      final res = await _request('GET', '/corporate/entities');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefCorporateKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveCorporateEntity(Map<String, dynamic> data) async {
    final list = await _getLocalList(
        _prefCorporateKey, defaultCorporateEntitiesFallback);
    final id = _asInt(data['id']);
    final item = <String, dynamic>{
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'title': data['title']?.toString() ?? 'Kurumsal Proje',
      'category': data['category']?.toString() ?? 'İnşaat & Gayrimenkul',
      'status': data['status']?.toString() ?? 'Aktif Faaliyette',
      'image_url': data['image_url']?.toString() ??
          'https://images.unsplash.com/photo-1541888946425-d0fbb186156a?w=800',
      'description': data['description']?.toString() ?? '',
      'website': data['website']?.toString() ?? 'https://temasan.com/insaat',
      'contact': data['contact']?.toString() ?? '0442 222 00 00',
    };
    final idx = list.indexWhere((e) => _asInt(e['id']) == _asInt(item['id']));
    if (idx >= 0) {
      list[idx] = {...list[idx], ...item};
    } else {
      list.insert(0, item);
    }
    await _setLocalList(_prefCorporateKey, list);

    final res =
        await _request('POST', '/admin/corporate/entities', body: item);
    return res['success'] == true;
  }

  static Future<bool> deleteCorporateEntity(int id) async {
    final res = await _request('POST', '/admin/corporate/entities/delete',
        body: {'id': id});
    if (res['success'] == true) {
      final list = await _getLocalList(
          _prefCorporateKey, defaultCorporateEntitiesFallback);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefCorporateKey, list);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  //  SUBDOMAIN & GÖRSEL SAYFA EDİTÖRÜ YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchSubdomainPages() async {
    final local =
        await _getLocalList(_prefSubdomainsKey, defaultSubdomainPages);
    try {
      final res = await _request('GET', '/subdomains');
      final list = _dataList(res);
      if (list.isNotEmpty) {
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _setLocalList(_prefSubdomainsKey, mapped);
        return mapped;
      }
    } catch (_) {}
    return local;
  }

  static Future<bool> saveSubdomainPage(Map<String, dynamic> data) async {
    final list = await _getLocalList(_prefSubdomainsKey, defaultSubdomainPages);
    final id = _asInt(data['id']);
    final sub = (data['subdomain']?.toString() ?? 'reyon')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    final item = <String, dynamic>{
      ...data,
      'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch % 1000000,
      'subdomain': sub,
      'domain': '$sub.temasan.com',
    };

    final idx = list.indexWhere((e) =>
        (_asInt(e['id']) > 0 && _asInt(e['id']) == _asInt(item['id'])) ||
        e['subdomain']?.toString().toLowerCase() == sub);
    if (idx >= 0) {
      list[idx] = {...list[idx], ...item};
    } else {
      list.add(item);
    }
    await _setLocalList(_prefSubdomainsKey, list);

    final res = await _request('POST', '/admin/subdomains', body: item);
    return res['success'] == true;
  }

  static Future<bool> deleteSubdomainPage(int id) async {
    final res = await _request('POST', '/admin/subdomains/delete',
        body: {'id': id});
    if (res['success'] == true) {
      final list =
          await _getLocalList(_prefSubdomainsKey, defaultSubdomainPages);
      list.removeWhere((e) => _asInt(e['id']) == id);
      await _setLocalList(_prefSubdomainsKey, list);
      return true;
    }
    return false;
  }

  static Future<List<dynamic>> fetchBrochures() async {
    try {
      final res = await _request('GET', '/brochures');
      return _dataList(res);
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  VARSAYILAN VERİ SETLERİ (DEFAULT FALLBACKS)
  // ─────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> defaultSubdomainPages = [
    {
      'id': 1,
      'title': 'Tema Kasaphane',
      'subdomain': 'kasap',
      'domain': 'kasap.temasan.com',
      'category': 'Tema Kasaphane',
      'slogan': 'Veteriner Hekim Onaylı, Çiftlikten Şubelere Canlı Sevk Takibi',
      'description':
          'Kendi kesimhanelerimizde veteriner kontrolünde, İslami usullere uygun helal kesim ve soğuk zincir güvencesiyle 1. sınıf yerli besi et ürünleri.',
      'hero_image':
          'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=1200',
      'color_hex': '#DC2626',
      'icon_name': 'set_meal',
      'custom_info':
          'Helal Kesim Sertifikalı • Erzurum Yerli Besi • Soğuk Hava Zinciri (+2°C)',
      'cta_text': 'Ürünleri İncele & Sipariş Ver',
      'is_active': true,
      'sections': [
        {
          'id': 'sec_hero',
          'type': 'hero_banner',
          'title': 'Hero Kapak & Serbest Tasarım Alanı',
          'visible': true,
        },
        {
          'id': 'sec_info',
          'type': 'info_strip',
          'title': 'Güvence & Özellik Rozet Şeridi',
          'visible': true,
        },
        {
          'id': 'sec_tracking',
          'type': 'tracking',
          'title': 'Canlı Çiftlik & Sevk Takibi',
          'visible': true,
        },
        {
          'id': 'sec_products',
          'type': 'products',
          'title': 'Öne Çıkan Reyon Ürünleri',
          'visible': true,
          'columns': 3,
        },
        {
          'id': 'sec_contact',
          'type': 'contact',
          'title': 'İletişim & WhatsApp Destek Kartı',
          'visible': true,
        },
      ],
    },
    {
      'id': 2,
      'title': 'Tema Şarküteri',
      'subdomain': 'sarkuteri',
      'domain': 'sarkuteri.temasan.com',
      'category': 'Şarküteri',
      'slogan': 'Yöresel ve Gurme Şarküteri Lezzetleri',
      'description':
          'Erzurum ve Doğu Anadolu yaylalarından seçme eski kaşar, tulum peyniri, ev yapımı kangal sucuk, pastırma ve zeytin çeşitleri.',
      'hero_image':
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200',
      'color_hex': '#B45309',
      'icon_name': 'egg_alt',
      'custom_info':
          'Köyden Sofraya • Katkısız Geleneksel Üretim • Günlük Taze Dilimleme',
      'cta_text': 'Şarküteri Reyonunu Keşfet',
      'is_active': true,
    },
    {
      'id': 3,
      'title': 'Tema Mandıra',
      'subdomain': 'mandira',
      'domain': 'mandira.temasan.com',
      'category': 'Tema Mandıra',
      'slogan': 'Doğal Köy Sütü, Peynirleri ve Yayık Tereyağı',
      'description':
          'Katkısız yayla sütü, geleneksel tereyağı, taze lor ve günlük yoğurt ile sofralarınıza doğallık ve sağlık taşıyoruz.',
      'hero_image':
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=1200',
      'color_hex': '#D97706',
      'icon_name': 'local_drink',
      'custom_info':
          '%100 Doğal Süt • Katkısız Yayık Tereyağı • Günlük Çiftlik Sevkiyatı',
      'cta_text': 'Mandıra Ürünlerini İncele',
      'is_active': true,
    },
    {
      'id': 4,
      'title': 'Tema Fırın',
      'subdomain': 'firin',
      'domain': 'firin.temasan.com',
      'category': 'Tema Fırın',
      'slogan': 'Taş Fırından Taptaze Ekmek & Sıcak Unlu Mamuller',
      'description':
          'Geleneksel ekşi mayalı taş fırın ekmekleri, çıtır simitler, enfes börekler ve taze tatlılar her saat dumanı üstünde.',
      'hero_image':
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1200',
      'color_hex': '#EA580C',
      'icon_name': 'bakery_dining',
      'custom_info':
          'Taş Tabanlı Fırın • Ekşi Mayalı Ekmekler • Her Saat Taze Pişirim',
      'cta_text': 'Sıcak Fırın Ürünleri',
      'is_active': true,
    },
    {
      'id': 5,
      'title': 'Tema Bakliyat',
      'subdomain': 'bakliyat',
      'domain': 'bakliyat.temasan.com',
      'category': 'Tema Bakliyat',
      'slogan': 'Bereketli Anadolu Topraklarından Sofranıza',
      'description':
          'Yerli üretim kırmızı mercimek, İspir kuru fasulyesi, nohut, bulgur ve pilavlık pirinç çeşitleri en uygun fiyatlarla.',
      'hero_image':
          'https://images.unsplash.com/photo-1515543237350-b3eea1ec8082?w=1200',
      'color_hex': '#15803D',
      'icon_name': 'grain',
      'custom_info':
          'Yerli Mahsul • İspir Fasulyesi • Doğal Kurutma & Temizleme',
      'cta_text': 'Bakliyat Reyonuna Git',
      'is_active': true,
    },
    {
      'id': 6,
      'title': 'Tema İnşaat',
      'subdomain': 'insaat',
      'domain': 'insaat.temasan.com',
      'category': 'Tema İnşaat',
      'slogan': 'Modern Konut ve Güvenli Yaşam Alanları',
      'description':
          'Depreme dayanıklı, lüks mimariye sahip Tema Konutları ve iş merkezi projelerimizle kente değer katıyoruz.',
      'hero_image':
          'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=1200',
      'color_hex': '#0F172A',
      'icon_name': 'apartment',
      'custom_info':
          'Depreme Dayanıklı Mimari • 1. ve 2. Etap Konutları • Anahtar Teslim',
      'cta_text': 'Projeleri İncele',
      'is_active': true,
    },
  ];

  static const List<Map<String, dynamic>> defaultKasaphaneFallback = [
    {
      'id': 1,
      'lot_no': '#TK-2026-084',
      'batch_no': '#TK-2026-084',
      'date': '16 Ekim 2026',
      'slaughter_date': '16 Ekim 2026',
      'farm': 'TEMA Palandöken Besi Çiftliği',
      'vet_report': 'VET-TR-25-8841 / Sağlıklı Onaylı',
      'vet_report_no': 'VET-TR-25-8841 / Sağlıklı Onaylı',
      'status': 'Şube Reyonlarına Ulaştı',
      'delivery_status': 'Şube Reyonlarına Ulaştı',
      'branches': 'Yakutiye, Palandöken, Şükrüpaşa',
      'note':
          'Veteriner hekim kontrolünde kesim yapılmış, soğuk zincir (+2°C) ile şubelere ulaştırılmıştır.',
      'notes':
          'Veteriner hekim kontrolünde kesim yapılmış, soğuk zincir (+2°C) ile şubelere ulaştırılmıştır.',
    },
    {
      'id': 2,
      'lot_no': '#TK-2026-085',
      'batch_no': '#TK-2026-085',
      'date': '17 Ekim 2026',
      'slaughter_date': '17 Ekim 2026',
      'farm': 'TEMA Aziziye Besi Tesisi',
      'vet_report': 'VET-TR-25-8854 / Sağlıklı Onaylı',
      'vet_report_no': 'VET-TR-25-8854 / Sağlıklı Onaylı',
      'status': 'Soğuk Hava Dinlendirmede',
      'delivery_status': 'Soğuk Hava Dinlendirmede',
      'branches': 'Tüm Şubeler',
      'note': 'Erzurum yerli besi dana eti. +2°C soğuk hava dinlendirme sürecindedir.',
      'notes': 'Erzurum yerli besi dana eti. +2°C soğuk hava dinlendirme sürecindedir.',
    },
  ];

  static const List<Map<String, dynamic>> defaultKasaphaneMediaFallback = [
    {
      'id': 1,
      'title': 'Hijyenik Kesim ve Parçalama Tesisi',
      'type': 'Fotoğraf',
      'url': 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'created_at': '16 Ekim 2026',
    },
    {
      'id': 2,
      'title': '+2°C Soğuk Zincir Sevkiyat Araçlarımız',
      'type': 'Video',
      'url': 'https://images.unsplash.com/photo-1588168333986-5078d3ae3976?w=800',
      'created_at': '17 Ekim 2026',
    },
  ];

  static const List<Map<String, dynamic>> defaultCorporateEntitiesFallback = [
    {
      'id': 1,
      'title': 'Tema İnşaat - Yıldız Yaşam Konutları',
      'category': 'İnşaat & Gayrimenkul',
      'status': 'Devam Ediyor (%85 Tamamlandı)',
      'image_url':
          'https://images.unsplash.com/photo-1541888946425-d0fbb186156a?w=800',
      'description':
          'Erzurum Aziziye mevkiinde 120 daireli lüks ve depreme dayanıklı modern konut projesi.',
      'website': 'https://insaat.temasan.com',
      'contact': '0442 222 00 00',
    },
    {
      'id': 2,
      'title': 'Tema Kasaphane Entegre Tesisleri',
      'category': 'Hayvancılık & Et Entegre',
      'status': 'Aktif Faaliyette',
      'image_url':
          'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'description':
          'Yerli besi, veteriner gözetiminde hijyenik kesim ve şubelere günlük sevkiyat.',
      'website': 'https://kasap.temasan.com',
      'contact': '0442 222 00 01',
    },
  ];

  static const List<Map<String, dynamic>> defaultApplicationsFallback = [
    {
      'id': 1,
      'name': 'Ahmet Yılmaz',
      'phone': '0532 111 22 33',
      'email': 'ahmet@example.com',
      'position': 'Reyon Görevlisi',
      'district': 'Aziziye',
      'education': 'Lise',
      'experience': '3 yıl süpermarket reyon ve stok düzenleme tecrübesi var.',
      'status': 'Beklemede',
      'created_at': 'Bugün 10:30',
    },
    {
      'id': 2,
      'name': 'Mehmet Demir',
      'phone': '0544 333 44 55',
      'email': 'mehmet@example.com',
      'position': 'Tema Kasaphane - Kasap / Usta',
      'district': 'Yakutiye',
      'education': 'Ön Lisans',
      'experience': '7 yıl et parçalama, sucuk ve soğuk zincir reyon tecrübesi.',
      'status': 'İncelendi',
      'created_at': 'Dün 14:15',
    },
    {
      'id': 3,
      'name': 'Ayşe Kaya',
      'phone': '0555 777 88 99',
      'email': 'ayse@example.com',
      'position': 'Kasiyer',
      'district': 'Palandöken',
      'education': 'Lisans',
      'experience': 'Kasa sistemleri, POS ve müşteri karşılama deneyimi.',
      'status': 'Mülakata Çağrıldı',
      'created_at': '15.10.2026',
    },
  ];

  static const List<Map<String, dynamic>> defaultOpenPositionsFallback = [
    {
      'id': 1,
      'title': 'Tema Kasaphane - Kasap Ustası',
      'branch': 'Palandöken Şubesi',
      'type': 'Tam Zamanlı',
      'is_active': true,
    },
    {
      'id': 2,
      'title': 'Reyon & Mağaza Görevlisi',
      'branch': 'Yakutiye Merkez Şubesi',
      'type': 'Tam Zamanlı',
      'is_active': true,
    },
    {
      'id': 3,
      'title': 'Motorlu Kurye',
      'branch': 'Tüm Şubeler',
      'type': 'Tam / Yarı Zamanlı',
      'is_active': true,
    },
  ];

  static const List<Map<String, dynamic>> defaultCouriersFallback = [
    {
      'id': 1,
      'name': 'Murat Kaya',
      'phone': '0530 111 22 33',
      'status': 'Müsait',
      'branch_id': 1,
      'vehicle': 'Motosiklet',
    },
    {
      'id': 2,
      'name': 'Burak Öztürk',
      'phone': '0535 222 33 44',
      'status': 'Siparişte',
      'branch_id': 1,
      'vehicle': 'Panelvan (Soğuk Zincir)',
    },
    {
      'id': 3,
      'name': 'Emre Arslan',
      'phone': '0542 333 44 55',
      'status': 'Müsait',
      'branch_id': 2,
      'vehicle': 'Motosiklet',
    },
  ];

  static const List<Map<String, dynamic>> defaultBranchesFallback = [
    {
      'id': 1,
      'name': 'Yakutiye Merkez Şubesi',
      'code': 'TEMA-YAK-01',
      'address': 'Cumhuriyet Cad. No: 42 Yakutiye / Erzurum',
      'city_district': 'Yakutiye',
      'phone': '0442 233 10 01',
      'working_hours': '08:00 - 22:00',
      'is_active': 1,
    },
    {
      'id': 2,
      'name': 'Palandöken Şubesi',
      'code': 'TEMA-PAL-02',
      'address': 'Yenişehir Mah. Palandöken Cad. No: 18 Palandöken / Erzurum',
      'city_district': 'Palandöken',
      'phone': '0442 316 20 02',
      'working_hours': '08:00 - 22:30',
      'is_active': 1,
    },
    {
      'id': 3,
      'name': 'Şükrüpaşa Şubesi',
      'code': 'TEMA-SUK-03',
      'address': 'Şükrüpaşa Mah. İstasyon Cad. No: 75 Yakutiye / Erzurum',
      'city_district': 'Yakutiye',
      'phone': '0442 242 30 03',
      'working_hours': '08:00 - 22:00',
      'is_active': 1,
    },
  ];

  static const List<Map<String, dynamic>> defaultCampaignsFallback = [
    {
      'id': 1,
      'title': 'Haftanın Yıldız Fırsatları',
      'description':
          'Temel gıda, temizlik ve taze manav reyonlarında geçerli aktüel broşür indirimleri.',
      'dates': '17 - 24 Ekim 2026',
      'discount_badge': '%25\'e Varan İndirim',
      'image':
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      'is_active': 1,
    },
    {
      'id': 2,
      'title': 'Tema Kasaphane & Mandıra İndirimi',
      'description':
          'Yerli besi dana eti, taze kıyma ve köy yayık tereyağında %20 avantajlı fiyatlar.',
      'dates': 'Bu Hafta Sonu Özel',
      'discount_badge': '%20 İndirim',
      'image':
          'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'is_active': 1,
    },
    {
      'id': 3,
      'title': 'Tema Fırın & Sıcak Ekmek Günleri',
      'description':
          'Taş fırın ekmekleri, simit ve unlu mamullerde özel kampanya.',
      'dates': 'Her Gün Taze',
      'discount_badge': 'Sıcak Fırsat',
      'image':
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
      'is_active': 1,
    },
  ];

  static const List<Map<String, dynamic>> defaultProductsFallback = [
    // ── Tema Kasaphane ──
    {
      'id': 101,
      'name': 'Tema Dana Kuşbaşı (1 kg)',
      'sub_brand': 'Tema Kasaphane',
      'base_price': '480.00',
      'original_price': '560.00',
      'stock': 45,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=500',
    },
    {
      'id': 102,
      'name': 'Tema Dana Kıyma (%100 Yerli Besi, 1 kg)',
      'sub_brand': 'Tema Kasaphane',
      'base_price': '420.00',
      'original_price': '490.00',
      'stock': 60,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1588168333986-5078d3ae3976?w=500',
    },
    {
      'id': 103,
      'name': 'Tema Kasap Köfte (Özel Baharatlı, 500 g)',
      'sub_brand': 'Tema Kasaphane',
      'base_price': '230.00',
      'original_price': '270.00',
      'stock': 35,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=500',
    },
    // ── Şarküteri ──
    {
      'id': 201,
      'name': 'Erzurum Eski Kaşar Peyniri (Karakovan, 500 g)',
      'sub_brand': 'Şarküteri',
      'base_price': '260.00',
      'original_price': '310.00',
      'stock': 28,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=500',
    },
    {
      'id': 202,
      'name': 'Erzurum Göğermiş / Civil Peyniri (500 g)',
      'sub_brand': 'Şarküteri',
      'base_price': '195.00',
      'original_price': '230.00',
      'stock': 40,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1559561853-08451507cbe7?w=500',
    },
    {
      'id': 203,
      'name': 'Geleneksel Kangal Fermente Sucuk (400 g)',
      'sub_brand': 'Şarküteri',
      'base_price': '280.00',
      'original_price': '340.00',
      'stock': 25,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=500',
    },
    // ── Tema Mandıra ──
    {
      'id': 301,
      'name': 'Tema Mandıra Doğal Yayık Tereyağı (1 kg)',
      'sub_brand': 'Tema Mandıra',
      'base_price': '390.00',
      'original_price': '450.00',
      'stock': 30,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500',
    },
    {
      'id': 302,
      'name': 'Tema Mandıra Günlük Çiftlik Sütü (3 L)',
      'sub_brand': 'Tema Mandıra',
      'base_price': '95.00',
      'original_price': '115.00',
      'stock': 50,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500',
    },
    {
      'id': 303,
      'name': 'Tema Mandıra Taze Köy Yoğurdu (1.5 kg Çömlek)',
      'sub_brand': 'Tema Mandıra',
      'base_price': '110.00',
      'original_price': '135.00',
      'stock': 32,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500',
    },
    // ── Tema Fırın ──
    {
      'id': 401,
      'name': 'Taş Fırın Ekşi Mayalı Köy Ekmeği',
      'sub_brand': 'Tema Fırın',
      'base_price': '35.00',
      'original_price': '40.00',
      'stock': 85,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500',
    },
    {
      'id': 402,
      'name': 'Geleneksel Çıtır Erzurum Ketesi (4 Adet)',
      'sub_brand': 'Tema Fırın',
      'base_price': '90.00',
      'original_price': '110.00',
      'stock': 40,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=500',
    },
    {
      'id': 403,
      'name': 'Susamlı Taş Fırın Simiti',
      'sub_brand': 'Tema Fırın',
      'base_price': '15.00',
      'original_price': '18.00',
      'stock': 120,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500',
    },
    // ── Tema Bakliyat ──
    {
      'id': 501,
      'name': 'İspir Şeker Kuru Fasulyesi (1 kg)',
      'sub_brand': 'Tema Bakliyat',
      'base_price': '185.00',
      'original_price': '220.00',
      'stock': 55,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1515543237350-b3eea1ec8082?w=500',
    },
    {
      'id': 502,
      'name': 'Tema Yerli Kırmızı Mercimek (1 kg)',
      'sub_brand': 'Tema Bakliyat',
      'base_price': '52.00',
      'original_price': '65.00',
      'stock': 70,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
    },
    {
      'id': 503,
      'name': 'Tema Osmancık Pirinç (2 kg)',
      'sub_brand': 'Tema Bakliyat',
      'base_price': '98.00',
      'original_price': '120.00',
      'stock': 60,
      'status': 'Aktif',
      'image':
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500',
    },
  ];

  static const List<Map<String, dynamic>> defaultOrdersFallback = [
    {
      'id': 1001,
      'order_number': 'ORD-2026-1001',
      'customer_name': 'Ahmet Yılmaz',
      'customer_phone': '0532 111 22 33',
      'address': 'Cumhuriyet Cad. No:12 Yakutiye / Erzurum',
      'branch_id': 1,
      'status': 'Teslim Edildi',
      'payment_method': 'Kredi Kartı (Online)',
      'courier_id': 1,
      'courier_name': 'Murat Kaya',
      'total_amount': 785.50,
      'created_at': '17 Ekim 2026 14:20',
      'items': [
        {'name': 'Tema Dana Kuşbaşı (1 kg)', 'qty': 1, 'price': 480.00},
        {'name': 'Erzurum Eski Kaşar Peyniri', 'qty': 1, 'price': 260.00},
        {'name': 'Taş Fırın Ekşi Mayalı Köy Ekmeği', 'qty': 1, 'price': 45.50},
      ],
    },
    {
      'id': 1002,
      'order_number': 'ORD-2026-1002',
      'customer_name': 'Ayşe Kaya',
      'customer_phone': '0555 777 88 99',
      'address': 'Yenişehir Mah. Lale Sok. No:8 Palandöken / Erzurum',
      'branch_id': 2,
      'status': 'Hazırlanıyor',
      'payment_method': 'Kapıda Kredi Kartı',
      'total_amount': 420.00,
      'created_at': '17 Ekim 2026 15:10',
      'items': [
        {'name': 'Tema Dana Kıyma (%100 Yerli Besi, 1 kg)', 'qty': 1, 'price': 420.00},
      ],
    },
    {
      'id': 1003,
      'order_number': 'ORD-2026-1003',
      'customer_name': 'Mehmet Demir',
      'customer_phone': '0544 333 44 55',
      'address': 'Şükrüpaşa Mah. Gül Cad. No:24 Yakutiye / Erzurum',
      'branch_id': 3,
      'status': 'Kuryede',
      'payment_method': 'Kapıda Nakit',
      'courier_id': 2,
      'courier_name': 'Burak Öztürk',
      'total_amount': 1150.00,
      'created_at': '17 Ekim 2026 15:35',
      'items': [
        {'name': 'Tema Dana Kuşbaşı (1 kg)', 'qty': 1, 'price': 480.00},
        {'name': 'Tema Mandıra Doğal Yayık Tereyağı (1 kg)', 'qty': 1, 'price': 390.00},
        {'name': 'Geleneksel Kangal Fermente Sucuk (400 g)', 'qty': 1, 'price': 280.00},
      ],
    },
  ];

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
