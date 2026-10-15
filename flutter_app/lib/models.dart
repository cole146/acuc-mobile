import 'package:flutter/foundation.dart';

import 'api.dart';

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

String plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&#8217;', '’')
    .replaceAll('&#8211;', '–')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

class Question {
  final String prompt;
  final bool required;
  final String placeholder;
  Question(this.prompt, this.required, this.placeholder);
  factory Question.fromJson(dynamic j) {
    if (j is String) return Question(j, false, '');
    final m = (j as Map).cast<String, dynamic>();
    return Question(_s(m['prompt'] ?? m['question'] ?? m['label']), _b(m['required']), _s(m['placeholder']));
  }
}

class Job {
  final int id;
  final String title, company, location, type, mode, salary, excerpt, permalink, logo, applyMethod, applyUrl, html, postedAt;
  final int companyId, postedDays;
  final bool expired, urgent, isNew;
  final Map<String, dynamic> raw;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.mode,
    required this.salary,
    required this.excerpt,
    required this.permalink,
    required this.logo,
    required this.applyMethod,
    required this.applyUrl,
    required this.html,
    required this.postedAt,
    required this.companyId,
    required this.postedDays,
    required this.expired,
    required this.urgent,
    required this.isNew,
    required this.raw,
  });

  factory Job.fromJson(Map<String, dynamic> j) {
    String logo = _s(j['company_logo'] ?? j['logo'] ?? j['company_logo_url'] ?? j['logo_url']);
    if (logo.isNotEmpty && !logo.startsWith('http')) logo = '';
    final method = _s(j['application_method'] ?? j['apply_method'] ?? j['acuc_apply_method']).toLowerCase();
    return Job(
      id: _i(j['id']),
      title: _s(j['title']),
      company: _s(j['company'] ?? j['company_name']),
      location: _s(j['location']),
      type: _s(j['type']),
      mode: _s(j['mode']),
      salary: _s(j['salary']),
      excerpt: plainText(_s(j['excerpt'])),
      permalink: _s(j['permalink'] ?? j['url']),
      logo: logo,
      applyMethod: method,
      applyUrl: _s(j['apply_url'] ?? j['acuc_apply_url']),
      html: _s(j['description_html'] ?? j['description']),
      postedAt: _s(j['created_at'] ?? j['posted_at']),
      companyId: _i(j['company_id'] ?? j['employer_id']),
      postedDays: _i(j['posted_days']),
      expired: _b(j['is_expired'] ?? j['expired']) || j['live'] == false,
      urgent: _b(j['is_urgent'] ?? j['urgent'] ?? j['acuc_urgent']),
      isNew: _b(j['is_new']),
      raw: j,
    );
  }

  /// Applying on ACUC itself (native form) vs on the employer's site.
  bool get appliesOnAcuc => applyMethod == 'acuc' || applyMethod == 'internal' || applyMethod.isEmpty && _b(raw['allow_acuc_apply']);
  bool get appliesOutside => !appliesOnAcuc && applyUrl.startsWith('http');

  String get howToApply => appliesOnAcuc ? 'Easy apply on ACUC' : (appliesOutside ? 'Apply on company website' : 'Apply on ACUC');

  bool get isNewish {
    if (isNew) return true;
    final t = DateTime.tryParse(postedAt);
    final days = postedDays > 0 ? postedDays : (t == null ? 99 : DateTime.now().difference(t).inDays);
    return days <= 7;
  }

  String get posted {
    if (postedDays <= 0) {
      final t = DateTime.tryParse(postedAt);
      if (t == null) return 'New';
      final d = DateTime.now().difference(t).inDays;
      if (d <= 0) return 'Today';
      if (d == 1) return 'Yesterday';
      return '$d days ago';
    }
    if (postedDays == 1) return 'Yesterday';
    if (postedDays < 30) return '$postedDays days ago';
    final m = (postedDays / 30).floor();
    return m == 1 ? '1 month ago' : '$m months ago';
  }

  List<Question> get questions {
    final q = raw['screening_questions'] ?? raw['questions'];
    if (q is List) return q.map(Question.fromJson).where((x) => x.prompt.isNotEmpty).toList();
    return const [];
  }

  bool get needsInterviewDates {
    final iv = raw['interview_request'];
    return _b(raw['require_interview_dates']) || (iv is Map && _b(iv['enabled']));
  }

  String get interviewHint {
    final iv = raw['interview_request'];
    final note = iv is Map ? _s(iv['note']) : '';
    return note.isNotEmpty ? note : _s(raw['interview_hint']);
  }
}

