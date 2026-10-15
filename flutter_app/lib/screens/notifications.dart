import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'job_detail.dart';
import 'web.dart';

/// Opens an acuc.jobs link the best way: a job natively, anything else as an in-app page.
Future<void> openAcucLink(BuildContext context, String link, {String title = 'ACUC'}) async {
  final u = Uri.tryParse(link);
  if (u == null || link.isEmpty) return;
  final jobId = int.tryParse(u.queryParameters['job'] ?? u.queryParameters['job_id'] ?? '');
  if (jobId != null && jobId > 0) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)));
    return;
  }
  final path = u.hasAuthority ? '${u.path}${u.hasQuery ? '?${u.query}' : ''}' : link;
  await WebPage.open(context, path.isEmpty ? '/network/' : path, title);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Notice>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Session.I.get('/notifications', {'limit': 80});
      setState(() => _items = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Notice.fromJson(m.cast<String, dynamic>())).toList());
    } catch (e) {
      setState(() => _error = '$e');
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
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _open(Notice n) async {
    if (!n.seen) {
      setState(() => n.seen = true);
      Session.I.post('/notifications/${n.id}', {'seen': true}).catchError((_) => null);
    }
    await openAcucLink(context, n.link, title: n.title.isEmpty ? 'ACUC' : n.title);
  }

  IconData _icon(String type) {
    if (type.contains('message') || type.contains('chat')) return Icons.chat_bubble_outline_rounded;
    if (type.contains('application') || type.contains('apply')) return Icons.assignment_outlined;
    if (type.contains('job')) return Icons.work_outline_rounded;
    if (type.contains('friend') || type.contains('connect') || type.contains('follow')) return Icons.people_outline_rounded;
    if (type.contains('interview') || type.contains('call')) return Icons.event_outlined;
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (items != null && items.any((n) => !n.seen)) TextButton(onPressed: _markAll, child: const Text('Mark all read'))],
      ),
      body: _error != null && items == null
          ? ErrorState(message: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          EmptyState(icon: Icons.notifications_none_rounded, title: 'You’re all caught up', text: 'News about your applications and messages shows up here.'),
                        ])
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(indent: 72),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            return ListTile(
                              tileColor: n.seen ? Colors.white : AC.blue.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: AC.blue.withValues(alpha: 0.1),
                                child: Icon(_icon(n.type), color: AC.blue, size: 22),
                              ),
                              title: Text(n.title, style: TextStyle(fontWeight: n.seen ? FontWeight.w600 : FontWeight.w800)),
                              subtitle: n.body.isEmpty ? null : Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                              trailing: Text(timeAgo(n.createdAt), style: const TextStyle(color: AC.sub, fontSize: 12.5)),
                              onTap: () => _open(n),
                            );
                          },
                        ),
                ),
    );
  }
}
