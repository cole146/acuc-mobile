import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'jobs.dart';
import 'web.dart';

class JobDetailPage extends StatefulWidget {
  final int jobId;
  final Job? preview;
  const JobDetailPage({super.key, required this.jobId, this.preview});
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  Job? _job;
  String? _error;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _job = widget.preview;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Session.I.get('/jobs/${widget.jobId}');
      final m = (r is Map && r['job'] is Map ? r['job'] : r) as Map;
      setState(() {
        _job = Job.fromJson(m.cast<String, dynamic>());
        _applied = m['applied'] == true || m['has_applied'] == true;
      });
      if (Session.I.signedIn && !_applied) _checkApplied();
    } catch (e) {
      if (_job == null) setState(() => _error = '$e');
    }
  }

  Future<void> _checkApplied() async {
    try {
      final r = await Session.I.get('/applications', {'per_page': 50});
      final ids = ((r['items'] ?? []) as List).whereType<Map>().map((m) => Application.fromJson(m.cast<String, dynamic>()).job?.id).toSet();
      if (mounted && ids.contains(widget.jobId)) setState(() => _applied = true);
    } catch (_) {}
  }

  Future<void> _apply() async {
    final j = _job;
    if (j == null) return;
    if (j.appliesOutside) {
      await launchUrl(Uri.parse(j.applyUrl), mode: LaunchMode.externalApplication);
      return;
    }
    if (!await requireSignIn(context, reason: 'Sign in to apply with your ACUC profile and CV.')) return;
    if (!mounted) return;
    if (Session.I.isEmployer) {
      toast(context, 'You’re signed in with an employer account. Sign in as a jobseeker to apply.');
      return;
    }
    if (!j.appliesOnAcuc) {
      await WebPage.open(context, Uri.parse(j.permalink).path, 'Apply');
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ApplySheet(job: j),
    );
    if (ok == true && mounted) {
      setState(() => _applied = true);
      toast(context, 'Application sent. Good luck!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: [
          if (j != null) SaveButton(jobId: j.id),
          if (j != null && j.permalink.isNotEmpty)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => SharePlus.instance.share(ShareParams(text: '${j.title} at ${j.company}\n${j.permalink}')),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: j == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                children: [
                  Row(children: [
                    CompanyAvatar(name: j.company, logo: j.logo, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: j.companyId > 0 ? () => WebPage.open(context, '/network/?company=${j.companyId}', j.company) : null,
                        child: Text(j.company, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AC.blue)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(j.title, style: const TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (j.location.isNotEmpty) Pill(j.location, icon: Icons.place_outlined),
                    if (j.type.isNotEmpty) Pill(j.type, icon: Icons.work_outline_rounded),
                    if (j.mode.isNotEmpty) Pill(j.mode, icon: Icons.home_work_outlined),
                    if (j.salary.isNotEmpty) Pill(j.salary, color: AC.green, icon: Icons.payments_outlined),
                    if (j.urgent) const Pill('Urgent', color: AC.red, icon: Icons.bolt_rounded),
                    if (j.expired) const Pill('No longer accepting applications', color: AC.red) else Pill('Posted ${j.posted.toLowerCase()}'),
                  ]),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 18),
                  const Text('About the job', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (j.html.isNotEmpty)
                    HtmlWidget(
                      j.html,
                      textStyle: const TextStyle(fontSize: 15.5, height: 1.55, color: AC.ink),
                      onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    )
                  else
                    Text(j.excerpt.isEmpty ? 'The employer has not added a description.' : j.excerpt,
                        style: const TextStyle(fontSize: 15.5, height: 1.55)),
                ],
              ),
            ),
      bottomNavigationBar: j == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AC.line))),
                child: FilledButton.icon(
                  onPressed: (j.expired || _applied) ? null : _apply,
                  icon: Icon(_applied ? Icons.check_circle_rounded : (j.appliesOutside ? Icons.open_in_new_rounded : Icons.send_rounded)),
                  label: Text(_applied
                      ? 'Applied'
                      : j.expired
                          ? 'Applications closed'
                          : j.appliesOutside
                              ? 'Apply on company site'
                              : 'Apply now'),
                ),
              ),
            ),
    );
  }
}

