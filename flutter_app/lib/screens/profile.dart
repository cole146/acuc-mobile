import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'jobs.dart';
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

/// The round "G" in the header → your settings.
void openMe(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));

Future<void> uploadCv(BuildContext context) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
  final f = r?.files.single;
  if (f?.path == null) return;
  if (context.mounted) toast(context, 'Uploading your CV…');
  try {
    await Session.I.upload('/cv', 'cv', f!.path!, filename: f.name);
    await Session.I.refreshMe();
    if (context.mounted) toast(context, 'CV updated');
  } catch (e) {
    if (context.mounted) toast(context, '$e');
  }
}

Future<void> uploadPhoto(BuildContext context) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image);
  final f = r?.files.single;
  if (f?.path == null) return;
  if (context.mounted) toast(context, 'Uploading your photo…');
  try {
    await Session.I.upload('/photo', 'photo', f!.path!, filename: f.name);
    await Session.I.refreshMe();
    if (context.mounted) toast(context, 'Photo updated');
  } catch (e) {
    if (context.mounted) toast(context, '$e');
  }
}

/// Home: your profile, exactly like the Network profile page (cover, avatar, name, headline, place,
/// online status, connections, Share / Settings, Analytics) — plus your CV, applications and tools.
class HomePage extends StatefulWidget {
  final ValueChanged<int> onGoTab;
  const HomePage({super.key, required this.onGoTab});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> _p = {};
  int _connections = 0;
  int _applications = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Session.I.refreshMe();
    final id = Session.I.user?['id'];
    if (id == null) return;
    try {
      final r = await Session.I.get('/jobseekers/browse/$id');
      if (mounted && r is Map) setState(() => _p = r.cast<String, dynamic>());
    } catch (_) {}
    Session.I.get('/friends').then((r) {
      if (mounted) setState(() => _connections = ((r['items'] ?? []) as List).length);
    }).catchError((_) {});
    Session.I.get('/applications', {'per_page': 1}).then((r) {
      if (mounted) setState(() => _applications = (r['total'] ?? 0) as int);
    }).catchError((_) {});
  }

  String _s(String k) => (_p[k] ?? Session.I.user?[k] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final u = Session.I.user ?? {};
        final name = Session.I.name;
        final photo = (u['photo'] is Map ? (u['photo']['id'] ?? 0) != 0 ? u['photo']['url'] : '' : '').toString();
        final headline = _s('title').isNotEmpty ? _s('title') : _s('headline');
        final loc = _s('location');
        final seen = _p['last_seen'] is Map ? (_p['last_seen']['label'] ?? '').toString() : '';
        final online = _p['last_seen'] is Map && _p['last_seen']['state'] == 'online';
        final slug = _s('slug');
        final cv = u['cv'] is Map ? u['cv'] as Map : const {};
        final cvName = (cv['filename'] ?? '').toString();
        final strength = _p['cv_strength'] is int ? _p['cv_strength'] as int : 0;
        return Scaffold(
          backgroundColor: AC.bg,
          appBar: AcucTopBar(onSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobSearchPage())), onMe: () => openMe(context)),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(0, 16, 0, 120), children: [
              // ---------- profile card ----------
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AC.softShadow),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(height: 130, decoration: const BoxDecoration(gradient: AC.coverGradient)),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _MiniRound(icon: Ico.pen, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()))),
                    ),
                    Positioned(
                      left: 16,
                      bottom: -50,
                      child: GestureDetector(
                        onTap: () => uploadPhoto(context),
                        child: Stack(clipBehavior: Clip.none, children: [
                          PersonAvatar(name: name, photo: photo, size: 100, ring: true),
                          Positioned(right: 0, top: 8, child: _MiniRound(icon: Ico.camera, size: 26)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 62),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(name, style: T.name)),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
                          icon: const Svg(Ico.pen, size: 17, color: AC.sub),
                        ),
                      ]),
                      if (headline.isNotEmpty) ...[const SizedBox(height: 6), Text(headline, style: T.body.copyWith(fontSize: 16.5, color: AC.ink2))],
                      const SizedBox(height: 14),
                      Row(children: [
                        const Text('🌍', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        if (loc.isNotEmpty) ...[
                          Text(loc, style: T.body.copyWith(color: AC.sub, fontSize: 15.5)),
                          const Text('  ·  ', style: TextStyle(color: AC.faint)),
                        ],
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
                          child: const Text('Contact info', style: TextStyle(color: AC.blue, fontWeight: FontWeight.w500, fontSize: 15.5)),
                        ),
                      ]),
                      if (seen.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(seen, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: online ? const Color(0xFF16A34A) : AC.ink2)),
                      ],
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => WebPage.open(context, '/network/friends/', 'Network'),
                        child: Text('$_connections connections',
                            style: const TextStyle(color: AC.blue, fontSize: 15.5, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: AC.blue)),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: _OutlineBtn(
                            icon: Ico.share,
                            label: 'Share',
                            onTap: () => SharePlus.instance.share(ShareParams(text: '$name on ACUC\n$kBase/network/?candidate=$slug')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _OutlineBtn(icon: Ico.gear, label: 'Settings', onTap: () => openMe(context))),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // ---------- analytics ----------
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Analytics', style: T.cardTitle),
                    const SizedBox(width: 10),
                    const Svg(Ico.eye, size: 15, color: AC.sub),
                    const SizedBox(width: 5),
                    Text('Private to you', style: T.bodyLight.copyWith(fontSize: 14)),
                  ]),
                  const SizedBox(height: 14),
                  _Stat(icon: Ico.eye, title: '${_p['view_count'] ?? 0} profile views', sub: 'Discover who’s viewed your profile.', onTap: () => WebPage.open(context, '/network/?candidate=$slug', 'Profile views')),
                  _Stat(icon: Ico.search, title: '${_p['search_appearances'] ?? 0} search appearances', sub: 'See how often you turn up in results.'),
                  _Stat(icon: Ico.user, title: '${_p['followers_count'] ?? 0} followers', sub: 'People following this profile.'),
                ]),
              ),
              // ---------- CV & applications ----------
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Your CV', style: T.cardTitle)),
                    if (strength > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: strength >= 70 ? AC.greenSoft : const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(99)),
                        child: Text('$strength% · ${_p['cv_strength_label'] ?? ''}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: strength >= 70 ? AC.green : const Color(0xFFB26A00))),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _Stat(icon: Ico.doc, title: cvName.isEmpty ? 'No CV uploaded yet' : cvName, sub: cvName.isEmpty ? 'Add a CV so you can apply in one tap.' : 'Used when you apply on ACUC.', onTap: () => uploadCv(context)),
                  _Stat(icon: Ico.jobs, title: '$_applications applications', sub: 'Follow every job you applied to.', onTap: () => widget.onGoTab(2)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: _OutlineBtn(icon: Ico.doc, label: cvName.isEmpty ? 'Upload CV' : 'Replace CV', onTap: () => uploadCv(context))),
                    const SizedBox(width: 10),
                    Expanded(child: _OutlineBtn(icon: Ico.sparkle, label: 'CV builder', onTap: () => WebPage.open(context, '/network/my-workspace/resumes/', 'CV builder'))),
                  ]),
                ]),
              ),
              // ---------- tools ----------
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('All tools', style: T.cardTitle),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.18,
                    children: [
                      _Tool('CV Builder', 'Create and edit your CVs, with a live preview.', () => WebPage.open(context, '/network/my-workspace/resumes/', 'CV builder')),
                      _Tool('Interview Coach', 'Practise interviews with AI, by voice or text.', () => WebPage.open(context, '/network/my-workspace/interviews/', 'Interview coach')),
                      _Tool('AI Apply', 'Let AI find and apply to matching jobs.', () => WebPage.open(context, '/network/my-workspace/ai-apply/', 'AI Apply')),
                      _Tool('Job Tracker', 'Every application and its status in one place.', () => widget.onGoTab(2)),
                      _Tool('CV Guide & Advisor', 'Tips to make your CV stand out.', () => WebPage.open(context, '/network/my-workspace/cv-guide/', 'CV guide')),
                      _Tool('Career Hub', 'Courses, guides and career paths.', () => WebPage.open(context, '/network/career-hub/', 'Career hub')),
                    ],
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _MiniRound extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final double size;
  const _MiniRound({required this.icon, this.onTap, this.size = 30});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)]),
          child: Center(child: Svg(icon, size: size * 0.48, color: AC.brand, stroke: 2.2)),
        ),
      );
}

