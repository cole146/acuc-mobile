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

class WelcomePage extends StatelessWidget {
  final VoidCallback onBrowse;
  const WelcomePage({super.key, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(flex: 2),
            Center(child: Image.asset('assets/images/logo.png', width: 92, height: 92)),
            const SizedBox(height: 26),
            const Text('Find your next job,\nanywhere in the world',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Search jobs, apply in a few taps, track every application and talk to employers.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, color: AC.sub, height: 1.5)),
            const Spacer(flex: 3),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInPage())),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WebAuthPage(signup: true))),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: onBrowse, child: const Text('Browse jobs first', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  final String reason;
  const SignInPage({super.key, this.reason = ''});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String _error = '';

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_login.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Session.I.signIn(_login.text, _pass.text);
      Saved.I.load();
      Unread.I.refresh();
      if (mounted) Navigator.of(context).pop(true);
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
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _login.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Send link')),
        ],
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Image.asset('assets/images/logo.png', width: 56, height: 56, alignment: Alignment.centerLeft),
            const SizedBox(height: 18),
            const Text('Sign in to ACUC', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.reason.isNotEmpty ? widget.reason : 'Use the same email and password as on acuc.jobs.',
                style: const TextStyle(color: AC.sub, fontSize: 15)),
            const SizedBox(height: 24),
            TextField(
              controller: _login,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error, style: const TextStyle(color: AC.red, fontWeight: FontWeight.w600)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 22),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AC.sub))),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _web(),
              icon: const Icon(Icons.language_rounded),
              label: const Text('Other ways to sign in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _web(signup: true), child: const Text('Create a new account')),
          ],
        ),
      ),
    );
  }
}
