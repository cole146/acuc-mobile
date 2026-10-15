import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'company.dart';
import 'jobs.dart';
import 'web.dart';

/// Loads the full job and whether I already applied.
class _JobState extends ChangeNotifier {
  Job job;
  bool applied = false;
  bool loaded = false;
  String? error;
  _JobState(this.job);

  void markApplied() {
    applied = true;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final r = await Session.I.get('/jobs/${job.id}');
      final m = (r is Map && r['job'] is Map ? r['job'] : r) as Map;
      job = Job.fromJson(m.cast<String, dynamic>());
      applied = m['applied'] == true || m['has_applied'] == true;
      loaded = true;
      notifyListeners();
      if (Session.I.signedIn && !applied) {
        final a = await Session.I.get('/applications', {'per_page': 50});
        final ids = ((a['items'] ?? []) as List).whereType<Map>().map((x) => Application.fromJson(x.cast<String, dynamic>()).job?.id).toSet();
        if (ids.contains(job.id)) {
          applied = true;
          notifyListeners();
        }
      }
    } catch (e) {
      error = '$e';
      loaded = true;
      notifyListeners();
    }
  }
}

Future<void> startApply(BuildContext context, _JobState st) async {
  final j = st.job;
  if (j.appliesOutside) {
    await launchUrl(Uri.parse(j.applyUrl), mode: LaunchMode.externalApplication);
    return;
  }
  if (!await requireSignIn(context, reason: 'Sign in to apply with your ACUC profile and CV.')) return;
  if (!context.mounted) return;
  if (Session.I.isEmployer) {
    toast(context, 'You’re signed in as an employer. Sign in as a jobseeker to apply.');
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
    barrierColor: const Color(0x8C08142A),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => ApplySheet(job: j),
  );
  if (ok == true) {
    st.markApplied();
    Applied.I.bump();
    if (context.mounted) toast(context, 'Application sent. Good luck!');
  }
}

/// The job sheet: rises from the bottom, drags up to full, drags down to close (acuc-job-sheet).
class JobSheet extends StatefulWidget {
  final Job job;
  const JobSheet({super.key, required this.job});

  static Future<void> open(BuildContext context, Job j) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x8C08142A),
        builder: (_) => JobSheet(job: j),
      );

  @override
  State<JobSheet> createState() => _JobSheetState();
}

class _JobSheetState extends State<JobSheet> {
  late final _JobState st = _JobState(widget.job)..load();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.62, 0.94],
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [BoxShadow(color: const Color(0xFF041130).withValues(alpha: 0.55), blurRadius: 70, spreadRadius: -24, offset: const Offset(0, -24))],
        ),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
          listenable: st,
          builder: (context, _) {
            final j = st.job;
            final meta = [j.company, j.location].where((s) => s.isNotEmpty).join(' · ');
            return Column(children: [
              Expanded(
                child: CustomScrollView(controller: scroll, slivers: [
                  SliverToBoxAdapter(
                    child: Column(children: [
                      SizedBox(
                        height: 22,
                        child: Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0x2E14213D), borderRadius: BorderRadius.circular(99)))),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4EAF4)))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const _Kick('Job'),
                              const SizedBox(height: 7),
                              Text(j.title, style: const TextStyle(fontSize: 18, height: 1.28, fontWeight: FontWeight.w800, letterSpacing: -0.18, color: Color(0xFF0C1E3A))),
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(meta, style: const TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500, color: Color(0xFF5B6B85))),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 12),
                          _CloseBtn(onTap: () => Navigator.pop(context)),
                        ]),
                      ),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                    sliver: SliverToBoxAdapter(child: _JobBody(st: st)),
                  ),
                ]),
              ),
              _ApplyBar(
                st: st,
                onFull: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobPage(jobId: j.id, preview: j)));
                },
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Kick extends StatelessWidget {
  final String text;
  const _Kick(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: AC.blueSoft, borderRadius: BorderRadius.circular(99)),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: AC.blue)),
      );
}

class _CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFE4EAF4))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(width: 38, height: 38, child: Center(child: Svg(Ico.close, size: 17, color: Color(0xFF0C1E3A), stroke: 2.2))),
        ),
      );
}

/// What the sheet and the full page show under the title.
class _JobBody extends StatelessWidget {
  final _JobState st;
  const _JobBody({required this.st});