class _OutlineBtn extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Svg(icon, size: 16, color: AC.ink2, stroke: 2),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _Stat({required this.icon, required this.title, required this.sub, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Svg(icon, size: 20, color: AC.sub, stroke: 1.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: AC.ink2)),
                const SizedBox(height: 2),
                Text(sub, style: T.bodyLight.copyWith(fontSize: 14)),
              ]),
            ),
          ]),
        ),
      );
}

class _Tool extends StatelessWidget {
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _Tool(this.title, this.sub, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE6EBF2))),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AC.ink2)),
              const SizedBox(height: 6),
              Expanded(child: Text(sub, overflow: TextOverflow.fade, style: T.bodyLight.copyWith(fontSize: 14))),
            ]),
          ),
        ),
      );
}

/// Settings (from the round "G" or the Settings button).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _lock = false;

  @override
  void initState() {
    super.initState();
    AppLock.enabled().then((v) => mounted ? setState(() => _lock = v) : null);
  }

  Future<void> _toggleLock(bool on) async {
    if (on && !await AppLock.unlock(reason: 'Confirm to turn on fingerprint lock')) return;
    await AppLock.set(on);
    setState(() => _lock = on);
  }

  Future<void> _signOut() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Log out of ACUC?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('You can sign in again any time with your email and password.', style: T.bodyLight),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AC.red), child: const Text('Log out')),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ]),
      ),
    );
    if (ok != true) return;
    await Session.I.signOut();
    Saved.I.ids.clear();
    Unread.I.value = 0;
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _tile(String icon, String title, VoidCallback onTap, {String? sub, Color color = AC.brand}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle), child: Center(child: Svg(icon, size: 19, color: color))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: color == AC.red ? AC.red : AC.ink2)),
                if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.bodyLight.copyWith(fontSize: 13.5)),
              ]),
            ),
            const Svg(Ico.chevron, size: 18, color: AC.faint),
          ]),
        ),
      );

  Widget _group(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 0, 8), child: Text(title.toUpperCase(), style: T.label.copyWith(color: AC.sub, fontSize: 12))),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AC.softShadow),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(indent: 66), rows[i]],
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final u = Session.I.user ?? {};
    final cv = u['cv'] is Map ? u['cv'] as Map : const {};
    final cvName = (cv['filename'] ?? '').toString();
    final photo = (u['photo'] is Map ? (u['photo']['id'] ?? 0) != 0 ? u['photo']['url'] : '' : '').toString();
    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AppBar(
        backgroundColor: AC.bg,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Svg(Ico.back, size: 22, color: AC.ink2)),
        title: const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AC.ink2)),
      ),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 40), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AC.softShadow),
            child: Row(children: [
              PersonAvatar(name: Session.I.name, photo: photo, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Session.I.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AC.ink2)),
                  Text((u['email'] ?? '').toString(), style: T.bodyLight.copyWith(fontSize: 14)),
                ]),
              ),
            ]),
          ),
        ),
        _group('Profile', [
          _tile(Ico.pen, 'Edit profile', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())), sub: 'Name, headline, location, phone, about'),
          _tile(Ico.camera, 'Change photo', () => uploadPhoto(context)),
          _tile(Ico.doc, cvName.isEmpty ? 'Upload your CV' : 'Replace CV', () => uploadCv(context), sub: cvName.isEmpty ? 'PDF or Word' : cvName),
        ]),
        _group('Security', [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: AC.brand.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Center(child: Svg(Ico.fingerprint, size: 19, color: AC.brand))),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fingerprint lock', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: AC.ink2)),
                  Text('Unlock the app with your fingerprint', style: TextStyle(fontSize: 13.5, color: AC.sub, fontWeight: FontWeight.w300)),
                ]),
              ),
              Switch(value: _lock, onChanged: _toggleLock, activeTrackColor: AC.blue),
            ]),
          ),
          _tile(Ico.lock, 'Email & password', () => WebPage.open(context, '/network/settings/', 'Settings')),
        ]),
        _group('ACUC', [
          _tile(Ico.shield, 'Privacy policy', () => launchUrl(Uri.parse('$kBase/privacy-policy/'), mode: LaunchMode.externalApplication)),
          _tile(Ico.help, 'Help & contact', () => launchUrl(Uri.parse('mailto:support@acuc.jobs'))),
        ]),
        _group('Account', [
          _tile(Ico.trash, 'Delete account', () => WebPage.open(context, '/delete-account/', 'Delete account'), color: AC.red),
          _tile(Ico.logout, 'Log out', _signOut, color: AC.red),
        ]),
        const SizedBox(height: 6),
        Center(child: Opacity(opacity: 0.85, child: Image.asset('assets/images/wordmark.png', height: 20))),
        const SizedBox(height: 6),
        const Center(child: Text('ACUC Jobs $kAppVersion · ACUC LLC', style: TextStyle(color: AC.sub, fontSize: 12.5, fontWeight: FontWeight.w300))),
      ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label.toUpperCase(), style: T.label.copyWith(color: AC.sub))),
          TextField(controller: _f[k], minLines: lines, maxLines: lines == 1 ? 1 : 8, keyboardType: type, style: const TextStyle(fontSize: 16.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Svg(Ico.close, size: 22, color: AC.ink2)),
          title: const Text('Edit profile'),
          actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
          _field('name', 'Full name'),
          _field('headline', 'Headline'),
          _field('location', 'City, country'),
          _field('phone', 'Phone', type: TextInputType.phone),
          _field('linkedin', 'LinkedIn', type: TextInputType.url),
          _field('summary', 'About you', lines: 5),
          const SizedBox(height: 6),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
        ]),
      );
}
