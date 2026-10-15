import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'lists.dart';
import 'web.dart';

class AppLock {
  static const key = 'app_lock';
  static Future<bool> enabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> set(bool on) async => (await SharedPreferences.getInstance()).setBool(key, on);

  static Future<bool> unlock({String reason = 'Unlock ACUC Jobs'}) async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return true;
      return await auth.authenticate(localizedReason: reason);
    } catch (_) {
      return true;
    }
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _lock = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppLock.enabled().then((v) => mounted ? setState(() => _lock = v) : null);
    Session.I.refreshMe();
  }

  Future<void> _uploadCv() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    final f = r?.files.single;
    if (f?.path == null) return;
    setState(() => _busy = true);
    try {
      await Session.I.upload('/cv', 'cv', f!.path!, filename: f.name);
      await Session.I.refreshMe();
      if (mounted) toast(context, 'CV updated');
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    final f = r?.files.single;
    if (f?.path == null) return;
    setState(() => _busy = true);
    try {
      await Session.I.upload('/photo', 'photo', f!.path!, filename: f.name);
      await Session.I.refreshMe();
      if (mounted) toast(context, 'Photo updated');
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLock(bool on) async {
    if (on && !await AppLock.unlock(reason: 'Confirm to turn on fingerprint lock')) return;
    await AppLock.set(on);
    setState(() => _lock = on);
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again any time with your email and password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await Session.I.signOut();
    Saved.I.ids.clear();
    Unread.I.value = 0;
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {String? sub, Color color = AC.blue}) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: AC.sub),
        onTap: onTap,
      );

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(color: AC.sub, fontWeight: FontWeight.w800, fontSize: 13))),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AC.line)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        if (!Session.I.signedIn) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: ListView(children: [
              const SizedBox(height: 40),
              const SignedOutHint(icon: Icons.person_outline_rounded, title: 'Your ACUC profile', text: 'Sign in to manage your profile, CV and settings.'),
              _section('ACUC', [
                _tile(Icons.privacy_tip_outlined, 'Privacy policy', () => launchUrl(Uri.parse('$kBase/privacy-policy/'), mode: LaunchMode.externalApplication)),
              ]),
            ]),
          );
        }
        final u = Session.I.user ?? {};
        final photo = (u['photo'] is Map ? u['photo']['url'] : u['avatar_url'] ?? '').toString();
        final cv = u['cv'] is Map ? u['cv'] as Map : const {};
        final cvName = (cv['filename'] ?? '').toString();
        final headline = [(u['headline'] ?? '').toString(), (u['location'] ?? '').toString()].where((s) => s.isNotEmpty).join(' · ');
        final slug = (u['slug'] ?? u['profile_slug'] ?? '').toString();
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: RefreshIndicator(
            onRefresh: Session.I.refreshMe,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(children: [
                    GestureDetector(
                      onTap: _busy ? null : _uploadPhoto,
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: AC.bg,
                          backgroundImage: photo.startsWith('http') ? CachedNetworkImageProvider(photo) : null,
                          child: photo.startsWith('http') ? null : Text(Session.I.name.isEmpty ? 'A' : Session.I.name[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: AC.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Session.I.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        if (headline.isNotEmpty) ...[const SizedBox(height: 3), Text(headline, style: const TextStyle(color: AC.sub))],
                        const SizedBox(height: 3),
                        Text((u['email'] ?? '').toString(), style: const TextStyle(color: AC.sub, fontSize: 13.5)),
                      ]),
                    ),
                  ]),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                _section('PROFILE', [
                  _tile(Icons.edit_outlined, 'Edit profile', () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                  }, sub: 'Name, headline, location, phone, summary'),
                  _tile(Icons.description_outlined, cvName.isEmpty ? 'Upload your CV' : 'Replace CV', _uploadCv, sub: cvName.isEmpty ? 'PDF or Word' : cvName),
                  _tile(Icons.public_rounded, 'View my public profile',
                      () => WebPage.open(context, slug.isNotEmpty ? '/network/?candidate=$slug' : '/network/', 'My profile')),
                ]),
                _section('CAREER TOOLS', [
                  _tile(Icons.auto_awesome_outlined, 'CV builder', () => WebPage.open(context, '/network/my-workspace/resumes/', 'CV builder')),
                  _tile(Icons.record_voice_over_outlined, 'Interview coach', () => WebPage.open(context, '/network/my-workspace/interviews/', 'Interview coach')),
                  _tile(Icons.dashboard_outlined, 'My workspace', () => WebPage.open(context, '/network/my-workspace/', 'My workspace')),
                  _tile(Icons.explore_outlined, 'Career hub', () => WebPage.open(context, '/network/career-hub/', 'Career hub')),
                  _tile(Icons.people_outline_rounded, 'My network', () => WebPage.open(context, '/network/', 'Network')),
                ]),
                _section('SETTINGS', [
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AC.blue.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.fingerprint_rounded, color: AC.blue),
                    ),
                    title: const Text('Fingerprint lock', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Unlock the app with your fingerprint or screen lock'),
                    value: _lock,
                    onChanged: _toggleLock,
                  ),
                  _tile(Icons.lock_reset_rounded, 'Account settings', () => WebPage.open(context, '/network/settings/', 'Settings')),
                  _tile(Icons.privacy_tip_outlined, 'Privacy policy', () => launchUrl(Uri.parse('$kBase/privacy-policy/'), mode: LaunchMode.externalApplication)),
                  _tile(Icons.help_outline_rounded, 'Help & contact', () => launchUrl(Uri.parse('mailto:support@acuc.jobs'), mode: LaunchMode.externalApplication)),
                  _tile(Icons.delete_outline_rounded, 'Delete account', () => WebPage.open(context, '/delete-account/', 'Delete account'), color: AC.red),
                  _tile(Icons.logout_rounded, 'Sign out', _signOut, color: AC.red),
                ]),
                const SizedBox(height: 18),
                const Center(child: Text('ACUC Jobs $kAppVersion · ACUC LLC', style: TextStyle(color: AC.sub, fontSize: 12.5))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final Map<String, TextEditingController> _f;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = Session.I.user ?? {};
    _f = {for (final k in ['name', 'headline', 'location', 'phone', 'linkedin', 'summary']) k: TextEditingController(text: (u[k] ?? '').toString())};
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_f['name']!.text.trim().isEmpty) {
      toast(context, 'Your name can’t be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      await Session.I.post('/profile', {for (final e in _f.entries) e.key: e.value.text.trim()});
      await Session.I.refreshMe();
      if (mounted) {
        toast(context, 'Profile saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String k, String label, {int lines = 1, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: _f[k], minLines: lines, maxLines: lines == 1 ? 1 : 8, keyboardType: type, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Edit profile'), actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          _field('name', 'Full name'),
          _field('headline', 'Headline (e.g. Sales Executive)'),
          _field('location', 'City, country'),
          _field('phone', 'Phone', type: TextInputType.phone),
          _field('linkedin', 'LinkedIn URL', type: TextInputType.url),
          _field('summary', 'About you', lines: 5),
          const SizedBox(height: 8),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
        ]),
      );
}
