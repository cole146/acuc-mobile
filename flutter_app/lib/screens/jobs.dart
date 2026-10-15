import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'job_detail.dart';
import 'profile.dart';

class SaveButton extends StatelessWidget {
  final int jobId;
  final bool chip;
  const SaveButton({super.key, required this.jobId, this.chip = false});

  static Future<void> toggle(BuildContext context, int jobId) async {
    if (!await requireSignIn(context, reason: 'Sign in to save jobs and see them on any device.')) return;
    try {
      await Saved.I.toggle(jobId);
      if (context.mounted) toast(context, Saved.I.has(jobId) ? 'Saved' : 'Removed from saved jobs');
    } catch (e) {
      if (context.mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Saved.I,
        builder: (context, _) {
          final on = Saved.I.has(jobId);
          if (chip) {
            return ChipBtn(
              icon: Ico.bookmark,
              label: on ? 'Saved' : 'Save',
              color: on ? AC.brand : AC.text,
              border: on ? AC.brand.withValues(alpha: 0.35) : AC.pillLine,
              onTap: () => toggle(context, jobId),
            );
          }
          return IconButton(
            tooltip: on ? 'Saved' : 'Save job',
            visualDensity: VisualDensity.compact,
            onPressed: () => toggle(context, jobId),
            icon: Svg(Ico.bookmark, size: 20, color: on ? AC.brand : const Color(0xFF4A5B78), fill: on),
          );
        },
      );
}

void shareJob(Job j) => SharePlus.instance.share(ShareParams(text: '${j.title} at ${j.company}\n${j.permalink}'));

/// Jobs tab: For you · Saved · Applied — every list uses the same card, and a job opens in the job sheet.
class JobsPage extends StatefulWidget {
  final int initialTab;
  const JobsPage({super.key, this.initialTab = 0});
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with AutomaticKeepAliveClientMixin {
  late int _tab = widget.initialTab;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AcucTopBar(
        onSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobSearchPage())),
        onMe: () => openMe(context),
      ),
      body: Column(children: [
        Container(
          color: AC.bg,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: SegTabs(
            labels: const ['For you', 'Saved', 'Applied'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: const [
            JobList(),
            SavedJobs(),
            AppliedJobs(),
          ]),
        ),
      ]),
    );
  }
}

/// Dark selected pill tabs (as on the company page: Snapshot · Posts · Reviews …).
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final List<int?>? counts;
  final int index;
  final ValueChanged<int> onChanged;
  const SegTabs({super.key, required this.labels, required this.index, required this.onChanged, this.counts});
  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE8EDF5))),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 2),
          itemBuilder: (_, i) {
            final on = i == index;
            final n = counts != null && i < counts!.length ? counts![i] : null;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? AC.ink2 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(labels[i], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : AC.text)),
                  if (n != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: on ? Colors.white24 : const Color(0xFFEEF2F8), borderRadius: BorderRadius.circular(99)),
                      child: Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white : AC.sub)),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      );
}

/// The list head: "● 24 jobs for you" (green dot, blue number).
class ListHead extends StatelessWidget {
  final String count;
  final String label;
  const ListHead({super.key, required this.count, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          if (count.isNotEmpty) ...[
            Text(count, style: const TextStyle(color: AC.brand, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AC.sub))),
        ]),
      );
}

void openJob(BuildContext context, Job j) => JobSheet.open(context, j);

class JobList extends StatefulWidget {
  final String q;
  final String loc;
  final bool header;
  const JobList({super.key, this.q = '', this.loc = '', this.header = true});
  @override
  State<JobList> createState() => _JobListState();
}

