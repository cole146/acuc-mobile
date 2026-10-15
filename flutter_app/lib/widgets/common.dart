import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

String initials(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return 'A';
  return (w.length == 1 ? w[0].substring(0, w[0].length.clamp(1, 2)) : '${w[0][0]}${w[1][0]}').toUpperCase();
}

/// Company logo square (52px, radius 12, light border) — initials on a soft blue when there is no logo.
class CompanyLogo extends StatelessWidget {
  final String name;
  final String logo;
  final double size;
  const CompanyLogo({super.key, required this.name, this.logo = '', this.size = 52});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.23);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: AC.line),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEAF1FF), Color(0xFFE3ECFB)]),
      ),
      child: Text(initials(name), style: TextStyle(color: AC.brand, fontWeight: FontWeight.w800, fontSize: size * 0.29)),
    );
    if (!logo.startsWith('http')) return fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: r, border: Border.all(color: AC.line), color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, errorWidget: (_, __, ___) => fallback, placeholder: (_, __) => fallback),
    );
  }
}

/// Round person avatar: photo, or initials on the light blue circle (like the profile page).
class PersonAvatar extends StatelessWidget {
  final String name;
  final String photo;
  final double size;
  final bool ring;
  const PersonAvatar({super.key, required this.name, this.photo = '', this.size = 40, this.ring = false});
  @override
  Widget build(BuildContext context) {
    final letters = Text(initials(name), style: TextStyle(color: AC.brand, fontWeight: FontWeight.w800, fontSize: size * 0.32, letterSpacing: -0.5));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEFF3FA),
        border: ring ? Border.all(color: Colors.white, width: size * 0.05) : null,
        boxShadow: ring ? [BoxShadow(color: const Color(0xFF0B1A33).withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photo.startsWith('http') && !photo.contains('d=404')
          ? CachedNetworkImage(imageUrl: photo, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, __, ___) => letters, placeholder: (_, __) => letters)
          : letters,
    );
  }
}

/// The small round blue "G" in the header.
class MeBubble extends StatelessWidget {
  final VoidCallback onTap;
  const MeBubble({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final n = Session.I.name;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AC.tabGradient,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: AC.blue.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: Text(n.isEmpty ? 'A' : n[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

/// Top bar: ACUC logo · "I'm looking for…" search pill · me bubble (as on the website app).
class AcucTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSearch;
  final VoidCallback? onMe;
  final bool back;
  const AcucTopBar({super.key, required this.onSearch, this.onMe, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1F7)))),
          child: Row(children: [
            if (back)
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Svg(Ico.back, size: 22, color: AC.ink2),
                visualDensity: VisualDensity.compact,
              ),
            Image.asset('assets/images/wordmark.png', height: 20),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onSearch,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFEFF2F7), borderRadius: BorderRadius.circular(999)),
                  child: const Row(children: [
                    Svg(Ico.search, size: 17, color: AC.text),
                    SizedBox(width: 8),
                    Text('I’m looking for…', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400, color: AC.text)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (Session.I.signedIn && onMe != null) MeBubble(onTap: onMe!),
          ]),
        ),
      ),
    );
  }
}

/// White rounded card (radius 22) used for every block on the profile / company pages.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.margin = const EdgeInsets.fromLTRB(14, 0, 14, 14)});
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AC.softShadow),
        child: child,
      );
}

/// Outlined pill (salary pill is green).
class OPill extends StatelessWidget {
  final String text;
  final bool money;
  const OPill(this.text, {super.key, this.money = false});
  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: money ? AC.greenLine : AC.pillLine, width: 1.5),
        ),
        child: Text(text,
            maxLines: 1,
            style: TextStyle(fontSize: 14.5, fontWeight: money ? FontWeight.w600 : FontWeight.w500, color: money ? AC.green : AC.text)),
      );
}