class Application {
  final int id;
  final String status, createdAt, coverLetter;
  final Job? job;
  final String jobTitle, company;
  Application(this.id, this.status, this.createdAt, this.coverLetter, this.job, this.jobTitle, this.company);

  factory Application.fromJson(Map<String, dynamic> j) {
    final a = (j['application'] is Map ? j['application'] : j) as Map;
    final jobMap = j['job'] is Map ? (j['job'] as Map).cast<String, dynamic>() : null;
    final job = jobMap != null ? Job.fromJson(jobMap) : null;
    return Application(
      _i(a['id']),
      _s(a['status']).toLowerCase(),
      _s(a['created_at']),
      _s(a['cover_letter']),
      job,
      job?.title ?? _s(a['job_title']),
      job?.company ?? '',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
      case 'new':
      case 'submitted':
        return 'Sent';
      case 'viewed':
      case 'seen':
        return 'Viewed';
      case 'reviewing':
      case 'review':
      case 'in_review':
        return 'In review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interview':
      case 'interviewing':
        return 'Interview';
      case 'offer':
      case 'offered':
        return 'Offer';
      case 'hired':
      case 'accepted':
        return 'Hired';
      case 'rejected':
      case 'declined':
      case 'not_selected':
        return 'Not selected';
      default:
        return status.isEmpty ? 'Sent' : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
    }
  }
}

class Notice {
  final String id, type, title, body, link, createdAt;
  bool seen;
  Notice(this.id, this.type, this.title, this.body, this.link, this.createdAt, this.seen);
  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        _s(j['id']),
        _s(j['type']),
        plainText(_s(j['title'])),
        plainText(_s(j['body'])),
        _s(j['link']),
        _s(j['created_at']),
        _b(j['seen']) || _b(j['read']),
      );
}

String timeAgo(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}/${t.year}';
}

/// Saved jobs, shared by every screen (heart icons stay in sync).
class Saved extends ChangeNotifier {
  Saved._();
  static final Saved I = Saved._();
  final Set<int> ids = {};

  Future<void> load() async {
    if (!Session.I.signedIn) {
      ids.clear();
      notifyListeners();
      return;
    }
    try {
      final r = await Session.I.get('/saved-jobs');
      ids
        ..clear()
        ..addAll(((r['ids'] ?? []) as List).map((e) => _i(e)));
      notifyListeners();
    } catch (_) {}
  }

  bool has(int id) => ids.contains(id);

  Future<void> toggle(int id) async {
    final add = !ids.contains(id);
    add ? ids.add(id) : ids.remove(id);
    notifyListeners();
    try {
      await Session.I.post('/saved-jobs', add ? {'add': [id]} : {'remove': [id]});
    } catch (e) {
      add ? ids.remove(id) : ids.add(id);
      notifyListeners();
      rethrow;
    }
  }
}

/// Unread notifications badge.
class Unread extends ValueNotifier<int> {
  Unread._() : super(0);
  static final Unread I = Unread._();
  Future<void> refresh() async {
    if (!Session.I.signedIn) {
      value = 0;
      return;
    }
    try {
      final r = await Session.I.get('/notifications', {'limit': 1});
      value = _i(r['unread']);
    } catch (_) {}
  }
}

/// Tells the Applied list to refresh after a new application.
class Applied extends ChangeNotifier {
  Applied._();
  static final Applied I = Applied._();
  void bump() => notifyListeners();
}
