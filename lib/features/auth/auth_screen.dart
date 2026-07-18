import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';

/// The Google "G" mark (brand colors) as inline SVG.
const _googleG = '''
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.teal,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topStart,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Color(0x99F4EEE1)),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('كَلِمَات',
                            style: TextStyle(
                                fontFamily: KFonts.display,
                                fontSize: 60,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                color: Color(0xFFF4EEE1))),
                        const SizedBox(height: 10),
                        Text('يهديك إلى أصلِ الكلمةِ ومعناها',
                            style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFFF4EEE1).withOpacity(0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _AuthSheet(),
        ],
      ),
    );
  }
}

class _AuthSheet extends ConsumerStatefulWidget {
  const _AuthSheet();
  @override
  ConsumerState<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<_AuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _authError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'بريد إلكتروني غير صالح.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'البريد أو كلمة المرور غير صحيحة.';
        case 'email-already-in-use':
          return 'هذا البريد مُسجَّل بالفعل.';
        case 'weak-password':
          return 'كلمة المرور ضعيفة (٦ أحرف على الأقل).';
        case 'network-request-failed':
          return 'تعذّر الاتصال بالشبكة.';
        default:
          return 'تعذّر إتمام العملية: ${e.code}';
      }
    }
    if (e is StateError) return e.message; // Firebase not configured
    return 'حدث خطأ غير متوقّع.';
  }

  /// After any successful sign-in: pull remote settings (or seed them).
  Future<void> _afterAuth() async {
    final auth = ref.read(authServiceProvider);
    final sync = ref.read(syncServiceProvider);
    final user = auth.currentUser;
    if (user != null) {
      final remote = await sync.pullHiddenSources(user.uid);
      if (remote != null) {
        ref.read(hiddenSourcesProvider.notifier).setAll(remote);
      } else {
        await sync.push(
            uid: user.uid, hiddenSources: ref.read(hiddenSourcesProvider));
      }
      if (mounted) context.pop();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      await _afterAuth();
    } catch (e) {
      _toast(_authError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _google() => _run(ref.read(authServiceProvider).signInWithGoogle);

  void _email_() {
    final e = _email.text.trim();
    final p = _password.text;
    if (e.isEmpty || p.isEmpty) {
      _toast('أدخل البريد وكلمة المرور.');
      return;
    }
    final auth = ref.read(authServiceProvider);
    _run(() => _register ? auth.registerWithEmail(e, p) : auth.signInWithEmail(e, p));
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(firebaseReadyProvider);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: KColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: SafeArea(
        top: false,
        child: AdaptiveContent(
          maxWidth: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_register ? 'إنشاء حساب' : 'مرحبًا بك',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: KColors.ink)),
              const SizedBox(height: 6),
              Text('سجّل الدخول لحفظ بحثك ومزامنة إعداداتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: KColors.sub)),
              const SizedBox(height: 20),

              if (!ready)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KColors.verseBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KColors.verseBorder),
                  ),
                  child: Text(
                    'المزامنة غير مُهيّأة بعد على هذه النسخة. التطبيق يعمل كاملًا دون حساب.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: KColors.brassText),
                  ),
                ),

              // Google
              OutlinedButton(
                onPressed: _loading ? null : _google,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFDCD2BC), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(_googleG, width: 20, height: 20),
                    const SizedBox(width: 12),
                    const Text('المتابعة عبر Google',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: KColors.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  const Expanded(child: Divider(color: KColors.paperLine)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('أو', style: TextStyle(color: KColors.mist, fontSize: 13)),
                  ),
                  const Expanded(child: Divider(color: KColors.paperLine)),
                ],
              ),
              const SizedBox(height: 18),

              Text('البريد الإلكتروني',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: KColors.teal)),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16, color: KColors.ink),
                  decoration: _fieldDecoration('name@example.com'),
                ),
              ),
              const SizedBox(height: 12),
              Text('كلمة المرور',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: KColors.teal)),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _password,
                  obscureText: true,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16, color: KColors.ink),
                  decoration: _fieldDecoration('••••••••'),
                ),
              ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: _loading ? null : _email_,
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFF4EEE1)))
                    : Text(_register ? 'إنشاء الحساب' : 'متابعة',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF4EEE1))),
              ),
              const SizedBox(height: 16),

              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _register = !_register),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: _register ? 'لديك حساب؟ ' : 'ليس لديك حساب؟ ',
                        style: TextStyle(fontSize: 13, color: KColors.sub)),
                    TextSpan(
                        text: _register ? 'تسجيل الدخول' : 'أنشئ حسابًا',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: KColors.teal)),
                  ])),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: KColors.tealTintBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KColors.tealTintBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 15, color: KColors.teal),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('الاستخدام متاح دون اتصال — الحساب للمزامنة فقط',
                          style: TextStyle(fontSize: 12, color: KColors.teal)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('المتابعة دون حساب',
                    style: TextStyle(fontSize: 13, color: KColors.sub)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: KColors.mist),
        filled: true,
        fillColor: KColors.paperCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCD2BC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KColors.teal, width: 1.5),
        ),
      );
}
