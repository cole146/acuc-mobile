import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'models.dart';
import 'screens/auth.dart';
import 'screens/jobs.dart';
import 'screens/lists.dart';
import 'screens/profile.dart';
import 'screens/web.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
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

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool _guest = false;
  bool _locked = false;
  bool _checkedLock = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        if (!Session.I.ready || !_checkedLock) return const Splash();
        if (_locked && Session.I.signedIn) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/logo.png', width: 80),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint_rounded), label: const Text('Unlock')),
              ]),
            ),
          );
        }
        if (!Session.I.signedIn && !_guest) return WelcomePage(onBrowse: () => setState(() => _guest = true));
        return const Shell();
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

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _visited = <int>{0};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => Unread.I.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const JobsPage();
      case 1:
        return const SavedPage();
      case 2:
        return const ApplicationsPage();
      case 3:
        return Session.I.signedIn
            ? const WebPage(path: '/network/message/', title: 'Messages', embedded: true)
            : Scaffold(
                appBar: AppBar(title: const Text('Messages')),
                body: const SignedOutHint(icon: Icons.chat_bubble_outline_rounded, title: 'Talk to employers', text: 'Sign in to message recruiters and your network.'),
              );
      default:
        return const ProfilePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Session.I.signedIn;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < 5; i++)
              _visited.contains(i) ? KeyedSubtree(key: ValueKey('tab$i-$signedIn'), child: _page(i)) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AC.line))),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() {
              _tab = i;
              _visited.add(i);
            }),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.manage_search_rounded), label: 'Jobs'),
              NavigationDestination(icon: Icon(Icons.bookmark_outline_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Saved'),
              NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Applied'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
