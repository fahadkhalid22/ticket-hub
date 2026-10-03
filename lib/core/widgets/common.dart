import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/models/models.dart';

String money(num value) => NumberFormat.currency(symbol: 'Rs. ', decimalDigits: value % 1 == 0 ? 0 : 2).format(value);
String prettyDate(DateTime value) => DateFormat('EEE, d MMM yyyy • h:mm a').format(value);

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF5B3CF5), Color(0xFF8C45F7), Color(0xFFD845D8)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
        icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
      ),
    ),
  );
}

class AsyncPane<T> extends StatelessWidget {
  const AsyncPane({super.key, required this.value, required this.builder, this.emptyMessage = 'Nothing here yet.', this.onRetry});
  final AsyncSnapshotLike<T> value;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final VoidCallback? onRetry;
  @override Widget build(BuildContext context) {
    if (value.loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    if (value.error != null) return ErrorState(message: value.error.toString(), onRetry: onRetry);
    final data = value.data as T;
    if (data is Iterable && data.isEmpty) return EmptyState(message: emptyMessage);
    return builder(data);
  }
}

class AsyncSnapshotLike<T> {
  const AsyncSnapshotLike({this.data, this.error, this.loading = false});
  final T? data;
  final Object? error;
  final bool loading;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.action});
  final String message;
  final Widget? action;
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.local_activity_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16), Text(message, textAlign: TextAlign.center), if (action != null) ...[const SizedBox(height: 16), action!],
    ]),
  ));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, size: 54, color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 12), const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center),
      if (onRetry != null) ...[const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))],
    ]),
  ));
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = switch (s) {
      'approved' || 'paid' || 'confirmed' || 'valid' || 'active' || 'completed' => Colors.green,
      'pending' || 'held' => Colors.orange,
      'used' => Colors.blueGrey,
      'cancelled' || 'rejected' || 'suspended' || 'invalid' => Colors.red,
      'refunded' => Colors.purple,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(label: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)), backgroundColor: color.withValues(alpha: .1), side: BorderSide.none, visualDensity: VisualDensity.compact);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), ?action]),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child, this.actions = const [], this.bottomNavigationBar, this.floatingActionButton});
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: child),
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
  );
}

class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key, required this.business, required this.onTap});
  final Business business;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(20), onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      CircleAvatar(radius: 28, backgroundImage: business.logoUrl == null ? null : NetworkImage(business.logoUrl!), child: business.logoUrl == null ? const Icon(Icons.storefront) : null),
      const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(business.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4), Text([business.city, business.address].whereType<String>().where((e) => e.isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6), Row(children: [const Icon(Icons.star_rounded, size: 18, color: Colors.amber), Text(' ${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount})')]),
      ])), const Icon(Icons.chevron_right_rounded),
    ])),
  ));
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});
  final Listing listing;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(20), onTap: onTap,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: AspectRatio(aspectRatio: 16/8, child: listing.posterUrl == null ? Container(color: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.local_activity, size: 48)) : Image.network(listing.posterUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined))))),
      Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(listing.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (listing.eventType != null) ...[const SizedBox(height: 4), Text(listing.eventType!)],
        if (listing.locationText != null) ...[const SizedBox(height: 6), Row(children: [const Icon(Icons.location_on_outlined, size: 17), const SizedBox(width: 4), Expanded(child: Text(listing.locationText!, overflow: TextOverflow.ellipsis))])],
      ])),
    ]),
  ));
}