  Widget _detailPill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 0.66, fontWeight: FontWeight.w700, color: Color(0xFF7A879C))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AC.ink2)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final j = st.job;
    final pills = <List<String>>[
      if (j.type.isNotEmpty) ['Job type', j.type],
      if (j.salary.isNotEmpty) ['Salary', j.salary],
      if (j.mode.isNotEmpty) ['Work mode', j.mode],
      ['Posted', j.posted],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (j.location.isNotEmpty)
        Row(children: [
          const Svg(Ico.pin, size: 15, color: Color(0xFF5B6B86)),
          const SizedBox(width: 6),
          Expanded(child: Text(j.location, style: const TextStyle(fontSize: 15, color: Color(0xFF5B6B86), fontWeight: FontWeight.w300))),
        ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (j.expired) const _Badge('Closed', red: true) else if (j.isNewish) const _Badge('New'),
        if (j.urgent) const _Badge('Urgent', red: true),
        if (st.applied) const _Badge('Applied'),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFFF1F5FD), borderRadius: BorderRadius.circular(10)),
        child: Text(
          j.appliesOutside ? 'Apply on the company’s website.' : 'Apply on ACUC with your profile.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF3A4A63), fontWeight: FontWeight.w400),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SaveButton(jobId: j.id, chip: true),
        ChipBtn(icon: Ico.share, label: 'Share', border: AC.pillLine, onTap: () => shareJob(j)),
        if (j.companyId > 0)
          ChipBtn(
            icon: Ico.building,
            label: 'Company',
            border: AC.pillLine,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyPage(id: j.companyId, name: j.company))),
          ),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.7,
        children: [for (final p in pills) _detailPill(p[0], p[1])],
      ),
      const SizedBox(height: 16),
      const Text('About the job', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0C1E3A))),
      const SizedBox(height: 8),
      if (!st.loaded && j.html.isEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final w in [1.0, 0.92, 0.97, 0.6])
            FractionallySizedBox(
              widthFactor: w,
              child: Container(height: 11, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: const Color(0xFFEEF2F8), borderRadius: BorderRadius.circular(6))),
            ),
        ])
      else if (j.html.isNotEmpty)
        HtmlWidget(
          j.html,
          textStyle: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF22324D), fontWeight: FontWeight.w400),
          onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        )
      else
        Text(j.excerpt.isEmpty ? 'The employer has not added a description.' : j.excerpt,
            style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF22324D))),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool red;
  const _Badge(this.text, {this.red = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: red ? AC.redSoft : AC.greenSoft, borderRadius: BorderRadius.circular(999)),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: red ? AC.red : AC.green)),
      );
}

/// Bottom bar: "Apply on ACUC" (blue gradient pill) + "Full page" (quiet pill).
class _ApplyBar extends StatelessWidget {
  final _JobState st;
  final VoidCallback? onFull;
  const _ApplyBar({required this.st, this.onFull});
  @override
  Widget build(BuildContext context) {
    final j = st.job;
    final disabled = j.expired || st.applied;
    final label = st.applied
        ? 'Applied'
        : j.expired
            ? 'Applications closed'
            : j.appliesOutside
                ? 'Apply on company site'
                : 'Apply on ACUC';
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE4EAF4)))),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: disabled ? null : () => startApply(context, st),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: disabled ? 0.55 : 1,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AC.blueGradient,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: disabled ? null : [BoxShadow(color: AC.blue.withValues(alpha: 0.85), blurRadius: 30, spreadRadius: -16, offset: const Offset(0, 16))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (st.applied) ...[const Svg(Ico.check2, size: 18, color: Colors.white, stroke: 2.2), const SizedBox(width: 7)],
                  if (j.appliesOutside && !disabled) ...[const Svg(Ico.external, size: 17, color: Colors.white, stroke: 2.1), const SizedBox(width: 7)],
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
        if (onFull != null) ...[
          const SizedBox(width: 9),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: onFull,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE4EAF4)),
                foregroundColor: const Color(0xFF0C1E3A),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                textStyle: const TextStyle(fontFamily: AC.font, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Full page'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// The job on its own page (from "Full page", a link or a notification).
class JobPage extends StatefulWidget {
  final int jobId;
  final Job? preview;
  const JobPage({super.key, required this.jobId, this.preview});
  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  late final _JobState st = _JobState(widget.preview ?? Job.fromJson({'id': widget.jobId}))..load();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final j = st.job;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Svg(Ico.back, size: 22, color: AC.ink2)),
            title: const Text('Job'),
            shape: const Border(bottom: BorderSide(color: Color(0xFFE4EAF4))),
          ),
          body: st.error != null && j.title.isEmpty
              ? ErrorState(message: st.error!, onRetry: () => st.load())
              : j.title.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 30), children: [
                      Row(children: [
                        CompanyLogo(name: j.company, logo: j.logo, size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: j.companyId > 0 ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyPage(id: j.companyId, name: j.company))) : null,
                            child: Text(j.company, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AC.brand)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      const _Kick('Job'),
                      const SizedBox(height: 8),
                      Text(j.title, style: const TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: Color(0xFF0C1E3A))),
                      const SizedBox(height: 14),
                      _JobBody(st: st),
                    ]),
          bottomNavigationBar: j.title.isEmpty ? null : _ApplyBar(st: st),
        );
      },
    );
  }
}

