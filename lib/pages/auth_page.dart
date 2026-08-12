import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

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
  late String _selectedRole;
  final TextEditingController _phoneController =
      TextEditingController(text: '5551234567');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.defaultRole;
  }

  void _sendOtp() async {
    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir telefon numarası girin.'),
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

    // Pop-up Modal (Bottom Sheet) ile SMS Doğrulama Kodu Giriş Alanını Aç
    _showOtpModal(mockCode);
  }

  void _showOtpModal(String prefilledCode) {
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
              if (code.isEmpty) {
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
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle Bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const Icon(Icons.mark_email_read_rounded,
                          size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      const Text(
                        'SMS Doğrulama Kodu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+90 ${_phoneController.text} numarasına gönderilen 6 haneli doğrulama kodunu giriniz.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
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
                          fontSize: 28,
                          letterSpacing: 8,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: '123987',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFDC2626)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFFDC2626), width: 2),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: (_) => verify(),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: verifying ? null : verify,
                          child: verifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Giriş Yap ve Devam Et',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onNavTap(int index) {
    if (index == 0 || index == 1 || index == 2 || index == 3) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildFloatingNavbar(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'id': 0, 'icon': Icons.home_rounded, 'label': 'Ana Sayfa'},
      {'id': 1, 'icon': Icons.store_rounded, 'label': 'Şubeler'},
      {'id': 2, 'icon': Icons.shopping_bag_outlined, 'label': 'Sepetim'},
      {'id': 3, 'icon': Icons.auto_awesome_rounded, 'label': 'Sizin İçin'},
      {'id': 4, 'icon': Icons.person_rounded, 'label': 'Hesabım'},
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xAA140A10),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: navItems.map((item) {
            final int id = item['id'] as int;
            final bool isSelected = id == 4; // Hesabım sayfasındayız
            final IconData icon = item['icon'] as IconData;

            if (isSelected) {
              return GestureDetector(
                onTap: () => _onNavTap(id),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white24,
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: const Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                ),
              );
            }

            return GestureDetector(
              onTap: () => _onNavTap(id),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildFloatingNavbar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Görsel 1: TEMA Capsule Glow Badge + Red Market Text Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2A55), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'TEMA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Market',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Hızlı ve Güvenli SMS Girişi',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Giriş Yapılacak Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Customer',
                              child: Text('🛒 Müşteri Hesabı',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Merchant',
                              child: Text('🏢 Bayi / Şube Yöneticisi',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Courier',
                              child: Text('🛵 Kurye Teslimat Personeli',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'SuperAdmin',
                              child: Text('👑 Genel Yönetici Konsolu',
                                  overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon Numarası',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendOtp(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: _isLoading ? null : _sendOtp,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('SMS Kodu Gönder',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
