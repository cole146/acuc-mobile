import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'web.dart';

/// Opens sign-in from anywhere; returns true when the person is signed in afterwards.
Future<bool> requireSignIn(BuildContext context, {String reason = ''}) async {
  if (Session.I.signedIn) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SignInPage(reason: reason)));
  return ok == true && Session.I.signedIn;
}

/// Sign in — the same look as the app sign-in page (acuc-app-login): big centred logo, tall rounded
/// fields, solid pill "Continue", "Forgot password?" under it, "Create new account" at the bottom.
class SignInPage extends StatefulWidget {
  final String reason;
  final bool rootPage; // shown as the app's first screen (no back arrow)
  const SignInPage({super.key, this.reason = '', this.rootPage = false});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _step2 = false;
  bool _busy = false;
  bool _hide = true;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (!_step2) {
      final e = _email.text.trim();
      if (e.isEmpty) {
        setState(() => _error = 'Enter your email address.');
        return;
      }
      setState(() {
        _error = '';
        _step2 = true;
      });
      Future.delayed(const Duration(milliseconds: 250), () => _passFocus.requestFocus());
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Session.I.signIn(_email.text, _pass.text);
      Saved.I.load();
      Unread.I.refresh();
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _web({bool signup = false}) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => WebAuthPage(signup: signup)));
    if (ok == true && mounted) {
      Saved.I.load();
      Unread.I.refresh();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _email.text.trim());
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0x2E14213D), borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 18),
          const Text('Reset your password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AC.ink2)),
          const SizedBox(height: 6),
          const Text('We’ll email you a link to choose a new one.', style: TextStyle(fontSize: 15, color: AC.sub, fontWeight: FontWeight.w300)),
          const SizedBox(height: 16),
          TextField(controller: c, autofocus: true, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address')),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Send link')),
        ]),
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      final r = await Session.I.post('/app/password-reset', {'login': email}, auth: false);
      if (mounted) toast(context, (r['message'] ?? 'Check your email for a reset link.').toString());
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: 48,
                    child: Row(children: [
                      if (!widget.rootPage || _step2)
                        IconButton(
                          onPressed: () {
                            if (_step2) {
                              setState(() {
                                _step2 = false;
                                _error = '';
                              });
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          icon: const Svg(Ico.back, size: 24, color: AC.ink2),
                        ),
                    ]),
                  ),
                  SizedBox(height: _step2 ? (h * 0.05).clamp(16, 50) : (h * 0.12).clamp(30, 110)),
                  Center(child: Image.asset('assets/images/logo.png', width: _step2 ? 60 : 76, height: _step2 ? 60 : 76)),
                  if (_step2) ...[
                    const SizedBox(height: 18),
                    const Text('Enter your password', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: Color(0xFF1C1E21))),
                    const SizedBox(height: 2),
                    Text(_email.text.trim(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF606770))),
                    const SizedBox(height: 28),
                  ] else
                    SizedBox(height: (h * 0.08).clamp(28, 84)),
                  if (widget.reason.isNotEmpty && !_step2) ...[
                    Text(widget.reason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF606770))),
                    const SizedBox(height: 16),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _step2
                        ? TextField(
                            key: const ValueKey('pw'),
                            controller: _pass,
                            focusNode: _passFocus,
                            obscureText: _hide,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _continue(),
                            style: const TextStyle(fontSize: 17, color: Color(0xFF1C1E21)),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() => _hide = !_hide),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                  child: Text(_hide ? 'Show' : 'Hide', style: const TextStyle(color: Color(0xFF606770), fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          )
                        : TextField(
                            key: const ValueKey('em'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _continue(),
                            style: const TextStyle(fontSize: 17, color: Color(0xFF1C1E21)),
                            decoration: const InputDecoration(hintText: 'Email address'),
                          ),
                  ),
                  if (_error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(color: AC.redSoft, borderRadius: BorderRadius.circular(14)),
                      child: Text(_error, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w500, fontSize: 14.5)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _continue,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_step2)
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _web(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDADDE1)),
                          foregroundColor: const Color(0xFF1C1E21),
                          textStyle: const TextStyle(fontFamily: AC.font, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _GoogleG(),
                          SizedBox(width: 10),
                          Text('Continue with Google'),
                        ]),
                      ),
                    ),
                  TextButton(
                    onPressed: _forgot,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF1C1E21)),
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => _web(signup: true),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AC.brand, width: 1.5),
                        foregroundColor: AC.brand,
                        textStyle: const TextStyle(fontFamily: AC.font, fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Create new account'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(child: Opacity(opacity: 0.9, child: Image.asset('assets/images/wordmark.png', height: 22))),
                  const SizedBox(height: 18),
                ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: Text('G', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF4285F4), height: 1.15)),
      );
}
