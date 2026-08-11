import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://temasanalmarket.com/api';

  static Future<List<dynamic>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
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

  static Future<List<dynamic>> fetchCampaigns() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/campaigns'));
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
