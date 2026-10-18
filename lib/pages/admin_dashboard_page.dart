import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';
import 'subdomain_landing_page.dart';

/// Yönetici ekranı: Özet, Şubeler, Siparişler, Ürünler, Kampanyalar,
/// Canlı Önizlemeli Sürükle-Bırak Subdomain Sayfa Editörü, İş Başvuruları,
/// Tema Kasaphane, Tema İnşaat & Grup ve Özellikler modüllerini içerir.
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
  List<Map<String, dynamic>> _openPositions = [];
  List<Map<String, dynamic>> _kasaphaneRecords = [];
  List<Map<String, dynamic>> _kasaphaneMedia = [];
  List<Map<String, dynamic>> _corporateEntities = [];
  List<Map<String, dynamic>> _couriers = [];
  Map<String, dynamic> _loyaltyRules = {
    'earn_rate': 0.05,
    'burn_rate': 1.0,
    'welcome_points': 100,
  };

  FeatureFlags _flags = const FeatureFlags();
  Map<String, dynamic> _capabilities = {};
  final Set<String> _savingFlags = {};

  // Filtre durumları
  String _orderStatusFilter = 'Tümü';
  String _productCategoryFilter = 'Tümü';
  String _productSearchQuery = '';
  String _applicationStatusFilter = 'Tümü';

  // ── Görsel Subdomain Sayfa Editörü Durumları ──
  int _selectedSubdomainIndex = 0;
  Map<String, dynamic>? _editingPage;
  String _editorSidebarTab = 'palette'; // 'palette' | 'inspector' | 'settings'
  String _previewDevice = 'desktop'; // 'desktop' | 'tablet' | 'mobile'
  String? _selectedSectionId;
  String? _selectedElementId;
  bool _savingSubdomainPage = false;

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

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> src) {
    final result = <String, dynamic>{};
    src.forEach((key, value) {
      if (value is Map) {
        result[key] = _deepCopyMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) {
            return _deepCopyMap(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  void _selectSubdomainForEditing(int index,
      [List<Map<String, dynamic>>? pagesOverride]) {
    final list = pagesOverride ?? _subdomainPages;
    if (list.isEmpty) {
      _editingPage = null;
      return;
    }
    final safeIdx = index.clamp(0, list.length - 1);
    final page = _deepCopyMap(list[safeIdx]);
    page['sections'] = SubdomainLandingPage.defaultSectionsFor(page);
    page['element_positions'] = page['element_positions'] is Map
        ? Map<String, dynamic>.from(page['element_positions'] as Map)
        : <String, dynamic>{};
    page['floating_elements'] = page['floating_elements'] is List
        ? (page['floating_elements'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    _selectedSubdomainIndex = safeIdx;
    _editingPage = page;
    final secs = page['sections'] as List;
    if (secs.isNotEmpty && _selectedSectionId == null) {
      _selectedSectionId = (secs.first as Map)['id']?.toString();
    }
  }

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
        ApiService.fetchCouriers(),
        ApiService.fetchLoyaltyRules(),
        ApiService.fetchOpenPositions(),
        ApiService.fetchKasaphaneMedia(),
      ]);
      if (!mounted) return;
      final configuration = Map<String, dynamic>.from(results[5] as Map);
      final rawFlags = configuration['flags'];
      final fetchedApps = _maps(results[6] as List<dynamic>);
      final fetchedKasap = _maps(results[7] as List<dynamic>);
      final fetchedCorps = _maps(results[8] as List<dynamic>);
      final fetchedSubs = _maps(results[9] as List<dynamic>);
      final fetchedCouriers = _maps(results[10] as List<dynamic>);
      final fetchedRules = Map<String, dynamic>.from(results[11] as Map);
      final fetchedPositions = _maps(results[12] as List<dynamic>);
      final fetchedMedia = _maps(results[13] as List<dynamic>);

      setState(() {
        _metrics = Map<String, dynamic>.from(results[0] as Map);
        _branches = _maps(results[1] as List<dynamic>);
        _orders = _maps(results[2] as List<dynamic>);
        _products = _maps(results[3] as List<dynamic>);
        _campaigns = _maps(results[4] as List<dynamic>);
        _applications = fetchedApps;
        _kasaphaneRecords = fetchedKasap;
        _corporateEntities = fetchedCorps;
        _subdomainPages = fetchedSubs.isNotEmpty
            ? fetchedSubs
            : ApiService.defaultSubdomainPages
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        _couriers = fetchedCouriers;
        _loyaltyRules = fetchedRules;
        _openPositions = fetchedPositions;
        _kasaphaneMedia = fetchedMedia;

        _selectSubdomainForEditing(_selectedSubdomainIndex, _subdomainPages);

        _flags = FeatureFlags.fromJson(
          rawFlags is Map ? Map<String, dynamic>.from(rawFlags) : const {},
        );
        _capabilities = configuration['capabilities'] is Map
            ? Map<String, dynamic>.from(configuration['capabilities'] as Map)
            : Map<String, dynamic>.from(ApiService.defaultCapabilities);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Özellik durumu güncellendi: ${value ? "Aktif" : "Pasif"}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
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
    if (capability is Map) {
      return capability['available'] != false;
    }
    return true;
  }

  String _featureReason(String key) {
    final capability = _capabilities[key];
    if (capability is Map && capability['reason'] != null) {
      return capability['reason'].toString();
    }
    final def = ApiService.defaultCapabilities[key];
    if (def is Map && def['reason'] != null) {
      return def['reason'].toString();
    }
    return 'Hazır ve aktif olarak kullanılabilir.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user?['role']?.toString() != 'SuperAdmin') {
      return const Scaffold(
        body: Center(
          child: Text('Bu sayfaya yalnızca yönetici hesabı erişebilir.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'temamarket.com Yönetim Paneli',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Verileri yenile',
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
          if (widget.onBackToStore != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: widget.onBackToStore,
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Mağazaya Dön'),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Özet'),
            Tab(icon: Icon(Icons.store_outlined), text: 'Şubeler'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Siparişler'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Ürünler'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Kampanyalar'),
            Tab(
              icon: Icon(Icons.design_services_outlined),
              text: 'Subdomain & Sayfa Editörü',
            ),
            Tab(icon: Icon(Icons.work_outline), text: 'İş Başvuruları'),
            Tab(icon: Icon(Icons.verified_outlined), text: 'Tema Kasaphane'),
            Tab(
              icon: Icon(Icons.apartment_outlined),
              text: 'Tema İnşaat & Grup',
            ),
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
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _overview(),
        _branchList(),
        _orderList(),
        _productList(),
        _campaignList(),
        _subdomainVisualEditorTab(),
        _applicationList(),
        _kasaphaneList(),
        _corporateList(),
        _featureList(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  1- ÖZET, KURYE HAVUZU VE TEMAPUAN KURALLARI
  // ─────────────────────────────────────────────────────────────
  Widget _overview() {
    final pendingAppsCount = _applications
        .where((a) => (a['status']?.toString() ?? '').contains('Beklemede'))
        .length;
    final activeCouriersCount =
        _couriers.where((c) => c['status'] != 'İzinli').length;
    final activeSubsCount =
        _subdomainPages.where((s) => s['is_active'] != false).length;

    final cards = [
      (
        'Toplam Sipariş',
        _orders.length,
        Icons.receipt_long_outlined,
        2,
        const Color(0xFFDC2626)
      ),
      (
        'Aktif Şubeler',
        _branches.length,
        Icons.store_outlined,
        1,
        const Color(0xFF2563EB)
      ),
      (
        'Kayıtlı Ürünler',
        _products.length,
        Icons.inventory_2_outlined,
        3,
        const Color(0xFF16A34A)
      ),
      (
        'Yayındaki Subdomainler',
        activeSubsCount,
        Icons.language_outlined,
        5,
        const Color(0xFFD97706)
      ),
      (
        'Bekleyen Başvurular',
        pendingAppsCount,
        Icons.pending_actions_outlined,
        6,
        const Color(0xFF7C3AED)
      ),
      (
        'Aktif Kuryeler',
        activeCouriersCount,
        Icons.delivery_dining_outlined,
        2,
        const Color(0xFF0D9488)
      ),
    ];

    double revenue = _asDouble(_metrics['total_revenue']);
    if (revenue <= 0) {
      for (final o in _orders) {
        revenue += _asDouble(o['total_amount']);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Hızlı Erişim Banner: Görsel Subdomain Sayfa Editörü
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.design_services_rounded,
                        color: Colors.amber, size: 36),
                    SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Canlı Önizlemeli Sürükle & Bırak Subdomain Sayfa Editörü',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'kasap.temamarket.com, sarkuteri.temamarket.com gibi tüm subdomain sayfalarını canlı önizleme üzerinde sürükleyip bırakarak tasarlayın.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _tabs.animateTo(5),
                  icon: const Icon(Icons.open_with_rounded, size: 18),
                  label: const Text('Sayfa Editörünü Aç'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Kartları (Tıklanabilir)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: 225,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _tabs.animateTo(card.$4),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    card.$5.withValues(alpha: 0.12),
                                child: Icon(card.$3, color: card.$5),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.$1,
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 12),
                                    ),
                                    Text(
                                      '${card.$2}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Ciro & TemaPuan Kuralları
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.payments_outlined,
                          color: Color(0xFF16A34A)),
                    ),
                    title: const Text('Toplam Sipariş Cirosu'),
                    subtitle: Text(
                        'Kayıtlı ${_metricsUserCount()} aktif müşteri hesabı'),
                    trailing: Text(
                      '₺${revenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // TemaPuan & Sadakat Kuralları Yönetimi
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.stars_rounded,
                              color: Color(0xFFDC2626), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Tema Avantaj Kart & TemaPuan Kuralları',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _showLoyaltyRulesDialog,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Kuralları Düzenle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _detailChip(
                        'Alışveriş Puan Kazanımı',
                        '%${(_asDouble(_loyaltyRules['earn_rate']) * 100).toStringAsFixed(0)} TemaPuan',
                      ),
                      _detailChip(
                        '1 TemaPuan Değeri',
                        '₺${_asDouble(_loyaltyRules['burn_rate'] ?? 1.0).toStringAsFixed(2)}',
                      ),
                      _detailChip(
                        'Yeni Üye Hoşgeldin Puanı',
                        '${_asInt(_loyaltyRules['welcome_points'] ?? 100)} Puan',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kurye Havuzu Yönetimi
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.delivery_dining,
                              color: Color(0xFF0F172A), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Kurye & Teslimat Ekibi Yönetimi',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCourierDialog(),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text('Yeni Kurye Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._couriers.map((courier) {
                    final status = courier['status']?.toString() ?? 'Müsait';
                    final isAvailable = status == 'Müsait';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isAvailable
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        child: Icon(
                          Icons.two_wheeler,
                          color: isAvailable
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                      ),
                      title: Text(
                        courier['name']?.toString() ?? 'Kurye',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${courier['phone'] ?? '-'} • ${courier['vehicle'] ?? 'Motosiklet'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: ['Müsait', 'Siparişte', 'İzinli']
                                    .contains(status)
                                ? status
                                : 'Müsait',
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Müsait', child: Text('🟢 Müsait')),
                              DropdownMenuItem(
                                  value: 'Siparişte',
                                  child: Text('🟠 Siparişte')),
                              DropdownMenuItem(
                                  value: 'İzinli', child: Text('⚪ İzinli')),
                            ],
                            onChanged: (val) async {
                              if (val != null) {
                                final updated = {...courier, 'status': val};
                                await ApiService.saveCourier(updated);
                                _loadData();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () async {
                              await ApiService.deleteCourier(
                                  _asInt(courier['id']));
                              _loadData();
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _metricsUserCount() =>
      _asInt(_metrics['total_users']) > 0 ? _asInt(_metrics['total_users']) : 1420;

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _showLoyaltyRulesDialog() {
    final earnCtrl = TextEditingController(
      text: '${(_asDouble(_loyaltyRules['earn_rate']) * 100).toStringAsFixed(0)}',
    );
    final burnCtrl = TextEditingController(
      text: _asDouble(_loyaltyRules['burn_rate'] ?? 1.0).toStringAsFixed(2),
    );
    final welcomeCtrl = TextEditingController(
      text: '${_asInt(_loyaltyRules['welcome_points'] ?? 100)}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TemaPuan Sadakat Kuralları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: earnCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puan Kazanım Oranı (%)',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: burnCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '1 Puanın TL Karşılığı',
                prefixText: '₺',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: welcomeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hoşgeldin Hediye Puanı',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final earnPercent = double.tryParse(earnCtrl.text.trim()) ?? 5.0;
              final burn = double.tryParse(burnCtrl.text.trim()) ?? 1.0;
              final welcome = int.tryParse(welcomeCtrl.text.trim()) ?? 100;
              final newRules = {
                'earn_rate': (earnPercent / 100.0).clamp(0.01, 1.0),
                'burn_rate': burn,
                'welcome_points': welcome,
              };
              await ApiService.updateLoyaltyRules(newRules);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('TemaPuan kuralları güncellendi.')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showCourierDialog([Map<String, dynamic>? existing]) {
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone']?.toString() ?? '0530 ');
    final vehicleCtrl = TextEditingController(
        text: existing?['vehicle']?.toString() ?? 'Motosiklet');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Kurye Düzenle' : 'Yeni Kurye Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Kurye Adı Soyadı'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Telefon Numarası'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vehicleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Araç Tipi (Motosiklet / Soğuk Zincir Panelvan)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ApiService.saveCourier({
                if (existing != null) 'id': existing['id'],
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'vehicle': vehicleCtrl.text.trim(),
                'status': existing?['status'] ?? 'Müsait',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  2- ŞUBELER YÖNETİMİ (EKLE / DÜZENLE / SİL / AKTİF-PASİF)
  // ─────────────────────────────────────────────────────────────
  Widget _branchList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Yeni Şube Ekle'),
        onPressed: () => _showBranchDialog(),
      ),
      body: _branches.isEmpty
          ? _AdminEmpty(
              message: 'Aktif şube bulunmuyor.',
              onRetry: _loadData,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _branches.length,
                itemBuilder: (context, index) {
                  final branch = _branches[index];
                  final isActive = branch['is_active'] == 1 ||
                      branch['is_active'] == true ||
                      branch['is_active']?.toString() == '1';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isActive
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFF1F5F9),
                                child: Icon(
                                  Icons.store_outlined,
                                  color: isActive
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      branch['name']?.toString() ?? 'Şube',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16),
                                    ),
                                    Text(
                                      'Kod: ${branch['code'] ?? '#${branch['id']}'} • İlçe: ${branch['city_district'] ?? 'Erzurum'}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (val) async {
                                  await ApiService.saveBranch({
                                    ...branch,
                                    'is_active': val ? 1 : 0,
                                  });
                                  _loadData();
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          _detailRow('Adres:',
                              branch['address']?.toString() ?? '-'),
                          _detailRow('Telefon:',
                              branch['phone']?.toString() ?? '0442 233 10 00'),
                          _detailRow(
                            'Çalışma Saatleri:',
                            branch['working_hours']?.toString() ??
                                '08:00 - 22:00',
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Düzenle'),
                                onPressed: () => _showBranchDialog(branch),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                icon:
                                    const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Sil'),
                                onPressed: () async {
                                  await ApiService.deleteBranch(
                                      _asInt(branch['id']));
                                  _loadData();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showBranchDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final codeCtrl = TextEditingController(
        text: existing?['code']?.toString() ??
            'TEMA-ERZ-0${_branches.length + 1}');
    final districtCtrl = TextEditingController(
        text: existing?['city_district']?.toString() ?? 'Yakutiye');
    final addressCtrl =
        TextEditingController(text: existing?['address']?.toString() ?? '');
    final phoneCtrl = TextEditingController(
        text: existing?['phone']?.toString() ?? '0442 233 10 00');
    final hoursCtrl = TextEditingController(
        text: existing?['working_hours']?.toString() ?? '08:00 - 22:00');
    bool isActive = existing == null ||
        existing['is_active'] == 1 ||
        existing['is_active'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEdit ? 'Şubeyi Düzenle' : 'Yeni Şube Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Şube Adı *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Şube Kodu'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: districtCtrl,
                  decoration: const InputDecoration(labelText: 'İlçe / Bölge'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Açık Adres'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hoursCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Çalışma Saatleri'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Şube Aktif Hizmette'),
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ApiService.saveBranch({
                  if (isEdit) 'id': existing['id'],
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'city_district': districtCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'working_hours': hoursCtrl.text.trim(),
                  'is_active': isActive ? 1 : 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  3- SİPARİŞLER YÖNETİMİ (DURUM GÜNCELLE / KURYE ATA / DETAY)
  // ─────────────────────────────────────────────────────────────
  Widget _orderList() {
    final statuses = [
      'Tümü',
      'Hazırlanıyor',
      'Kuryede',
      'Teslim Edildi',
      'İptal Edildi'
    ];
    final filtered = _orderStatusFilter == 'Tümü'
        ? _orders
        : _orders
            .where((o) =>
                (o['status']?.toString() ?? '') == _orderStatusFilter)
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Yeni Manuel Sipariş'),
        onPressed: _showCreateOrderDialog,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses
                    .map(
                      (st) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: _orderStatusFilter == st,
                          onSelected: (_) =>
                              setState(() => _orderStatusFilter = st),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _AdminEmpty(
                    message: 'Bu filtrede sipariş bulunmuyor.',
                    onRetry: _loadData,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        final id = _asInt(order['id']);
                        final status =
                            order['status']?.toString() ?? 'Hazırlanıyor';
                        final courierName =
                            order['courier_name']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFFEE2E2),
                                      child: Icon(Icons.receipt_long_outlined,
                                          color: Color(0xFFDC2626)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order['order_number']?.toString() ??
                                                'Sipariş #$id',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${order['customer_name'] ?? '-'} • ${order['created_at'] ?? 'Bugün'}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₺${_asDouble(order['total_amount']).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                _detailRow('Teslimat Adresi:',
                                    order['address']?.toString() ?? 'Erzurum'),
                                _detailRow(
                                    'Ödeme Yöntemi:',
                                    order['payment_method']?.toString() ??
                                        'Kapıda Ödeme'),
                                _detailRow(
                                  'Atanan Kurye:',
                                  courierName.isNotEmpty
                                      ? '🛵 $courierName'
                                      : 'Henüz kurye atanmadı',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    DropdownButton<String>(
                                      value: statuses
                                              .skip(1)
                                              .contains(status)
                                          ? status
                                          : 'Hazırlanıyor',
                                      items: statuses
                                          .skip(1)
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text('Durum: $s',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (newStatus) async {
                                        if (newStatus != null) {
                                          await ApiService.updateOrderStatus(
                                              id, newStatus);
                                          _loadData();
                                        }
                                      },
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(
                                              Icons.delivery_dining,
                                              size: 16),
                                          label: const Text('Kurye Ata'),
                                          onPressed: () =>
                                              _showAssignCourierModal(order),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red),
                                          tooltip: 'Siparişi Sil',
                                          onPressed: () async {
                                            await ApiService.deleteOrder(id);
                                            _loadData();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAssignCourierModal(Map<String, dynamic> order) {
    final orderId = _asInt(order['id']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${order['order_number']} İçin Kurye Ata'),
        content: SizedBox(
          width: 400,
          child: _couriers.isEmpty
              ? const Text('Kayıtlı kurye bulunamadı.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _couriers
                      .map(
                        (c) => ListTile(
                          leading: const Icon(Icons.two_wheeler,
                              color: Color(0xFFDC2626)),
                          title: Text(c['name']?.toString() ?? 'Kurye'),
                          subtitle:
                              Text('${c['phone'] ?? ''} • ${c['status'] ?? ''}'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await ApiService.assignCourier(
                                orderId,
                                _asInt(c['id']),
                                courierName: c['name']?.toString(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${c['name']} siparişe atandı ve durum Kuryede olarak güncellendi.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Ata'),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _showCreateOrderDialog() {
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '0532 ');
    final addressCtrl =
        TextEditingController(text: 'Yakutiye Merkez / Erzurum');
    final amountCtrl = TextEditingController(text: '480.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Manuel / Telefon Siparişi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Müşteri Adı Soyadı *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration:
                    const InputDecoration(labelText: 'Teslimat Adresi'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sipariş Tutarı (₺)', prefixText: '₺'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (customerCtrl.text.trim().isEmpty) return;
              await ApiService.createOrder({
                'customer_name': customerCtrl.text.trim(),
                'customer_phone': phoneCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'total_amount':
                    double.tryParse(amountCtrl.text.trim()) ?? 480.0,
                'status': 'Hazırlanıyor',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Sipariş Oluştur'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  4- ÜRÜNLER & STOK YÖNETİMİ (EKLE / DÜZENLE / STOK +/- / SİL)
  // ─────────────────────────────────────────────────────────────
  Widget _productList() {
    final categories = [
      'Tümü',
      'Tema Kasaphane',
      'Şarküteri',
      'Tema Mandıra',
      'Tema Fırın',
      'Tema Bakliyat',
    ];

    final filtered = _products.where((p) {
      final matchesCat = _productCategoryFilter == 'Tümü' ||
          (p['sub_brand']?.toString().toLowerCase() ?? '') ==
              _productCategoryFilter.toLowerCase();
      final matchesQuery = _productSearchQuery.trim().isEmpty ||
          (p['name']?.toString().toLowerCase() ?? '')
              .contains(_productSearchQuery.trim().toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Yeni Ürün Ekle'),
        onPressed: () => _showProductDialog(),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Ürün adı veya reyon ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _productSearchQuery = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories
                        .map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: _productCategoryFilter == cat,
                              onSelected: (_) => setState(
                                  () => _productCategoryFilter = cat),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _AdminEmpty(
                    message: 'Filtreye uygun ürün bulunmuyor.',
                    onRetry: _loadData,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final id = _asInt(product['id']);
                        final stock = _asInt(product['stock']);
                        final price = _asDouble(product['base_price']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 52,
                                height: 52,
                                color: const Color(0xFFF1F5F9),
                                child: (product['image']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                    ? Image.network(
                                        product['image'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.inventory_2),
                                      )
                                    : const Icon(Icons.inventory_2),
                              ),
                            ),
                            title: Text(
                              product['name']?.toString() ?? 'Ürün',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${product['sub_brand'] ?? '-'} • Fiyat: ₺${price.toStringAsFixed(2)} • Stok: $stock adet',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Stok Azalt (-5)',
                                  icon: const Icon(
                                      Icons.remove_circle_outline,
                                      size: 20),
                                  onPressed: () async {
                                    final next =
                                        (stock - 5).clamp(0, 999999);
                                    await ApiService.updateProductStock(
                                        id, next);
                                    _loadData();
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: stock > 0
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$stock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: stock > 0
                                          ? const Color(0xFF166534)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Stok Artır (+5)',
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 20),
                                  onPressed: () async {
                                    await ApiService.updateProductStock(
                                        id, stock + 5);
                                    _loadData();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Düzenle',
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.blue, size: 20),
                                  onPressed: () =>
                                      _showProductDialog(product),
                                ),
                                IconButton(
                                  tooltip: 'Sil',
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () async {
                                    await ApiService.deleteProduct(id);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showProductDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    String selectedCat =
        existing?['sub_brand']?.toString() ?? 'Tema Kasaphane';
    final categories = [
      'Tema Kasaphane',
      'Şarküteri',
      'Tema Mandıra',
      'Tema Fırın',
      'Tema Bakliyat',
      'Manav',
      'Temel Gıda',
    ];
    if (!categories.contains(selectedCat)) {
      selectedCat = 'Tema Kasaphane';
    }
    final priceCtrl = TextEditingController(
        text: existing?['base_price']?.toString() ?? '250.00');
    final origPriceCtrl = TextEditingController(
        text: existing?['original_price']?.toString() ?? '290.00');
    final stockCtrl =
        TextEditingController(text: '${_asInt(existing?['stock'] ?? 40)}');
    final imageCtrl =
        TextEditingController(text: existing?['image']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEdit ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ürün Adı *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration:
                      const InputDecoration(labelText: 'Reyon / Kategori'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedCat = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Satış Fiyatı (₺)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: origPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Eski Fiyat (₺)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok Adedi'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ürün Görsel URL',
                    hintText: 'https://...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ApiService.saveProduct({
                  if (isEdit) 'id': existing['id'],
                  'name': nameCtrl.text.trim(),
                  'sub_brand': selectedCat,
                  'base_price': priceCtrl.text.trim(),
                  'original_price': origPriceCtrl.text.trim(),
                  'stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                  'image': imageCtrl.text.trim(),
                  'status': 'Aktif',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  5- KAMPANYALAR YÖNETİMİ (EKLE / DÜZENLE / SİL / AKTİF-PASİF)
  // ─────────────────────────────────────────────────────────────
  Widget _campaignList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Yeni Kampanya Ekle'),
        onPressed: () => _showCampaignDialog(),
      ),
      body: _campaigns.isEmpty
          ? _AdminEmpty(
              message: 'Yayında kampanya bulunmuyor.',
              onRetry: _loadData,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _campaigns.length,
                itemBuilder: (context, index) {
                  final campaign = _campaigns[index];
                  final id = _asInt(campaign['id']);
                  final isActive = campaign['is_active'].toString() == '1' ||
                      campaign['is_active'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFF1F5F9),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: isActive
                              ? const Color(0xFFDC2626)
                              : Colors.grey,
                        ),
                      ),
                      title: Text(
                        campaign['title']?.toString() ?? 'Kampanya',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${campaign['discount_badge'] ?? '%20 İndirim'} • ${campaign['description'] ?? ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (val) async {
                              await ApiService.saveCampaign({
                                ...campaign,
                                'is_active': val ? 1 : 0,
                              });
                              _loadData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.blue),
                            onPressed: () => _showCampaignDialog(campaign),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () async {
                              await ApiService.deleteCampaign(id);
                              _loadData();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showCampaignDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final badgeCtrl = TextEditingController(
        text: existing?['discount_badge']?.toString() ?? '%20 İndirim');
    final imageCtrl =
        TextEditingController(text: existing?['image']?.toString() ?? '');
    bool isActive = existing == null ||
        existing['is_active'].toString() == '1' ||
        existing['is_active'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEdit ? 'Kampanyayı Düzenle' : 'Yeni Kampanya Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Kampanya Başlığı *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: badgeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'İndirim Rozeti (Örn: %25 İndirim)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Kampanya Açıklaması'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Afiş / Görsel URL'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kampanya Yayında'),
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await ApiService.saveCampaign({
                  if (isEdit) 'id': existing['id'],
                  'title': titleCtrl.text.trim(),
                  'discount_badge': badgeCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'image': imageCtrl.text.trim(),
                  'is_active': isActive ? 1 : 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  6- GÖRSEL SÜRÜKLE-BIRAK SUBDOMAIN SAYFA EDİTÖRÜ & CANLI PREVIEW
  // ─────────────────────────────────────────────────────────────
  Widget _subdomainVisualEditorTab() {
    if (_editingPage == null && _subdomainPages.isNotEmpty) {
      _selectSubdomainForEditing(0);
    }
    final page = _editingPage;
    if (page == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _showSubdomainDialog(),
          icon: const Icon(Icons.add),
          label: const Text('İlk Subdomain Sayfasını Oluştur'),
        ),
      );
    }

    final sub = page['subdomain']?.toString() ?? 'kasap';
    final domain = page['domain']?.toString() ?? '$sub.temamarket.com';

    return Column(
      children: [
        // ── Üst Subdomain Seçici & Editör Aksiyon Çubuğu ──
        Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.language, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Düzenlenen Subdomain:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < _subdomainPages.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  '${_subdomainPages[i]['title']} (${_subdomainPages[i]['subdomain']}.temamarket.com)',
                                  style: TextStyle(
                                    color: _selectedSubdomainIndex == i
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                selected: _selectedSubdomainIndex == i,
                                selectedColor: const Color(0xFFDC2626),
                                backgroundColor: Colors.white,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedSectionId = null;
                                    _selectedElementId = null;
                                    _selectSubdomainForEditing(i);
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add_link, size: 16),
                    label: const Text('Yeni Subdomain',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => _showSubdomainDialog(),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    onPressed: _savingSubdomainPage
                        ? null
                        : _saveCurrentEditingSubdomainPage,
                    icon: _savingSubdomainPage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Kaydet & Yayına Al',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Ana Editör Gövdesi: Sol Araç Kutusu + Sağ Canlı Sürükle-Bırak Sayfa Preview ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 370,
                      child: _buildEditorSidebar(page),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _buildLivePagePreviewPane(page, domain),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    SizedBox(
                      height: 290,
                      child: _buildEditorSidebar(page),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildLivePagePreviewPane(page, domain),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveCurrentEditingSubdomainPage() async {
    final page = _editingPage;
    if (page == null) return;
    setState(() => _savingSubdomainPage = true);
    try {
      await ApiService.saveSubdomainPage(page);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              '✅ ${page['domain']} sayfası tasarım ve konumlarıyla kaydedilip yayına alındı!',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSubdomainPage = false);
    }
  }

  Widget _buildEditorSidebar(Map<String, dynamic> page) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Sol Panel Sekmeleri
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                _sidebarTabBtn(
                    'palette', Icons.widgets_outlined, 'Sürükle & Ekle'),
                const SizedBox(width: 4),
                _sidebarTabBtn(
                    'inspector', Icons.tune_rounded, 'Alan Düzenle'),
                const SizedBox(width: 4),
                _sidebarTabBtn(
                    'settings', Icons.settings_outlined, 'Subdomain'),
              ],
            ),
          ),
          Expanded(
            child: _editorSidebarTab == 'palette'
                ? _buildPaletteTab(page)
                : _editorSidebarTab == 'inspector'
                    ? _buildInspectorTab(page)
                    : _buildPageSettingsTab(page),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTabBtn(String key, IconData icon, String label) {
    final active = _editorSidebarTab == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _editorSidebarTab = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15, color: active ? Colors.amber : Colors.black54),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sol Panel 1: Sürükle & Bırak Bileşen Paleti + Serbest Sürüklenebilir Elemanlar + Bölüm Sıralaması
  Widget _buildPaletteTab(Map<String, dynamic> page) {
    final blockTemplates = <Map<String, dynamic>>[
      {
        'drag_kind': 'new_block',
        'type': 'promo_banner',
        'title': 'Kampanya & İndirim Afişi',
        'icon': Icons.local_offer_outlined,
        'desc': 'Özel indirimli reyon afişi bloğu',
      },
      {
        'drag_kind': 'new_block',
        'type': 'free_canvas',
        'title': 'Serbest Sürükleme Tuvali',
        'icon': Icons.open_with_rounded,
        'desc': 'İçine istediğiniz elemanı serbestçe yerleştireceğiniz alan',
      },
      {
        'drag_kind': 'new_block',
        'type': 'products',
        'title': 'Reyon Ürün Vitrini',
        'icon': Icons.grid_view_rounded,
        'desc': 'Kategoriye ait ürünleri ızgara olarak listeler',
      },
      {
        'drag_kind': 'new_block',
        'type': 'tracking',
        'title': 'Canlı Sevk & Çiftlik Takibi',
        'icon': Icons.verified_outlined,
        'desc': 'Parti no, veteriner raporu ve sevk durumu',
      },
      {
        'drag_kind': 'new_block',
        'type': 'media_showcase',
        'title': 'Fotoğraf & Video Galerisi',
        'icon': Icons.photo_library_outlined,
        'desc': 'Tesis ve reyon görselleri kaydırmalı vitrini',
      },
      {
        'drag_kind': 'new_block',
        'type': 'features_grid',
        'title': 'Neden Biz? (3\'lü Kutu)',
        'icon': Icons.workspace_premium_outlined,
        'desc': 'Kalite, soğuk zincir ve teslimat güvence kutuları',
      },
      {
        'drag_kind': 'new_block',
        'type': 'info_strip',
        'title': 'Özellik & Rozet Şeridi',
        'icon': Icons.check_circle_outline,
        'desc': 'Madde işaretli hızlı bilgi şeridi',
      },
      {
        'drag_kind': 'new_block',
        'type': 'custom_text',
        'title': 'Özel Duyuru / Metin Bloğu',
        'icon': Icons.article_outlined,
        'desc': 'Başlık ve açıklamalı serbest metin kartı',
      },
      {
        'drag_kind': 'new_block',
        'type': 'contact',
        'title': 'İletişim & WhatsApp Kartı',
        'icon': Icons.support_agent_rounded,
        'desc': 'Çağrı merkezi ve hızlı WhatsApp sipariş butonu',
      },
    ];

    final floatingTemplates = <Map<String, dynamic>>[
      {
        'drag_kind': 'floating_element',
        'element_type': 'badge',
        'text': '🔥 %100 Yerli Besi',
        'color_hex': '#DC2626',
        'icon': Icons.stars_rounded,
        'label': 'Kayan Rozet',
      },
      {
        'drag_kind': 'floating_element',
        'element_type': 'price_card',
        'text': 'Günün Özel Fiyatı',
        'subtext': '₺420.00 / kg',
        'color_hex': '#16A34A',
        'icon': Icons.sell_outlined,
        'label': 'Fiyat Etiketi',
      },
      {
        'drag_kind': 'floating_element',
        'element_type': 'text_box',
        'text': 'Veteriner Hekim Kontrolünde',
        'subtext': 'Günlük taze sevkiyat',
        'color_hex': '#0F172A',
        'icon': Icons.text_fields_rounded,
        'label': 'Serbest Metin',
      },
      {
        'drag_kind': 'floating_element',
        'element_type': 'button',
        'text': 'Hemen Sipariş Ver',
        'color_hex': '#DC2626',
        'icon': Icons.smart_button_rounded,
        'label': 'Aksiyon Butonu',
      },
      {
        'drag_kind': 'floating_element',
        'element_type': 'image_box',
        'text': 'Taze Reyon',
        'image_url':
            'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=500',
        'color_hex': '#DC2626',
        'icon': Icons.image_outlined,
        'label': 'Görsel Kutusu',
      },
    ];

    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade400),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_outlined,
                  color: Color(0xFF92400E), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aşağıdaki elemanları sağdaki Sayfa Önizlemesi üzerinde istediğiniz alana sürükleyip bırakın veya tıklayarak ekleyin!',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '1. İSTEDİĞİN ALANA SÜRÜKLENEBİLİR SERBEST ELEMANLAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sayfa önizlemesinde herhangi bir bloğun üzerine sürükleyip istediğiniz X/Y noktasına taşıyabilirsiniz:',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: floatingTemplates.map((tpl) {
            final pill = Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tpl['icon'] as IconData,
                      size: 16, color: const Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Text(
                    tpl['label'] as String,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );

            return Draggable<Map<String, dynamic>>(
              data: tpl,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: pill,
              ),
              child: InkWell(
                onTap: () => _addFloatingElementToSection(0, tpl,
                    const Offset(36, 36)),
                borderRadius: BorderRadius.circular(10),
                child: pill,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text(
          '2. SAYFA BÖLÜMLERİ / BLOKLARI (SÜRÜKLE VEYA TIKLA EKLE)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ...blockTemplates.map((tpl) {
          final cardWidget = Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator,
                    color: Colors.black38, size: 18),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFEE2E2),
                  child: Icon(tpl['icon'] as IconData,
                      color: const Color(0xFFDC2626), size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tpl['title'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      Text(
                        tpl['desc'] as String,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sayfaya Ekle',
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFFDC2626), size: 20),
                  onPressed: () =>
                      _insertNewBlockAt(sections.length, tpl),
                ),
              ],
            ),
          );

          return Draggable<Map<String, dynamic>>(
            data: tpl,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 290, child: cardWidget),
            ),
            child: cardWidget,
          );
        }),
        const SizedBox(height: 14),
        const Text(
          '3. MEVCUT SAYFA AKIŞI (SÜRÜKLE SIRALA)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          onReorder: _reorderSections,
          itemBuilder: (ctx, idx) {
            final sec = sections[idx];
            final secId = sec['id']?.toString() ?? 'sec_$idx';
            final isSel = _selectedSectionId == secId;
            return Card(
              key: ValueKey(secId),
              color: isSel ? const Color(0xFFFEE2E2) : Colors.white,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () {
                  setState(() {
                    _selectedSectionId = secId;
                    _selectedElementId = null;
                    _editorSidebarTab = 'inspector';
                  });
                },
                leading: const Icon(Icons.drag_handle, size: 18),
                title: Text(
                  sec['title']?.toString() ?? 'Bölüm',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedSectionId = secId;
                      _selectedElementId = null;
                      _editorSidebarTab = 'inspector';
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Sol Panel 2: Seçili Bölüm veya Seçili Serbest Eleman Düzenleyici (Inspector)
  Widget _buildInspectorTab(Map<String, dynamic> page) {
    final floatingList = (page['floating_elements'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final selectedFloatingIdx = floatingList
        .indexWhere((e) => e['id']?.toString() == _selectedElementId);

    // Eğer serbest sürüklenen bir eleman seçildiyse onun özelliklerini düzenle
    if (selectedFloatingIdx >= 0) {
      final el = floatingList[selectedFloatingIdx];
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seçili Serbest Eleman',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () =>
                    _deleteFloatingElement(el['id'].toString()),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Sil'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Konum: X = ${(el['dx'] as num? ?? 0).toStringAsFixed(0)} px, Y = ${(el['dy'] as num? ?? 0).toStringAsFixed(0)} px\n(Önizleme üzerinde fare/dokunma ile istediğiniz yere sürükleyebilirsiniz)',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('el_text_${el['id']}'),
            initialValue: el['text']?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'Metin / Başlık'),
            onChanged: (v) {
              setState(() {
                el['text'] = v;
                floatingList[selectedFloatingIdx] = el;
                page['floating_elements'] = floatingList;
              });
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('el_sub_${el['id']}'),
            initialValue: el['subtext']?.toString() ?? '',
            decoration:
                const InputDecoration(labelText: 'Alt Metin / Fiyat'),
            onChanged: (v) {
              setState(() {
                el['subtext'] = v;
                floatingList[selectedFloatingIdx] = el;
                page['floating_elements'] = floatingList;
              });
            },
          ),
          if (el['element_type'] == 'image_box') ...[
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('el_img_${el['id']}'),
              initialValue: el['image_url']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Görsel URL'),
              onChanged: (v) {
                setState(() {
                  el['image_url'] = v;
                  floatingList[selectedFloatingIdx] = el;
                  page['floating_elements'] = floatingList;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          const Text('Eleman Rengi:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              '#DC2626',
              '#16A34A',
              '#2563EB',
              '#D97706',
              '#0F172A',
              '#7C3AED',
            ].map((hex) {
              final c = Color(
                  int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              return GestureDetector(
                onTap: () {
                  setState(() {
                    el['color_hex'] = hex;
                    floatingList[selectedFloatingIdx] = el;
                    page['floating_elements'] = floatingList;
                  });
                },
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: c,
                  child: el['color_hex'] == hex
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    // Seçili Bölüm (Section) Düzenleyici
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final secIdx = sections
        .indexWhere((s) => s['id']?.toString() == _selectedSectionId);

    if (secIdx < 0) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Düzenlemek için sağdaki canlı önizleme üzerinden bir bölüme veya sürüklenebilir elemana tıklayın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final sec = sections[secIdx];
    final secType = sec['type']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Bölüm: ${sec['title'] ?? secType}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Bu Bölümü Sil',
              onPressed: () => _deleteSectionById(sec['id'].toString()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('sec_title_${sec['id']}'),
          initialValue: sec['title']?.toString() ?? '',
          decoration:
              const InputDecoration(labelText: 'Bölüm Etiketi (Editör İçi)'),
          onChanged: (v) {
            setState(() {
              sec['title'] = v;
              sections[secIdx] = sec;
              page['sections'] = sections;
            });
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('sec_ctitle_${sec['id']}'),
          initialValue: sec['custom_title']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Görünür Başlık (Boşsa varsayılan kullanılır)',
          ),
          onChanged: (v) {
            setState(() {
              sec['custom_title'] = v;
              sections[secIdx] = sec;
              page['sections'] = sections;
            });
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('sec_csub_${sec['id']}'),
          initialValue: sec['custom_subtitle']?.toString() ?? '',
          decoration:
              const InputDecoration(labelText: 'Alt Başlık / Slogan'),
          onChanged: (v) {
            setState(() {
              sec['custom_subtitle'] = v;
              sections[secIdx] = sec;
              page['sections'] = sections;
            });
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('sec_cdesc_${sec['id']}'),
          initialValue: sec['custom_description']?.toString() ?? '',
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Açıklama / İçerik Metni',
          ),
          onChanged: (v) {
            setState(() {
              sec['custom_description'] = v;
              sections[secIdx] = sec;
              page['sections'] = sections;
            });
          },
        ),
        if (secType == 'hero_banner' ||
            secType == 'promo_banner' ||
            secType == 'free_canvas') ...[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('sec_img_${sec['id']}'),
            initialValue: sec['image_url']?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Arka Plan Görsel URL',
              hintText: 'https://...',
            ),
            onChanged: (v) {
              setState(() {
                sec['image_url'] = v;
                sections[secIdx] = sec;
                page['sections'] = sections;
              });
            },
          ),
        ],
        if (secType == 'products') ...[
          const SizedBox(height: 12),
          const Text('Ürün Vitrini Sütun Sayısı:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2 Sütun')),
              ButtonSegment(value: 3, label: Text('3 Sütun')),
              ButtonSegment(value: 4, label: Text('4 Sütun')),
            ],
            selected: {_asInt(sec['columns']) > 0 ? _asInt(sec['columns']) : 3},
            onSelectionChanged: (s) {
              setState(() {
                sec['columns'] = s.first;
                sections[secIdx] = sec;
                page['sections'] = sections;
              });
            },
          ),
        ],
        if (secType == 'contact') ...[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('sec_phone_${sec['id']}'),
            initialValue: sec['phone']?.toString() ?? '0850 300 00 00',
            decoration: const InputDecoration(labelText: 'İletişim Telefonu'),
            onChanged: (v) {
              setState(() {
                sec['phone'] = v;
                sections[secIdx] = sec;
                page['sections'] = sections;
              });
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('sec_wa_${sec['id']}'),
            initialValue: sec['whatsapp']?.toString() ?? '905300000000',
            decoration:
                const InputDecoration(labelText: 'WhatsApp Numarası'),
            onChanged: (v) {
              setState(() {
                sec['whatsapp'] = v;
                sections[secIdx] = sec;
                page['sections'] = sections;
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Hero Eleman Konumlarını Sıfırla'),
          onPressed: () {
            setState(() {
              page['element_positions'] = <String, dynamic>{};
            });
          },
        ),
      ],
    );
  }

  /// Sol Panel 3: Genel Subdomain & Tema Ayarları
  Widget _buildPageSettingsTab(Map<String, dynamic> page) {
    final categories = [
      'Tema Kasaphane',
      'Şarküteri',
      'Tema Mandıra',
      'Tema Fırın',
      'Tema Bakliyat',
      'Tema İnşaat',
      'Manav',
      'Temel Gıda',
    ];
    final currentCat = categories.contains(page['category']?.toString())
        ? page['category'].toString()
        : 'Tema Kasaphane';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Genel Subdomain & Tema Ayarları',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('pg_title_${page['id']}'),
          initialValue: page['title']?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Sayfa Başlığı *'),
          onChanged: (v) => setState(() => page['title'] = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('pg_sub_${page['id']}'),
          initialValue: page['subdomain']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Subdomain Adresi *',
            prefixText: 'https://',
            suffixText: '.temamarket.com',
          ),
          onChanged: (v) {
            final clean =
                v.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '');
            setState(() {
              page['subdomain'] = clean;
              page['domain'] = '$clean.temamarket.com';
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: currentCat,
          decoration:
              const InputDecoration(labelText: 'Eşleşen Reyon / Kategori'),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => page['category'] = val);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('pg_slogan_${page['id']}'),
          initialValue: page['slogan']?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Ana Slogan'),
          onChanged: (v) => setState(() => page['slogan'] = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('pg_desc_${page['id']}'),
          initialValue: page['description']?.toString() ?? '',
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Sayfa Açıklaması'),
          onChanged: (v) => setState(() => page['description'] = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('pg_hero_${page['id']}'),
          initialValue: page['hero_image']?.toString() ?? '',
          decoration:
              const InputDecoration(labelText: 'Hero Kapak Görsel URL'),
          onChanged: (v) => setState(() => page['hero_image'] = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('pg_info_${page['id']}'),
          initialValue: page['custom_info']?.toString() ?? '',
          decoration: const InputDecoration(
              labelText: 'Özellik Şeridi (• ile ayırın)'),
          onChanged: (v) => setState(() => page['custom_info'] = v),
        ),
        const SizedBox(height: 12),
        const Text('Marka Rengi:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '#DC2626',
            '#B45309',
            '#D97706',
            '#EA580C',
            '#15803D',
            '#0F172A',
            '#2563EB',
            '#7C3AED',
          ].map((hex) {
            final c = Color(
                int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
            return GestureDetector(
              onTap: () => setState(() => page['color_hex'] = hex),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: c,
                child: (page['color_hex']?.toString().toUpperCase() == hex)
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Subdomain Yayında (Aktif)'),
          value: page['is_active'] != false,
          onChanged: (v) => setState(() => page['is_active'] = v),
        ),
        const Divider(),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => _confirmDeleteSubdomain(
              _asInt(page['id']), page['title']?.toString() ?? 'Sayfa'),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Bu Subdomain Sayfasını Sil'),
        ),
      ],
    );
  }

  /// Sağ Alan: Canlı Sayfa Önizlemesi (Live Interactive Drag & Drop Page Preview)
  Widget _buildLivePagePreviewPane(Map<String, dynamic> page, String domain) {
    double maxPreviewWidth;
    switch (_previewDevice) {
      case 'mobile':
        maxPreviewWidth = 410;
        break;
      case 'tablet':
        maxPreviewWidth = 768;
        break;
      case 'desktop':
      default:
        maxPreviewWidth = 1200;
    }

    return Container(
      color: const Color(0xFFE2E8F0),
      child: Column(
        children: [
          // Tarayıcı & Cihaz Önizleme Üst Çubuğu
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(
                            'https://$domain',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '💡 İpucu: Elemanları ve blokları önizleme üzerinde istediğiniz yere sürükleyin',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Masaüstü Görünümü',
                      icon: Icon(
                        Icons.desktop_windows_outlined,
                        color: _previewDevice == 'desktop'
                            ? const Color(0xFFDC2626)
                            : Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _previewDevice = 'desktop'),
                    ),
                    IconButton(
                      tooltip: 'Tablet Görünümü',
                      icon: Icon(
                        Icons.tablet_mac_outlined,
                        color: _previewDevice == 'tablet'
                            ? const Color(0xFFDC2626)
                            : Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _previewDevice = 'tablet'),
                    ),
                    IconButton(
                      tooltip: 'Mobil Görünümü',
                      icon: Icon(
                        Icons.phone_iphone_outlined,
                        color: _previewDevice == 'mobile'
                            ? const Color(0xFFDC2626)
                            : Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _previewDevice = 'mobile'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_full, size: 15),
                      label: const Text('Tam Ekran Önizle',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _openSubdomainPreview(page),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Canlı Sayfa Önizleme Çerçevesi
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                constraints: BoxConstraints(maxWidth: maxPreviewWidth),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: SubdomainLandingPage(
                  key: ValueKey(
                      'preview_${page['subdomain']}_${page['color_hex']}'),
                  subdomainSlug: page['subdomain']?.toString() ?? 'kasap',
                  initialData: page,
                  isEditorMode: true,
                  selectedSectionId: _selectedSectionId,
                  selectedElementId: _selectedElementId,
                  onSelectSection: (secId) {
                    setState(() {
                      _selectedSectionId = secId;
                      _selectedElementId = null;
                      _editorSidebarTab = 'inspector';
                    });
                  },
                  onSelectElement: (elId) {
                    setState(() {
                      _selectedElementId = elId;
                      if (!elId.startsWith('hero_')) {
                        _editorSidebarTab = 'inspector';
                      }
                    });
                  },
                  onReorderSections: _reorderSections,
                  onDropNewBlock: _insertNewBlockAt,
                  onDeleteSection: _deleteSectionById,
                  onToggleSectionVisibility: _toggleSectionVisibilityById,
                  onDragHeroElement: (elementKey, delta) {
                    setState(() {
                      final posMap = page['element_positions'] is Map
                          ? Map<String, dynamic>.from(
                              page['element_positions'] as Map)
                          : <String, dynamic>{};
                      final cur = posMap[elementKey] is Map
                          ? Map<String, dynamic>.from(
                              posMap[elementKey] as Map)
                          : <String, dynamic>{'dx': 0.0, 'dy': 0.0};
                      final nx = ((cur['dx'] as num? ?? 0.0).toDouble() +
                              delta.dx)
                          .clamp(-250.0, 500.0);
                      final ny = ((cur['dy'] as num? ?? 0.0).toDouble() +
                              delta.dy)
                          .clamp(-160.0, 260.0);
                      posMap[elementKey] = {'dx': nx, 'dy': ny};
                      page['element_positions'] = posMap;
                    });
                  },
                  onDragFloatingElement: (elId, delta) {
                    setState(() {
                      final list = (page['floating_elements'] as List?)
                              ?.whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList() ??
                          [];
                      final idx = list.indexWhere(
                          (e) => e['id']?.toString() == elId);
                      if (idx >= 0) {
                        final curX =
                            (list[idx]['dx'] as num? ?? 24.0).toDouble();
                        final curY =
                            (list[idx]['dy'] as num? ?? 24.0).toDouble();
                        list[idx]['dx'] =
                            (curX + delta.dx).clamp(0.0, 850.0);
                        list[idx]['dy'] =
                            (curY + delta.dy).clamp(0.0, 850.0);
                        page['floating_elements'] = list;
                      }
                    });
                  },
                  onDropFloatingElement: _addFloatingElementToSection,
                  onDeleteFloatingElement: _deleteFloatingElement,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _reorderSections(int oldIndex, int newIndex) {
    final page = _editingPage;
    if (page == null) return;
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    if (oldIndex < 0 || oldIndex >= sections.length) return;
    int target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, sections.length - 1);
    setState(() {
      final item = sections.removeAt(oldIndex);
      sections.insert(target, item);
      page['sections'] = sections;
    });
  }

  void _insertNewBlockAt(int targetIndex, Map<String, dynamic> tpl) {
    final page = _editingPage;
    if (page == null) return;
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final newId = 'sec_${DateTime.now().millisecondsSinceEpoch}';
    final newBlock = <String, dynamic>{
      'id': newId,
      'type': tpl['type']?.toString() ?? 'custom_text',
      'title': tpl['title']?.toString() ?? 'Yeni Bölüm',
      'visible': true,
      if (tpl['type'] == 'products') 'columns': 3,
    };
    final safeIdx = targetIndex.clamp(0, sections.length);
    setState(() {
      sections.insert(safeIdx, newBlock);
      page['sections'] = sections;
      _selectedSectionId = newId;
      _selectedElementId = null;
      _editorSidebarTab = 'inspector';
    });
  }

  void _deleteSectionById(String secId) {
    final page = _editingPage;
    if (page == null) return;
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    setState(() {
      sections.removeWhere((s) => s['id']?.toString() == secId);
      page['sections'] = sections;
      if (_selectedSectionId == secId) {
        _selectedSectionId =
            sections.isNotEmpty ? sections.first['id']?.toString() : null;
      }
    });
  }

  void _toggleSectionVisibilityById(String secId) {
    final page = _editingPage;
    if (page == null) return;
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final idx = sections.indexWhere((s) => s['id']?.toString() == secId);
    if (idx >= 0) {
      setState(() {
        sections[idx]['visible'] = sections[idx]['visible'] == false;
        page['sections'] = sections;
      });
    }
  }

  void _addFloatingElementToSection(
    int sectionIndex,
    Map<String, dynamic> tpl,
    Offset localDropOffset,
  ) {
    final page = _editingPage;
    if (page == null) return;
    final sections = (page['sections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final targetSectionId = (sectionIndex >= 0 && sectionIndex < sections.length)
        ? sections[sectionIndex]['id']?.toString() ?? 'sec_hero'
        : (sections.isNotEmpty
            ? sections.first['id']?.toString() ?? 'sec_hero'
            : 'sec_hero');

    final floatingList = (page['floating_elements'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final newElId = 'el_${DateTime.now().millisecondsSinceEpoch}';
    final newEl = <String, dynamic>{
      'id': newElId,
      'section_id': targetSectionId,
      'element_type': tpl['element_type']?.toString() ?? 'badge',
      'text': tpl['text']?.toString() ?? 'Özel Etiket',
      'subtext': tpl['subtext']?.toString() ?? '',
      'image_url': tpl['image_url']?.toString() ?? '',
      'color_hex':
          tpl['color_hex']?.toString() ?? page['color_hex'] ?? '#DC2626',
      'dx': localDropOffset.dx.clamp(10.0, 600.0),
      'dy': localDropOffset.dy.clamp(10.0, 350.0),
    };

    setState(() {
      floatingList.add(newEl);
      page['floating_elements'] = floatingList;
      _selectedElementId = newElId;
      _editorSidebarTab = 'inspector';
    });
  }

  void _deleteFloatingElement(String elId) {
    final page = _editingPage;
    if (page == null) return;
    final floatingList = (page['floating_elements'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    setState(() {
      floatingList.removeWhere((e) => e['id']?.toString() == elId);
      page['floating_elements'] = floatingList;
      if (_selectedElementId == elId) _selectedElementId = null;
    });
  }

  void _showSubdomainDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final subCtrl =
        TextEditingController(text: existing?['subdomain']?.toString() ?? '');
    final catCtrl = TextEditingController(
        text: existing?['category']?.toString() ?? 'Tema Kasaphane');
    final sloganCtrl =
        TextEditingController(text: existing?['slogan']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final heroCtrl = TextEditingController(
        text: existing?['hero_image']?.toString() ??
            'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200');
    final colorCtrl = TextEditingController(
        text: existing?['color_hex']?.toString() ?? '#DC2626');
    final customInfoCtrl = TextEditingController(
        text: existing?['custom_info']?.toString() ??
            'Helal & Güvenilir • Yerli Üretim • Günlük Sevkiyat');
    bool isActive = existing?['is_active'] != false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            isEdit
                ? 'Subdomain Sayfasını Düzenle'
                : 'Yeni Subdomain Sayfası Oluştur',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sayfa Başlığı *',
                      hintText: 'Örn: Tema Manav veya Tema Pastane',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subdomain Adı *',
                      hintText: 'Örn: manav, pastane, toptan',
                      helperText:
                          'Adres: https://${subCtrl.text.trim().isEmpty ? '...' : subCtrl.text.trim().toLowerCase()}.temamarket.com',
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sloganCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Slogan / Kısa Tanıtım',
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
                      labelText: 'Hero Görsel URL',
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
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final sub = subCtrl.text
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                      if (title.isEmpty || sub.isEmpty) return;
                      setDlgState(() => saving = true);
                      final data = <String, dynamic>{
                        if (isEdit) 'id': existing['id'],
                        'title': title,
                        'subdomain': sub,
                        'domain': '$sub.temamarket.com',
                        'category': catCtrl.text.trim(),
                        'slogan': sloganCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'hero_image': heroCtrl.text.trim(),
                        'color_hex': colorCtrl.text.trim().isEmpty
                            ? '#DC2626'
                            : colorCtrl.text.trim(),
                        'custom_info': customInfoCtrl.text.trim(),
                        'is_active': isActive,
                      };
                      await ApiService.saveSubdomainPage(data);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();
                      final idx = _subdomainPages
                          .indexWhere((p) => p['subdomain'] == sub);
                      if (idx >= 0) {
                        setState(() => _selectSubdomainForEditing(idx));
                      }
                    },
              child: const Text('Oluştur ve Editörde Aç'),
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
        content:
            Text('"$title" sayfası ve subdomain yönlendirmesi silinecektir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteSubdomainPage(id);
              _selectedSubdomainIndex = 0;
              await _loadData();
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  7- İŞ BAŞVURULARI & AÇIK POZİSYONLAR YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _applicationList() {
    final statuses = [
      'Tümü',
      'Beklemede',
      'İncelendi',
      'Mülakata Çağrıldı',
      'Kabul Edildi',
      'Reddedildi'
    ];
    final filtered = _applicationStatusFilter == 'Tümü'
        ? _applications
        : _applications
            .where((a) =>
                (a['status']?.toString() ?? '') == _applicationStatusFilter)
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Açık Pozisyon Ekle'),
        onPressed: _showAddPositionDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Açık İş Pozisyonları Yönetimi
            Card(
              color: const Color(0xFF0F172A),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.work_outline,
                            color: Colors.amber, size: 26),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aktif Açık İş Pozisyonları (İlanlar)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _openPositions.map((pos) {
                        return Chip(
                          backgroundColor: Colors.white,
                          label: Text(
                            '${pos['title']} (${pos['branch'] ?? 'Tüm Şubeler'})',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          onDeleted: () async {
                            await ApiService.deleteOpenPosition(
                                _asInt(pos['id']));
                            _loadData();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Durum Filtreleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses
                    .map(
                      (st) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: _applicationStatusFilter == st,
                          onSelected: (_) =>
                              setState(() => _applicationStatusFilter = st),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Seçili filtrede iş başvurusu bulunmuyor.')),
              )
            else
              ...filtered.map((app) {
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
                            ? app['name']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase()
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () async {
                            await ApiService.deleteJobApplication(
                                _asInt(app['id']));
                            _loadData();
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Başvurulan Pozisyon:',
                    app['position']?.toString() ?? '-'),
                _detailRow('Telefon:', app['phone']?.toString() ?? '-'),
                _detailRow('E-posta:', app['email']?.toString() ?? '-'),
                _detailRow(
                    'İkametgah İlçesi:', app['district']?.toString() ?? '-'),
                _detailRow(
                    'Eğitim Durumu:', app['education']?.toString() ?? '-'),
                _detailRow(
                    'Başvuru Tarihi:', app['created_at']?.toString() ?? '-'),
                const Divider(height: 20),
                const Text('İş Deneyimi & Notlar:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: [
                    'Beklemede',
                    'İncelendi',
                    'Mülakata Çağrıldı',
                    'Kabul Edildi',
                    'Reddedildi'
                  ].contains(currentStatus)
                      ? currentStatus
                      : 'Beklemede',
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Beklemede', child: Text('⏳ Beklemede')),
                    DropdownMenuItem(
                        value: 'İncelendi', child: Text('👁️ İncelendi')),
                    DropdownMenuItem(
                      value: 'Mülakata Çağrıldı',
                      child: Text('📞 Mülakata Çağrıldı'),
                    ),
                    DropdownMenuItem(
                      value: 'Kabul Edildi',
                      child: Text('✅ Kabul Edildi'),
                    ),
                    DropdownMenuItem(
                      value: 'Reddedildi',
                      child: Text('❌ Reddedildi'),
                    ),
                  ],
                  onChanged: (val) async {
                    if (val != null) {
                      setDialogState(() => currentStatus = val);
                      setState(() {
                        app['status'] = val;
                      });
                      final id = _asInt(app['id']);
                      await ApiService.updateJobApplicationStatus(id, val);
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
            width: 135,
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
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPositionDialog() {
    final titleController = TextEditingController();
    final branchController = TextEditingController(text: 'Tüm Şubeler');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Açık Pozisyon Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Pozisyon Başlığı (Örn: Kasaphane Kasap Ustası)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: branchController,
              decoration: const InputDecoration(
                labelText: 'Görev Şubesi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final text = titleController.text.trim();
              if (text.isNotEmpty) {
                await ApiService.saveOpenPosition({
                  'title': text,
                  'branch': branchController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  8- TEMA KASAPHANE PANELİ (Kesim, Takip & Medya Yönetimi)
  // ─────────────────────────────────────────────────────────────
  Widget _kasaphaneList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Yeni Sevk Kaydı'),
        onPressed: () => _showAddKasaphaneRecordDialog(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
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
                ElevatedButton.icon(
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
                final id = _asInt(item['id']);
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
                                item['lot_no']?.toString() ??
                                    item['batch_no']?.toString() ??
                                    'Parti No',
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
                                item['status']?.toString() ??
                                    item['delivery_status']?.toString() ??
                                    'Durum',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.blue, size: 18),
                              onPressed: () =>
                                  _showAddKasaphaneRecordDialog(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              onPressed: () async {
                                await ApiService.deleteKasaphaneTracking(id);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _detailRow(
                          'Kesim Tarihi:',
                          item['date']?.toString() ??
                              item['slaughter_date']?.toString() ??
                              '-',
                        ),
                        _detailRow(
                          'Çiftlik / Tesis:',
                          item['farm']?.toString() ?? 'TEMA Besi Çiftliği',
                        ),
                        _detailRow(
                          'Veteriner Raporu:',
                          item['vet_report']?.toString() ??
                              item['vet_report_no']?.toString() ??
                              '-',
                        ),
                        _detailRow(
                          'Sevk Şubeleri:',
                          item['branches']?.toString() ?? '-',
                        ),
                        if ((item['note'] ?? item['notes'])
                                ?.toString()
                                .isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 6),
                          Text(
                            (item['note'] ?? item['notes']).toString(),
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

            const SizedBox(height: 16),
            const Text(
              'Yüklenen Kasaphane Fotoğraf & Videoları',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ..._kasaphaneMedia.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFEE2E2),
                      child: Icon(
                        m['type'] == 'Video'
                            ? Icons.videocam_outlined
                            : Icons.photo_camera_outlined,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    title: Text(
                      m['title']?.toString() ?? 'Medya',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${m['type']} • ${m['url']}'),
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ApiService.deleteKasaphaneMedia(
                            _asInt(m['id']));
                        _loadData();
                      },
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showAddKasaphaneRecordDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final lotController = TextEditingController(
      text: existing?['lot_no']?.toString() ??
          existing?['batch_no']?.toString() ??
          'TK-${DateTime.now().year}/GZ-0${_kasaphaneRecords.length + 1}',
    );
    final farmController = TextEditingController(
      text: existing?['farm']?.toString() ?? 'TEMA Palandöken Besi Çiftliği',
    );
    final vetController = TextEditingController(
      text: existing?['vet_report']?.toString() ??
          existing?['vet_report_no']?.toString() ??
          'VET-TR-25-0045 Onaylı',
    );
    final branchesController = TextEditingController(
      text: existing?['branches']?.toString() ?? 'Tüm Şubeler',
    );
    final noteController = TextEditingController(
      text: existing?['note']?.toString() ??
          existing?['notes']?.toString() ??
          '',
    );
    String status = existing?['status']?.toString() ??
        existing?['delivery_status']?.toString() ??
        'Şube Reyonlarına Ulaştı';
    const validStatuses = [
      'Kesim Aşamasında',
      'Soğuk Hava Dinlendirmede',
      'Soğuk Zincir Sevkiyatta',
      'Şube Reyonlarına Ulaştı',
    ];
    if (!validStatuses.contains(status)) {
      status = 'Şube Reyonlarına Ulaştı';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit
              ? 'Sevk Kaydını Düzenle'
              : 'Yeni Kesim / Sevk Takibi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lotController,
                  decoration:
                      const InputDecoration(labelText: 'Parti / Lot No'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: farmController,
                  decoration:
                      const InputDecoration(labelText: 'Çiftlik / Besi Yeri'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vetController,
                  decoration:
                      const InputDecoration(labelText: 'Veteriner Onay No'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: branchesController,
                  decoration:
                      const InputDecoration(labelText: 'Sevk Edilen Şubeler'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Sevk Durumu'),
                  items: validStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration:
                      const InputDecoration(labelText: 'Açıklama / Not'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final record = {
                  if (isEdit) 'id': existing['id'],
                  'lot_no': lotController.text.trim(),
                  'date': existing?['date'] ??
                      '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                  'farm': farmController.text.trim(),
                  'vet_report': vetController.text.trim(),
                  'branches': branchesController.text.trim(),
                  'status': status,
                  'note': noteController.text.trim(),
                };
                await ApiService.saveKasaphaneTracking(record);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
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
    final urlController = TextEditingController(
      text: 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
    );
    String type = 'Fotoğraf';

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
                  decoration:
                      const InputDecoration(labelText: 'Medya Başlığı *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Medya Türü'),
                  items: const [
                    DropdownMenuItem(value: 'Video', child: Text('Video')),
                    DropdownMenuItem(
                        value: 'Fotoğraf', child: Text('Fotoğraf')),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                await ApiService.saveKasaphaneMedia({
                  'title': titleController.text.trim(),
                  'type': type,
                  'url': urlController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Yükle & Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  9- TEMA İNŞAAT & GRUP ŞİRKETLERİ YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _corporateList() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Yeni Proje / Şirket Ekle'),
        onPressed: () => _showCorporateDialog(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
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
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.blue),
                              tooltip: 'Düzenle',
                              onPressed: () => _showCorporateDialog(corp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFDC2626)),
                              tooltip: 'Projeyi Sil',
                              onPressed: () async {
                                final id = _asInt(corp['id']);
                                await ApiService.deleteCorporateEntity(id);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                corp['status']?.toString() ?? 'Aktif',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          corp['description']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.link,
                                size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => launchUrl(Uri.parse(
                                  corp['website']?.toString() ??
                                      'https://temamarket.com')),
                              child: Text(
                                corp['website']?.toString() ?? '-',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tel: ${corp['contact'] ?? '0442 222 00 00'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
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

  void _showCorporateDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final catController = TextEditingController(
        text: existing?['category']?.toString() ?? 'İnşaat & Gayrimenkul');
    final statusController = TextEditingController(
        text: existing?['status']?.toString() ?? 'Aktif Faaliyette');
    final descController = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final webController = TextEditingController(
        text: existing?['website']?.toString() ??
            'https://insaat.temamarket.com');
    final phoneController = TextEditingController(
        text: existing?['contact']?.toString() ?? '0442 222 00 00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit
            ? 'Proje / Şirket Düzenle'
            : 'Yeni Şirket / Proje Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Proje / Şirket Adı *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catController,
                decoration:
                    const InputDecoration(labelText: 'Kategori / Sektör'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: statusController,
                decoration: const InputDecoration(labelText: 'Proje Durumu'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration:
                    const InputDecoration(labelText: 'Kısa Açıklama'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: webController,
                decoration:
                    const InputDecoration(labelText: 'Web Sitesi / Subdomain'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration:
                    const InputDecoration(labelText: 'İletişim Telefonu'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final newCorp = {
                if (isEdit) 'id': existing['id'],
                'title': titleController.text.trim(),
                'category': catController.text.trim(),
                'status': statusController.text.trim(),
                'description': descController.text.trim(),
                'website': webController.text.trim(),
                'contact': phoneController.text.trim(),
              };
              await ApiService.saveCorporateEntity(newCorp);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  10- ÖZELLİKLER (FEATURE FLAGS) YÖNETİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _featureList() {
    final entries = <(String, String, bool)>[
      ('sanal_market', 'Sanal Market & Online Sipariş', _flags.sanalMarket),
      ('bayi_stok', 'Bayi & Şube Anlık Stok Yönetimi', _flags.bayiStok),
      ('temapuan', 'Tema Avantaj Kart & TemaPuan', _flags.temapuan),
      ('kampanyalar', 'Kampanyalar & Aktüel Broşür', _flags.kampanyalar),
      (
        'api_entegrasyon',
        'ERP & Harici API Entegrasyonu',
        _flags.apiEntegrasyon
      ),
      ('sms_gonderim', 'OTP & Kampanya Toplu SMS', _flags.smsGonderim),
      ('sanal_pos', '3D Secure Online Sanal POS', _flags.sanalPos),
      ('soft_pos', 'Kurye Kapıda SoftPOS / NFC', _flags.softPos),
      ('e_fatura', 'GİB E-Fatura & E-Arşiv Entegrasyonu', _flags.eFatura),
      ('serbest_kurye', 'Serbest Kurye Havuzu Atama', _flags.serbestKurye),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          color: Color(0xFF0F172A),
          child: ListTile(
            leading: Icon(Icons.tune, color: Colors.amber),
            title: Text(
              'Sistem Modülleri & Özellik Anahtarları',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'Buradan açıp kapattığınız özellikler anında kaydedilir ve mağaza / bayi / kurye ekranlarına uygulanır.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) {
            final available = _featureAvailable(entry.$1);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                title: Text(
                  entry.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  _savingFlags.contains(entry.$1)
                      ? 'Kaydediliyor…'
                      : _featureReason(entry.$1),
                ),
                value: entry.$3,
                onChanged: !available || _savingFlags.contains(entry.$1)
                    ? null
                    : (value) => _toggleFlag(entry.$1, value),
              ),
            );
          },
        ),
      ],
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