/// Small filled tag: NEW (green) / URGENT (red).
class Tag extends StatelessWidget {
  final String text;
  final bool red;
  const Tag(this.text, {super.key, this.red = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: red ? AC.redSoft : const Color(0xFFE3F5EC), borderRadius: BorderRadius.circular(999)),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: red ? const Color(0xFFC62828) : const Color(0xFF0F7A4D))),
      );
}

/// Small outlined action chip (Save / Share / Write a review …).
class ChipBtn extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color border;
  final bool filled;
  const ChipBtn({super.key, required this.icon, required this.label, this.onTap, this.color = AC.text, this.border = AC.line, this.filled = false});
  @override
  Widget build(BuildContext context) => Material(
        color: filled ? AC.blue : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: filled ? AC.blue : border, width: 1.3)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Svg(icon, size: 16, color: filled ? Colors.white : color, stroke: 2),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filled ? Colors.white : color)),
            ]),
          ),
        ),
      );
}

/// The job card used in every list (same as the Network Jobs list): logo, title, company, place,
/// salary & type pills, how to apply, NEW tag, Save and Share on the right.
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final Widget? saveButton;
  final String? status;
  const JobCard({super.key, required this.job, required this.onTap, this.onShare, this.saveButton, this.status});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 10, 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AC.line), boxShadow: AC.softShadow),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CompanyLogo(name: job.company, logo: job.logo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job.title, style: const TextStyle(fontSize: 17, height: 1.32, fontWeight: FontWeight.w700, letterSpacing: -0.17, color: AC.ink2)),
                if (job.company.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(job.company, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AC.text)),
                  ),
                if (job.location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Svg(Ico.pin, size: 15, color: AC.muted),
                      const SizedBox(width: 5),
                      Expanded(child: Text(job.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, color: AC.muted, fontWeight: FontWeight.w400))),
                    ]),
                  ),
                if (job.salary.isNotEmpty || job.type.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      if (job.salary.isNotEmpty) OPill(job.salary, money: true),
                      if (job.type.isNotEmpty) OPill(job.type),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(status ?? job.howToApply, style: TextStyle(fontSize: 14.5, color: status != null ? AC.brand : AC.sub, fontWeight: status != null ? FontWeight.w600 : FontWeight.w300)),
                ),
                if (job.isNewish || job.urgent || job.expired)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(spacing: 8, children: [
                      if (job.expired) const Tag('Closed', red: true) else if (job.isNewish) const Tag('New'),
                      if (job.urgent) const Tag('Urgent', red: true),
                    ]),
                  ),
              ]),
            ),
            Column(children: [
              if (saveButton != null) saveButton!,
              if (onShare != null) ...[
                const SizedBox(height: 4),
                IconButton(onPressed: onShare, icon: const Svg(Ico.share, size: 20, color: Color(0xFF4A5B78)), visualDensity: VisualDensity.compact),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.text = '', this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AC.blueSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Svg(icon, size: 28, color: AC.brand),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AC.ink)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: T.bodyLight.copyWith(fontSize: 15)),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: Ico.globe, title: 'Couldn’t load this', text: message, action: 'Try again', onAction: onRetry);
}

class CardSkeleton extends StatefulWidget {
  const CardSkeleton({super.key});
  @override
  State<CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<CardSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: const Color(0xFFEEF2F9), borderRadius: BorderRadius.circular(7)));

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AC.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(52, 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bar(double.infinity, 16),
                const SizedBox(height: 10),
                _bar(170, 13),
                const SizedBox(height: 8),
                _bar(120, 13),
                const SizedBox(height: 14),
                Row(children: [_bar(90, 30), const SizedBox(width: 8), _bar(80, 30)]),
              ]),
            ),
          ]),
        ),
      );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), margin: const EdgeInsets.fromLTRB(24, 0, 24, 96), duration: const Duration(milliseconds: 2200)));
}

/// Round white icon button with a light border (header actions on Alerts / Messages).
class RoundIcon extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final double size;
  const RoundIcon({super.key, required this.icon, this.onTap, this.size = 42});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFE6EBF2))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Center(child: Svg(icon, size: 20, color: AC.ink2))),
        ),
      );
}
