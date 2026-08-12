import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// TEMASAN ERP — Mobil SMS OTP Giriş Sayfası
/// • Telefon numarası girilip "Kodu Gönder" basılınca OTP Bottom Sheet açılır
/// • Ana sayfaya dön butonu her zaman görünür
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
  int _activeTab = 0;
  final TextEditingController _phoneController =
      TextEditingController(text: '5551234567');
  bool _isLoading = false;
  bool _kvkkAccepted = true;

  @override
  void initState() {
    super.initState();
    if (widget.defaultRole == 'Courier') {
      _activeTab = 1;
    } else if (widget.defaultRole == 'Merchant' ||
        widget.defaultRole == 'SuperAdmin') {
      _activeTab = 2;
    }
  }

  String get _selectedRole {
    if (_activeTab == 1) return 'Courier';
    if (_activeTab == 2) return 'Merchant';
    return 'Customer';
  }

  // ─── OTP Kodu Gönder ve ardından bottom sheet aç ───────────────
  void _sendOtp() async {
    if (!_kvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen KVKK ve izin şartlarını onaylayın.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir 10 haneli telefon numarası girin.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    String mockCode = '';
    try {
      final phone = '+90$raw';
      final res = await ApiService.sendOtp(phone);
      mockCode = (res['data']?['mock_otp_code'] ??
              res['demo_code'] ??
              res['mock_otp_code'] ??
              '')
          .toString();
    } catch (_) {
      mockCode = '';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    // OTP bottom sheet'i aç
    _showOtpBottomSheet(mockCode);
  }

  // ─── OTP Bottom Sheet ───────────────────────────────────────────
  void _showOtpBottomSheet(String prefilledCode) {
    final otpController = TextEditingController(text: prefilledCode);
    bool verifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> verify() async {
              final code = otpController.text.trim();
              if (code.length < 4) {
                setModalState(() => errorText = 'Lütfen doğrulama kodunu girin.');
                return;
              }
              setModalState(() {
                verifying = true;
                errorText = null;
              });
              try {
                final phone =
                    '+90${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
                final res = await ApiService.verifyOtp(phone, code);

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                final Map<String, dynamic> rawUser = res['user'] ?? res;
                final Map<String, dynamic> user =
                    Map<String, dynamic>.from(rawUser);
                if (user['role'] == null || user['role'].toString().isEmpty) {
                  user['role'] = _selectedRole;
                }

                widget.onLoginSuccess?.call(user);
              } catch (e) {
                setModalState(() {
                  verifying = false;
                  errorText = e.toString().replaceAll('ApiException(200): ', '');
                });
              }
            }

            return Padding(
              // Klavye çıktığında kaymayı sağla
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ─── Tutamaç çizgisi
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),

                        // ─── Lock ikonu
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFECDD3), width: 1.5),
                          ),
                          child: const Icon(Icons.lock_rounded,
                              size: 30, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 16),

                        // ─── Başlık
                        const Text(
                          'SMS Doğrulama Kodu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '+90 ${_phoneController.text} numarasına\ngönderilen 6 haneli kodu girin.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.5),
                        ),
                        const SizedBox(height: 28),

                        // ─── 6 Hane OTP Kutusu
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: errorText != null
                                  ? Colors.red
                                  : const Color(0xFFDC2626),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626)
                                    .withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: otpController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              letterSpacing: 10,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: '●  ●  ●  ●  ●  ●',
                              hintStyle: TextStyle(
                                  fontSize: 20,
                                  letterSpacing: 6,
                                  color: Color(0xFFCBD5E1)),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 18),
                            ),
                            onSubmitted: (_) => verify(),
                          ),
                        ),

                        if (errorText != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFDC2626), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorText!,
                                    style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ─── Giriş Yap Butonu
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              elevation: 4,
                              shadowColor: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                            ),
                            onPressed: verifying ? null : verify,
                            child: verifying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Doğrula ve Giriş Yap',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ─── Tekrar Kod Gönder
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendOtp();
                          },
                          child: const Text(
                            'Kodu almadım, tekrar gönder →',
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Ana Sayfaya Dön butonu (üstte)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                    label: const Text(
                      'Ana Sayfaya Dön',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Giriş Kartı
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
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
                        // ─── Header
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF2A55),
                                        Color(0xFFDC2626)
                                      ]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Text('TEMA',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Tema Sanalmarket',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.3)),
                                    SizedBox(height: 2),
                                    Text(
                                        'SMS OTP ile Tek Tıkla Şifresiz Giriş',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        // ─── Rol Sekmeleri
                        Container(
                          margin:
                              const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildRoleTab(
                                      0, Icons.person, 'Müşteri')),
                              Expanded(
                                  child: _buildRoleTab(
                                      1, Icons.two_wheeler, 'Kurye')),
                              Expanded(
                                  child: _buildRoleTab(
                                      2, Icons.store, 'Bayi / Satıcı')),
                            ],
                          ),
                        ),

                        // ─── Form Alanı
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Telefon label + Test chip
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Cep Telefonu Numarası',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155))),
                                  InkWell(
                                    borderRadius:
                                        BorderRadius.circular(100),
                                    onTap: () => setState(() =>
                                        _phoneController.text =
                                            '5551234567'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        border: Border.all(
                                            color:
                                                const Color(0xFFFECDD3)),
                                      ),
                                      child: const Text(
                                          'Test Müşteri: 5551234567',
                                          style: TextStyle(
                                              color: Color(0xFFDC2626),
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // +90 Telefon Kutusu
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(14),
                                          bottomLeft: Radius.circular(14),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.phone_iphone,
                                              size: 16,
                                              color: Color(0xFFDC2626)),
                                          SizedBox(width: 4),
                                          Text('+90',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color:
                                                      Color(0xFF0F172A),
                                                  fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType:
                                            TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(
                                              11),
                                        ],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            letterSpacing: 1),
                                        decoration:
                                            const InputDecoration(
                                          hintText: '5551234567',
                                          border: InputBorder.none,
                                          contentPadding:
                                              EdgeInsets.only(right: 16),
                                        ),
                                        onSubmitted: (_) => _sendOtp(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // KVKK Checkbox
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _kvkkAccepted,
                                      activeColor:
                                          const Color(0xFFDC2626),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      onChanged: (val) => setState(() =>
                                          _kvkkAccepted = val ?? true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "KVKK Aydınlatma Metni'ni, Ticari İleti SMS ve Anlık Mobil Bildirim İzin Şartlarını okudum, kabul ediyorum.",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF64748B),
                                          height: 1.3),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Doğrulama Kodu Gönder Butonu
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFDC2626),
                                    elevation: 4,
                                    shadowColor: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100)),
                                  ),
                                  onPressed:
                                      _isLoading ? null : _sendOtp,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5))
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.sms_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Doğrulama Kodu Gönder',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: Colors.white),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(Icons.arrow_forward,
                                                size: 16,
                                                color: Colors.white),
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
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTab(int tabIndex, IconData icon, String label) {
    final bool isSelected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFFDC2626) : Colors.transparent,
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
            Icon(icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