/// Apply form (native): CV, message, screening questions, three interview days.
class ApplySheet extends StatefulWidget {
  final Job job;
  const ApplySheet({super.key, required this.job});
  @override
  State<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<ApplySheet> {
  final _cover = TextEditingController();
  final List<TextEditingController> _answers = [];
  final List<DateTime?> _dates = [null, null, null];
  List<Question> _qs = [];
  bool _needDates = false;
  String _cvName = '';
  int _cvId = 0;
  bool _uploading = false;
  bool _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _setQs(widget.job.questions);
    _needDates = widget.job.needsInterviewDates;
    final cv = Session.I.user?['cv'];
    if (cv is Map) {
      _cvId = (cv['id'] is int) ? cv['id'] as int : 0;
      _cvName = (cv['filename'] ?? '').toString();
    }
    _loadQuestions();
  }

  void _setQs(List<Question> qs) {
    _qs = qs;
    for (final c in _answers) {
      c.dispose();
    }
    _answers
      ..clear()
      ..addAll(List.generate(qs.length, (_) => TextEditingController()));
  }

  Future<void> _loadQuestions() async {
    try {
      final r = await Session.I.get('/jobs/${widget.job.id}/questions');
      final list = (r['screening_questions'] ?? r['questions'] ?? []) as List;
      final qs = list.map(Question.fromJson).where((q) => q.prompt.isNotEmpty).toList();
      final iv = r['interview_request'];
      if (!mounted) return;
      setState(() {
        if (qs.length != _qs.length) _setQs(qs);
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
    if (_needDates && _dates.whereType<DateTime>().map(_fmt).toSet().length != 3) {
      setState(() => _error = 'Choose 3 different days you could do an interview.');
      return;
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
      if (r is Map && r['status'] == 'already_applied') toast(context, 'You already applied to this job.');
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0C1E3A))),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15.5, color: Color(0xFF8A8D91), fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        builder: (context, scroll) => Column(children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              children: [
                SizedBox(
                  height: 22,
                  child: Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0x2E14213D), borderRadius: BorderRadius.circular(99)))),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _Kick('Apply'),
                      const SizedBox(height: 7),
                      Text(widget.job.title, style: const TextStyle(fontSize: 18, height: 1.28, fontWeight: FontWeight.w800, color: Color(0xFF0C1E3A))),
                      const SizedBox(height: 4),
                      Text(widget.job.company, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF5B6B85))),
                    ]),
                  ),
                  _CloseBtn(onTap: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 16),
                _label('Your CV'),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Svg(Ico.doc, size: 22, color: _cvId > 0 ? AC.brand : AC.sub),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_cvId > 0 ? (_cvName.isEmpty ? 'Your CV' : _cvName) : 'No CV yet — add one (PDF or Word)',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AC.ink2)),
                    ),
                    _uploading
                        ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)))
                        : TextButton(onPressed: _pickCv, child: Text(_cvId > 0 ? 'Change' : 'Add CV', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 18),
                _label('Message to the employer (optional)'),
                TextField(controller: _cover, minLines: 3, maxLines: 8, decoration: _dec('Why you are a good fit…')),
                for (var i = 0; i < _qs.length; i++) ...[
                  const SizedBox(height: 18),
                  _label('${_qs[i].prompt}${_qs[i].required ? ' *' : ''}'),
                  TextField(controller: _answers[i], minLines: 1, maxLines: 5, decoration: _dec(_qs[i].placeholder.isEmpty ? 'Your answer' : _qs[i].placeholder)),
                ],
                if (_needDates) ...[
                  const SizedBox(height: 18),
                  _label('3 days you could do an interview *'),
                  if (widget.job.interviewHint.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.job.interviewHint, style: const TextStyle(color: AC.sub, fontWeight: FontWeight.w300))),
                  Row(children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickDate(i),
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _dates[i] == null ? Colors.white : AC.blueSoft,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: _dates[i] == null ? AC.pillLine : AC.blue, width: 1.5),
                            ),
                            child: Text(_dates[i] == null ? 'Day ${i + 1}' : _short(_dates[i]!),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dates[i] == null ? AC.text : AC.blue)),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(color: AC.redSoft, borderRadius: BorderRadius.circular(14)),
                    child: Text(_error, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE4EAF4)))),
            child: GestureDetector(
              onTap: _sending || _uploading ? null : _send,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AC.blueGradient,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: AC.blue.withValues(alpha: 0.85), blurRadius: 30, spreadRadius: -16, offset: const Offset(0, 16))],
                ),
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Send application', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
