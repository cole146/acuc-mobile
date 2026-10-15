import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'company.dart';
import 'job_detail.dart';
import 'web.dart';

/// Opens an acuc.jobs link the best way: jobs and companies natively, anything else as an in-app page.
Future<void> openAcucLink(BuildContext context, String link, {String title = 'ACUC'}) async {
  final u = Uri.tryParse(link);
  if (u == null || link.isEmpty) return;
  final jobId = int.tryParse(u.queryParameters['job'] ?? u.queryParameters['job_id'] ?? '');
  if (jobId != null && jobId > 0) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobPage(jobId: jobId)));
    return;
  }
  final co = int.tryParse(u.queryParameters['company'] ?? (u.path.contains('company-profile') ? u.queryParameters['id'] ?? '' : ''));
  if (co != null && co > 0) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyPage(id: co)));
    return;
  }
  final path = u.hasAuthority ? '${u.path}${u.hasQuery ? '?${u.query}' : ''}' : link;
  await WebPage.open(context, path.isEmpty ? '/network/' : path, title);
}

/// Alerts — the same screen as the Network "Alerts": big title, unread count, filter pills, grouped list.
class AlertsPage extends StatefulWidget {
  final bool asTab;
  const AlertsPage({super.key, this.asTab = true});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with AutomaticKeepAliveClientMixin {
  List<Notice>? _items;
  String? _error;
  int _filter = 0;
  bool _searching = false;
  String _q = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    Unread.I.addListener(_maybeReload);
  }

  @override
  void dispose() {
    Unread.I.removeListener(_maybeReload);
    super.dispose();
  }

  int _lastUnread = -1;
  void _maybeReload() {
    if (Unread.I.value != _lastUnread && _lastUnread != -1 && Unread.I.value > _lastUnread) _load();
    _lastUnread = Unread.I.value;
  }

  Future<void> _load() async {
    try {
      final r = await Session.I.get('/notifications', {'limit': 80});
      if (mounted) {
        setState(() {
          _items = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Notice.fromJson(m.cast<String, dynamic>())).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _markAll() async {
    try {
      await Session.I.post('/notifications/mark-all', {});
      setState(() {
        for (final n in _items ?? <Notice>[]) {
          n.seen = true;
        }
      });
      Unread.I.value = 0;
      if (mounted) toast(context, 'All caught up');
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _open(Notice n) async {
    if (!n.seen) {
      setState(() => n.seen = true);
      Session.I.post('/notifications/${n.id}', {'seen': true}).catchError((_) => null);
      if (Unread.I.value > 0) Unread.I.value = Unread.I.value - 1;
    }
    await openAcucLink(context, n.link, title: n.title.isEmpty ? 'ACUC' : n.title);
  }

  String _icon(String type) {
    if (type.contains('message') || type.contains('chat')) return Ico.messages;
    if (type.contains('application') || type.contains('apply')) return Ico.doc;
    if (type.contains('job')) return Ico.jobs;
    if (type.contains('friend') || type.contains('connect') || type.contains('follow') || type.contains('people')) return Ico.network;
    return Ico.alerts;
  }

  bool _match(Notice n) {
    final t = n.type;
    switch (_filter) {
      case 1:
        if (n.seen) return false;
        break;
      case 2:
        if (!(t.contains('message') || t.contains('chat'))) return false;
        break;
      case 3:
        if (!(t.contains('friend') || t.contains('connect') || t.contains('follow') || t.contains('people'))) return false;
        break;
      case 4:
        if (!(t.contains('job') || t.contains('application') || t.contains('apply'))) return false;
        break;
    }
    if (_q.isNotEmpty) return '${n.title} ${n.body}'.toLowerCase().contains(_q.toLowerCase());
    return true;
  }

  String _section(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return 'Earlier';
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (d <= 0) return 'Today';
    if (d == 1) return 'Yesterday';
    if (d < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _items;
    final unread = items?.where((n) => !n.seen).length ?? 0;
    final shown = items?.where(_match).toList() ?? [];
    final groups = <String, List<Notice>>{};
    for (final n in shown) {
      groups.putIfAbsent(_section(n.createdAt), () => []).add(n);
    }
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 120), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!widget.asTab)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    child: IconButton(onPressed: () => Navigator.pop(context), icon: const Svg(Ico.back, size: 22, color: AC.ink2)),
                  ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Alerts', style: T.title),
                    Text(unread == 0 ? 'All caught up' : '$unread unread', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w300, color: AC.text)),
                  ]),
                ),
                RoundIcon(icon: Ico.search, onTap: () => setState(() => _searching = !_searching)),
                const SizedBox(width: 8),
                RoundIcon(icon: '<path d="M2 12.5l5 5L18 6.5"/><path d="M12 15.5l2 2L22 7"/>', onTap: unread > 0 ? _markAll : null),
                const SizedBox(width: 8),
                RoundIcon(icon: Ico.dots, onTap: () => WebPage.open(context, '/network/notifications/', 'Alerts')),
              ]),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search alerts',
                    isDense: true,
                    fillColor: const Color(0xFFEFF2F7),
                    prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Svg(Ico.search, size: 18, color: AC.sub)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final (i, l) in ['All', 'Unread', 'Messages', 'People', 'Jobs'].indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _filter == i ? AC.ink2 : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _filter == i ? AC.ink2 : const Color(0xFFE3E8F0)),
                        ),
                        child: Row(children: [
                          Text(l, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400, color: _filter == i ? Colors.white : AC.text)),
                          if (i == 1 && unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(color: _filter == i ? Colors.white24 : AC.blueSoft, borderRadius: BorderRadius.circular(99)),
                              child: Text('$unread', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _filter == i ? Colors.white : AC.blue)),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (items == null && _error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (items == null)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(icon: Ico.alerts, title: 'You’re all caught up', text: 'News about your applications, messages and network shows up here.'),
              )
            else
              for (final e in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AC.sub)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AC.softShadow),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [for (final n in e.value) _row(n)]),
                ),
              ],
          ]),
        ),
      ),
    );
  }

  String _ago(String iso) {
    final t = timeAgo(iso);
    return t == 'now' || t.contains('/') ? t : '$t ago';
  }

  Widget _row(Notice n) => Material(
        color: n.seen ? Colors.white : const Color(0xFFF3F7FE),
        child: InkWell(
          onTap: () => _open(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 6, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 14,
                child: n.seen ? null : Padding(padding: const EdgeInsets.only(top: 18, left: 2), child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AC.blue, shape: BoxShape.circle))),
              ),
              Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFEAF0FB), shape: BoxShape.circle), child: Center(child: Svg(_icon(n.type), size: 20, color: AC.blue))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(n.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AC.ink2))),
                    Text(_ago(n.createdAt),
                        style: TextStyle(fontSize: 12.5, fontWeight: n.seen ? FontWeight.w400 : FontWeight.w700, color: n.seen ? AC.sub : AC.blue)),
                  ]),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w300, color: AC.text)),
                  ],
                ]),
              ),
              const Padding(padding: EdgeInsets.only(top: 2, left: 4), child: Svg(Ico.dots, size: 20, color: AC.faint)),
            ]),
          ),
        ),
      );
}