class _JobListState extends State<JobList> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final List<Job> _jobs = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _more = true;
  String? _error;
  int _seq = 0;
  String _where = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 700) _fetch();
    });
    _reload();
  }

  @override
  void didUpdateWidget(JobList old) {
    super.didUpdateWidget(old);
    if (old.q != widget.q || old.loc != widget.loc) _reload();
  }

  @override
  void dispose() {
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
      final r = await Session.I.get('/jobs', {'q': widget.q, 'loc': widget.loc, 'page': _page, 'per_page': 20});
      if (seq != _seq) return;
      final items = ((r['items'] ?? r['jobs'] ?? []) as List).whereType<Map>().map((m) => Job.fromJson(m.cast<String, dynamic>())).toList();
      final seen = _jobs.map((j) => j.id).toSet();
      setState(() {
        _jobs.addAll(items.where((j) => !seen.contains(j.id)));
        _total = (r['total'] is int) ? r['total'] as int : _jobs.length;
        _more = items.length >= 20 && _jobs.length < _total;
        _page++;
        final s = r['search'];
        _where = s is Map ? (s['where_label'] ?? '').toString() : '';
      });
    } catch (e) {
      if (seq == _seq) setState(() => _error = '$e');
    } finally {
      if (seq == _seq && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searching = widget.q.isNotEmpty || widget.loc.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              sliver: SliverToBoxAdapter(
                child: ListHead(
                  count: _jobs.isEmpty ? '' : '$_total',
                  label: _jobs.isEmpty && _loading
                      ? 'Finding jobs…'
                      : searching
                          ? (_total == 1 ? 'job found' : 'jobs found')
                          : (_where.isNotEmpty ? 'jobs in $_where' : (_total == 1 ? 'job for you' : 'jobs for you')),
                ),
              ),
            ),
          if (_error != null && _jobs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: _error!, onRetry: _reload))
          else if (_jobs.isEmpty && _loading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverList.separated(itemCount: 5, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, __) => const CardSkeleton()),
            )
          else if (_jobs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Ico.jobs, title: 'No jobs match that yet', text: 'Try a shorter title or another city.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverList.separated(
                itemCount: _jobs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == _jobs.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : _more
                                ? TextButton(onPressed: _fetch, child: const Text('Load more'))
                                : const Text('You’ve seen all the jobs', style: TextStyle(color: AC.sub, fontWeight: FontWeight.w300)),
                      ),
                    );
                  }
                  final j = _jobs[i];
                  return JobCard(job: j, onTap: () => openJob(context, j), saveButton: SaveButton(jobId: j.id), onShare: () => shareJob(j));
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

class SavedJobs extends StatefulWidget {
  const SavedJobs({super.key});
  @override
  State<SavedJobs> createState() => _SavedJobsState();
}

class _SavedJobsState extends State<SavedJobs> {
  List<Job>? _jobs;
  String? _error;

  @override
  void initState() {
    super.initState();
    Saved.I.addListener(_changed);
    Session.I.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    Saved.I.removeListener(_changed);
    Session.I.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final j = _jobs;
    if (j == null || Saved.I.ids.length != j.length || j.any((x) => !Saved.I.has(x.id))) _load();
  }

