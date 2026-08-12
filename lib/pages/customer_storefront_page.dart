import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/feature_flags_service.dart';

class CustomerStorefrontPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenMerchant;
  final VoidCallback? onOpenCourier;
  final VoidCallback? onLogout;

  const CustomerStorefrontPage({
    super.key,
    this.user,
    this.onOpenAdmin,
    this.onOpenMerchant,
    this.onOpenCourier,
    this.onLogout,
  });

  @override
  State<CustomerStorefrontPage> createState() => _CustomerStorefrontPageState();
}

class _CustomerStorefrontPageState extends State<CustomerStorefrontPage> {
  FeatureFlags _flags = const FeatureFlags();

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    final flags = await FeatureFlagsService.loadFlags();
    if (mounted) setState(() => _flags = flags);
  }

  final List<Map<String, dynamic>> _cart = [];
  int _currentTabIndex = 0;
  String _selectedBranch = 'Lalapaşa AVM (Yakutiye)';
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  // ignore: unused_field
  String _tcNo = '';

  // Kişiselleştirilmiş İndirim & Sadakat Tercihleri State
  final List<String> _favCategories = ['Taze Et & Kasap', 'Şarküteri & Peynir'];
  final List<String> _dietaryPrefs = ['Erzurum Yerli Üretimi', 'Organik & Doğal'];
  String _householdSize = '3-4 Kişi (Çekirdek Aile)';
  bool _hasChildren = false;
  bool _hasPets = false;
  bool _pushConsent = true;
  bool _smsConsent = true;
  bool _kvkkConsent = true;

  // TemaPuan Bakiye Değerleri
  final int _userPoints = 450;
  // ignore: unused_element
  double get _userPointsTL => _userPoints * 0.10;

  final List<Map<String, String>> _branchDetails = [
    {'name': 'Lalapaşa AVM (Yakutiye)', 'district': 'Yakutiye / Erzurum', 'phone': '0 (442) 234 11 22', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Pasinler (Pasinler)', 'district': 'Pasinler / Erzurum', 'phone': '0 (442) 661 22 33', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Yenişehir AVM (Palandöken)', 'district': 'Palandöken / Erzurum', 'phone': '0 (442) 316 44 55', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Kelkit-1 (Gümüşhane)', 'district': 'Kelkit / Gümüşhane', 'phone': '0 (456) 317 10 20', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Dadaşkent AVM (Aziziye)', 'district': 'Aziziye / Erzurum', 'phone': '0 (442) 327 99 88', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Palandöken AVM (Palandöken)', 'district': 'Palandöken / Erzurum', 'phone': '0 (442) 317 88 99', 'status': 'AÇIK - Canlı Teslimat'},
  ];

  final List<Map<String, dynamic>> _popularProducts = [
    {
      'id': 101,
      'name': 'Dana Kasap Antrikot 1 kg',
      'price': 690.00,
      'orig_price': 790.00,
      'sub_brand': 'Kasap',
      'rating': 4.9,
      'badge': 'ÇOK SATAN',
      'image': 'https://picsum.photos/seed/meat1/400/400',
    },
    {
      'id': 102,
      'name': 'Yerli Amasya Elması 1 kg',
      'price': 34.90,
      'orig_price': 45.00,
      'sub_brand': 'Manav',
      'rating': 4.8,
      'badge': 'Taze Hasat',
      'image': 'https://picsum.photos/seed/apple2/400/400',
    },
    {
      'id': 103,
      'name': 'Erzurum Hakiki Bal Petek 500 g',
      'price': 350.00,
      'orig_price': 420.00,
      'sub_brand': 'Sarkuteri',
      'rating': 5.0,
      'badge': 'YÖRESEL',
      'image': 'https://picsum.photos/seed/honey3/400/400',
    },
    {
      'id': 104,
      'name': 'Erzurum Civil Peyniri 1 kg',
      'price': 240.00,
      'orig_price': 280.00,
      'sub_brand': 'Sarkuteri',
      'rating': 4.9,
      'badge': 'GELENEKSEL',
      'image': 'https://picsum.photos/seed/cheese4/400/400',
    },
  ];

  final List<Map<String, dynamic>> _discountedProducts = [
    {
      'id': 301,
      'name': 'Torku Tam Yağlı Kaşar 600 g',
      'price': 299.00,
      'orig_price': 479.00,
      'sub_brand': 'Sarkuteri',
      'discount_rate': '%37 İNDİRİM',
      'image': 'https://picsum.photos/seed/kasar3/400/400',
    },
    {
      'id': 302,
      'name': 'Dana Kasap Parmak Sucuk 500 g',
      'price': 499.00,
      'orig_price': 625.00,
      'sub_brand': 'Kasap',
      'discount_rate': '%20 İNDİRİM',
      'image': 'https://picsum.photos/seed/sucuk1/400/400',
    },
    {
      'id': 303,
      'name': 'Sıkma File Portakal 2 kg',
      'price': 49.90,
      'orig_price': 65.00,
      'sub_brand': 'Manav',
      'discount_rate': '%23 İNDİRİM',
      'image': 'https://picsum.photos/seed/orange2/400/400',
    },
    {
      'id': 304,
      'name': 'Trabzon Ekşi Mayalı Ekmek 800 g',
      'price': 35.00,
      'orig_price': 42.00,
      'sub_brand': 'Firin',
      'discount_rate': '%16 İNDİRİM',
      'image': 'https://picsum.photos/seed/bread4/400/400',
    },
  ];

  final List<Map<String, dynamic>> _products = [
    {
      'id': 1,
      'name': 'Dana Kasap Parmak Sucuk 500 g',
      'price': 499.00,
      'orig_price': 625.00,
      'sub_brand': 'Kasap',
      'image': 'https://picsum.photos/seed/sucuk1/400/400',
    },
    {
      'id': 2,
      'name': 'Sıkma File Portakal 2 kg',
      'price': 49.90,
      'orig_price': 65.00,
      'sub_brand': 'Manav',
      'image': 'https://picsum.photos/seed/orange2/400/400',
    },
    {
      'id': 3,
      'name': 'Torku Tam Yağlı Kaşar 600 g',
      'price': 299.00,
      'orig_price': 479.00,
      'sub_brand': 'Sarkuteri',
      'image': 'https://picsum.photos/seed/kasar3/400/400',
    },
    {
      'id': 4,
      'name': 'Trabzon Ekşi Mayalı Ekmek 800 g',
      'price': 35.00,
      'orig_price': 42.00,
      'sub_brand': 'Firin',
      'image': 'https://picsum.photos/seed/bread4/400/400',
    },
    {
      'id': 5,
      'name': 'Çaykur Rize Turist Çayı 1000 g',
      'price': 165.00,
      'orig_price': 185.00,
      'sub_brand': 'Icecek',
      'image': 'https://picsum.photos/seed/tea5/400/400',
    },
    {
      'id': 6,
      'name': 'Yerli Kuru Fasulye 1 kg',
      'price': 120.00,
      'orig_price': 145.00,
      'sub_brand': 'Bakliyat',
      'image': 'https://picsum.photos/seed/beans6/400/400',
    },
  ];


  double get _cartTotal => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));

  void _addToCart(Map<String, dynamic> product) {
    if (!_flags.sanalMarket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Sanal Market siparişe kapalıdır. Ürünler şubelerimizde fırsat ürünü olarak satılmaktadır.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      final index = _cart.indexWhere((i) => i['id'] == product['id']);
      if (index >= 0) {
        _cart[index]['qty'] += 1;
      } else {
        _cart.add({...product, 'qty': 1});
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} sepete eklendi.'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  void _showFranchiseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.handshake, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Bayimiz Olmak İster Misiniz?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'TEMA Marketçilik franchise ve şube ortaklığı için başvurunuzu yönetici ekibimize iletebilirsiniz. Başvuru formunuz 24 saat içinde incelenecektir.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bayilik başvurunuz alınmıştır. İletişim numaranızdan dönüş yapılacaktır.')),
              );
            },
            child: const Text('Başvuru Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRentalSpaceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.home_work, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Kiralık İş Yeriniz mi Var?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Erzurum ve çevre illerde TEMA Market açılışına uygun dükkan/iş yeri gayrimenkulünüzü kiralamak için bilgilerinizi ekibimize iletin.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kiralık iş yeri bildiriminiz gayrimenkul birimimize iletilmiştir.')),
              );
            },
            child: const Text('Gayrimenkul Bildir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) => Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(20)),
                    child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !_flags.sanalMarket ? 'Market' : 'sanalmarket',
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_flags.sanalMarket)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A), size: 28),
                  if (_cart.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: const Color(0xFFDC2626),
                        child: Text('${_cart.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showCartBottomSheet(context),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Color(0xFF0F172A)),
            onSelected: (value) {
              if (value == 'admin' && widget.onOpenAdmin != null) widget.onOpenAdmin!();
              if (value == 'merchant' && widget.onOpenMerchant != null) widget.onOpenMerchant!();
              if (value == 'courier' && widget.onOpenCourier != null) widget.onOpenCourier!();
              if (value == 'logout' && widget.onLogout != null) widget.onLogout!();
            },
            itemBuilder: (context) => [
              if (widget.user?['role'] == 'SuperAdmin')
                const PopupMenuItem(value: 'admin', child: Text('Yönetici Konsolu')),
              if (widget.user?['role'] == 'Merchant' || widget.user?['role'] == 'SuperAdmin')
                const PopupMenuItem(value: 'merchant', child: Text('Bayi Paneli')),
              if (widget.user?['role'] == 'Courier')
                const PopupMenuItem(value: 'courier', child: Text('Kurye Paneli')),
              const PopupMenuItem(value: 'logout', child: Text('Çıkış Yap')),
            ],
          ),
        ],
      ),
      body: _buildCurrentTabBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Şubeler'),
          BottomNavigationBarItem(icon: Badge(label: Text('${_cart.length}'), child: const Icon(Icons.shopping_bag)), label: 'Sepetim'),
          const BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Sizin İçin'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hesabım'),
        ],
        onTap: (index) {
          if (index == 2) {
            _showCartBottomSheet(context);
          } else {
            setState(() => _currentTabIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTabIndex) {
      case 1:
        return _buildBranchesPage();
      case 3:
        return _buildForYouPage();
      case 4:
        return _buildAccountPage();
      case 0:
      default:
        return _buildHomeStorefrontPage();
    }
  }

  // 🏠 TAB 0: ANA SAYFA MAĞAZASI
  Widget _buildHomeStorefrontPage() {
    final filteredCatalog = _products.where((p) {
      if (_selectedCategory == 'İndirimli Ürünler') {
        return (p['orig_price'] != null && p['orig_price'] > p['price']);
      } else if (_selectedCategory != 'Tümü' && p['sub_brand'] != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        return p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_flags.sanalMarket)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sanal Market Sipariş Alımına Kapalıdır',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ürünlerimiz sergilenmekte olup canlı sipariş alımı geçici olarak durdurulmuştur. Şubelerimizden alışveriş yapabilirsiniz.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBranch,
                isExpanded: true,
                icon: const Icon(Icons.location_on, color: Color(0xFFDC2626)),
                items: _branchDetails.map((b) => DropdownMenuItem(value: b['name']!, child: Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626))))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBranch = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🤝 KURUMSAL İŞ ORTAKLIĞI VE KİRALIK İŞ YERİ AKSİYON BUTONLARI
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.handshake, size: 14, color: Color(0xFF0F172A)),
                  label: const Text('Bayimiz Olun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => _showFranchiseDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.home_work, size: 14, color: Color(0xFF0F172A)),
                  label: const Text('Kiralık İş Yeri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => _showRentalSpaceDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Arama Çubuğu
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Ürün veya kategori arayın...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // 🏷️ KATEGORİ SEÇİM ŞERİDİ (İNDİRİMLİ ÜRÜNLER SEKMESİ İLE BİRLİKTE)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'Tümü',
                'İndirimli Ürünler',
                'Kasap',
                'Manav',
                'Sarkuteri',
                'Firin',
                'Icecek',
              ].map((cat) {
                final isSelected = _selectedCategory == cat;
                final isDiscountTab = cat == 'İndirimli Ürünler';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: isDiscountTab ? Icon(Icons.local_offer, size: 14, color: isSelected ? Colors.white : const Color(0xFFDC2626)) : null,
                    label: Text(cat == 'Tümü' ? 'Tüm Ürünler' : cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDC2626),
                    backgroundColor: isDiscountTab ? const Color(0xFFFEF2F2) : Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? Colors.white : (isDiscountTab ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                    ),
                    onSelected: (selected) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 💳 TEMA VIP KART & KİŞİYE ÖZEL İNDİRİM REKLAM ALANI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                      child: const Text('KİŞİYE ÖZEL İNDİRİM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0x33EAB308), borderRadius: BorderRadius.circular(6)),
                      child: const Text('TEMA VIP KART', style: TextStyle(color: Color(0xFFFEF08A), fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'TEMA VIP Kartınızı Oluşturun, Size Özel İndirimleri Kaçırmayın',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Doğum günü sürprizi, özel gün hediyeleri ve alışveriş tercihlerinize özel indirimler için profilinizi güncelleyin.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.credit_card, size: 16, color: Color(0xFF0F172A)),
                    label: const Text('VIP Kartım ve Profilim ➔', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => setState(() => _currentTabIndex = 4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🏷️ İNDİRİMLİ ÜRÜNLER & ŞUBE FIRSATLARI SEÇKİSİ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF5F5), Color(0xFFFEF2F2)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_offer, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 6),
                        Text('🏷️ İndirimli Ürünler & Şube Fırsatları', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      ],
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedCategory = 'İndirimli Ürünler'),
                      child: const Text('Tüm Fırsatlar ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$_selectedBranch şubemizde ve tüm TEMA Market mağazalarımızda geçerli fırsatlar.', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 14),

                SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _discountedProducts.length,
                    itemBuilder: (context, index) {
                      final p = _discountedProducts[index];
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(p['image'], height: 85, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                                        child: Text(p['discount_rate'], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const Spacer(),
                                Row(
                                  children: [
                                    Text('₺${p['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFDC2626))),
                                    const SizedBox(width: 4),
                                    Text('₺${p['orig_price']}', style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 28,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _flags.sanalMarket ? const Color(0xFFDC2626) : const Color(0xFFFEF2F2),
                                      elevation: 0,
                                      side: _flags.sanalMarket ? null : const BorderSide(color: Color(0xFFFECDD3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                    ),
                                    onPressed: _flags.sanalMarket ? () => _addToCart(p) : null,
                                    child: Text(
                                      _flags.sanalMarket ? 'Ekle' : 'Şubede Fırsat',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _flags.sanalMarket ? Colors.white : const Color(0xFFDC2626)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🔥 POPÜLER ÜRÜNLER ALANI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🔥 Popüler Ürünler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              InkWell(
                onTap: () => _openFullCatalogModal('Tüm Popüler Ürünler', _popularProducts),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Tümünü Gör ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _popularProducts.length,
              itemBuilder: (context, index) {
                final p = _popularProducts[index];
                return Container(
                  width: 155,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(p['image'], height: 95, width: double.infinity, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                                  child: Text(p['badge'], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Row(
                            children: [
                              Text('₺${p['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFDC2626))),
                              const SizedBox(width: 4),
                              Text('₺${p['orig_price']}', style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 30,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _flags.sanalMarket ? const Color(0xFFDC2626) : Colors.grey.shade300,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                              onPressed: _flags.sanalMarket ? () => _addToCart(p) : null,
                              child: Text(_flags.sanalMarket ? 'Ekle' : 'Şubede Fırsat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _flags.sanalMarket ? Colors.white : Colors.grey.shade700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // 🛒 ANA ÜRÜN KATALOĞU GRID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_selectedCategory == 'Tümü' ? 'Tüm Taze Ürünler' : '$_selectedCategory Ürünleri', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text('${filteredCatalog.length} ürün', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredCatalog.length,
            itemBuilder: (context, index) {
              final p = filteredCatalog[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(p['image'], height: 110, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          Text('₺${p['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFDC2626))),
                          const SizedBox(width: 4),
                          if (p['orig_price'] != null)
                            Text('₺${p['orig_price']}', style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _flags.sanalMarket ? const Color(0xFFDC2626) : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: _flags.sanalMarket ? () => _addToCart(p) : null,
                          child: Text(_flags.sanalMarket ? 'Hemen Ekle' : 'Şubede Fırsat Ürünü', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _flags.sanalMarket ? Colors.white : Colors.grey.shade700)),
                        ),
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

  Widget _buildBranchesPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('TEMA SanalMarket Şube Ağı (6 Şube)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Size en yakın şubemizi seçerek canlı stoklar üzerinden sipariş oluşturabilirsiniz.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ..._branchDetails.map((b) {
          final isSelected = b['name'] == _selectedBranch;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSelected ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                  child: Icon(Icons.store, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(b['district']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Tel: ${b['phone']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedBranch = b['name']!;
                      _currentTabIndex = 0;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${b['name']} şubesi seçildi.')));
                  },
                  child: Text(isSelected ? 'Seçili Şube' : 'Şubeyi Seç', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildForYouPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Sizin İçin Seçtiklerimiz & Özel Fırsatlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Alışveriş alışkanlıklarınıza özel hazırlanmış indirimli fırsat paketleri.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ..._discountedProducts.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(p['image'], width: double.infinity, height: 140, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('2x TemaPuan', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p['discount_rate'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('₺${p['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                        const SizedBox(width: 8),
                        Text('₺${p['orig_price']}', style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: () => _addToCart(p),
                      child: const Text('Sepete Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAccountPage() {
    final userName = widget.user?['name'] ?? 'Zeynep Yılmaz';
    final userPhone = widget.user?['phone'] ?? '+90 532 100 22 33';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFDC2626),
                  child: Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(userPhone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                        child: Text(widget.user?['role'] ?? 'Müşteri Hesabı', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 💳 FİZİKİ & DİJİTAL TEMA VIP KART MOCKUP (Apple Wallet & Ultra Premium UI)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF450A0A),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KART ÜST BAŞLIK & LOGO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_basket, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'TEMA VIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEAB308), Color(0xFFCA8A04)]),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: const [BoxShadow(color: Color(0x66EAB308), blurRadius: 8)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('VIP MEMBER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ÇİP & NFC SİMGE SİMGESİ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // SIM ÇİP SİMÜLASYONU
                    Container(
                      width: 42,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCA8A04), width: 1),
                      ),
                      child: Stack(
                        children: [
                          Positioned(top: 14, left: 0, right: 0, child: Container(height: 1, color: Colors.black26)),
                          Positioned(left: 20, top: 0, bottom: 0, child: Container(width: 1, color: Colors.black26)),
                        ],
                      ),
                    ),
                    const Icon(Icons.contactless, color: Color(0xFF94A3B8), size: 26),
                  ],
                ),
                const SizedBox(height: 16),

                // MÜŞTERİ ADI VE NUMARA
                Text(
                  userName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: TEMA-${userPhone.replaceAll(RegExp(r'\D'), '')}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 20),

                // BARKOD & NFC BUTONLARI ALANI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _showEnlargedBarcodeModal(context, userPhone),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.qr_code_2, color: Color(0xFF0F172A), size: 24),
                                    SizedBox(width: 6),
                                    Text('Kasa Barkod / QR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fullscreen, size: 14, color: Color(0xFFDC2626)),
                                      SizedBox(width: 2),
                                      Text('Büyüt', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ÇİZGİ BARKOD ÖNİZLEMESİ
                            Container(
                              height: 38,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(30, (index) {
                                  final width = (index % 3 == 0) ? 3.0 : ((index % 2 == 0) ? 1.8 : 1.0);
                                  return Container(
                                    width: width,
                                    height: 35,
                                    color: (index % 5 == 4) ? Colors.transparent : Colors.black,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userPhone.replaceAll(RegExp(r'\D'), ''),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '🔍 Dokunarak Kasa Okuyucusu İçin Büyütün',
                              style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 20),

                      // TEMASSIZ NFC ILE KASAYA ILETME BUTONU
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.nfc, size: 18, color: Colors.white),
                          label: const Text('📲 NFC Temassız Okut (Telefon No İlet)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _showNFCContactlessModal(context, userPhone),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🎛️ KİŞİSELLEŞTİRİLMİŞ İNDİRİM & ALIŞVERİŞ TERCİHLERİ FORMU
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFFDC2626), size: 22),
                    SizedBox(width: 8),
                    Text('Kişiselleştirilmiş İndirim Tercihleri', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Seçtiğiniz kategorilere özel anlık indirim ve kupon tanımlanacaktır.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),

                const Text('Sık Alışveriş Yaptığınız Kategoriler:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    'Taze Et & Kasap',
                    'Taze Meyve & Sebze',
                    'Şarküteri & Peynir',
                    'Fırın & Ekmek',
                    'Süt & Kahvaltılık',
                    'Dondurulmuş Gıdalar',
                  ].map((cat) {
                    final isFav = _favCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: isFav,
                      selectedColor: const Color(0xFFFEF2F2),
                      checkmarkColor: const Color(0xFFDC2626),
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isFav ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _favCategories.add(cat);
                          } else {
                            _favCategories.remove(cat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                const Text('Özel Ürün & Beslenme Tercihleriniz:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    'Glutensiz Ürünler',
                    'Şeker İlavesiz',
                    'Organik & Doğal',
                    'Erzurum Yerli Üretimi',
                    'Laktozsuz Süt Ürünleri',
                  ].map((pref) {
                    final isSelected = _dietaryPrefs.contains(pref);
                    return FilterChip(
                      label: Text(pref),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFEF2F2),
                      checkmarkColor: const Color(0xFFDC2626),
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _dietaryPrefs.add(pref);
                          } else {
                            _dietaryPrefs.remove(pref);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Ev Halkı Büyüklüğü
                const Text('Ev Halkı Büyüklüğü:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _householdSize,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    '1-2 Kişi (Bireysel / Çift)',
                    '3-4 Kişi (Çekirdek Aile)',
                    '5+ Kişi (Geniş Aile)',
                  ].map((h) => DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _householdSize = val);
                  },
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Evde Bebek / Çocuk Var (Çocuk İndirimleri)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _hasChildren,
                  activeThumbColor: const Color(0xFFDC2626),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _hasChildren = val),
                ),
                SwitchListTile(
                  title: const Text('Evcil Hayvanım Var (Mama İndirimleri)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _hasPets,
                  activeThumbColor: const Color(0xFFDC2626),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _hasPets = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 📜 YASAL BİLDİRİM & İZİNLER PANELİ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, color: Color(0xFF16A34A), size: 22),
                    SizedBox(width: 8),
                    Text('Yasal İzinler ve İletişim Tercihleri', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Mobil Uygulama Push Bildirim İzni', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Anlık kampanya ve indirim haberleri', style: TextStyle(fontSize: 10)),
                  value: _pushConsent,
                  activeThumbColor: const Color(0xFF16A34A),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _pushConsent = val),
                ),
                SwitchListTile(
                  title: const Text('SMS İletişim Bildirim İzni', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Kupon ve sipariş durum bildirimleri', style: TextStyle(fontSize: 10)),
                  value: _smsConsent,
                  activeThumbColor: const Color(0xFF16A34A),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _smsConsent = val),
                ),
                SwitchListTile(
                  title: const Text('KVKK Aydınlatma Metni & Veri İşleme İzni', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _kvkkConsent,
                  activeThumbColor: const Color(0xFF16A34A),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _kvkkConsent = val),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil bilgileriniz ve indirim tercihleriniz güncellendi.')),
                      );
                    },
                    child: const Text('Profilim & Tercihlerimi Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // TC Kimlik No Bilgilendirme Formu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('E-Fatura TC Kimlik Bilgisi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                TextField(
                  maxLength: 11,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '11 Haneli TC Kimlik No (Opsiyonel)',
                    counterText: '',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _tcNo = val),
                ),
                const SizedBox(height: 6),
                const Text(
                  'E-faturanız kayıtlı iletişim numaranıza ve e-posta adresinize gönderilecektir.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Diğer Panel Kısayolları
          if (widget.onOpenAdmin != null)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFDC2626)),
              title: const Text('Yönetici Konsolu', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenAdmin,
            ),
          if (widget.onOpenMerchant != null)
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFFDC2626)),
              title: const Text('Bayi Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenMerchant,
            ),
          if (widget.onOpenCourier != null)
            ListTile(
              leading: const Icon(Icons.delivery_dining, color: Color(0xFFDC2626)),
              title: const Text('Kurye Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenCourier,
            ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.grey),
            title: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sepetim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('Toplam: ₺${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                ],
              ),
              const Divider(height: 24),
              if (_cart.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Sepetiniz henüz boş.'))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('₺${item['price']} x ${item['qty']}'),
                        trailing: Text('₺${(item['price'] * item['qty']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                      );
                    },
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _flags.sanalMarket ? const Color(0xFFDC2626) : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: (_cart.isEmpty || !_flags.sanalMarket)
                      ? null
                      : () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Siparişiniz alındı. E-faturanız kayıtlı iletişim numaranıza gönderilecektir.')),
                          );
                        },
                  child: Text(
                    !_flags.sanalMarket
                        ? 'Sanal Market Siparişe Kapalı'
                        : 'Siparişi Tamamla (₺${_cartTotal.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFullCatalogModal(String title, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final p = items[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(p['image'], height: 110, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                            Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('₺${p['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFDC2626))),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                onPressed: () {
                                  _addToCart(p);
                                  Navigator.pop(context);
                                },
                                child: const Text('Sepete Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEnlargedBarcodeModal(BuildContext context, String rawNumber) {
    final cleanPhone = rawNumber.replaceAll(RegExp(r'\D'), '');
    final barcodeNo = cleanPhone; // Birebir aynı müşteri telefon numarası!
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Kasa Taraması (Büyütülmüş)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.api, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Text('Kasa Okuyucu Verisi (Telefon No): $cleanPhone', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.qr_code_2, size: 150, color: Color(0xFF0F172A)),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                              child: const Icon(Icons.shopping_basket, size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 60,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(35, (index) {
                            final width = (index % 3 == 0) ? 4.0 : ((index % 2 == 0) ? 2.0 : 1.0);
                            return Container(
                              width: width,
                              height: 55,
                              color: (index % 5 == 4) ? Colors.transparent : Colors.black,
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        barcodeNo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontFamily: 'monospace',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text('Telefon No Kopyala ($cleanPhone)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cleanPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Müşteri telefon numarası ($cleanPhone) panoya kopyalandı.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNFCContactlessModal(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _NFCAnimationSheet(phone: phone);
      },
    );
  }
}

class _NFCAnimationSheet extends StatefulWidget {
  final String phone;

  const _NFCAnimationSheet({required this.phone});

  @override
  State<_NFCAnimationSheet> createState() => _NFCAnimationSheetState();
}

class _NFCAnimationSheetState extends State<_NFCAnimationSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isTransmitting = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  void _triggerNfcTransmission() {
    setState(() => _isTransmitting = true);
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _isTransmitting = false;
          _isSuccess = true;
        });
        _controller.stop();
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
    final isDesktop = kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.nfc, color: Color(0xFFEAB308), size: 28),
              const SizedBox(width: 8),
              Text(
                _isSuccess
                    ? 'NFC İletimi Başarılı!'
                    : (_isTransmitting ? 'NFC Verisi Gönderiliyor...' : 'NFC Temassız Veri Aktarımı'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isSuccess
                ? 'Müşteri Telefon Numarası ($cleanPhone) Kasa Sistemine İletildi!\nKasa API Üzerinden TemaPuan ve İndirimler Sorgulandı ✓'
                : (_isTransmitting
                    ? 'Telefon Numarası ($cleanPhone) Kasa Okuyucusuna Aktarılıyor...'
                    : 'Telefonunuzu Kasa NFC Okuyucusuna Yaklaştırın Veya Sinyali Gönderin.\nMüşteri No: $cleanPhone'),
            style: TextStyle(
              color: _isSuccess ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          if (isDesktop && !_isSuccess)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.computer, color: Color(0xFFEAB308), size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Masaüstü/Web ortamındasınız. Mobil cihazlarda fiziksel NFC çipi ile temas kurulur.',
                      style: TextStyle(color: Color(0xFFFDE047), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // NFC DALGA SİMÜLASYONU
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_isSuccess)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final scale = 1.0 + (_controller.value * 0.4);
                      final opacity = (1.0 - _controller.value).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: (_isTransmitting ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: opacity), width: 3),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSuccess ? const Color(0xFF16A34A) : (_isTransmitting ? const Color(0xFFCA8A04) : const Color(0xFFDC2626)),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isSuccess ? Icons.check_circle : Icons.contactless,
                    size: 54,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (_isSuccess)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamamlandı', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            )
          else ...[
            ElevatedButton.icon(
              icon: _isTransmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.nfc, size: 18),
              label: Text(_isTransmitting ? 'Sinyal Aktarılıyor...' : 'NFC Sinyalini Gönder (Kasaya Okut)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                minimumSize: const Size(double.infinity, 46),
              ),
              onPressed: _isTransmitting ? null : _triggerNfcTransmission,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal Et', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
