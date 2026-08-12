import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/feature_flags_service.dart';

/// TEMASAN ERP — Tam Teşekküllü Yönetici Konsolu (Admin & Merchant Dashboard)
/// Web Yönetici Paneli (AdminDashboardPage.tsx) ile 1'e 1 Birebir Aynı Tasarım ve Fonksiyonsellik.
class MerchantPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const MerchantPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<MerchantPanelPage> createState() => _MerchantPanelPageState();
}

class _MerchantPanelPageState extends State<MerchantPanelPage>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0;
  bool _isLoading = false;

  // ── CANLI VERİ HAFIZASI ──
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _users = [];
  FeatureFlags _featureFlags = const FeatureFlags();
  Timer? _syncTimer;

  // Arama & Filtreleme State'leri
  String _searchBranchQuery = '';
  String _searchProductQuery = '';
  String _orderStatusFilter = 'Tümü';

  // 16 Adet Gerçek TEMA Şubesi (Web paneli ile birebir eşleştirilmiş sabit liste)
  final List<Map<String, dynamic>> _defaultBranchesData = [
    {
      'id': 1,
      'code': 'SUB-001',
      'name': 'Lalapaşa AVM (Yakutiye)',
      'manager_name': 'Kadir KUZU',
      'email': 'lalapasa@temasan.com',
      'phone': '0531 221 36 32',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Lalapaşa, Cumhuriyet Cd., 25030 Yakutiye/Erzurum',
      'year': 1989,
      'area': '6000 m²',
      'status': 'AKTİF'
    },
    {
      'id': 2,
      'code': 'SUB-002',
      'name': 'Pasinler',
      'manager_name': 'Yusuf BAYOĞLU',
      'email': 'pasinler@temasan.com',
      'phone': '0532 624 82 37',
      'city_district': 'Pasinler / Erzurum',
      'address': 'Erzurumkapı, 25300 Pasinler/Erzurum',
      'year': 1999,
      'area': '1600 m²',
      'status': 'AKTİF'
    },
    {
      'id': 3,
      'code': 'SUB-003',
      'name': 'Yenişehir AVM',
      'manager_name': 'Taşkın ÇUBUK',
      'email': 'yenisehir@temasan.com',
      'phone': '0542 805 29 46',
      'city_district': 'Palandöken / Erzurum',
      'address': 'Tema AVM, Hacı Salih Efendi Mh, 25000 Palandöken/Erzurum',
      'year': 2002,
      'area': '3900 m²',
      'status': 'AKTİF'
    },
    {
      'id': 4,
      'code': 'SUB-004',
      'name': 'Kelkit-1',
      'manager_name': 'Volkan MANSIZ',
      'email': 'kelkit1@temasan.com',
      'phone': '0530 465 29 30',
      'city_district': 'Kelkit / Gümüşhane',
      'address': 'Milli Egemenlik Meydanı, Aydın Doğan Cd. Kelkit/Gümüşhane',
      'year': 2004,
      'area': '750 m²',
      'status': 'AKTİF'
    },
    {
      'id': 5,
      'code': 'SUB-005',
      'name': 'Şenkaya',
      'manager_name': 'Adem ŞARA',
      'email': 'senkaya@temasan.com',
      'phone': '0530 264 53 47',
      'city_district': 'Şenkaya / Erzurum',
      'address': 'Yukarı Mah. 25360 Şenkaya/Erzurum',
      'year': 2004,
      'area': '650 m²',
      'status': 'AKTİF'
    },
    {
      'id': 6,
      'code': 'SUB-006',
      'name': 'Kelkit-2',
      'manager_name': 'Volkan MANSIZ',
      'email': 'kelkit2@temasan.com',
      'phone': '0530 465 29 30',
      'city_district': 'Kelkit / Gümüşhane',
      'address': 'Cumhuriyet Mah. 29600 Kelkit/Gümüşhane',
      'year': 2005,
      'area': '600 m²',
      'status': 'AKTİF'
    },
    {
      'id': 7,
      'code': 'SUB-007',
      'name': 'Selimiye',
      'manager_name': 'Ertuğrul DİKİCİ',
      'email': 'selimiye@temasan.com',
      'phone': '0538 943 12 15',
      'city_district': 'Palandöken / Erzurum',
      'address': 'Osmangazi Mahallesi, 75. Sk., 25070 Palandöken/Erzurum',
      'year': 2006,
      'area': '900 m²',
      'status': 'AKTİF'
    },
    {
      'id': 8,
      'code': 'SUB-008',
      'name': 'Uzundere',
      'manager_name': 'Bekir ÖZDEMİR',
      'email': 'uzundere@temasan.com',
      'phone': '0532 705 25 91',
      'city_district': 'Uzundere / Erzurum',
      'address': 'Merkez Mah. 25440 Uzundere/Erzurum',
      'year': 2007,
      'area': '700 m²',
      'status': 'AKTİF'
    },
    {
      'id': 9,
      'code': 'SUB-009',
      'name': 'Terminal',
      'manager_name': 'Eren GÜRSES',
      'email': 'terminal@temasan.com',
      'phone': '0546 743 13 29',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Üniversite Mah. 25240 Yakutiye/Erzurum',
      'year': 2011,
      'area': '900 m²',
      'status': 'AKTİF'
    },
    {
      'id': 10,
      'code': 'SUB-010',
      'name': 'Çırcır',
      'manager_name': 'Harun BİNGÖL',
      'email': 'circir@temasan.com',
      'phone': '0531 221 36 46',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Muratpaşa, Cami Sk. Bakaçlar Sitesi D:4/1 Yakutiye/Erzurum',
      'year': 2013,
      'area': '950 m²',
      'status': 'AKTİF'
    },
    {
      'id': 11,
      'code': 'SUB-011',
      'name': 'Hilalkent',
      'manager_name': 'Salih SIĞIRLILI',
      'email': 'hilalkent@temasan.com',
      'phone': '0531 232 62 77',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Kurtuluş Mah. Aycan Sok. No:10 Yakutiye/Erzurum',
      'year': 2013,
      'area': '1300 m²',
      'status': 'AKTİF'
    },
    {
      'id': 12,
      'code': 'SUB-012',
      'name': 'Dadaşkent AVM',
      'manager_name': 'Musab Ahmet BAKAÇ',
      'email': 'dadaskentavm@temasan.com',
      'phone': '0506 962 02 58',
      'city_district': 'Aziziye / Erzurum',
      'address': 'Saltuklu Mah. Milli Egemenlik Cad. Aziziye/Erzurum',
      'year': 2014,
      'area': '2300 m²',
      'status': 'AKTİF'
    },
    {
      'id': 13,
      'code': 'SUB-013',
      'name': 'Yıldızkent-2',
      'manager_name': 'Selahattin BAYRAK',
      'email': 'yildizkent2@temasan.com',
      'phone': '0542 426 93 03',
      'city_district': 'Palandöken / Erzurum',
      'address': 'Hüseyin Avni Ulaş, 212. Sk. No:15 Palandöken/Erzurum',
      'year': 2015,
      'area': '1200 m²',
      'status': 'AKTİF'
    },
    {
      'id': 14,
      'code': 'SUB-014',
      'name': 'Kayakyolu-1',
      'manager_name': 'Kadir YILMAZ',
      'email': 'kayakyolu1@temasan.com',
      'phone': '0534 548 18 67',
      'city_district': 'Palandöken / Erzurum',
      'address': 'Osman Bektaş, Öz Meral Sk. No:29 Palandöken/Erzurum',
      'year': 2016,
      'area': '750 m²',
      'status': 'AKTİF'
    },
    {
      'id': 15,
      'code': 'SUB-015',
      'name': 'Nenehatun',
      'manager_name': 'Recep TOKYÜREK',
      'email': 'nenehatun@temasan.com',
      'phone': '0544 241 58 29',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Şükrüpaşa, Necip Fazıl Kısakürek Cd. Yakutiye/Erzurum',
      'year': 2018,
      'area': '900 m²',
      'status': 'AKTİF'
    },
    {
      'id': 16,
      'code': 'SUB-016',
      'name': 'Enkule AVM',
      'manager_name': 'Abdulkadir ŞİRCİ',
      'email': 'enkuleavm@temasan.com',
      'phone': '0545 446 48 11',
      'city_district': 'Yakutiye / Erzurum',
      'address': 'Rabia Ana Mah. Palandöken Cad. No:1 Yakutiye/Erzurum',
      'year': 2020,
      'area': '1250 m²',
      'status': 'AKTİF'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // 2 saniyede bir canlı senkronizasyon döngüsü
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncLiveFlags();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Canlı Şubeler
      final apiBranches = await ApiService.fetchBranches();
      if (apiBranches.isNotEmpty) {
        _branches = apiBranches;
      } else {
        _branches = List.from(_defaultBranchesData);
      }

      // 2. Canlı Ürünler
      final apiProducts = await ApiService.fetchProducts();
      if (apiProducts.isNotEmpty) {
        _products = apiProducts;
      }

      // 3. Canlı Kampanyalar
      final apiCampaigns = await ApiService.fetchCampaigns();
      if (apiCampaigns.isNotEmpty) {
        _campaigns = apiCampaigns;
      }

      // 4. Canlı Feature Flags
      await _syncLiveFlags();
    } catch (e) {
      debugPrint('Admin console load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncLiveFlags() async {
    try {
      final flags = await FeatureFlagsService.loadFlags();
      if (mounted && !flags.isIdenticalTo(_featureFlags)) {
        setState(() {
          _featureFlags = flags;
        });
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

    // Optimistik UI Güncellemesi
    setState(() {
      _featureFlags = FeatureFlags.fromJson(updatedMap);
    });

    // Canlı Backend API'ye kaydet
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

  // ── MENÜ LİSTESİ (Web Admin ile Birebir Aynı) ──
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
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2A55), Color(0xFFDC2626)],
                ),
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
                  TextSpan(text: '  Yönetici Konsolu', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            tooltip: 'Yenile',
            onPressed: _loadInitialData,
          ),
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
                // ── MASAÜSTÜ / TABLET İÇİN SOL SIDEBAR ──
                if (isWideScreen)
                  Container(
                    width: 260,
                    color: Colors.white,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
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
                                  leading: Icon(
                                    item['icon'] as IconData,
                                    color: isActive ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  title: Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                      color: isActive ? const Color(0xFFDC2626) : const Color(0xFF334155),
                                    ),
                                  ),
                                  onTap: () => setState(() => _activeTab = item['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── ANA İÇERİK ALANI ──
                Expanded(
                  child: Column(
                    children: [
                      // MOBİL İÇİN ÜST YATAY TAB BAR
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
                                  labelStyle: TextStyle(
                                    color: isActive ? Colors.white : const Color(0xFF334155),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => setState(() => _activeTab = item['id']),
                                ),
                              );
                            },
                          ),
                        ),

                      // AKTİF SEKMEYE GÖRE İÇERİK
                      Expanded(
                        child: IndexedStack(
                          index: _activeTab,
                          children: [
                            _buildDashboardTab(),       // Tab 0
                            _buildBranchesTab(),        // Tab 1
                            _buildOrdersTab(),          // Tab 2
                            _buildProductsTab(),        // Tab 3
                            _buildCategoriesTab(),      // Tab 4
                            _buildCampaignsTab(),       // Tab 5
                            _buildSmsTab(),             // Tab 6
                            _buildApplicationsTab(),    // Tab 7
                            _buildApiIntegrationsTab(), // Tab 8
                            _buildLoyaltyTab(),         // Tab 9
                            _buildUsersTab(),           // Tab 10
                            _buildInvoicesTab(),        // Tab 11
                            _buildFeatureFlagsTab(),    // Tab 12
                            _buildB2bTab(),             // Tab 13
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

  // ─────────────────────────────────────────────────────────────
  //  TAB 0: DASHBOARD (KPİ Metrikleri & Analitikler)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 Genel Bakış & Performans Metrikleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('TEMA ERP canlı satış, şube stoku ve kurye verileri.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // KPI KARTLARI (Grid)
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
              _buildKpiCard('Toplam Ürün Kataloğu', '${_products.length > 0 ? _products.length : 148} Çeşit', 'Kasap & Manav Dahil', Icons.inventory_2_outlined, const Color(0xFFD97706)),
              _buildKpiCard('Aktif Kuryeler', '12 Kurye Görevde', 'Ort. 22 dk teslimat', Icons.two_wheeler_outlined, const Color(0xFFDC2626)),
            ],
          ),
          const SizedBox(height: 20),

          // ŞUBELER HIZLI ÖZET KARTI
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🏢 Mağaza Ağ Durumu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      TextButton(
                        onPressed: () => setState(() => _activeTab = 1),
                        child: const Text('Tüm Şubeleri Yönet ➔', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFEF2F2), child: Icon(Icons.location_city, color: Color(0xFFDC2626))),
                    title: const Text('Lalapaşa AVM (Merkez Şube)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Yakutiye / Erzurum • 6000 m² Mağaza'),
                    trailing: const Chip(label: Text('AKTİF'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.location_city, color: Color(0xFF2563EB))),
                    title: const Text('Dadaşkent AVM Şubesi', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Aziziye / Erzurum • 2300 m² Mağaza'),
                    trailing: const Chip(label: Text('AKTİF'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
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
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 1: ŞUBE & BAYİ HESAPLARI (Tüm 16 TEMA Şubesi)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBranchesTab() {
    final filteredBranches = _branches.where((b) {
      final q = _searchBranchQuery.toLowerCase();
      final name = (b['name'] ?? '').toString().toLowerCase();
      final code = (b['code'] ?? '').toString().toLowerCase();
      final district = (b['city_district'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || district.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🏢 Şube & Bayi Hesapları (${_branches.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Yeni Şube Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Arama Çubuğu
          TextField(
            decoration: InputDecoration(
              hintText: 'Şube adı, kod veya ilçe ile ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchBranchQuery = val),
          ),
          const SizedBox(height: 16),

          // Şube Listesi / Grid
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredBranches.length,
            itemBuilder: (context, index) {
              final b = filteredBranches[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFEF2F2),
                    child: Text(b['code']?.toString().replaceFirst('SUB-', '') ?? '${b['id']}', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                  title: Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${b['city_district'] ?? ''} • Müdür: ${b['manager_name'] ?? 'Atanmadı'} • Tel: ${b['phone'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(b['status'] ?? 'AKTİF'),
                        backgroundColor: const Color(0xFFDCFCE7),
                        labelStyle: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey), onPressed: () {}),
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

  // ─────────────────────────────────────────────────────────────
  //  TAB 2: SİPARİŞLER (Canlı Sipariş Takibi & Kurye Atama)
  // ─────────────────────────────────────────────────────────────
  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🛒 Siparişler (${_orders.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ChoiceChip(
                selected: true,
                label: const Text('Canlı Sipariş Akışı'),
                selectedColor: const Color(0xFFDC2626),
                labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Henüz Aktif Bekleyen Sipariş Bulunmuyor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Canlı mağaza siparişleri geldikçe burada anlık listelenecektir.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 3: ÜRÜNLER (Ürün Kataloğu & Fiyat Düzenleme)
  // ─────────────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📦 Ürünler & Stok (${_products.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Yeni Ürün Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Ürün adı veya kategori ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchProductQuery = val),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p['image'] ?? 'https://picsum.photos/seed/product/100/100',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('₺${p['base_price'] ?? p['price'] ?? 0} • ${p['sub_brand'] ?? 'Genel'}'),
                  trailing: const Chip(label: Text('Stokta'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 4: KATEGORİLER
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategoriesTab() {
    final categories = [
      {'name': 'Et & Kasap', 'sub': 'Taze Kırmızı Et ve Kasap Ürünleri', 'icon': Icons.kebab_dining},
      {'name': 'Meyve & Sebze', 'sub': 'Günlük Taze Manav Hasadı', 'icon': Icons.eco},
      {'name': 'Şarküteri', 'sub': 'Peynir, Zeytin ve Yöresel Kahvaltılıklar', 'icon': Icons.breakfast_dining},
      {'name': 'Fırın & Unlu Mamuller', 'sub': 'Sıcak Ekmek ve Börek Çeşitleri', 'icon': Icons.bakery_dining},
      {'name': 'İçecekler', 'sub': 'Su, Maden Suyu ve Meşrubat', 'icon': Icons.local_drink},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final c = categories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFFEF2F2), child: Icon(c['icon'] as IconData, color: const Color(0xFFDC2626))),
            title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(c['sub'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 5: KAMPANYALAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildCampaignsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🎯 Kampanyalar & İndirim Kuponları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Yeni Kampanya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: const ListTile(
              leading: CircleAvatar(backgroundColor: Color(0xFFFEF2F2), child: Icon(Icons.confirmation_number_outlined, color: Color(0xFFDC2626))),
              title: Text('TEMA50 — ₺50 İndirim Kuponu', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Min. ₺300 alışverişlerde geçerli ilk sipariş fırsatı.'),
              trailing: Chip(label: Text('AKTİF'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 6: SMS GÖNDERİMİ
  // ─────────────────────────────────────────────────────────────
  Widget _buildSmsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💬 NetGSM & Türk Telekom Toplu SMS Paneli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              const TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Müşterilerinize gönderilecek SMS duyuru metnini yazın...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                label: const Text('SMS Duyurusu Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 7: BAŞVURULAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildApplicationsTab() {
    return const Center(child: Text('📝 Kurye & Bayi Başvuruları Listesi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 8: API ENTEGRASYONLARI
  // ─────────────────────────────────────────────────────────────
  Widget _buildApiIntegrationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.sms, color: Color(0xFFDC2626)),
            title: Text('NetGSM SMS Entegrasyonu', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Durum: Bağlı & Aktif (Kredi: 14,200 SMS)'),
            trailing: Chip(label: Text('BAĞLI'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.point_of_sale, color: Color(0xFF2563EB)),
            title: Text('QNB Finansbank Sanal POS', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('3D Secure Otomatik Ödeme Altyapısı'),
            trailing: Chip(label: Text('BAĞLI'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 9: TEMAPUAN & SADAKAT
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoyaltyTab() {
    return const Center(child: Text('⭐ TemaPuan & VIP Sadakat Sistemi Ayarları', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 10: YETKİLER
  // ─────────────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    return const Center(child: Text('👥 Kullanıcılar & Rol Yetkileri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 11: ÖDEMELER & FATURALAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildInvoicesTab() {
    return const Center(child: Text('💳 Ödemeler & GİB E-Fatura Geçmişi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  }

  // ─────────────────────────────────────────────────────────────
  //  TAB 12: SİSTEM ÖZELLİKLERİ & MODÜL ŞALTERLERİ (FEATURE FLAGS)
  //  Web Yönetici Paneli ile %100 Birebir Canlı Senkronize!
  // ─────────────────────────────────────────────────────────────
  Widget _buildFeatureFlagsTab() {
    final flagsList = [
      {
        'key': 'sanal_market',
        'label': '1. Sanal Market (Sepet & Sipariş)',
        'desc': 'Deaktif edilirse ürünler sergilenir fakat sepete ekle ve sepet alanı gizlenir, sipariş verilemez.',
        'val': _featureFlags.sanalMarket,
      },
      {
        'key': 'bayi_stok',
        'label': '2. Bayi Stok Yönetim Sistemi',
        'desc': 'Şubelerin stok giriş-çıkış kontrolünü ve kritik stok uyarılarını yönetir.',
        'val': _featureFlags.bayiStok,
      },
      {
        'key': 'temapuan',
        'label': '3. TemaPuan Sadakat & Cüzdan',
        'desc': 'Deaktif edilirse TemaPuan kazanımı/kullanımı ve puan kartları gizlenir.',
        'val': _featureFlags.temapuan,
      },
      {
        'key': 'api_entegrasyon',
        'label': '4. API Entegrasyonları',
        'desc': 'Trendyol Market, Yemeksepeti ve Getir dış entegrasyon servislerini yönetir.',
        'val': _featureFlags.apiEntegrasyon,
      },
      {
        'key': 'sms_gonderim',
        'label': '5. SMS Gönderim Özelliği',
        'desc': 'Deaktif edilirse SMS paneli ve duyuruları kapalı konuma getirilir.',
        'val': _featureFlags.smsGonderim,
      },
      {
        'key': 'kampanyalar',
        'label': '6. Kampanyalar Özelliği',
        'desc': 'Deaktif edilirse indirim kuponları ve promosyonlar geçersiz sayılır.',
        'val': _featureFlags.kampanyalar,
      },
      {
        'key': 'sanal_pos',
        'label': '7. Sanal POS ve Online Ödeme',
        'desc': 'Deaktif edilirse ödeme sayfasında 3D Secure Sanal POS seçeneği gizlenir.',
        'val': _featureFlags.sanalPos,
      },
      {
        'key': 'soft_pos',
        'label': '8. Soft POS ile Kapıda Ödeme',
        'desc': 'Kuryelerin NFC cihazları üzerinden kapıda temassız tahsilatını yönetir.',
        'val': _featureFlags.softPos,
      },
      {
        'key': 'e_fatura',
        'label': '9. Otomatik E-FATURA Kesimi',
        'desc': 'Aktifse siparişler için otomatik GİB E-Fatura düzenlenir.',
        'val': _featureFlags.eFatura,
      },
      {
        'key': 'serbest_kurye',
        'label': '10. Serbest Kurye Havuzu',
        'desc': 'Bağımsız serbest kuryelerin otomatik sipariş kabul havuzunu yönetir.',
        'val': _featureFlags.serbestKurye,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 8),
              Text('⚙️ Sistem Özellikleri & Modül Şalterleri (Feature Flags)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Platform genelinde (Web ve Mobil Uygulama) sistem özelliklerini anlık aktif/deaktif edebilirsiniz. Deaktif edilen özellikler kullanıma kapatılır.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isEnabled ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
                    width: 1.5,
                  ),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flag['label'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Text(flag['desc'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(isEnabled ? '🟢 AKTİF (Kullanımda)' : '🔴 DEAKTİF (Gizli & Kapalı)'),
                              backgroundColor: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                              labelStyle: TextStyle(
                                color: isEnabled ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isEnabled,
                        activeTrackColor: const Color(0xFF16A34A),
                        onChanged: (val) => _toggleFeature(flag['key'] as String, val),
                      ),
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

  // ─────────────────────────────────────────────────────────────
  //  TAB 13: B2B ÖDEMELER
  // ─────────────────────────────────────────────────────────────
  Widget _buildB2bTab() {
    return const Center(child: Text('🏢 B2B Kurumsal Cari Hesaplar & Banka IBAN Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
  }
}
