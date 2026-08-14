import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';

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
  FeatureFlags _flags = const FeatureFlags();
  Map<String, dynamic> _capabilities = {};
  final Set<String> _savingFlags = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
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
      ]);
      if (!mounted) return;
      final configuration = Map<String, dynamic>.from(results[5] as Map);
      final rawFlags = configuration['flags'];
      setState(() {
        _metrics = Map<String, dynamic>.from(results[0] as Map);
        _branches = _maps(results[1] as List<dynamic>);
        _orders = _maps(results[2] as List<dynamic>);
        _products = _maps(results[3] as List<dynamic>);
        _campaigns = _maps(results[4] as List<dynamic>);
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
        title: const Text('TEMASAN Yönetim',
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
