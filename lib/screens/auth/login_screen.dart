import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _codeSent = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.gray400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _sendCode(AuthProvider auth) async {
    setState(() {
      _errorMessage = '';
    });
    
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen geçerli bir telefon numarası girin.';
      });
      return;
    }

    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        formattedPhone = '+90${phone.substring(1)}';
      } else {
        formattedPhone = '+90$phone';
      }
    }

    await auth.verifyPhone(
      phone: formattedPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _codeSent = true;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
        });
      },
    );
  }

  Future<void> _verifyOTP(AuthProvider auth) async {
    setState(() {
      _errorMessage = '';
    });

    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() {
        _errorMessage = 'Lütfen 6 haneli doğrulama kodunu girin.';
      });
      return;
    }

    try {
      await auth.signInWithOTP(code);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800),
                        children: const [
                          TextSpan(text: 'Süt', style: TextStyle(color: AppColors.primary600)),
                          TextSpan(text: 'App', style: TextStyle(color: AppColors.gray800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dijital Süt Toplama Platformu',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                    ),
                    const SizedBox(height: 24),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _codeSent ? 'Doğrulama Kodu' : 'Telefonla Giriş / Üye Ol',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          if (!_codeSent) ...[
                            // Phone Number Field
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Telefon Numarası',
                                hintText: '555 123 4567',
                                prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AppColors.gray400),
                              ),
                            ),
                          ] else ...[
                            // SMS Code Field
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'Doğrulama Kodu',
                                hintText: '######',
                                counterText: '',
                                prefixIcon: Icon(Icons.security_outlined, size: 18, color: AppColors.gray400),
                              ),
                            ),
                          ],

                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: GestureDetector(
                              onTap: auth.loading
                                  ? null
                                  : () => _codeSent ? _verifyOTP(auth) : _sendCode(auth),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: AppShadows.blue,
                                ),
                                child: Center(
                                  child: auth.loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _codeSent ? 'Kodu Doğrula' : 'Kod Gönder',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          if (_codeSent) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _codeSent = false;
                                  _codeController.clear();
                                });
                              },
                              child: Text(
                                'Numarayı Değiştir',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary600, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(children: [
                      Expanded(child: Container(height: 1, color: AppColors.gray200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('HIZLI DEMO GİRİŞ', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.gray400, letterSpacing: 0.8)),
                      ),
                      Expanded(child: Container(height: 1, color: AppColors.gray200)),
                    ]),
                    const SizedBox(height: 16),

                    // Group 1: Yönetim & Firmalar
                    _buildSectionHeader('YÖNETİM VE FİRMALAR'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _DemoBtn(
                        icon: Icons.admin_panel_settings_rounded, label: 'Admin', desc: 'Sistem Yönetimi',
                        color: const Color(0xFF7C3AED), bgColor: const Color(0xFFEDE9FE),
                        onTap: () => auth.demoLogin(UserRole.admin),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _DemoBtn(
                        icon: Icons.business_rounded, label: 'Kayseri Çiftlik', desc: 'Firma Yöneticisi',
                        color: AppColors.primary600, bgColor: AppColors.primary50,
                        onTap: () => auth.demoLogin(UserRole.firma, customName: 'Kayseri Çiftlik'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _DemoBtn(
                        icon: Icons.business_rounded, label: 'Sivas Süt A.Ş.', desc: 'Firma Yöneticisi',
                        color: AppColors.primary600, bgColor: AppColors.primary50,
                        onTap: () => auth.demoLogin(UserRole.firma, customName: 'Sivas Süt A.Ş.'),
                      )),
                    ]),
                    
                    const SizedBox(height: 16),

                    // Group 2: Toplayıcılar
                    _buildSectionHeader('TOPLAYICILAR'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _DemoBtn(
                        icon: Icons.local_shipping_rounded, label: 'Ahmet Kara', desc: 'Toplayıcı',
                        color: AppColors.success, bgColor: AppColors.successLight,
                        onTap: () => auth.demoLogin(UserRole.surucu, customName: 'Ahmet Kara'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _DemoBtn(
                        icon: Icons.local_shipping_rounded, label: 'Veli Yıldız', desc: 'Toplayıcı',
                        color: AppColors.success, bgColor: AppColors.successLight,
                        onTap: () => auth.demoLogin(UserRole.surucu, customName: 'Veli Yıldız'),
                      )),
                    ]),

                    const SizedBox(height: 16),

                    // Group 3: Üreticiler
                    _buildSectionHeader('ÜRETİCİLER'),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.8,
                      children: [
                        _DemoBtn(
                          icon: Icons.agriculture_rounded, label: 'Mehmet Yılmaz', desc: 'Süt Üreticisi',
                          color: AppColors.warning, bgColor: AppColors.warningLight,
                          onTap: () => auth.demoLogin(UserRole.uretici, customName: 'Mehmet Yılmaz'),
                        ),
                        _DemoBtn(
                          icon: Icons.agriculture_rounded, label: 'Fatma Korkmaz', desc: 'Süt Üreticisi',
                          color: AppColors.warning, bgColor: AppColors.warningLight,
                          onTap: () => auth.demoLogin(UserRole.uretici, customName: 'Fatma Korkmaz'),
                        ),
                        _DemoBtn(
                          icon: Icons.agriculture_rounded, label: 'Ali Özdemir', desc: 'Süt Üreticisi',
                          color: AppColors.warning, bgColor: AppColors.warningLight,
                          onTap: () => auth.demoLogin(UserRole.uretici, customName: 'Ali Özdemir'),
                        ),
                        _DemoBtn(
                          icon: Icons.agriculture_rounded, label: 'Ayşe Şahin', desc: 'Süt Üreticisi',
                          color: AppColors.warning, bgColor: AppColors.warningLight,
                          onTap: () => auth.demoLogin(UserRole.uretici, customName: 'Ayşe Şahin'),
                        ),
                        _DemoBtn(
                          icon: Icons.agriculture_rounded, label: 'Hüseyin Kaya', desc: 'Süt Üreticisi',
                          color: AppColors.warning, bgColor: AppColors.warningLight,
                          onTap: () => auth.demoLogin(UserRole.uretici, customName: 'Hüseyin Kaya'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _DemoBtn({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200, width: 1.5),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

