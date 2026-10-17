import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';
import 'subdomain_landing_page.dart';

/// Yönetici ekranında yalnızca API ile gerçekten desteklenen modüller bulunur.
/// Sabit KPI, örnek veri ve boş modül sekmeleri gösterilmez.
class AdminDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const AdminDashboardPage({super.key, this.user, this.onBackToStore});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _subdomainPages = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _kasaphaneRecords = [];
  List<Map<String, dynamic>> _corporateEntities = [];
  FeatureFlags _flags = const FeatureFlags();
  Map<String, dynamic> _capabilities = {};
  final Set<String> _savingFlags = {};

  static final List<Map<String, dynamic>> _defaultApplications = [
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

  static final List<Map<String, dynamic>> _defaultKasaphaneRecords = [
    {
      'id': 1,
      'lot_no': 'TK-2026/GZ-01',
      'date': '17.10.2026',
      'farm': 'TEMA Palandöken Besi Çiftliği',
      'vet_report': 'TR-25-0042 / Sağlıklı Onaylı',
      'status': 'Şube Reyonlarına Ulaştı',
      'branches': 'Palandöken, Yakutiye, Aziziye Şubeleri',
      'note': 'Veteriner kontrolünde helal kesim yapıldı, soğuk zincirle reyonlara sevk edildi.',
    },
    {
      'id': 2,
      'lot_no': 'TK-2026/GZ-02',
      'date': '16.10.2026',
      'farm': 'TEMA Aziziye Besi Tesisi',
      'vet_report': 'TR-25-0039 / Sağlıklı Onaylı',
      'status': 'Soğuk Hava Dinlendirmede',
      'branches': 'Merkez ve Yıldız Şubeleri',
      'note': '+2°C soğuk hava deposunda dinlendirilmektedir.',
    },
  ];

  static final List<Map<String, dynamic>> _defaultCorporateEntities = [
    {
      'id': 1,
      'title': 'Tema İnşaat - Yıldız Yaşam Konutları',
      'category': 'İnşaat & Gayrimenkul',
      'status': 'Devam Ediyor (%85 Tamamlandı)',
      'image_url': 'https://images.unsplash.com/photo-1541888946425-d0fbb186156a?w=800',
      'description': 'Erzurum Aziziye mevkiinde 120 daireli lüks ve depreme dayanıklı modern konut projesi.',
      'website': 'https://temamarket.com/insaat',
      'contact': '0442 222 00 00',
    },
    {
      'id': 2,
      'title': 'Tema Kasaphane Entegre Tesisleri',
      'category': 'Hayvancılık & Et Entegre',
      'status': 'Aktif Faaliyette',
      'image_url': 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'description': 'Yerli besi, veteriner gözetiminde hijyenik kesim ve şubelere günlük sevkiyat.',
      'website': 'https://temamarket.com/kasaphane',
      'contact': '0442 222 00 01',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 10, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(List<dynamic> values) => values
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.fetchDashboardMetrics(),
        ApiService.fetchBranches(),
        ApiService.fetchOrders(),
        ApiService.fetchProducts(),
        ApiService.fetchCampaigns(),
        ApiService.fetchFeatureConfiguration(),
        ApiService.fetchJobApplications(),
        ApiService.fetchKasaphaneTracking(),
        ApiService.fetchCorporateEntities(),
        ApiService.fetchSubdomainPages(),
      ]);
      if (!mounted) return;
      final configuration = Map<String, dynamic>.from(results[5] as Map);
      final rawFlags = configuration['flags'];
      final fetchedApps = _maps(results[6] as List<dynamic>);
      final fetchedKasap = _maps(results[7] as List<dynamic>);
      final fetchedCorps = _maps(results[8] as List<dynamic>);
      final fetchedSubs = _maps(results[9] as List<dynamic>);

      setState(() {
        _metrics = Map<String, dynamic>.from(results[0] as Map);
        _branches = _maps(results[1] as List<dynamic>);
        _orders = _maps(results[2] as List<dynamic>);
        _products = _maps(results[3] as List<dynamic>);
        _campaigns = _maps(results[4] as List<dynamic>);
        _applications = fetchedApps.isNotEmpty ? fetchedApps : List.from(_defaultApplications);
        _kasaphaneRecords = fetchedKasap.isNotEmpty ? fetchedKasap : List.from(_defaultKasaphaneRecords);
        _corporateEntities = fetchedCorps.isNotEmpty ? fetchedCorps : List.from(_defaultCorporateEntities);
        _subdomainPages = fetchedSubs.isNotEmpty ? fetchedSubs : List.from(ApiService.defaultSubdomainPages);
        _flags = FeatureFlags.fromJson(
          rawFlags is Map ? Map<String, dynamic>.from(rawFlags) : const {},
        );
        _capabilities = configuration['capabilities'] is Map
            ? Map<String, dynamic>.from(configuration['capabilities'] as Map)
            : {};
      });
      await FeatureFlagsService.saveFlags(_flags);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFlag(String key, bool value) async {
    if (_savingFlags.contains(key)) return;
    if (value && !_featureAvailable(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_featureReason(key))),
      );
      return;
    }
    final oldFlags = _flags;
    final updated = {...oldFlags.toJson(), key: value};
    setState(() {
      _flags = FeatureFlags.fromJson(updated);
      _savingFlags.add(key);
    });
    try {
      final configuration = await ApiService.saveFeatureFlags(updated);
      final savedFlags = configuration['flags'];
      final serverFlags = FeatureFlags.fromJson(
        savedFlags is Map ? Map<String, dynamic>.from(savedFlags) : updated,
      );
      if (!mounted) return;
      setState(() {
        _flags = serverFlags;
        if (configuration['capabilities'] is Map) {
          _capabilities =
              Map<String, dynamic>.from(configuration['capabilities'] as Map);
        }
      });
      await FeatureFlagsService.saveFlags(serverFlags);
    } catch (error) {
      if (!mounted) return;
      setState(() => _flags = oldFlags);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _savingFlags.remove(key));
    }
  }

  bool _featureAvailable(String key) {
    final capability = _capabilities[key];
    return capability is Map && capability['available'] == true;
  }

  String _featureReason(String key) {
    final capability = _capabilities[key];
    if (capability is Map) {
      return capability['reason']?.toString() ??
          'Sunucu yetenek bilgisi alınamadı.';
    }
    return 'Sunucu yetenek bilgisi alınamadı.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user?['role']?.toString() != 'SuperAdmin') {
      return const Scaffold(
        body: Center(
            child: Text('Bu sayfaya yalnızca yönetici hesabı erişebilir.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('temamarket.com Yönetim Paneli',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Verileri yenile',
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
          if (widget.onBackToStore != null)
            IconButton(
              tooltip: 'Mağazaya dön',
              onPressed: widget.onBackToStore,
              icon: const Icon(Icons.storefront_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Özet'),
            Tab(icon: Icon(Icons.store_outlined), text: 'Şubeler'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Siparişler'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Ürünler'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Kampanyalar'),
            Tab(icon: Icon(Icons.language_outlined), text: 'Subdomain & Sayfalar'),
            Tab(icon: Icon(Icons.work_outline), text: 'İş Başvuruları'),
            Tab(icon: Icon(Icons.verified_outlined), text: 'Tema Kasaphane'),
            Tab(icon: Icon(Icons.apartment_outlined), text: 'Tema İnşaat & Grup'),
            Tab(icon: Icon(Icons.tune), text: 'Özellikler'),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _metrics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _metrics.isEmpty) {
      return _AdminEmpty(message: _error!, onRetry: _loadData);
    }
    return TabBarView(
      controller: _tabs,
      children: [
        _overview(),
        _branchList(),
        _orderList(),
        _productList(),
        _campaignList(),
        _subdomainList(),
        _applicationList(),
        _kasaphaneList(),
        _corporateList(),
        _featureList(),
      ],
    );
  }

  Widget _overview() {
    final cards = [
      ('Kullanıcılar', _metrics['total_users'], Icons.people_outline),
      (
        'Bekleyen Başvurular',
        _metrics['pending_applications'],
        Icons.pending_actions_outlined
      ),
      ('Siparişler', _metrics['total_orders'], Icons.receipt_long_outlined),
      (
        'Aktif Kuryeler',
        _metrics['active_couriers'],
        Icons.delivery_dining_outlined
      ),
    ];
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: 235,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(card.$3,
                                size: 34, color: const Color(0xFFDC2626)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(card.$1,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                  Text(
                                    '${card.$2 ?? 0}',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Toplam sipariş tutarı'),
              trailing: Text(
                '₺${_asDouble(_metrics['total_revenue']).toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Son yenileme hatası: $_error',
                  style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _branchList() => _listOrEmpty(
        _branches,
        'Aktif şube bulunmuyor.',
        (branch) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
          title: Text(branch['name']?.toString() ?? 'Şube'),
          subtitle: Text(branch['address']?.toString() ??
              branch['city_district']?.toString() ??
              '-'),
          trailing: Text(branch['code']?.toString() ?? '#${branch['id']}'),
        ),
      );

  Widget _orderList() => _listOrEmpty(
        _orders,
        'Sipariş bulunmuyor.',
        (order) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
          title: Text(
              order['order_number']?.toString() ?? 'Sipariş #${order['id']}'),
          subtitle: Text(
              '${order['customer_name'] ?? '-'} • ${order['status'] ?? '-'}'),
          trailing:
              Text('₺${_asDouble(order['total_amount']).toStringAsFixed(2)}'),
        ),
      );

  Widget _productList() => _listOrEmpty(
        _products,
        'Ürün bulunmuyor.',
        (product) => ListTile(
          leading: CircleAvatar(child: Text('${_asInt(product['stock'])}')),
          title: Text(product['name']?.toString() ?? 'Ürün'),
          subtitle: Text(
              '${product['sub_brand'] ?? '-'} • ${product['status'] ?? '-'}'),
          trailing:
              Text('₺${_asDouble(product['base_price']).toStringAsFixed(2)}'),
        ),
      );

  Widget _campaignList() => _listOrEmpty(
        _campaigns,
        'Yayında kampanya bulunmuyor.',
        (campaign) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
          title: Text(campaign['title']?.toString() ?? 'Kampanya'),
          subtitle: Text(campaign['description']?.toString() ?? ''),
          trailing:
              Text(campaign['is_active'].toString() == '1' ? 'Aktif' : 'Pasif'),
        ),
      );

  // ─────────────────────────────────────────────────────────────
  //  ÖZEL SUBDOMAIN & SAYFA YÖNETİMİ (kasap.temamarket.com vb.)
  // ─────────────────────────────────────────────────────────────
  Widget _subdomainList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link),
        label: const Text('Yeni Subdomain Sayfası Oluştur'),
        onPressed: () => _showSubdomainDialog(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.public, color: Colors.amber, size: 38),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Özel Subdomain Sayfa Yönetimi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kasap, şarküteri, mandıra, fırın, inşaat gibi özel sayfaları yönetebilir; belirleyeceğiniz subdomain üzerinde (örn: kasap.temamarket.com) anında yayına alabilirsiniz.',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_subdomainPages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Henüz oluşturulmuş subdomain sayfası bulunmuyor.'),
                ),
              )
            else
              ..._subdomainPages.map((page) {
                final id = _asInt(page['id']);
                final title = page['title']?.toString() ?? 'Sayfa';
                final sub = page['subdomain']?.toString() ?? '';
                final domain = page['domain']?.toString() ?? '$sub.temamarket.com';
                final category = page['category']?.toString() ?? '-';
                final slogan = page['slogan']?.toString() ?? '';
                final isActive = page['is_active'] != false;
                final colorHex = page['color_hex']?.toString() ?? '#DC2626';

                Color brandColor;
                try {
                  brandColor = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
                } catch (_) {
                  brandColor = const Color(0xFFDC2626);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: brandColor.withValues(alpha: 0.15),
                              radius: 20,
                              child: Icon(Icons.language, color: brandColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isActive ? 'Yayında' : 'Taslak',
                                          style: TextStyle(
                                            color: isActive ? const Color(0xFF166534) : Colors.grey,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _openSubdomainPreview(page),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: brandColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '🌐 https://$domain',
                                        style: TextStyle(
                                          color: brandColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (slogan.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            slogan,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Bağlı Reyon/Kategori: $category',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              label: const Text('Sayfayı Önizle'),
                              onPressed: () => _openSubdomainPreview(page),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Düzenle',
                              onPressed: () => _showSubdomainDialog(page),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Sil',
                              onPressed: () => _confirmDeleteSubdomain(id, title),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }

  void _showSubdomainDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title']?.toString() ?? '');
    final subCtrl = TextEditingController(text: existing?['subdomain']?.toString() ?? '');
    final catCtrl = TextEditingController(text: existing?['category']?.toString() ?? 'Tema Kasaphane');
    final sloganCtrl = TextEditingController(text: existing?['slogan']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final heroCtrl = TextEditingController(text: existing?['hero_image']?.toString() ?? '');
    final colorCtrl = TextEditingController(text: existing?['color_hex']?.toString() ?? '#DC2626');
    final customInfoCtrl = TextEditingController(text: existing?['custom_info']?.toString() ?? '');
    bool isActive = existing?['is_active'] != false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            isEdit ? 'Subdomain Sayfasını Düzenle' : 'Yeni Subdomain Sayfası Oluştur',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sayfa Başlığı *',
                      hintText: 'Örn: Tema Kasaphane veya Tema Şarküteri',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subdomain Adı *',
                      hintText: 'Örn: kasap, sarkuteri, mandira',
                      helperText: 'Sonuç: ${subCtrl.text.trim().isEmpty ? '...' : subCtrl.text.trim().toLowerCase()}.temamarket.com',
                      prefixText: 'https://',
                      suffixText: '.temamarket.com',
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: [
                      'Tema Kasaphane',
                      'Şarküteri',
                      'Tema Mandıra',
                      'Tema Fırın',
                      'Tema Bakliyat',
                      'Tema İnşaat',
                      'Manav',
                      'Temel Gıda',
                    ].contains(catCtrl.text)
                        ? catCtrl.text
                        : 'Tema Kasaphane',
                    decoration: const InputDecoration(labelText: 'Eşleşen Kategori / Reyon'),
                    items: const [
                      DropdownMenuItem(value: 'Tema Kasaphane', child: Text('Tema Kasaphane')),
                      DropdownMenuItem(value: 'Şarküteri', child: Text('Tema Şarküteri')),
                      DropdownMenuItem(value: 'Tema Mandıra', child: Text('Tema Mandıra')),
                      DropdownMenuItem(value: 'Tema Fırın', child: Text('Tema Fırın')),
                      DropdownMenuItem(value: 'Tema Bakliyat', child: Text('Tema Bakliyat')),
                      DropdownMenuItem(value: 'Tema İnşaat', child: Text('Tema İnşaat')),
                      DropdownMenuItem(value: 'Manav', child: Text('Manav')),
                      DropdownMenuItem(value: 'Temel Gıda', child: Text('Temel Gıda')),
                    ],
                    onChanged: (val) {
                      if (val != null) catCtrl.text = val;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sloganCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Slogan / Kısa Tanıtım',
                      hintText: 'Örn: Veteriner Onaylı Çiftlikten Şubelere',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ayrıntılı Tanıtım Yazısı',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: heroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hero Görsel / Banner URL',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tema Rengi (HEX)',
                            hintText: '#DC2626',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: isActive,
                        onChanged: (val) => setDlgState(() => isActive = val),
                      ),
                      Text(isActive ? 'Yayında' : 'Taslak'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customInfoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Öne Çıkan Özellikler (• ile ayırın)',
                      hintText: 'Helal Kesim • Yerli Besi • Soğuk Zincir',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final sub = subCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                      if (title.isEmpty || sub.isEmpty) {
                        return;
                      }
                      setDlgState(() => saving = true);
                      final data = {
                        if (isEdit) 'id': existing['id'],
                        'title': title,
                        'subdomain': sub,
                        'domain': '$sub.temamarket.com',
                        'category': catCtrl.text.trim(),
                        'slogan': sloganCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'hero_image': heroCtrl.text.trim(),
                        'color_hex': colorCtrl.text.trim().isEmpty ? '#DC2626' : colorCtrl.text.trim(),
                        'custom_info': customInfoCtrl.text.trim(),
                        'is_active': isActive,
                      };
                      await ApiService.saveSubdomainPage(data);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Güncelle' : 'Kaydet ve Yayına Al'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSubdomainPreview(Map<String, dynamic> page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubdomainLandingPage(
          subdomainSlug: page['subdomain']?.toString() ?? 'kasap',
          initialData: page,
          onBackToMain: () => Navigator.of(context).pop(),
          onOpenSanalMarket: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _confirmDeleteSubdomain(int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Subdomain Sayfası Silinsin mi?'),
        content: Text('"$title" sayfası ve subdomain yönlendirmesi silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteSubdomainPage(id);
              _loadData();
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  11- İŞ BAŞVURULARI LİSTESİ & YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _applicationList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Pozisyon Ekle'),
        onPressed: _showAddPositionDialog,
      ),
      body: _applications.isEmpty
          ? _AdminEmpty(
              message: 'Henüz kayıtlı iş başvurusu bulunmuyor.',
              onRetry: _loadData,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF0F172A),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.work_outline,
                              color: Colors.white, size: 32),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'İş Başvuruları Yönetim Merkezi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toplam ${_applications.length} başvuru kayıtlı. İncelemek veya durum güncellemek için başvuruya dokunun.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._applications.map((app) {
                    final status = app['status']?.toString() ?? 'Beklemede';
                    Color statusColor;
                    if (status.contains('Kabul')) {
                      statusColor = const Color(0xFF16A34A);
                    } else if (status.contains('Mülakat') ||
                        status.contains('İncelendi')) {
                      statusColor = const Color(0xFF2563EB);
                    } else if (status.contains('Red')) {
                      statusColor = const Color(0xFFDC2626);
                    } else {
                      statusColor = const Color(0xFFD97706);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFDC2626),
                          child: Text(
                            (app['name']?.toString().isNotEmpty == true)
                                ? app['name'].toString().substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                app['name']?.toString() ?? 'İsimsiz',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Pozisyon: ${app['position'] ?? 'Genel Başvuru'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Tel: ${app['phone'] ?? '-'} | İlçe: ${app['district'] ?? 'Erzurum'} | Tarih: ${app['created_at'] ?? 'Yeni'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showApplicationDetailDialog(app),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  void _showApplicationDetailDialog(Map<String, dynamic> app) {
    String currentStatus = app['status']?.toString() ?? 'Beklemede';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  app['name']?.toString() ?? 'Başvuru Detayı',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Başvurulan Pozisyon:', app['position']?.toString() ?? '-'),
                _detailRow('Telefon:', app['phone']?.toString() ?? '-'),
                _detailRow('E-posta:', app['email']?.toString() ?? '-'),
                _detailRow('İkametgah İlçesi:', app['district']?.toString() ?? '-'),
                _detailRow('Eğitim Durumu:', app['education']?.toString() ?? '-'),
                _detailRow('Başvuru Tarihi:', app['created_at']?.toString() ?? '-'),
                const Divider(height: 20),
                const Text('İş Deneyimi & Notlar:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    app['experience']?.toString() ?? 'Belirtilmedi.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Başvuru Durumu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: currentStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Beklemede', child: Text('⏳ Beklemede')),
                    DropdownMenuItem(value: 'İncelendi', child: Text('👁️ İncelendi')),
                    DropdownMenuItem(
                        value: 'Mülakata Çağrıldı',
                        child: Text('📞 Mülakata Çağrıldı')),
                    DropdownMenuItem(
                        value: 'Kabul Edildi', child: Text('✅ Kabul Edildi')),
                    DropdownMenuItem(
                        value: 'Reddedildi', child: Text('❌ Reddedildi')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => currentStatus = val);
                      setState(() {
                        app['status'] = val;
                      });
                      final id = _asInt(app['id']);
                      if (id > 0) {
                        ApiService.updateJobApplicationStatus(id, val);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPositionDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Açık Pozisyon Ekle'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Pozisyon Başlığı (Örn: Kasaphane Kasap Ustası)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final text = titleController.text.trim();
              if (text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pozisyon eklendi: $text')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  3- TEMA KASAPHANE PANELİ (Kesim, Takip & Medya Yönetimi)
  // ─────────────────────────────────────────────────────────────
  Widget _kasaphaneList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Yeni Sevk Kaydı'),
        onPressed: _showAddKasaphaneRecordDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFF991B1B),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema Kasaphane Takip Paneli',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kesim anından şubelerimize sevkiyata kadar tüm aşamaları buradan yönetebilir, müşterilerimize şeffaf takip sunabilirsiniz.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktif Kesim & Sevk Partileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.video_library_outlined, size: 18),
                  label: const Text('Medya / Video Yükle'),
                  onPressed: _showAddKasaphaneMediaDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_kasaphaneRecords.isEmpty)
              const Center(child: Text('Henüz sevk kaydı girilmedi.'))
            else
              ..._kasaphaneRecords.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['lot_no']?.toString() ?? 'Parti No',
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                item['status']?.toString() ?? 'Durum',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _detailRow('Kesim Tarihi:', item['date']?.toString() ?? '-'),
                        _detailRow('Çiftlik / Tesis:', item['farm']?.toString() ?? '-'),
                        _detailRow('Veteriner Raporu:', item['vet_report']?.toString() ?? '-'),
                        _detailRow('Sevk Şubeleri:', item['branches']?.toString() ?? '-'),
                        if (item['note'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            item['note'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddKasaphaneRecordDialog() {
    final lotController = TextEditingController(text: 'TK-${DateTime.now().year}/GZ-03');
    final farmController = TextEditingController(text: 'TEMA Besi Çiftliği');
    final vetController = TextEditingController(text: 'TR-25-0045 Onaylı');
    final branchesController = TextEditingController(text: 'Tüm Şubeler');
    final noteController = TextEditingController();
    String status = 'Şube Reyonlarına Ulaştı';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Kesim / Sevk Takibi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lotController,
                  decoration: const InputDecoration(labelText: 'Parti / Lot No'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: farmController,
                  decoration: const InputDecoration(labelText: 'Çiftlik / Besi Yeri'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vetController,
                  decoration: const InputDecoration(labelText: 'Veteriner Onay No'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: branchesController,
                  decoration: const InputDecoration(labelText: 'Sevk Edilen Şubeler'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Sevk Durumu'),
                  items: const [
                    DropdownMenuItem(value: 'Kesim Aşamasında', child: Text('Kesim Aşamasında')),
                    DropdownMenuItem(value: 'Soğuk Hava Dinlendirmede', child: Text('Soğuk Hava Dinlendirmede')),
                    DropdownMenuItem(value: 'Soğuk Zincir Sevkiyatta', child: Text('Soğuk Zincir Sevkiyatta')),
                    DropdownMenuItem(value: 'Şube Reyonlarına Ulaştı', child: Text('Şube Reyonlarına Ulaştı')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Açıklama / Not'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                final newRecord = {
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'lot_no': lotController.text.trim(),
                  'date': '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                  'farm': farmController.text.trim(),
                  'vet_report': vetController.text.trim(),
                  'branches': branchesController.text.trim(),
                  'status': status,
                  'note': noteController.text.trim(),
                };
                setState(() => _kasaphaneRecords.insert(0, newRecord));
                ApiService.saveKasaphaneTracking(newRecord);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yeni sevk takibi kaydedildi.')),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKasaphaneMediaDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String type = 'Video';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kasaphane Resim / Video Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Medya Başlığı'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Medya Türü'),
                  items: const [
                    DropdownMenuItem(value: 'Video', child: Text('Video')),
                    DropdownMenuItem(value: 'Fotoğraf', child: Text('Fotoğraf')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Video veya Resim URL bağlantısı',
                    hintText: 'https://...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kasaphane medyası yüklendi.')),
                );
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  6- TEMA İNŞAAT & GRUP ŞİRKETLERİ YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _corporateList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Yeni Proje / Şirket Ekle'),
        onPressed: _showAddCorporateDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFF1E293B),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.apartment, color: Colors.white, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema Grup & İştirakler Yönetimi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tema İnşaat gibi diğer grup şirketlerimizi, projelerinizi ekleyip düzenleyebilir, ana sayfada vitrine çıkarabilirsiniz.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_corporateEntities.isEmpty)
              const Center(child: Text('Kayıtlı şirket veya proje bulunmuyor.'))
            else
              ..._corporateEntities.map((corp) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                corp['title']?.toString() ?? 'Proje Başlığı',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFDC2626)),
                              tooltip: 'Projeyi Sil',
                              onPressed: () {
                                setState(() {
                                  _corporateEntities.remove(corp);
                                });
                                final id = _asInt(corp['id']);
                                if (id > 0) ApiService.deleteCorporateEntity(id);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            corp['category']?.toString() ?? 'Sektör',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          corp['description']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.link, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              corp['website']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddCorporateDialog() {
    final titleController = TextEditingController();
    final catController = TextEditingController(text: 'İnşaat & Gayrimenkul');
    final descController = TextEditingController();
    final webController = TextEditingController(text: 'https://temamarket.com/insaat');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Şirket / Proje Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Proje / Şirket Adı (Örn: Tema İnşaat)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catController,
                decoration: const InputDecoration(labelText: 'Kategori / Sektör'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Kısa Açıklama'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: webController,
                decoration: const InputDecoration(labelText: 'Web Sitesi / Link'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final newCorp = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'title': titleController.text.trim(),
                'category': catController.text.trim(),
                'description': descController.text.trim(),
                'website': webController.text.trim(),
                'status': 'Aktif',
              };
              setState(() => _corporateEntities.insert(0, newCorp));
              ApiService.saveCorporateEntity(newCorp);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yeni proje kaydedildi.')),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _featureList() {
    final entries = <(String, String, bool)>[
      ('sanal_market', 'Sanal Market', _flags.sanalMarket),
      ('bayi_stok', 'Bayi Stok', _flags.bayiStok),
      ('temapuan', 'TemaPuan', _flags.temapuan),
      ('kampanyalar', 'Kampanyalar', _flags.kampanyalar),
      ('api_entegrasyon', 'Harici API entegrasyonu', _flags.apiEntegrasyon),
      ('sms_gonderim', 'Toplu SMS', _flags.smsGonderim),
      ('sanal_pos', 'Sanal POS', _flags.sanalPos),
      ('soft_pos', 'SoftPOS', _flags.softPos),
      ('e_fatura', 'E-Fatura', _flags.eFatura),
      ('serbest_kurye', 'Serbest kurye', _flags.serbestKurye),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(
                'Hazır özellikler anında uygulanır; sağlayıcı gerektiren özellikler yapılandırılana kadar açılamaz.'),
          ),
        ),
        ...entries.map(
          (entry) {
            final available = _featureAvailable(entry.$1);
            return SwitchListTile(
              title: Text(entry.$2),
              subtitle: Text(_savingFlags.contains(entry.$1)
                  ? 'Kaydediliyor…'
                  : _featureReason(entry.$1)),
              value: entry.$3,
              onChanged: !available || _savingFlags.contains(entry.$1)
                  ? null
                  : (value) => _toggleFlag(entry.$1, value),
            );
          },
        ),
      ],
    );
  }

  Widget _listOrEmpty(
    List<Map<String, dynamic>> items,
    String emptyMessage,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    if (items.isEmpty) {
      return _AdminEmpty(message: emptyMessage, onRetry: _loadData);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => builder(items[index]),
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminEmpty({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Yenile')),
          ],
        ),
      );
}
