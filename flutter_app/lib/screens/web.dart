import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../api.dart';
import '../theme.dart';

const String kWebUA =
    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36 $kUserAgent';

bool _isAcuc(Uri u) {
  final h = u.host.toLowerCase().replaceFirst('www.', '');
  final base = Uri.parse(kBase).host.toLowerCase().replaceFirst('www.', '');
  return h == base;
}

/// Builds a WebView controller for acuc.jobs pages inside the app: app user agent (so the site knows it is the
/// app), file uploads, microphone/camera for calls and voice notes, outside links open in the browser.
WebViewController acucWebController({
  void Function(int progress)? onProgress,
  void Function(String url)? onPageFinished,
  NavigationDecision Function(Uri uri)? intercept,
}) {
  late final WebViewController c;
  c = WebViewController(onPermissionRequest: (req) async {
    final want = <Permission>[];
    for (final t in req.types) {
      if (t == WebViewPermissionResourceType.microphone) want.add(Permission.microphone);
      if (t == WebViewPermissionResourceType.camera) want.add(Permission.camera);
    }
    if (want.isEmpty) return req.deny();
    final res = await want.request();
    res.values.every((s) => s.isGranted) ? await req.grant() : await req.deny();
  })
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AC.bg)
    ..setUserAgent(kWebUA)
    ..setNavigationDelegate(NavigationDelegate(
      onProgress: onProgress,
      onPageFinished: onPageFinished,
      onNavigationRequest: (req) {
        final u = Uri.tryParse(req.url);
        if (u == null) return NavigationDecision.prevent;
        if (intercept != null) {
          final d = intercept(u);
          if (d == NavigationDecision.prevent) return d;
        }
        if (u.scheme == 'http' || u.scheme == 'https') {
          if (_isAcuc(u) || !req.isMainFrame) return NavigationDecision.navigate;
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
        if (u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob') return NavigationDecision.navigate;
        launchUrl(u, mode: LaunchMode.externalApplication); // tel:, mailto:, whatsapp:, intent: …
        return NavigationDecision.prevent;
      },
    ));
  final p = c.platform;
  if (p is AndroidWebViewController) {
    p.setMediaPlaybackRequiresUserGesture(false);
    p.setOnShowFileSelector((params) async {
      final images = params.acceptTypes.any((t) => t.startsWith('image/'));
      final r = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: images && params.acceptTypes.every((t) => t.startsWith('image/')) ? FileType.image : FileType.any,
      );
      if (r == null) return <String>[];
      return r.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList();
    });
  }
  return c;
}

/// An acuc.jobs page inside the app, signed in as the app user.
class WebPage extends StatefulWidget {
  final String path;
  final String title;
  final bool embedded; // true when used as a tab (no back arrow)
  const WebPage({super.key, required this.path, required this.title, this.embedded = false});

  static Future<void> open(BuildContext context, String path, String title) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebPage(path: path, title: title)));

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> with AutomaticKeepAliveClientMixin {
  late final WebViewController _c;
  int _progress = 0;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = acucWebController(onProgress: (p) => mounted ? setState(() => _progress = p) : null);
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final path = widget.path.startsWith('http') ? widget.path : '$kBase${widget.path}';
    if (!Session.I.signedIn) {
      await _c.loadRequest(Uri.parse(path));
      return;
    }
    try {
      final r = await Session.I.post('/app/web-session', {'path': widget.path});
      await _c.loadRequest(Uri.parse((r['url'] ?? path).toString()));
    } on ApiError catch (e) {
      if (e.status == 0) {
        setState(() => _error = e.message);
      } else {
        await _c.loadRequest(Uri.parse(path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          await _c.goBack();
        } else if (!widget.embedded && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: widget.embedded
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: SafeArea(
                  bottom: false,
                  child: _progress < 100
                      ? LinearProgressIndicator(value: _progress / 100, minHeight: 2, backgroundColor: Colors.transparent, color: AC.blue)
                      : const SizedBox(height: 2),
                ),
              )
            : AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Svg(Ico.back, size: 22, color: AC.ink2)),
          title: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.ink2)),
          shape: const Border(bottom: BorderSide(color: Color(0xFFEDF1F7))),
          actions: [IconButton(tooltip: 'Reload', icon: const Svg('<path d="M21 12a9 9 0 1 1-2.6-6.4"/><path d="M21 3v6h-6"/>', size: 20, color: AC.ink2), onPressed: () => _c.reload())],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 2, backgroundColor: Colors.transparent, color: AC.blue),
                )
              : null,
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AC.sub)),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ]),
                ),
              )
            : WebViewWidget(controller: _c),
      ),
    );
  }
}

/// Sign up / Google sign-in on the website inside the app, then the site hands an app token back.
class WebAuthPage extends StatefulWidget {
  final bool signup;
  const WebAuthPage({super.key, this.signup = false});
  @override
  State<WebAuthPage> createState() => _WebAuthPageState();
}

class _WebAuthPageState extends State<WebAuthPage> {
  late final WebViewController _c;
  late final String _state;
  int _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final r = Random.secure();
    _state = List.generate(32, (_) => 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[r.nextInt(56)]).join();
    _c = acucWebController(
      onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      onPageFinished: _checkSignedIn,
      intercept: (u) {
        if (u.scheme == 'acucjobs') {
          _finish(u);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    );
    final issue = Uri.parse(kBase).replace(path: '/', queryParameters: {'acuc_app_issue': _state}).toString();
    final start = Uri.parse(kBase).replace(path: widget.signup ? '/register-form/' : '/acuc-lo/', queryParameters: {'redirect_to': issue});
    _c.loadRequest(start);
  }

  /// After signing up the site may land on its own page: once WordPress says we are signed in, ask for the token.
  Future<void> _checkSignedIn(String url) async {
    if (_done) return;
    final u = Uri.tryParse(url);
    if (u == null || u.queryParameters.containsKey('acuc_app_issue')) return;
    try {
      final r = await _c.runJavaScriptReturningResult("document.body && document.body.classList.contains('logged-in') ? 1 : 0");
      if ('$r' == '1' || '$r' == 'true') {
        final issue = Uri.parse(kBase).replace(path: '/', queryParameters: {'acuc_app_issue': _state});
        await _c.loadRequest(issue);
      }
    } catch (_) {}
  }

  Future<void> _finish(Uri u) async {
    if (_done) return;
    if (u.queryParameters['state'] != _state) return;
    _done = true;
    try {
      await Session.I.useToken(u.queryParameters['token'] ?? '');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _done = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _c.canGoBack()) {
            await _c.goBack();
          } else if (context.mounted) {
            Navigator.of(context).pop(false);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(onPressed: () => Navigator.of(context).maybePop(false), icon: const Svg(Ico.close, size: 22, color: AC.ink2)),
            title: Text(widget.signup ? 'Create account' : 'Sign in', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.ink2)),
            bottom: _progress < 100
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(2),
                    child: LinearProgressIndicator(value: _progress / 100, minHeight: 2, backgroundColor: Colors.transparent),
                  )
                : null,
          ),
          body: WebViewWidget(controller: _c),
        ),
      );
}
