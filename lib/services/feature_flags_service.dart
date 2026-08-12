import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

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
    this.sanalMarket    = true,
    this.bayiStok       = true,
    this.temapuan       = true,
    this.apiEntegrasyon = true,
    this.smsGonderim    = true,
    this.kampanyalar    = true,
    this.sanalPos       = true,
    this.softPos        = true,
    this.eFatura        = true,
    this.serbestKurye   = true,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      sanalMarket:    json['sanal_market']    ?? json['sanalMarket']    ?? true,
      bayiStok:       json['bayi_stok']       ?? json['bayiStok']       ?? true,
      temapuan:       json['temapuan']                                  ?? true,
      apiEntegrasyon: json['api_entegrasyon'] ?? json['apiEntegrasyon'] ?? true,
      smsGonderim:    json['sms_gonderim']    ?? json['smsGonderim']    ?? true,
      kampanyalar:    json['kampanyalar']                               ?? true,
      sanalPos:       json['sanal_pos']       ?? json['sanalPos']       ?? true,
      softPos:        json['soft_pos']        ?? json['softPos']        ?? true,
      eFatura:        json['e_fatura']        ?? json['eFatura']        ?? true,
      serbestKurye:   json['serbest_kurye']   ?? json['serbestKurye']   ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'sanal_market':    sanalMarket,
    'bayi_stok':       bayiStok,
    'temapuan':        temapuan,
    'api_entegrasyon': apiEntegrasyon,
    'sms_gonderim':    smsGonderim,
    'kampanyalar':     kampanyalar,
    'sanal_pos':       sanalPos,
    'soft_pos':        softPos,
    'e_fatura':        eFatura,
    'serbest_kurye':   serbestKurye,
  };

  /// İki flag set'ini karşılaştır (gereksiz setState'i önler)
  bool isIdenticalTo(FeatureFlags other) =>
      sanalMarket    == other.sanalMarket    &&
      bayiStok       == other.bayiStok       &&
      temapuan       == other.temapuan       &&
      apiEntegrasyon == other.apiEntegrasyon &&
      smsGonderim    == other.smsGonderim    &&
      kampanyalar    == other.kampanyalar    &&
      sanalPos       == other.sanalPos       &&
      softPos        == other.softPos        &&
      eFatura        == other.eFatura        &&
      serbestKurye   == other.serbestKurye;
}

class FeatureFlagsService {
  static FeatureFlags _current = const FeatureFlags();

  /// Arka arkaya kaç kez sunucuya ulaşılamadı
  static int _offlineCount = 0;

  /// Sunucu müsait değilken polling aralığını uzatır (backoff)
  /// 0-2 hata: 2sn, 3-5 hata: 10sn, 6+ hata: 30sn
  static Duration get recommendedPollInterval {
    if (_offlineCount <= 2) return const Duration(seconds: 2);
    if (_offlineCount <= 5) return const Duration(seconds: 10);
    return const Duration(seconds: 30);
  }

  static FeatureFlags get current => _current;

  /// Flag'leri yükle.
  /// Sunucuya ulaşılamazsa → önbellekteki değeri döndür (uygulama çalışmaya devam eder).
  static Future<FeatureFlags> loadFlags() async {
    try {
      final remoteFlagsMap = await ApiService.fetchFeatureFlags();
      if (remoteFlagsMap != null) {
        final newFlags = FeatureFlags.fromJson(remoteFlagsMap);
        _offlineCount = 0; // bağlantı sağlandı
        // Değer değişmişse kaydet, aynıysa gereksiz disk yazımını atla
        if (!newFlags.isIdenticalTo(_current)) {
          _current = newFlags;
          await saveFlags(_current);
        }
        return _current;
      }
    } catch (_) {
      // ApiService zaten kendi içinde handle ediyor
    }

    // Sunucuya ulaşılamadı
    _offlineCount++;

    // Önbellekten yükle (ilk açılışta)
    if (_offlineCount == 1) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('temasan_feature_flags');
        if (saved != null) {
          _current = FeatureFlags.fromJson(json.decode(saved));
        }
      } catch (_) {}
    }

    return _current;
  }

  static Future<void> saveFlags(FeatureFlags flags) async {
    _current = flags;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'temasan_feature_flags',
        json.encode(flags.toJson()),
      );
    } catch (_) {}
  }
}
