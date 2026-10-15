import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// The three welcome slides — same art, copy, colours and motion as the website app (acuc-onboarding).
class OnboardingPage extends StatefulWidget {
  final VoidCallback onStart; // "Get started" → sign in
  final VoidCallback onSkip; // "Skip" → browse
  const OnboardingPage({super.key, required this.onStart, required this.onSkip});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  final String title, text, kicker;
  final List<Color> colors;
  final double angle; // css linear-gradient angle
  const _Slide(this.title, this.text, this.colors, this.angle, {this.kicker = ''});
}

const _slides = [
  _Slide('Find Your Next Job, Anywhere in the World',
      'Discover opportunities across countries and industries. Search jobs, connect with employers, and apply from wherever you are.',
      [Color(0xFF0F3A7A), Color(0xFF1D4F93), Color(0xFF2F6FE8)], 155, kicker: 'Find Jobs Worldwide'),
  _Slide('Build your CV and get found by employers', 'Create a professional CV in minutes and join the CV database employers search every day.',
      [Color(0xFF0E7C86), Color(0xFF16B3A3)], 150),
  _Slide('Hire, chat and grow on ACUC', 'Employers post jobs and manage teams. Message and call in one place, on the app, web and mobile.',
      [Color(0xFF243B7A), Color(0xFF4C6FD6)], 150),
];