  Future<void> _load() async {
    if (!Session.I.signedIn) {
      if (mounted) setState(() => _jobs = null);
      return;
    }
    try {
      final r = await Session.I.get('/saved-jobs', {'full': 1});
      if (mounted) setState(() => _jobs = ((r['jobs'] ?? []) as List).whereType<Map>().map((m) => Job.fromJson(m.cast<String, dynamic>())).toList());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.I.signedIn) {
      return EmptyState(icon: Ico.bookmark, title: 'Save jobs for later', text: 'Sign in and tap the bookmark on any job to keep it here.', action: 'Sign in', onAction: () => requireSignIn(context));
    }
    if (_jobs == null) return _error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
        children: [
          ListHead(count: '${_jobs!.length}', label: _jobs!.length == 1 ? 'saved job' : 'saved jobs'),
          if (_jobs!.isEmpty) const EmptyState(icon: Ico.bookmark, title: 'No saved jobs yet', text: 'Tap the bookmark on a job to save it here.'),
          for (final j in _jobs!) ...[
            JobCard(job: j, onTap: () => openJob(context, j), saveButton: SaveButton(jobId: j.id), onShare: () => shareJob(j)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class AppliedJobs extends StatefulWidget {
  const AppliedJobs({super.key});
  @override
  State<AppliedJobs> createState() => _AppliedJobsState();
}

class _AppliedJobsState extends State<AppliedJobs> {
  List<Application>? _apps;
  String? _error;

  @override
  void initState() {
    super.initState();
    Applied.I.addListener(_load);
    Session.I.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Applied.I.removeListener(_load);
    Session.I.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!Session.I.signedIn) {
      if (mounted) setState(() => _apps = null);
      return;
    }
    try {
      final r = await Session.I.get('/applications', {'per_page': 50});
      if (mounted) setState(() => _apps = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Application.fromJson(m.cast<String, dynamic>())).toList());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.status == 403 ? 'Applications are for jobseeker accounts.' : e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.I.signedIn) {
      return EmptyState(icon: Ico.doc, title: 'Track your applications', text: 'Sign in to follow every job you applied to.', action: 'Sign in', onAction: () => requireSignIn(context));
    }
    if (_apps == null) return _error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
        children: [
          ListHead(count: '${_apps!.length}', label: _apps!.length == 1 ? 'application' : 'applications'),
          if (_apps!.isEmpty) const EmptyState(icon: Ico.doc, title: 'No applications yet', text: 'When you apply to jobs, you can follow each one here.'),
          for (final a in _apps!) ...[
            if (a.job != null)
              JobCard(
                job: a.job!,
                status: '${a.statusLabel} · applied ${timeAgo(a.createdAt)} ago',
                onTap: () => openJob(context, a.job!),
                onShare: () => shareJob(a.job!),
              )
            else
              Panel(margin: EdgeInsets.zero, child: Text('${a.jobTitle.isEmpty ? 'Job no longer listed' : a.jobTitle} · ${a.statusLabel}')),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Search: "I'm looking for…" — title / skill / company and a place.
class JobSearchPage extends StatefulWidget {
  const JobSearchPage({super.key});
  @override
  State<JobSearchPage> createState() => _JobSearchPageState();
}

class _JobSearchPageState extends State<JobSearchPage> {
  final _q = TextEditingController();
  final _loc = TextEditingController();
  String _sq = '', _sl = '';
  static const _quick = ['Remote', 'Dubai', 'Abu Dhabi', 'Sharjah', 'Sales', 'Accountant', 'Teacher', 'Engineer', 'Nurse', 'Driver', 'Admin', 'Marketing'];

  void _go() {
    FocusScope.of(context).unfocus();
    setState(() {
      _sq = _q.text.trim();
      _sl = _loc.text.trim();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _loc.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, String icon) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEFF2F7),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 8), child: Svg(icon, size: 18, color: AC.text)),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        hintStyle: const TextStyle(fontSize: 15.5, color: AC.sub, fontWeight: FontWeight.w400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: AC.brand, width: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    final searched = _sq.isNotEmpty || _sl.isNotEmpty;
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 12),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Svg(Ico.back, size: 22, color: AC.ink2)),
                Expanded(
                  child: TextField(controller: _q, autofocus: true, textInputAction: TextInputAction.search, onSubmitted: (_) => _go(), decoration: _dec('I’m looking for…', Ico.search)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 48),
                Expanded(child: TextField(controller: _loc, textInputAction: TextInputAction.search, onSubmitted: (_) => _go(), decoration: _dec('City or country', Ico.pin))),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(gradient: AC.blueGradient, borderRadius: BorderRadius.circular(999)),
                    child: TextButton(
                      onPressed: _go,
                      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18)),
                      child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          if (!searched)
            Expanded(
              child: ListView(padding: const EdgeInsets.all(18), children: [
                const Text('Popular searches', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AC.sub)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 10, children: [
                  for (final k in _quick)
                    GestureDetector(
                      onTap: () {
                        if (['Remote', 'Dubai', 'Abu Dhabi', 'Sharjah'].contains(k)) {
                          _loc.text = k;
                        } else {
                          _q.text = k;
                        }
                        _go();
                      },
                      child: OPill(k),
                    ),
                ]),
              ]),
            )
          else
            Expanded(child: JobList(q: _sq, loc: _sl)),
        ]),
      ),
    );
  }
}
