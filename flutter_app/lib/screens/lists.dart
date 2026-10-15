import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'job_detail.dart';
import 'jobs.dart';

class SignedOutHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const SignedOutHint({super.key, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, title: title, text: text, action: 'Sign in', onAction: () => requireSignIn(context));
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Job>? _jobs;
  String? _error;

  @override
  void initState() {
    super.initState();
    Saved.I.addListener(_onSaved);
    _load();
  }

  @override
  void dispose() {
    Saved.I.removeListener(_onSaved);
    super.dispose();
  }

  void _onSaved() {
    final j = _jobs;
    if (j == null) return;
    if (j.any((x) => !Saved.I.has(x.id)) || Saved.I.ids.length != j.length) _load();
  }

  Future<void> _load() async {
    if (!Session.I.signedIn) return;
    setState(() => _error = null);
    try {
      final r = await Session.I.get('/saved-jobs', {'full': 1});
      setState(() => _jobs = ((r['jobs'] ?? []) as List).whereType<Map>().map((m) => Job.fromJson(m.cast<String, dynamic>())).toList());
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!Session.I.signedIn) {
      body = const SignedOutHint(icon: Icons.bookmark_outline_rounded, title: 'Save jobs for later', text: 'Sign in and tap the bookmark on any job to keep it here.');
    } else if (_error != null && _jobs == null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_jobs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_jobs!.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 80),
          EmptyState(icon: Icons.bookmark_outline_rounded, title: 'No saved jobs yet', text: 'Tap the bookmark on a job to save it here.'),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _jobs!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final j = _jobs![i];
            return JobCard(
              job: j,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: j.id, preview: j))),
              trailing: SaveButton(jobId: j.id),
            );
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Saved jobs')), body: body);
  }
}

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});
  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<Application>? _apps;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Session.I.signedIn) return;
    setState(() => _error = null);
    try {
      final r = await Session.I.get('/applications', {'per_page': 50});
      setState(() => _apps = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Application.fromJson(m.cast<String, dynamic>())).toList());
    } on ApiError catch (e) {
      setState(() => _error = e.status == 403 ? 'Applications are for jobseeker accounts.' : e.message);
    }
  }

  Color _color(String label) {
    switch (label) {
      case 'Shortlisted':
      case 'Interview':
      case 'Offer':
      case 'Hired':
        return AC.green;
      case 'Not selected':
        return AC.red;
      case 'Viewed':
      case 'In review':
        return AC.amber;
      default:
        return AC.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!Session.I.signedIn) {
      body = const SignedOutHint(icon: Icons.assignment_outlined, title: 'Track your applications', text: 'Sign in to see every job you applied to and where it stands.');
    } else if (_error != null && _apps == null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_apps == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_apps!.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 80),
          EmptyState(icon: Icons.assignment_outlined, title: 'No applications yet', text: 'When you apply to jobs, you can follow each one here.'),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _apps!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = _apps![i];
            final j = a.job;
            if (j != null) {
              return JobCard(
                job: j,
                badge: '${a.statusLabel} · ${timeAgo(a.createdAt)}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: j.id, preview: j))),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(Icons.circle, size: 12, color: _color(a.statusLabel)),
                ),
              );
            }
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AC.line)),
              title: Text(a.jobTitle.isEmpty ? 'Job no longer listed' : a.jobTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${a.statusLabel} · ${timeAgo(a.createdAt)}'),
            );
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Applications')), body: body);
  }
}