class _OnboardingPageState extends State<OnboardingPage> {
  int _i = 0;
  Timer? _t;
  double? _x0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 5500), (_) => setState(() => _i = (_i + 1) % _slides.length));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _go(int n) {
    _t?.cancel();
    setState(() => _i = (n + _slides.length) % _slides.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = _slides[_i];
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _x0 = d.localPosition.dx,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -150) _go(_i + 1);
            if (v > 150) _go(_i - 1);
            _x0 = null;
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 40,
                child: Row(children: [
                  Image.asset('assets/images/wordmark.png', height: 30),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF4B5B78), textStyle: const TextStyle(fontFamily: AC.font, fontSize: 15, fontWeight: FontWeight.w600)),
                    child: const Text('Skip'),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(a), child: child),
                  ),
                  child: _SlideView(key: ValueKey(_i), slide: s, index: _i, width: w - 48),
                ),
              ),
              const SizedBox(height: 26),
              Row(children: [
                for (var k = 0; k < _slides.length; k++)
                  GestureDetector(
                    onTap: () => _go(k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: k == _i ? 30 : 8,
                      height: 6,
                      decoration: BoxDecoration(color: k == _i ? AC.ink2 : const Color(0xFFC9D3E3), borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                height: 60,
                child: FilledButton(
                  onPressed: widget.onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: AC.go,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    textStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  child: const Text('Get started'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatefulWidget {
  final _Slide slide;
  final int index;
  final double width;
  const _SlideView({super.key, required this.slide, required this.index, required this.width});
  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _in.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve c = const Cubic(.2, .8, .2, 1)]) =>
      CurvedAnimation(parent: _in, curve: Interval(a, b, curve: c));

  Alignment _begin(double deg) {
    final r = (deg - 90) * math.pi / 180;
    return Alignment(-math.cos(r), -math.sin(r));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slide;
    final up1 = _iv(0.0, 0.4), up2 = _iv(0.06, 0.46), up3 = _iv(0.12, 0.52);
    Widget rise(Animation<double> a, Widget c) => AnimatedBuilder(
          animation: a,
          builder: (_, child) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: child)),
          child: c,
        );
    final art = AnimatedBuilder(
      animation: _iv(0, 0.43),
      builder: (_, child) {
        final v = _iv(0, 0.43).value;
        return Opacity(opacity: v, child: Transform.scale(scale: 0.94 + 0.06 * v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(begin: _begin(s.angle), end: -_begin(s.angle), colors: s.colors),
          boxShadow: [BoxShadow(color: const Color(0xFF0F3A7A).withValues(alpha: 0.55), blurRadius: 40, spreadRadius: -18, offset: const Offset(0, 18))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Center(child: widget.index == 0 ? _animatedGlobe() : SvgPicture.asset('assets/onboarding/slide${widget.index + 1}.svg', fit: BoxFit.contain)),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: const Alignment(0.6, -1), radius: 1.1, colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0)], stops: const [0, 0.6]),
              ),
            ),
          ),
        ]),
      ),
    );
    return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: (MediaQuery.of(context).size.height * 0.4).clamp(180.0, 330.0), width: double.infinity, child: art),
      if (s.kicker.isNotEmpty) ...[
        const SizedBox(height: 20),
        rise(up1, const _Kicker('Find Jobs Worldwide')),
      ],
      SizedBox(height: s.kicker.isNotEmpty ? 12 : 18),
      rise(up2, Text(s.title, style: T.h1.copyWith(fontSize: (widget.width * 0.086 + 4).clamp(28, 36)))),
      const SizedBox(height: 12),
      rise(up3, Text(s.text, style: const TextStyle(fontSize: 17, height: 1.55, color: Color(0xFF1C2B46), fontWeight: FontWeight.w300))),
    ]));
  }

  /// Slide 1: the globe turns, the pin drops and bobs, the cards slide in and float, the check pops,
  /// the person rises, the magnifier sweeps and the sparkles twinkle — like the website.
  Widget _animatedGlobe() {
    return AspectRatio(
      aspectRatio: 320 / 330,
      child: LayoutBuilder(builder: (context, c) {
        final k = c.maxWidth / 320;
        Widget layer(String f) => Positioned.fill(child: SvgPicture.asset('assets/onboarding/$f', fit: BoxFit.fill));
        return AnimatedBuilder(
          animation: Listenable.merge([_in, _loop]),
          builder: (context, _) {
            final t = _loop.value; // 0..1 over 14 s
            final secs = t * 14;
            double wave(double period, [double phase = 0]) => math.sin((secs + phase) / period * 2 * math.pi);
            final pinIn = _iv(0.25, 0.75, const Cubic(.3, 1.6, .5, 1)).value;
            final c1In = _iv(0.14, 0.64).value;
            final c2In = _iv(0.32, 0.82).value;
            final chk = _iv(0.78, 1.0, const Cubic(.3, 1.8, .5, 1)).value;
            final person = _iv(0.07, 0.64).value;
            return Stack(children: [
              layer('s1_base.svg'),
              // turning land, clipped to the globe
              Positioned(
                left: 64 * k,
                top: 36 * k,
                width: 192 * k,
                height: 192 * k,
                child: ClipOval(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: 440 * k,
                    minWidth: 440 * k,
                    maxHeight: 330 * k,
                    minHeight: 330 * k,
                    child: Transform.translate(
                      offset: Offset((-64 - 192 * t) * k, -36 * k),
                      child: SvgPicture.asset('assets/onboarding/s1_land.svg', width: 440 * k, height: 330 * k, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, (-30 * (1 - pinIn) + 3 * (wave(3) - 1)) * k),
                child: Opacity(opacity: pinIn.clamp(0, 1), child: Stack(children: [layer('s1_pin.svg')])),
              ),
              Transform.translate(
                offset: Offset(-40 * (1 - c1In) * k, (-3.5 + 3.5 * wave(4.2, 1)) * k),
                child: Opacity(opacity: c1In.clamp(0, 1), child: Stack(children: [layer('s1_c1.svg')])),
              ),
              Transform.translate(
                offset: Offset(40 * (1 - c2In) * k, (-3.5 - 3.5 * wave(4.6, 1.2)) * k),
                child: Opacity(
                  opacity: c2In.clamp(0, 1),
                  child: Stack(children: [
                    layer('s1_c2.svg'),
                    Positioned.fill(
                      child: Transform.scale(
                        scale: chk.clamp(0, 1.2),
                        origin: Offset((304 - 160) * k, (152 - 165) * k),
                        child: SvgPicture.asset('assets/onboarding/s1_check.svg', fit: BoxFit.fill),
                      ),
                    ),
                  ]),
                ),
              ),
              Transform.translate(
                offset: Offset(0, 40 * (1 - person) * k),
                child: Opacity(opacity: person.clamp(0, 1), child: Stack(children: [layer('s1_person.svg')])),
              ),
              Transform.translate(
                offset: Offset((15 + 15 * math.sin(secs / 5 * 2 * math.pi)) * k * 0.9, (-8 * math.sin(secs / 2.5 * 2 * math.pi).abs()) * k),
                child: Stack(children: [layer('s1_mag.svg')]),
              ),
              Opacity(opacity: (0.6 + 0.4 * wave(2.2)).clamp(0.25, 1), child: Stack(children: [layer('s1_spark.svg')])),
            ]);
          },
        );
      }),
    );
  }
}

class _Kicker extends StatefulWidget {
  final String text;
  const _Kicker(this.text);
  @override
  State<_Kicker> createState() => _KickerState();
}

class _KickerState extends State<_Kicker> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AC.blueSoft, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _p,
            builder: (_, __) {
              final v = (_p.value / 0.8).clamp(0.0, 1.0);
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.6 * (1 - v)), spreadRadius: 8 * v)],
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(widget.text.toUpperCase(), style: const TextStyle(color: AC.brand, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ]),
      );
}
