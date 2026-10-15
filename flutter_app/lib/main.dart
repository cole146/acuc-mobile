import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'models.dart';
import 'screens/auth.dart';
import 'screens/jobs.dart';
import 'screens/notifications.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/web.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const AcucApp());
  Session.I.load().then((_) {
    Saved.I.load();
    Unread.I.refresh();
  });
}

class AcucApp extends StatelessWidget {
  const AcucApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ACUC Jobs',
        debugShowCheckedModeBanner: false,
        theme: acucTheme(),
        home: const Root(),
      );
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

enum _Gate { welcome, signin, guest }

class _RootState extends State<Root> with WidgetsBindingObserver {
  _Gate _gate = _Gate.welcome;
  bool _locked = false;
  bool _checkedLock = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialLock();
    Session.I.addListener(_onSession);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Session.I.removeListener(_onSession);
    super.dispose();
  }

  // After logging out, the welcome slides show again (like the website).
  bool _wasIn = false;
  void _onSession() {
    if (_wasIn && !Session.I.signedIn) setState(() => _gate = _Gate.welcome);
    _wasIn = Session.I.signedIn;
  }

  Future<void> _initialLock() async {
    final on = await AppLock.enabled();
    setState(() {
      _locked = on;
      _checkedLock = true;
    });
    if (on) _unlock();
  }

  Future<void> _unlock() async {
    if (await AppLock.unlock()) setState(() => _locked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed) {
      Unread.I.refresh();
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      if (Session.I.signedIn && away > const Duration(minutes: 2) && await AppLock.enabled()) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        Widget page;
        if (!Session.I.ready || !_checkedLock) {
          page = const Splash(key: ValueKey('splash'));
        } else if (_locked && Session.I.signedIn) {
          page = Scaffold(
            key: const ValueKey('lock'),
            backgroundColor: Colors.white,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/logo.png', width: 76),
                const SizedBox(height: 28),
                SizedBox(
                  width: 220,
                  height: 50,
                  child: FilledButton(
                    onPressed: _unlock,
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Svg(Ico.fingerprint, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Unlock'),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        } else if (Session.I.signedIn) {
          page = const Shell(key: ValueKey('shell-in'));
        } else if (_gate == _Gate.welcome) {
          page = OnboardingPage(
            key: const ValueKey('welcome'),
            onStart: () => setState(() => _gate = _Gate.signin),
            onSkip: () => setState(() => _gate = _Gate.guest),
          );
        } else if (_gate == _Gate.signin) {
          page = PopScope(
            key: const ValueKey('signin'),
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _gate = _Gate.guest);
            },
            child: const SignInPage(rootPage: true),
          );
        } else {
          page = Shell(key: const ValueKey('shell-guest'), onLogin: () => setState(() => _gate = _Gate.signin));
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: page);
      },
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Image.asset('assets/images/logo.png', width: 96, height: 96)),
      );
}

class _Tab {
  final String key, label, icon;
  final bool primary;
  const _Tab(this.key, this.label, this.icon, {this.primary = false});
}

/// The app frame: pages + the floating glass bottom menu (Home · Network · Jobs · Messages · Alerts).
class Shell extends StatefulWidget {
  final VoidCallback? onLogin;
  const Shell({super.key, this.onLogin});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int _tab = Session.I.signedIn ? 0 : 2;
  final _visited = <int>{};
  Timer? _poll;

  static const _member = [
    _Tab('home', 'Home', Ico.home),
    _Tab('network', 'Network', Ico.network),
    _Tab('jobs', 'Jobs', Ico.jobs, primary: true),
    _Tab('messages', 'Messages', Ico.messages),
    _Tab('alerts', 'Alerts', Ico.alerts),
  ];
  static const _guest = [
    _Tab('home', 'Home', Ico.home),
    _Tab('search', 'Search', Ico.search),
    _Tab('jobs', 'Jobs', Ico.jobs, primary: true),
    _Tab('ai', 'AI Apply', Ico.sparkle),
    _Tab('login', 'Log in', Ico.login),
  ];

  bool get _in => Session.I.signedIn;
  List<_Tab> get _tabs => _in ? _member : _guest;

  @override
  void initState() {
    super.initState();
    _visited.add(_tab);
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => Unread.I.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _go(int i) => setState(() {
        _tab = i;
        _visited.add(i);
      });

  Future<void> _tap(int i) async {
    final t = _tabs[i];
    if (!_in) {
      if (t.key == 'search') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobSearchPage()));
        return;
      }
      if (t.key == 'login') {
        widget.onLogin?.call();
        return;
      }
      if (t.key == 'ai') {
        await requireSignIn(context, reason: 'Sign in to let AI find and apply to jobs for you.');
        return;
      }
      _go(2);
      return;
    }
    if (i == _tab && t.key == 'jobs') return;
    _go(i);
  }

  // Website screens sit above the floating menu (a web view can't scroll under it).
  Widget _padded(Widget w) => Padding(padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom), child: w);

  Widget _page(int i) {
    final key = _tabs[i].key;
    switch (key) {
      case 'home':
        return _in ? HomePage(onGoTab: (t) => _go(t == 2 ? 2 : t)) : const JobsPage();
      case 'network':
        return _padded(const WebPage(path: '/network/friends/', title: 'Network', embedded: true));
      case 'jobs':
        return const JobsPage();
      case 'messages':
        return _padded(const WebPage(path: '/network/message/', title: 'Messages', embedded: true));
      case 'alerts':
        return const AlertsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: _tab == (_in ? 0 : 2),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_in ? 0 : 2);
      },
      child: Scaffold(
        backgroundColor: AC.bg,
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < 5; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 8 + bottom),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(33),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                height: 66,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(33),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                ),
                child: Row(children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(child: _TabButton(tab: _tabs[i], selected: i == _tab && (_in || _tabs[i].key == 'jobs'), onTap: () => _tap(i))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = tab.primary
        ? Container(
            width: 44,
            height: 30,
            decoration: BoxDecoration(
              gradient: AC.tabGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: AC.blue.withValues(alpha: 0.75), blurRadius: 14, spreadRadius: -6, offset: const Offset(0, 6))],
            ),
            child: Center(child: Svg(tab.icon, size: 20, color: Colors.white)),
          )
        : Svg(tab.icon, size: 24, color: const Color(0xFF14213D));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: selected && !tab.primary ? const Color(0xFFEEF1F6) : Colors.transparent, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            height: 30,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              icon,
              if (tab.key == 'alerts')
                ValueListenableBuilder<int>(
                  valueListenable: Unread.I,
                  builder: (_, n, __) => n <= 0
                      ? const SizedBox.shrink()
                      : Positioned(
                          top: -4,
                          left: 16,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(color: AC.badge, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 2)),
                            alignment: Alignment.center,
                            child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
                          ),
                        ),
                ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(tab.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: tab.primary && selected ? AC.blue : const Color(0xFF14213D))),
        ]),
      ),
    );
  }
}
