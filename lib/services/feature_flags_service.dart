import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlags {
  final bool sanalMarket;
  final bool bayiStok;
  final bool temapuan;
  final bool apiEntegrasyon;
  final bool smsGonderim;
  final bool kampanyalar;
  final bool sanalPos;
  final bool softPos;
  final bool eFatura;
  final bool serbestKurye;

  const FeatureFlags({
    this.sanalMarket = true,
    this.bayiStok = true,
    this.temapuan = true,
    this.apiEntegrasyon = true,
    this.smsGonderim = true,
    this.kampanyalar = true,
    this.sanalPos = true,
    this.softPos = true,
    this.eFatura = true,
    this.serbestKurye = true,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      sanalMarket: json['sanal_market'] ?? true,
      bayiStok: json['bayi_stok'] ?? true,
      temapuan: json['temapuan'] ?? true,
      apiEntegrasyon: json['api_entegrasyon'] ?? true,
      smsGonderim: json['sms_gonderim'] ?? true,
      kampanyalar: json['kampanyalar'] ?? true,
      sanalPos: json['sanal_pos'] ?? true,
      softPos: json['soft_pos'] ?? true,
      eFatura: json['e_fatura'] ?? true,
      serbestKurye: json['serbest_kurye'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sanal_market': sanalMarket,
      'bayi_stok': bayiStok,
      'temapuan': temapuan,
      'api_entegrasyon': apiEntegrasyon,
      'sms_gonderim': smsGonderim,
      'kampanyalar': kampanyalar,
      'sanal_pos': sanalPos,
      'soft_pos': softPos,
      'e_fatura': eFatura,
      'serbest_kurye': serbestKurye,
    };
  }
}

class FeatureFlagsService {
  static FeatureFlags _current = const FeatureFlags();

  static FeatureFlags get current => _current;

  static Future<FeatureFlags> loadFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('temasan_feature_flags');
      if (saved != null) {
        _current = FeatureFlags.fromJson(json.decode(saved));
      }
    } catch (_) {}
    return _current;
  }

  static Future<void> saveFlags(FeatureFlags flags) async {
    _current = flags;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temasan_feature_flags', json.encode(flags.toJson()));
    } catch (_) {}
  }
}
