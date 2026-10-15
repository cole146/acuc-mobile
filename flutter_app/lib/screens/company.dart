import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'jobs.dart';
import 'profile.dart';
import 'web.dart';

/// Company page — same layout as the Network company page: cover, logo, name, verified tick, rating,
/// Follow · followers · Write a review · Share · Report, then Snapshot / Posts / Reviews / Jobs / Salaries / People.
class CompanyPage extends StatefulWidget {
  final int id;
  final String name;
  const CompanyPage({super.key, required this.id, this.name = ''});
  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  Map<String, dynamic> _c = {};
  Map<String, dynamic> _dir = {};
  List<Job>? _jobs;
  int _jobsTotal = 0;
  int _followers = 0;
  bool _following = false;
  double _rating = 0;
  int _reviews = 0;
  int _tab = 0;
  bool _busyFollow = false;
  String? _error;

  String get _name => (_c['name'] ?? widget.name).toString();
  String get _url => '$kBase/network/?company=${widget.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Session.I.get('/company/${widget.id}');
      if (mounted) setState(() => _c = (r as Map).cast<String, dynamic>());
    } catch (e) {
      if (mounted && _c.isEmpty) setState(() => _error = '$e');
    }
    Session.I.get('/company/${widget.id}/jobs', {'per_page': 50}).then((r) {
      if (!mounted) return;
      setState(() {
        _jobs = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Job.fromJson(m.cast<String, dynamic>())).toList();
        _jobsTotal = (r['total'] is int) ? r['total'] as int : _jobs!.length;
      });
    }).catchError((_) {
      if (mounted) setState(() => _jobs = []);
    });
    Session.I.get('/company/${widget.id}/followers').then((r) {
      if (mounted) setState(() {
        _followers = (r['followers'] ?? r['count'] ?? 0) as int;
        _following = r['i_follow'] == true || r['following'] == true;
      });
    }).catchError((_) {});
    Session.I.get('/company/${widget.id}/rating').then((r) {
      if (mounted) setState(() {
        _rating = ((r['avg'] ?? 0) as num).toDouble();
        _reviews = (r['count'] ?? 0) as int;
      });
    }).catchError((_) {});
    final n = widget.name.isNotEmpty ? widget.name : _name;
    if (n.isNotEmpty) {
      Session.I.get('/company-directory', {'q': n, 'per_page': 6}).then((r) {
        final it = ((r['items'] ?? []) as List).whereType<Map>().firstWhere((m) => m['id'] == widget.id, orElse: () => {});
        if (mounted) setState(() => _dir = it.cast<String, dynamic>());
      }).catchError((_) {});
    }
  }

  Future<void> _follow() async {
    if (!await requireSignIn(context, reason: 'Sign in to follow companies and hear about their jobs.')) return;
    setState(() => _busyFollow = true);
    try {
      final r = await Session.I.post('/company/${widget.id}/follow', {'follow': !_following});
      setState(() {
        _following = r['i_follow'] == true || r['following'] == true;
        _followers = (r['followers'] ?? r['count'] ?? _followers) as int;
      });
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Widget _cover() {
    final logo = (_c['logo_url'] ?? _dir['logo'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AC.softShadow),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF1F2747), Color(0xFF3A3170), Color(0xFF9B3FB5)]),
            ),
            child: Stack(children: [
              Positioned(top: 0, left: 0, right: 0, height: 4, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF16B3A3), Color(0xFF1E63E9)])))),
              Positioned(right: -40, top: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white12)))),
              Positioned(right: 40, top: 20, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10)))),
            ]),
          ),
          Positioned(
            left: 14,
            bottom: -30,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
              child: CompanyLogo(name: _name, logo: logo, size: 58),
            ),
          ),
        ]),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name, style: const TextStyle(fontSize: 19, height: 1.25, fontWeight: FontWeight.w600, color: AC.ink2, letterSpacing: -0.2)),
            const SizedBox(height: 8),
            Row(children: [
              if (_dir['verified'] == true)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AC.blue, shape: BoxShape.circle),
                  child: const Center(child: Svg('<path d="M5 12.5l4.5 4.5L19 7.5"/>', size: 14, color: Colors.white, stroke: 2.6)),
                ),
              if (_dir['verified'] == true) const SizedBox(width: 8),
              if ((_c['industry'] ?? '').toString().isNotEmpty)
                Flexible(child: Text((_c['industry']).toString(), style: const TextStyle(color: AC.sub, fontWeight: FontWeight.w300))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: AC.blueSoft, borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFC9DAFB))),
              child: Text(_reviews > 0 ? '★ ${_rating.toStringAsFixed(1)} · $_reviews reviews' : '– Rating',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.blue)),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 10, children: [
              ChipBtn(
                icon: Ico.heart,
                label: _following ? 'Following' : 'Follow',
                filled: !_following,
                color: AC.blue,
                border: AC.blue.withValues(alpha: 0.4),
                onTap: _busyFollow ? null : _follow,
              ),
              _CountChip(icon: Ico.users, count: _followers, label: _followers == 1 ? 'follower' : 'followers'),
              ChipBtn(icon: Ico.pen, label: 'Write a review', onTap: () => WebPage.open(context, '/network/?company=${widget.id}', _name)),
              ChipBtn(icon: Ico.share, label: 'Share', onTap: () => SharePlus.instance.share(ShareParams(text: '$_name on ACUC\n$_url'))),
              ChipBtn(
                icon: Ico.flag,
                label: 'Report',
                color: AC.red,
                border: const Color(0xFFF5C2C2),
                onTap: () => launchUrl(Uri.parse('mailto:support@acuc.jobs?subject=${Uri.encodeComponent('Report company: $_name (#${widget.id})')}')),
              ),
            ]),
            const SizedBox(height: 18),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String icon, String label, String value, {bool ok = false, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF1F6)))),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: const BoxDecoration(color: Color(0xFFF1F4F9), shape: BoxShape.circle), child: Center(child: Svg(icon, size: 17, color: AC.brand))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: T.label),
                const SizedBox(height: 3),
                Row(children: [
                  if (ok) ...[Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)), const SizedBox(width: 6)],
                  Flexible(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: onTap != null ? AC.brand : AC.ink2))),
                ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _snapshot() {
    String v(String k) => (_c[k] ?? '').toString();
    final site = v('website'), mail = v('email');
    return Column(children: [
      Panel(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('About', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AC.ink2)),
          if (v('about').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(plainText(v('about')), style: T.body),
          ],
          const SizedBox(height: 12),
          _row(Ico.globe, 'Website', site.isEmpty ? 'Not added yet' : site, onTap: site.isEmpty ? null : () => launchUrl(Uri.parse(site.startsWith('http') ? site : 'https://$site'), mode: LaunchMode.externalApplication)),
          _row(Ico.mail, 'Email', mail.isEmpty ? 'Not added yet' : mail, onTap: mail.isEmpty ? null : () => launchUrl(Uri.parse('mailto:$mail'))),
          _row(Ico.pin, 'Location', v('location').isEmpty ? 'Not added yet' : v('location')),
          _row(Ico.shield, 'Verified page', _dir['verified'] == true ? 'Verified' : 'Not verified yet', ok: _dir['verified'] == true),
          _row(Ico.building, 'Industry', v('industry').isEmpty ? 'Not added yet' : v('industry')),
          _row(Ico.users, 'Company size', v('size').isEmpty ? 'Not added yet' : v('size')),
        ]),
      ),
      if ((_jobs ?? []).isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Row(children: [
            Expanded(child: ListHead(count: '$_jobsTotal', label: _jobsTotal == 1 ? 'open job' : 'open jobs')),
            TextButton(onPressed: () => setState(() => _tab = 3), child: const Text('See all')),
          ]),
        ),
        for (final j in _jobs!.take(2))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: JobCard(job: j, onTap: () => openJob(context, j), saveButton: SaveButton(jobId: j.id), onShare: () => shareJob(j)),
          ),
      ],
    ]);
  }

  Widget _jobsTab() {
    if (_jobs == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    if (_jobs!.isEmpty) return const EmptyState(icon: Ico.jobs, title: 'No open jobs right now', text: 'Follow the company to hear when they post one.');
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 0), child: ListHead(count: '$_jobsTotal', label: _jobsTotal == 1 ? 'open job' : 'open jobs')),
      for (final j in _jobs!)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: JobCard(job: j, onTap: () => openJob(context, j), saveButton: SaveButton(jobId: j.id), onShare: () => shareJob(j)),
        ),
    ]);
  }

  Widget _webTab(String what) => Panel(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(children: [
          const SizedBox(height: 8),
          Text(what, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AC.ink2)),
          const SizedBox(height: 6),
          const Text('Open the full company page to see this.', textAlign: TextAlign.center, style: T.bodyLight),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => WebPage.open(context, '/network/?company=${widget.id}', _name), child: Text('Open $what')),
          const SizedBox(height: 4),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final tabs = ['Snapshot', 'Posts', 'Reviews', 'Jobs', 'Salaries', 'People'];
    return Scaffold(
      backgroundColor: AC.bgBlue,
      appBar: AcucTopBar(back: true, onSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobSearchPage())), onMe: () => openMe(context)),
      body: _error != null && _c.isEmpty
          ? ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
                _cover(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SegTabs(labels: tabs, counts: [null, null, _reviews, _jobsTotal, null, null], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      0 => _snapshot(),
                      3 => _jobsTab(),
                      _ => _webTab(tabs[_tab]),
                    },
                  ),
                ),
              ]),
            ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String icon;
  final int count;
  final String label;
  const _CountChip({required this.icon, required this.count, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: AC.line, width: 1.3)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Svg(icon, size: 16, color: AC.sub, stroke: 2),
          const SizedBox(width: 7),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, color: AC.ink2, fontSize: 14)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AC.sub, fontSize: 13.5)),
        ]),
      );
}
