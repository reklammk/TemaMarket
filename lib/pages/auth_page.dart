import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// TEMASAN ERP — Mobil SMS OTP Giriş Sayfası (Web Auth Modal UI 1-to-1 Birebir Aynı)
class AuthPage extends StatefulWidget {
  final String defaultRole;
  final Function(Map<String, dynamic> user)? onLoginSuccess;
  final VoidCallback? onClose;

  const AuthPage({
    super.key,
    this.defaultRole = 'Customer',
    this.onLoginSuccess,
    this.onClose,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Sekme İndeksi: 0 = Müşteri (Customer), 1 = Kurye (Courier), 2 = Bayi (Merchant)
  int _activeTab = 0;
  final TextEditingController _phoneController = TextEditingController(text: '5551234567');
  final TextEditingController _otpController = TextEditingController(text: '123987');

  bool _otpSent = false;
  bool _isLoading = false;
  bool _kvkkAccepted = true;

  @override
  void initState() {
    super.initState();
    if (widget.defaultRole == 'Courier') {
      _activeTab = 1;
    } else if (widget.defaultRole == 'Merchant' || widget.defaultRole == 'SuperAdmin') {
      _activeTab = 2;
    } else {
      _activeTab = 0;
    }
  }

  String get _selectedRole {
    if (_activeTab == 1) return 'Courier';
    if (_activeTab == 2) return 'Merchant';
    return 'Customer';
  }

  void _sendOtp() async {
    if (!_kvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen devam etmek için KVKK ve izin şartlarını onaylayın.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = '+90${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
      final res = await ApiService.sendOtp(phone);
      final mockCode = res['data']?['mock_otp_code'] ?? res['mock_otp_code'] ?? '123987';
      _otpController.text = mockCode.toString();

      setState(() {
        _isLoading = false;
        _otpSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔒 SMS Doğrulama Kodu Gönderildi: $mockCode'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final phone = '+90${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
      final res = await ApiService.verifyOtp(phone, _otpController.text);
      setState(() => _isLoading = false);

      final Map<String, dynamic> rawUser = res['user'] ?? res;
      final Map<String, dynamic> user = Map<String, dynamic>.from(rawUser);
      user['role'] = _selectedRole;

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(user);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. ÜST HEADER ALANI (Web Modal Header 1-to-1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF2A55), Color(0xFFDC2626)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Tema Sanalmarket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3)),
                              SizedBox(height: 2),
                              Text('SMS OTP ile Tek Tıkla Şifresiz Giriş', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (Navigator.canPop(context) || widget.onClose != null)
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              if (widget.onClose != null) {
                                widget.onClose!();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 2. ROL SEÇİM SEKMELERİ (Soft Pill Segmented Control 1-to-1)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildRoleTab(0, Icons.person, 'Müşteri')),
                        Expanded(child: _buildRoleTab(1, Icons.two_wheeler, 'Kurye')),
                        Expanded(child: _buildRoleTab(2, Icons.store, 'Bayi / Satıcı')),
                      ],
                    ),
                  ),

                  // 3. TELEFON GİRİŞİ VEYA OTP GİRİŞİ ALANI
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label Row (Label + Test Müşteri Chip)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cep Telefonu Numarası', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _phoneController.text = '5551234567';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFFFECDD3)),
                                ),
                                child: const Text('Test Müşteri: 5551234567', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Telefon Giriş Kutusu (Bayi/Müşteri Tasarımı 1-to-1)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.phone_iphone, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 4),
                                    Text('+90', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                                  decoration: const InputDecoration(
                                    hintText: '5551234567',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          const Text('SMS Doğrulama Kodu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                            ),
                            child: TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 4),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '123987',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // 4. KVKK VE İZİN CHECKBOX (1-to-1)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _kvkkAccepted,
                                activeColor: const Color(0xFFDC2626),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => setState(() => _kvkkAccepted = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "KVKK Aydınlatma Metni'ni, Ticari İleti SMS ve Anlık Mobil Bildirim İzin Şartlarını okudum, kabul ediyorum.",
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.3),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 5. GÖNDER / DOĞRULA BUTONU (Gradient Red Button 1-to-1)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              elevation: 4,
                              shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                            onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _otpSent ? 'Doğrula ve Giriş Yap' : 'Doğrulama Kodu Gönder',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(int tabIndex, IconData icon, String label) {
    final bool isSelected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabIndex;
          _otpSent = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
