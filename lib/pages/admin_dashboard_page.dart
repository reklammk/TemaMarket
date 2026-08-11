import 'package:flutter/material.dart';

class AdminDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const AdminDashboardPage({super.key, this.user, this.onBackToStore});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _activeTab = 11;
  int? _expandedRowId;

  final List<Map<String, dynamic>> _payments = [
    {
      'id': 1,
      'customer': 'Zeynep Yılmaz',
      'order_no': '#TEM-84920',
      'card_detail': '3434****2322 SANAL POS (QNB Finansbank)',
      'coupon': 'TEMA50 (₺50.00 İndirim)',
      'invoice_no': 'GIB2026000008492',
      'items': '2x Dana Kasap Parmak Sucuk 500 g, 1x Ekşi Mayalı Trabzon Ekmeği',
      'address': 'Gezköy OSB Mah. 3. Sanayi Cad. No:5 Aziziye / Erzurum',
      'courier': 'Ahmet Yılmaz (25 AB 123 - Motosiklet)',
      'branch': 'Lalapaşa AVM Şubesi',
      'total': 499.00,
      'coupon_val': 50.00,
      'kdv': 36.96,
      'bank_commission': 9.23,
      'net_hakedis': 439.81,
    },
    {
      'id': 2,
      'customer': 'Murat Kaya',
      'order_no': '#TEM-84921',
      'card_detail': '5406****9912 KAPIDA SOFTPOS (Mobil POS)',
      'coupon': 'KASAP30 (₺30.00 İndirim)',
      'invoice_no': 'GIB2026000008493',
      'items': '1x Sıkma File Portakal 2 kg, 1x Torku Kaşar 600 g',
      'address': 'Şükrüpaşa Mah. İstasyon Cad. No:42 Yakutiye / Erzurum',
      'courier': 'Mehmet Demir (25 EV 456 - Motosiklet)',
      'branch': 'Şükrüpaşa Şubesi',
      'total': 348.90,
      'coupon_val': 30.00,
      'kdv': 25.84,
      'bank_commission': 6.45,
      'net_hakedis': 312.45,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('TEMASAN Yönetici Konsolu & ERP', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.home, color: Color(0xFF0F172A)), onPressed: widget.onBackToStore),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Seçim Çubuğu
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip(11, 'Ödemeler & Faturalar'),
                  _buildTabChip(0, 'Dashboard Metrikleri'),
                  _buildTabChip(1, 'Şube & Bayi Hesapları'),
                  _buildTabChip(2, 'Tüm Siparişler'),
                  _buildTabChip(6, 'SMS Gönderimi'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_activeTab == 11) ...[
              const Text('Ödemeler, Faturalar & Finans Konsolu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('GİB onaylı faturalar, banka POS komisyon kesintileri, KDV matrahları ve kupon indirimleri.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              // Finansal Özet Kartları
              Row(
                children: [
                  Expanded(child: _buildFinCard('TOPLAM HACİM', '₺847.90', const Color(0xFFFEF2F2), const Color(0xFFDC2626))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildFinCard('NET GELEN TUTAR', '₺769.42', const Color(0xFFF0FDF4), const Color(0xFF16A34A))),
                ],
              ),
              const SizedBox(height: 16),

              // Ödemeler Tablosu
              ..._payments.map((p) {
                final isExpanded = _expandedRowId == p['id'];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p['customer'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            Chip(label: Text(p['order_no'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), backgroundColor: const Color(0xFFF1F5F9)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Ödeme: ${p['card_detail']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                        Text('Kupon / İndirim: ${p['coupon']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        Text('Fatura No: ${p['invoice_no']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('İçerik: ${p['items']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Kurye: ${p['courier']}', style: const TextStyle(fontSize: 11)),
                        Text('Bayi: ${p['branch']}', style: const TextStyle(fontSize: 11)),
                        const Divider(height: 16),

                        // Dropdown Açılır Detay Butonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFDC2626)),
                              label: Text(isExpanded ? 'Finansal Detayı Gizle' : 'Finansal Detay Dropdown', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                              onPressed: () {
                                setState(() {
                                  _expandedRowId = isExpanded ? null : p['id'];
                                });
                              },
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.receipt, size: 14, color: Colors.white),
                              label: const Text('Faturayı Görüntüle', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              onPressed: () => _showInvoiceDialog(context, p),
                            ),
                          ],
                        ),

                        // Dropdown İçeriği
                        if (isExpanded) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              children: [
                                _finRow('Toplam Sipariş Tutarı', '₺${p['total']}'),
                                _finRow('Kupon / İndirim Tutarı', '-₺${p['coupon_val']}', color: const Color(0xFFDC2626)),
                                _finRow('Hesaplanan KDV (%8)', '₺${p['kdv']}'),
                                _finRow('Banka POS Komisyonu (%1.85)', '-₺${p['bank_commission']}', color: const Color(0xFFEA580C)),
                                const Divider(),
                                _finRow('Satıcı Net Hakediş Tutarı', '₺${p['net_hakedis']}', color: const Color(0xFF16A34A), isBold: true),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Seçilen Yönetici Sekmesi Yükleniyor...'))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(int id, String title) {
    final isSel = _activeTab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSel,
        label: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF0F172A))),
        selectedColor: const Color(0xFFDC2626),
        backgroundColor: Colors.white,
        onSelected: (_) => setState(() => _activeTab = id),
      ),
    );
  }

  Widget _buildFinCard(String title, String val, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _finRow(String label, String val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  void _showInvoiceDialog(BuildContext context, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('GİB E-Fatura Belgesi (${p['invoice_no']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TEMA MARKETÇİLİK VE SANAL RETAIL A.Ş.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
            const Text('Vergi Dairesi: Aziziye V.D. | VKN: 8390192841', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Divider(height: 16),
            Text('Alıcı: ${p['customer']}'),
            Text('Adres: ${p['address']}'),
            const SizedBox(height: 8),
            Text('Fatura Tutarı: ₺${p['total']} (KDV Dahil)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
            const SizedBox(height: 8),
            const Text('GİB E-Fatura UUID: 8A291C4B-91C0-4E8A-9012-7F63B9C1029F', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context),
            child: const Text('PDF İndir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