class ApplySheet extends StatefulWidget {
  final Job job;
  const ApplySheet({super.key, required this.job});
  @override
  State<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<ApplySheet> {
  final _cover = TextEditingController();
  late final List<TextEditingController> _answers;
  final List<DateTime?> _dates = [null, null, null];
  late List<Question> _qs;
  bool _needDates = false;
  String _cvName = '';
  int _cvId = 0;
  bool _uploading = false;
  bool _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _qs = widget.job.questions;
    _needDates = widget.job.needsInterviewDates;
    _answers = List.generate(_qs.length, (_) => TextEditingController());
    final cv = Session.I.user?['cv'];
    if (cv is Map) {
      _cvId = (cv['id'] is int) ? cv['id'] as int : 0;
      _cvName = (cv['filename'] ?? '').toString();
    }
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final r = await Session.I.get('/jobs/${widget.job.id}/questions');
      final list = (r['screening_questions'] ?? r['questions'] ?? []) as List;
      final qs = list.map(Question.fromJson).where((q) => q.prompt.isNotEmpty).toList();
      final iv = r['interview_request'];
      if (!mounted) return;
      setState(() {
        if (qs.length != _qs.length) {
          _qs = qs;
          _answers
            ..clear()
            ..addAll(List.generate(qs.length, (_) => TextEditingController()));
        }
        _needDates = r['require_interview_dates'] == true || (iv is Map && iv['enabled'] == true);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _cover.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCv() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    final f = r?.files.single;
    if (f == null || f.path == null) return;
    setState(() {
      _uploading = true;
      _error = '';
    });
    try {
      final res = await Session.I.upload('/cv', 'cv', f.path!, filename: f.name);
      setState(() {
        _cvId = (res['id'] is int) ? res['id'] as int : 0;
        _cvName = (res['filename'] ?? f.name).toString();
      });
      Session.I.refreshMe();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate(int i) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dates[i] ?? now.add(Duration(days: 2 + i)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    );
    if (d != null) setState(() => _dates[i] = d);
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _short(DateTime d) => '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _send() async {
    if (_cvId == 0) {
      setState(() => _error = 'Add your CV first.');
      return;
    }
    for (var i = 0; i < _qs.length; i++) {
      if (_qs[i].required && _answers[i].text.trim().isEmpty) {
        setState(() => _error = 'Please answer: ${_qs[i].prompt}');
        return;
      }
    }
    if (_needDates) {
      final ds = _dates.whereType<DateTime>().map(_fmt).toSet();
      if (ds.length != 3) {
        setState(() => _error = 'Choose 3 different days you could do an interview.');
        return;
      }
    }
    setState(() {
      _sending = true;
      _error = '';
    });
    try {
      final r = await Session.I.post('/apply', {
        'job_id': widget.job.id,
        'cv_id': _cvId,
        'cover_letter': _cover.text.trim(),
        if (_qs.isNotEmpty) 'screening_answers': _answers.map((c) => c.text.trim()).toList(),
        if (_needDates) 'interview_dates': _dates.whereType<DateTime>().map(_fmt).toList(),
      });
      if (!mounted) return;
      if (r is Map && r['status'] == 'already_applied') {
        toast(context, 'You already applied to this job.');
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AC.line, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Apply', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${widget.job.title} · ${widget.job.company}', style: const TextStyle(color: AC.sub, fontSize: 14.5)),
            const SizedBox(height: 20),
            const Text('Your CV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.line)),
              child: Row(children: [
                Icon(_cvId > 0 ? Icons.description_rounded : Icons.upload_file_rounded, color: AC.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_cvId > 0 ? (_cvName.isEmpty ? 'Your CV' : _cvName) : 'No CV yet — add one (PDF or Word)',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                _uploading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : TextButton(onPressed: _pickCv, child: Text(_cvId > 0 ? 'Change' : 'Add CV')),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Message to the employer (optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 8),
            TextField(controller: _cover, minLines: 3, maxLines: 8, decoration: const InputDecoration(hintText: 'Why you are a good fit…')),
            for (var i = 0; i < _qs.length; i++) ...[
              const SizedBox(height: 18),
              Text('${_qs[i].prompt}${_qs[i].required ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 8),
              TextField(controller: _answers[i], minLines: 1, maxLines: 5, decoration: InputDecoration(hintText: _qs[i].placeholder.isEmpty ? 'Your answer' : _qs[i].placeholder)),
            ],
            if (_needDates) ...[
              const SizedBox(height: 18),
              const Text('3 days you could do an interview *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              if (widget.job.interviewHint.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(widget.job.interviewHint, style: const TextStyle(color: AC.sub)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: _dates[i] == null ? null : AC.blue.withValues(alpha: 0.07),
                        side: BorderSide(color: _dates[i] == null ? AC.line : AC.blue, width: 1.5),
                      ),
                      onPressed: () => _pickDate(i),
                      child: Text(_dates[i] == null ? 'Day ${i + 1}' : _short(_dates[i]!),
                          maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ]),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(_error, style: const TextStyle(color: AC.red, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _sending || _uploading ? null : _send,
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Send application'),
            ),
          ],
        ),
      ),
    );
  }
}
