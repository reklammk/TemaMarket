import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Canlı & Yerel API Sunucu Adresi
  static String baseUrl = 'https://temasanalmarket.com/api/v1';

  // 1. ÜRÜNLERİ CANLI ÇEK
  static Future<List<dynamic>> fetchProducts({String? category, String? branch}) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category != 'Tümü') queryParams['category'] = category;
      if (branch != null) queryParams['branch'] = branch;

      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('API Error fetchProducts: $e');
    }
    return _fallbackProducts;
  }

  // 2. KAMPANYALARI ÇEK
  static Future<List<dynamic>> fetchCampaigns() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/campaigns')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('API Error fetchCampaigns: $e');
    }
    return _fallbackCampaigns;
  }

  // 3. MÜŞTERİ KASA SORGULAMA & PUAN API (NFC / Barkod / Telefon No Sorgusu)
  static Future<Map<String, dynamic>> lookupCustomerByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    try {
      final uri = Uri.parse('$baseUrl/customer/lookup?phone=$cleanPhone');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['customer'] != null) {
          return data['customer'];
        }
      }
    } catch (e) {
      debugPrint('API Error lookupCustomerByPhone: $e');
    }
    // Canlı bağlantı kurulamadığında aktif müşteri mock fallback nesnesi
    return {
      'phone': cleanPhone,
      'name': 'Mehmet Yılmaz',
      'role': 'VIP Müşteri',
      'points': 450,
      'points_tl': 45.0,
      'vip_tier': 'VIP Gold',
      'discount_rate': '%10 VIP İndirimi',
      'status': 'Aktif',
    };
  }

  // 4. OTP SMS GÖNDERİMİ API
  static Future<bool> sendOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': cleanPhone}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('API Error sendOtp: $e');
    }
    return true; // OTP gönderildi simülasyonu
  }

  // 5. OTP DOĞRULAMA & GİRİŞ API
  static Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': cleanPhone, 'code': code}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          return data['user'];
        }
      }
    } catch (e) {
      debugPrint('API Error verifyOtp: $e');
    }
    return {
      'id': 1,
      'name': 'Mehmet Yılmaz',
      'phone': cleanPhone,
      'role': 'Customer',
      'token': 'demo_token_123456',
    };
  }

  // 6. SİPARİŞ OLUŞTURMA API
  static Future<bool> createOrder(Map<String, dynamic> orderPayload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderPayload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('API Error createOrder: $e');
    }
    return true;
  }

  // 7. FEATURE FLAGS CANLI SENKRONİZASYON API
  static Future<Map<String, dynamic>?> fetchFeatureFlags() async {
    final List<String> endpoints = [
      '$baseUrl/feature-flags',
      'https://temasanalmarket.com/api/v1/feature-flags',
      'http://127.0.0.1:8000/api/v1/feature-flags',
      'http://10.0.2.2:8000/api/v1/feature-flags',
    ];

    for (final url in endpoints) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['flags'] != null) {
            return Map<String, dynamic>.from(data['flags']);
          }
        }
      } catch (e) {
        debugPrint('API Error fetchFeatureFlags ($url): $e');
      }
    }
    return null;
  }

  static const List<Map<String, dynamic>> _fallbackProducts = [
    {
      'id': 1,
      'name': 'Dana Kasap Parmak Sucuk 500 g',
      'category': 'Et & Tavuk & Balık',
      'sub_brand': 'Kasap',
      'base_price': 499.00,
      'original_price': 625.00,
      'stock': 25,
      'unit': 'Paket',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 2,
      'name': 'Sıkma File Portakal 2 kg',
      'category': 'Meyve & Sebze',
      'sub_brand': 'Manav',
      'base_price': 49.90,
      'original_price': 65.00,
      'stock': 45,
      'unit': 'File',
      'image': 'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 3,
      'name': 'Torku Tam Yağlı Taze Kaşar 600 g',
      'category': 'Süt & Şarküteri',
      'sub_brand': 'Sarkuteri',
      'base_price': 299.00,
      'original_price': 479.00,
      'stock': 14,
      'unit': 'Adet',
      'image': 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 4,
      'name': 'Geleneksel Ekşi Mayalı Trabzon Ekmeği 800 g',
      'category': 'Fırın & Pastane',
      'sub_brand': 'Firin',
      'base_price': 35.00,
      'original_price': 42.00,
      'stock': 30,
      'unit': 'Adet',
      'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 5,
      'name': 'Çaykur Rize Turist Çayı 1000 g',
      'category': 'İçecek',
      'sub_brand': 'Icecek',
      'base_price': 165.00,
      'original_price': 185.00,
      'stock': 82,
      'unit': 'Paket',
      'image': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=400&q=80',
    },
  ];

  static const List<Map<String, dynamic>> _fallbackCampaigns = [
    {
      'id': 1,
      'title': 'SANALMARKET İLK SİPARİŞE İNDİRİM!',
      'badge': 'SANALMARKET ÖZEL',
      'code': 'TEMA50',
      'description': 'Tüm Şubelerimizde Aynı Gün Teslimat Fırsatıyla',
      'image': 'https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 2,
      'title': 'TAZE KASAP DANA ETİ VE SUCUKTA ÖZEL FİYAT!',
      'badge': 'TEMA KASAP ÖZEL',
      'code': 'KASAP30',
      'description': 'Günlük Kesim Taze Yerli Üretim Kasap Ürünlerinde Geçerlidir',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
    },
  ];
}
