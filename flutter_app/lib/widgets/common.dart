import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class CompanyAvatar extends StatelessWidget {
  final String name;
  final String logo;
  final double size;
  const CompanyAvatar({super.key, required this.name, this.logo = '', this.size = 48});

  static const _tints = [Color(0xFF1D4F93), Color(0xFF0F7A4D), Color(0xFF7B3FA0), Color(0xFFB26A00), Color(0xFF00838F), Color(0xFFC2185B)];

  @override
  Widget build(BuildContext context) {
    final letters = name.trim().isEmpty
        ? 'A'
        : name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final tint = _tints[name.hashCode.abs() % _tints.length];
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(letters, style: TextStyle(color: tint, fontWeight: FontWeight.w800, fontSize: size * 0.34)),
    );
    if (logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, errorWidget: (_, __, ___) => fallback, placeholder: (_, __) => fallback),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color = AC.sub, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? badge;
  const JobCard({super.key, required this.job, required this.onTap, this.trailing, this.badge});

  @override
  Widget build(BuildContext context) {
    final meta = [job.location, job.type].where((s) => s.isNotEmpty).join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AC.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CompanyAvatar(name: job.company, logo: job.logo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 3),
                if (job.company.isNotEmpty)
                  Text(job.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.sub, fontSize: 13.5)),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (badge != null) Pill(badge!, color: AC.blue),
                  if (job.urgent) const Pill('Urgent', color: AC.red, icon: Icons.bolt_rounded),
                  if (job.salary.isNotEmpty) Pill(job.salary, color: AC.green),
                  if (job.expired) const Pill('Closed', color: AC.red) else Pill(job.posted, color: AC.sub),
                ]),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AC.blue.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AC.blue),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AC.sub, fontSize: 14.5, height: 1.45)),
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
      EmptyState(icon: Icons.wifi_off_rounded, title: 'Couldn’t load this', text: message, action: 'Try again', onAction: onRetry);
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

  Widget _bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: AC.line, borderRadius: BorderRadius.circular(8)));

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AC.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(48, 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bar(double.infinity, 16),
                const SizedBox(height: 8),
                _bar(160, 13),
                const SizedBox(height: 8),
                _bar(120, 13),
              ]),
            ),
          ]),
        ),
      );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
