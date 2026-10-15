import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'job_detail.dart';
import 'notifications.dart';

class SaveButton extends StatelessWidget {
  final int jobId;
  const SaveButton({super.key, required this.jobId});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Saved.I,
        builder: (context, _) {
          final on = Saved.I.has(jobId);
          return IconButton(
            tooltip: on ? 'Saved' : 'Save job',
            icon: Icon(on ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: on ? AC.blue : AC.sub),
            onPressed: () async {
              if (!await requireSignIn(context, reason: 'Sign in to save jobs and see them on any device.')) return;
              try {
                await Saved.I.toggle(jobId);
                if (context.mounted) toast(context, Saved.I.has(jobId) ? 'Saved to your jobs' : 'Removed from saved jobs');
              } catch (e) {
                if (context.mounted) toast(context, '$e');
              }
            },
          );
        },
      );
}

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with AutomaticKeepAliveClientMixin {
  final _q = TextEditingController();
  final _loc = TextEditingController();
  final _scroll = ScrollController();
  final List<Job> _jobs = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _more = true;
  String? _error;
  int _seq = 0;
  String _heading = '';

  static const _quick = ['Remote', 'Dubai', 'Abu Dhabi', 'Sales', 'Accountant', 'Teacher', 'Engineer', 'Nurse', 'Driver', 'Admin'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _fetch();
    });
    _reload();
  }

  @override
  void dispose() {
    _q.dispose();
    _loc.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _seq++;
    setState(() {
      _jobs.clear();
      _page = 1;
      _more = true;
      _error = null;
      _loading = false;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_loading || !_more) return;
    final seq = _seq;
    setState(() => _loading = true);
    try {
      final r = await Session.I.get('/jobs', {'q': _q.text.trim(), 'loc': _loc.text.trim(), 'page': _page, 'per_page': 20});
      if (seq != _seq) return;
      final items = ((r['items'] ?? r['jobs'] ?? []) as List).whereType<Map>().map((m) => Job.fromJson(m.cast<String, dynamic>())).toList();
      final seen = _jobs.map((j) => j.id).toSet();
      setState(() {
        _jobs.addAll(items.where((j) => !seen.contains(j.id)));
        _total = (r['total'] is int) ? r['total'] as int : _jobs.length;
        _more = items.length >= 20 && _jobs.length < _total;
        _page++;
        final s = r['search'];
        _heading = s is Map && (s['where_label'] ?? '').toString().isNotEmpty ? 'Jobs in ${s['where_label']}' : '';
      });
    } catch (e) {
      if (seq == _seq) setState(() => _error = '$e');
    } finally {
      if (seq == _seq && mounted) setState(() => _loading = false);
    }
  }

  void _search() {
    FocusScope.of(context).unfocus();
    _reload();
  }

  void _open(Job j) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: j.id, preview: j)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final name = Session.I.signedIn ? Session.I.firstName : '';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Image.asset('assets/images/logo.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Text(name.isNotEmpty ? 'Hi, $name' : 'ACUC Jobs'),
        ]),
        actions: [
          if (Session.I.signedIn)
            ValueListenableBuilder<int>(
              valueListenable: Unread.I,
              builder: (context, n, _) => IconButton(
                tooltip: 'Notifications',
                icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: const Icon(Icons.notifications_outlined)),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
                  Unread.I.refresh();
                },
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(children: [
                  TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Job title, skill or company',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.text.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
                              _q.clear();
                              _search();
                            }),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _loc,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: const InputDecoration(hintText: 'City or country', prefixIcon: Icon(Icons.place_outlined)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _search,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 20)),
                        child: const Text('Search'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quick.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ActionChip(
                        label: Text(_quick[i]),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AC.ink),
                        backgroundColor: AC.bg,
                        side: const BorderSide(color: AC.line),
                        shape: const StadiumBorder(),
                        onPressed: () {
                          final k = _quick[i];
                          if (['Remote', 'Dubai', 'Abu Dhabi'].contains(k)) {
                            _loc.text = k;
                          } else {
                            _q.text = k;
                          }
                          _search();
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  _jobs.isEmpty && _loading
                      ? 'Finding jobs…'
                      : _heading.isNotEmpty
                          ? _heading
                          : (_q.text.isEmpty && _loc.text.isEmpty ? 'Jobs for you' : '$_total ${_total == 1 ? 'job' : 'jobs'} found'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (_error != null && _jobs.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: _error!, onRetry: _reload))
            else if (_jobs.isEmpty && _loading)
              SliverList.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: CardSkeleton()),
              )
            else if (_jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.work_outline_rounded,
                  title: 'No jobs match that yet',
                  text: 'Try a shorter title, another city, or clear the search.',
                  action: 'Clear search',
                  onAction: () {
                    _q.clear();
                    _loc.clear();
                    _search();
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: _jobs.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == _jobs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : _more
                                  ? TextButton(onPressed: _fetch, child: const Text('Load more'))
                                  : const Text('You’ve seen all the jobs', style: TextStyle(color: AC.sub)),
                        ),
                      );
                    }
                    final j = _jobs[i];
                    return JobCard(job: j, onTap: () => _open(j), trailing: SaveButton(jobId: j.id));
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
