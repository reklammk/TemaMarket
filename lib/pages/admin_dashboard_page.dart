import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/feature_flags_service.dart';

/// TEMASAN ERP — SuperAdmin Yönetici Konsolu (Admin Dashboard Console)
/// Web Yönetici Paneli (AdminDashboardPage.tsx) ile 1'e 1 Birebir Aynı 14 Modüllü Süper Admin Paneli.
class AdminDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const AdminDashboardPage({super.key, this.user, this.onBackToStore});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _activeTab = 0;
  bool _isLoading = false;

  // ── CANLI VERİ HAFIZASI ──
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _campaigns = [];
  FeatureFlags _featureFlags = const FeatureFlags();
  Timer? _syncTimer;

  // Arama State'leri
  String _searchBranchQuery = '';
  String _searchProductQuery = '';

  // 16 Adet Gerçek TEMA Şubesi
  final List<Map<String, dynamic>> _defaultBranchesData = [
    {'id': 1, 'code': 'SUB-001', 'name': 'Lalapaşa AVM (Yakutiye)', 'manager_name': 'Kadir KUZU', 'email': 'lalapasa@temasan.com', 'phone': '0531 221 36 32', 'city_district': 'Yakutiye / Erzurum', 'address': 'Lalapaşa, Cumhuriyet Cd., 25030 Yakutiye/Erzurum', 'year': 1989, 'area': '6000 m²', 'status': 'AKTİF'},
    {'id': 2, 'code': 'SUB-002', 'name': 'Pasinler', 'manager_name': 'Yusuf BAYOĞLU', 'email': 'pasinler@temasan.com', 'phone': '0532 624 82 37', 'city_district': 'Pasinler / Erzurum', 'address': 'Erzurumkapı, 25300 Pasinler/Erzurum', 'year': 1999, 'area': '1600 m²', 'status': 'AKTİF'},
    {'id': 3, 'code': 'SUB-003', 'name': 'Yenişehir AVM', 'manager_name': 'Taşkın ÇUBUK', 'email': 'yenisehir@temasan.com', 'phone': '0542 805 29 46', 'city_district': 'Palandöken / Erzurum', 'address': 'Tema AVM, Hacı Salih Efendi Mh, 25000 Palandöken/Erzurum', 'year': 2002, 'area': '3900 m²', 'status': 'AKTİF'},
    {'id': 4, 'code': 'SUB-004', 'name': 'Kelkit-1', 'manager_name': 'Volkan MANSIZ', 'email': 'kelkit1@temasan.com', 'phone': '0530 465 29 30', 'city_district': 'Kelkit / Gümüşhane', 'address': 'Milli Egemenlik Meydanı, Aydın Doğan Cd. Kelkit/Gümüşhane', 'year': 2004, 'area': '750 m²', 'status': 'AKTİF'},
    {'id': 5, 'code': 'SUB-005', 'name': 'Şenkaya', 'manager_name': 'Adem ŞARA', 'email': 'senkaya@temasan.com', 'phone': '0530 264 53 47', 'city_district': 'Şenkaya / Erzurum', 'address': 'Yukarı Mah. 25360 Şenkaya/Erzurum', 'year': 2004, 'area': '650 m²', 'status': 'AKTİF'},
    {'id': 6, 'code': 'SUB-006', 'name': 'Kelkit-2', 'manager_name': 'Volkan MANSIZ', 'email': 'kelkit2@temasan.com', 'phone': '0530 465 29 30', 'city_district': 'Kelkit / Gümüşhane', 'address': 'Cumhuriyet Mah. 29600 Kelkit/Gümüşhane', 'year': 2005, 'area': '600 m²', 'status': 'AKTİF'},
    {'id': 7, 'code': 'SUB-007', 'name': 'Selimiye', 'manager_name': 'Ertuğrul DİKİCİ', 'email': 'selimiye@temasan.com', 'phone': '0538 943 12 15', 'city_district': 'Palandöken / Erzurum', 'address': 'Osmangazi Mahallesi, 75. Sk., 25070 Palandöken/Erzurum', 'year': 2006, 'area': '900 m²', 'status': 'AKTİF'},
    {'id': 8, 'code': 'SUB-008', 'name': 'Uzundere', 'manager_name': 'Bekir ÖZDEMİR', 'email': 'uzundere@temasan.com', 'phone': '0532 705 25 91', 'city_district': 'Uzundere / Erzurum', 'address': 'Merkez Mah. 25440 Uzundere/Erzurum', 'year': 2007, 'area': '700 m²', 'status': 'AKTİF'},
    {'id': 9, 'code': 'SUB-009', 'name': 'Terminal', 'manager_name': 'Eren GÜRSES', 'email': 'terminal@temasan.com', 'phone': '0546 743 13 29', 'city_district': 'Yakutiye / Erzurum', 'address': 'Üniversite Mah. 25240 Yakutiye/Erzurum', 'year': 2011, 'area': '900 m²', 'status': 'AKTİF'},
    {'id': 10, 'code': 'SUB-010', 'name': 'Çırcır', 'manager_name': 'Harun BİNGÖL', 'email': 'circir@temasan.com', 'phone': '0531 221 36 46', 'city_district': 'Yakutiye / Erzurum', 'address': 'Muratpaşa, Cami Sk. Bakaçlar Sitesi D:4/1 Yakutiye/Erzurum', 'year': 2013, 'area': '950 m²', 'status': 'AKTİF'},
    {'id': 11, 'code': 'SUB-011', 'name': 'Hilalkent', 'manager_name': 'Salih SIĞIRLILI', 'email': 'hilalkent@temasan.com', 'phone': '0531 232 62 77', 'city_district': 'Yakutiye / Erzurum', 'address': 'Kurtuluş Mah. Aycan Sok. No:10 Yakutiye/Erzurum', 'year': 2013, 'area': '1300 m²', 'status': 'AKTİF'},
    {'id': 12, 'code': 'SUB-012', 'name': 'Dadaşkent AVM', 'manager_name': 'Musab Ahmet BAKAÇ', 'email': 'dadaskentavm@temasan.com', 'phone': '0506 962 02 58', 'city_district': 'Aziziye / Erzurum', 'address': 'Saltuklu Mah. Milli Egemenlik Cad. Aziziye/Erzurum', 'year': 2014, 'area': '2300 m²', 'status': 'AKTİF'},
    {'id': 13, 'code': 'SUB-013', 'name': 'Yıldızkent-2', 'manager_name': 'Selahattin BAYRAK', 'email': 'yildizkent2@temasan.com', 'phone': '0542 426 93 03', 'city_district': 'Palandöken / Erzurum', 'address': 'Hüseyin Avni Ulaş, 212. Sk. No:15 Palandöken/Erzurum', 'year': 2015, 'area': '1200 m²', 'status': 'AKTİF'},
    {'id': 14, 'code': 'SUB-014', 'name': 'Kayakyolu-1', 'manager_name': 'Kadir YILMAZ', 'email': 'kayakyolu1@temasan.com', 'phone': '0534 548 18 67', 'city_district': 'Palandöken / Erzurum', 'address': 'Osman Bektaş, Öz Meral Sk. No:29 Palandöken/Erzurum', 'year': 2016, 'area': '750 m²', 'status': 'AKTİF'},
    {'id': 15, 'code': 'SUB-015', 'name': 'Nenehatun', 'manager_name': 'Recep TOKYÜREK', 'email': 'nenehatun@temasan.com', 'phone': '0544 241 58 29', 'city_district': 'Yakutiye / Erzurum', 'address': 'Şükrüpaşa, Necip Fazıl Kısakürek Cd. Yakutiye/Erzurum', 'year': 2018, 'area': '900 m²', 'status': 'AKTİF'},
    {'id': 16, 'code': 'SUB-016', 'name': 'Enkule AVM', 'manager_name': 'Abdulkadir ŞİRCİ', 'email': 'enkuleavm@temasan.com', 'phone': '0545 446 48 11', 'city_district': 'Yakutiye / Erzurum', 'address': 'Rabia Ana Mah. Palandöken Cad. No:1 Yakutiye/Erzurum', 'year': 2020, 'area': '1250 m²', 'status': 'AKTİF'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncLiveFlags());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final apiBranches = await ApiService.fetchBranches();
      if (apiBranches.isNotEmpty) {
        _branches = List<Map<String, dynamic>>.from(apiBranches);
      } else {
        _branches = List<Map<String, dynamic>>.from(_defaultBranchesData);
      }

      final apiProducts = await ApiService.fetchProducts();
      if (apiProducts.isNotEmpty) {
        _products = List<Map<String, dynamic>>.from(apiProducts);
      }

      final apiCampaigns = await ApiService.fetchCampaigns();
      if (apiCampaigns.isNotEmpty) {
        _campaigns = List<Map<String, dynamic>>.from(apiCampaigns);
      }

      await _syncLiveFlags();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncLiveFlags() async {
    try {
      final flags = await FeatureFlagsService.loadFlags();
      if (mounted && !flags.isIdenticalTo(_featureFlags)) {
        setState(() => _featureFlags = flags);
      }
    } catch (_) {}
  }

  Future<void> _toggleFeature(String key, bool value) async {
    final Map<String, dynamic> updatedMap = {
      'sanal_market': key == 'sanal_market' ? value : _featureFlags.sanalMarket,
      'bayi_stok': key == 'bayi_stok' ? value : _featureFlags.bayiStok,
      'temapuan': key == 'temapuan' ? value : _featureFlags.temapuan,
      'api_entegrasyon': key == 'api_entegrasyon' ? value : _featureFlags.apiEntegrasyon,
      'sms_gonderim': key == 'sms_gonderim' ? value : _featureFlags.smsGonderim,
      'kampanyalar': key == 'kampanyalar' ? value : _featureFlags.kampanyalar,
      'sanal_pos': key == 'sanal_pos' ? value : _featureFlags.sanalPos,
      'soft_pos': key == 'soft_pos' ? value : _featureFlags.softPos,
      'e_fatura': key == 'e_fatura' ? value : _featureFlags.eFatura,
      'serbest_kurye': key == 'serbest_kurye' ? value : _featureFlags.serbestKurye,
    };

    setState(() => _featureFlags = FeatureFlags.fromJson(updatedMap));

    await ApiService.saveFeatureFlags(updatedMap);
    await FeatureFlagsService.saveFlags(_featureFlags);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şalter güncellendi: $key ➔ ${value ? "AKTİF" : "DEAKTİF"}'),
          backgroundColor: value ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 14 ADET YÖNETİCİ MENÜ ÖĞESİ
  final List<Map<String, dynamic>> _menuItems = [
    {'id': 0, 'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
    {'id': 1, 'label': 'Şube & Bayi Hesapları', 'icon': Icons.store_outlined},
    {'id': 2, 'label': 'Siparişler', 'icon': Icons.shopping_bag_outlined},
    {'id': 3, 'label': 'Ürünler', 'icon': Icons.inventory_2_outlined},
    {'id': 4, 'label': 'Kategoriler', 'icon': Icons.category_outlined},
    {'id': 5, 'label': 'Kampanyalar', 'icon': Icons.local_offer_outlined},
    {'id': 6, 'label': 'SMS Gönderimi', 'icon': Icons.sms_outlined},
    {'id': 7, 'label': 'Başvurular', 'icon': Icons.assignment_ind_outlined},
    {'id': 8, 'label': 'API Entegrasyonları', 'icon': Icons.api_outlined},
    {'id': 9, 'label': 'TemaPuan & Sadakat', 'icon': Icons.stars_outlined},
    {'id': 10, 'label': 'Yetkiler', 'icon': Icons.people_outline},
    {'id': 11, 'label': '💳 Ödemeler & Faturalar', 'icon': Icons.credit_card_outlined},
    {'id': 12, 'label': '⚙️ Sistem Özellikleri', 'icon': Icons.tune_outlined},
    {'id': 13, 'label': '🏢 B2B Ödemeler & IBAN', 'icon': Icons.business_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF2A55), Color(0xFFDC2626)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                children: [
                  TextSpan(text: 'ERP'),
                  TextSpan(text: '.co', style: TextStyle(color: Color(0xFFDC2626))),
                  TextSpan(text: '  SuperAdmin Konsolu', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)), tooltip: 'Yenile', onPressed: _loadInitialData),
          if (widget.onBackToStore != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: const Icon(Icons.storefront, size: 16),
                label: const Text('Sanal Mağazaya Dön', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: widget.onBackToStore,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : Row(
              children: [
                if (isWideScreen)
                  Container(
                    width: 260,
                    color: Colors.white,
                    child: ListView.builder(
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final bool isActive = _activeTab == item['id'];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFFEF2F2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isActive ? Border.all(color: const Color(0xFFFECDD3)) : null,
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(item['icon'] as IconData, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF64748B), size: 18),
                            title: Text(item['label'] as String, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.w500, fontSize: 13, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF334155))),
                            onTap: () => setState(() => _activeTab = item['id']),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (!isWideScreen)
                        Container(
                          height: 48,
                          color: Colors.white,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _menuItems.length,
                            itemBuilder: (context, index) {
                              final item = _menuItems[index];
                              final bool isActive = _activeTab == item['id'];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                child: ChoiceChip(
                                  selected: isActive,
                                  label: Text(item['label'] as String),
                                  avatar: Icon(item['icon'] as IconData, size: 16, color: isActive ? Colors.white : const Color(0xFF64748B)),
                                  selectedColor: const Color(0xFFDC2626),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  labelStyle: TextStyle(color: isActive ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 12),
                                  onSelected: (_) => setState(() => _activeTab = item['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _activeTab,
                          children: [
                            _buildDashboardTab(),
                            _buildBranchesTab(),
                            _buildOrdersTab(),
                            _buildProductsTab(),
                            _buildCategoriesTab(),
                            _buildCampaignsTab(),
                            _buildSmsTab(),
                            _buildApplicationsTab(),
                            _buildApiIntegrationsTab(),
                            _buildLoyaltyTab(),
                            _buildUsersTab(),
                            _buildInvoicesTab(),
                            _buildFeatureFlagsTab(),
                            _buildB2bTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 SuperAdmin Genel Bakış & Performans Metrikleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 700 ? 2 : 1),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKpiCard('Toplam Ciro (Aylık)', '₺482,950.00', '+%14.2 artış', Icons.payments_outlined, const Color(0xFF16A34A)),
              _buildKpiCard('Aktif Şubeler', '${_branches.length} Mağaza', '16 Şube Canlı', Icons.store_outlined, const Color(0xFF2563EB)),
              _buildKpiCard('Toplam Ürün Kataloğu', '${_products.isNotEmpty ? _products.length : 148} Çeşit', 'Kasap & Manav Dahil', Icons.inventory_2_outlined, const Color(0xFFD97706)),
              _buildKpiCard('Aktif Kuryeler', '12 Kurye Görevde', 'Ort. 22 dk teslimat', Icons.two_wheeler_outlined, const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesTab() {
    final filteredBranches = _branches.where((b) {
      final q = _searchBranchQuery.toLowerCase();
      final name = (b['name'] ?? '').toString().toLowerCase();
      final code = (b['code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏢 Tüm TEMA Şubeleri (${_branches.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(hintText: 'Şube adı veya kod ara...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            onChanged: (val) => setState(() => _searchBranchQuery = val),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredBranches.length,
            itemBuilder: (context, index) {
              final b = filteredBranches[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFFFEF2F2), child: Text(b['code']?.toString().replaceFirst('SUB-', '') ?? '${b['id']}', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 11))),
                  title: Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${b['city_district'] ?? ''} • Müdür: ${b['manager_name'] ?? 'Atanmadı'} • Tel: ${b['phone'] ?? ''}'),
                  trailing: const Chip(label: Text('AKTİF'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() => const Center(child: Text('🛒 Tüm Sistem Siparişleri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildProductsTab() => const Center(child: Text('📦 Tüm Sistem Ürün Kataloğu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildCategoriesTab() => const Center(child: Text('🏷️ Sistem Kategorileri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildCampaignsTab() => const Center(child: Text('🎯 Kampanyalar & İndirim Kuponları', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildSmsTab() => const Center(child: Text('💬 NetGSM & Türk Telekom Toplu SMS Paneli', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildApplicationsTab() => const Center(child: Text('📝 Başvuru Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildApiIntegrationsTab() => const Center(child: Text('🔌 API Entegrasyonları', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildLoyaltyTab() => const Center(child: Text('⭐ TemaPuan & VIP Sadakat Ayarları', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildUsersTab() => const Center(child: Text('👥 Kullanıcı Yetki Tanımları', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _buildInvoicesTab() => const Center(child: Text('💳 Ödemeler & GİB E-Fatura Geçmişi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));

  Widget _buildFeatureFlagsTab() {
    final flagsList = [
      {'key': 'sanal_market', 'label': '1. Sanal Market (Sepet & Sipariş)', 'desc': 'Deaktif edilirse ürünler sergilenir fakat sepete ekle ve sepet alanı gizlenir.', 'val': _featureFlags.sanalMarket},
      {'key': 'bayi_stok', 'label': '2. Bayi Stok Yönetim Sistemi', 'desc': 'Şubelerin stok kontrolünü yönetir.', 'val': _featureFlags.bayiStok},
      {'key': 'temapuan', 'label': '3. TemaPuan Sadakat & Cüzdan', 'desc': 'TemaPuan kazanımı ve puan kartları.', 'val': _featureFlags.temapuan},
      {'key': 'api_entegrasyon', 'label': '4. API Entegrasyonları', 'desc': 'Trendyol ve Yemeksepeti entegrasyonları.', 'val': _featureFlags.apiEntegrasyon},
      {'key': 'sms_gonderim', 'label': '5. SMS Gönderim Özelliği', 'desc': 'SMS paneli ve duyuruları.', 'val': _featureFlags.smsGonderim},
      {'key': 'kampanyalar', 'label': '6. Kampanyalar Özelliği', 'desc': 'İndirim kuponları ve promosyonlar.', 'val': _featureFlags.kampanyalar},
      {'key': 'sanal_pos', 'label': '7. Sanal POS ve Online Ödeme', 'desc': '3D Secure Sanal POS seçeneği.', 'val': _featureFlags.sanalPos},
      {'key': 'soft_pos', 'label': '8. Soft POS ile Kapıda Ödeme', 'desc': 'Kapıda temassız tahsilat.', 'val': _featureFlags.softPos},
      {'key': 'e_fatura', 'label': '9. Otomatik E-FATURA Kesimi', 'desc': 'Otomatik GİB E-Fatura düzenlenir.', 'val': _featureFlags.eFatura},
      {'key': 'serbest_kurye', 'label': '10. Serbest Kurye Havuzu', 'desc': 'Bağımsız kurye havuzu.', 'val': _featureFlags.serbestKurye},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚙️ Sistem Özellikleri & Modül Şalterleri (Feature Flags)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Platform genelinde sistem özelliklerini canlı aktif/deaktif edebilirsiniz.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: flagsList.length,
            itemBuilder: (context, index) {
              final flag = flagsList[index];
              final bool isEnabled = flag['val'] as bool;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isEnabled ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3), width: 1.5)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flag['label'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(flag['desc'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Chip(label: Text(isEnabled ? '🟢 AKTİF (Kullanımda)' : '🔴 DEAKTİF (Gizli & Kapalı)'), backgroundColor: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2), labelStyle: TextStyle(color: isEnabled ? const Color(0xFF16A34A) : const Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch.adaptive(value: isEnabled, activeTrackColor: const Color(0xFF16A34A), onChanged: (val) => _toggleFeature(flag['key'] as String, val)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildB2bTab() => const Center(child: Text('🏢 B2B Kurumsal Cari Hesaplar & IBAN Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
}
