import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../../shared/models/models.dart';

String money(num value) => NumberFormat.currency(
  symbol: 'Rs. ',
  decimalDigits: value % 1 == 0 ? 0 : 2,
).format(value);
String prettyDate(DateTime value) =>
    DateFormat('EEE, d MMM yyyy • h:mm a').format(value);

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF5B3CF5), Color(0xFF8C45F7), Color(0xFFD845D8)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
      ),
    ),
  );
}

class AsyncPane<T> extends StatelessWidget {
  const AsyncPane({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
  });
  final AsyncSnapshotLike<T> value;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (value.error != null) {
      return ErrorState(message: value.error.toString(), onRetry: onRetry);
    }
    final data = value.data as T;
    if (data is Iterable && data.isEmpty) {
      return EmptyState(message: emptyMessage);
    }
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

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_activity_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 54,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Something went wrong',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = switch (s) {
      'approved' ||
      'paid' ||
      'confirmed' ||
      'valid' ||
      'active' ||
      'completed' => Colors.green,
      'pending' || 'held' => Colors.orange,
      'used' => Colors.blueGrey,
      'cancelled' || 'rejected' || 'suspended' || 'invalid' => Colors.red,
      'refunded' => Colors.purple,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottomNavigationBar,
    this.floatingActionButton,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: child),
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
  );
}

class CompactFilterDropdown<T> extends StatelessWidget {
  const CompactFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? .18 : .05,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key, required this.business, required this.onTap});
  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: business.logoUrl == null
                  ? null
                  : NetworkImage(business.logoUrl!),
              child: business.logoUrl == null
                  ? const Icon(Icons.storefront)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [business.city, business.address]
                        .whereType<String>()
                        .where((e) => e.isNotEmpty)
                        .join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                      Text(
                        ' ${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});
  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingArtwork(listing: listing),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (listing.eventType != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      listing.eventType!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
                if (listing.locationText != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 17),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.locationText!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ListingArtwork extends StatelessWidget {
  const ListingArtwork({
    super.key,
    required this.listing,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
  });

  final Listing listing;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final icon = _listingIcon(listing);
    final gradient = _listingGradient(listing);
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child:
            ticketHubEventBanner(listing) == null &&
                listing.posterUrl != null &&
                listing.posterUrl!.trim().isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    listing.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _assetArtwork(context, icon, gradient),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .35),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _assetArtwork(context, icon, gradient),
      ),
    );
  }

  Widget _assetArtwork(
    BuildContext context,
    IconData icon,
    List<Color> gradient,
  ) {
    final assetPath = listingPosterAsset(listing);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackArtwork(context, icon, gradient),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: .18)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackArtwork(
    BuildContext context,
    IconData icon,
    List<Color> gradient,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -10,
            child: Icon(
              icon,
              size: 116,
              color: Colors.white.withValues(alpha: .10),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -18,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Live tickets',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .22),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.eventType ?? 'Event',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover • Book • Enjoy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? ticketHubEventBanner(Listing listing) {
  final title = listing.title.trim().toLowerCase();
  return _eventBannerByTitle[title];
}

const _eventBannerByTitle = <String, String>{
  'adventure park day pass': 'assets/images/event_adventure_park_day_pass.webp',
  'startup networking evening':
      'assets/images/event_startup_networking_evening.webp',
  'flutter app workshop': 'assets/images/event_flutter_app_workshop.webp',
  'midnight horizon': 'assets/images/event_midnight_horizon.webp',
  'tech conference day pass':
      'assets/images/event_tech_conference_day_pass.webp',
  'capital football clash': 'assets/images/event_capital_football_clash.webp',
  'the silent stage': 'assets/images/event_the_silent_stage.webp',
  'islamabad city food walk':
      'assets/images/event_islamabad_city_food_walk.webp',
  'neon nights live': 'assets/images/event_neon_nights_live.webp',
  'autumn food festival': 'assets/images/event_autumn_food_festival.webp',
  'digital marketing bootcamp':
      'assets/images/event_digital_marketing_bootcamp.webp',
  'margalla sunrise hike': 'assets/images/event_margalla_sunrise_hike.webp',
  'the last signal': 'assets/images/event_the_last_signal.webp',
  'national basketball night':
      'assets/images/event_national_basketball_night.webp',
  'midnight premiere': 'assets/images/event_midnight_premiere.webp',
  'comedy night live': 'assets/images/event_comedy_night_live.webp',
  'family animation weekend':
      'assets/images/event_family_animation_weekend.webp',
  'night safari experience': 'assets/images/event_night_safari_experience.webp',
  'director q&a night': 'assets/images/event_director_q_a_night.webp',
  'acoustic under the stars':
      'assets/images/event_acoustic_under_the_stars.webp',
  'career fair entry': 'assets/images/event_career_fair_entry.webp',
  'islamabad live 2026': 'assets/images/event_islamabad_live_2026.webp',
  'creative expo 2026': 'assets/images/event_creative_expo_2026.webp',
  'acoustic sunset': 'assets/images/event_acoustic_sunset.webp',
  'photography masterclass': 'assets/images/event_photography_masterclass.webp',
  'capital derby': 'assets/images/event_capital_derby.webp',
  'weekend basketball cup': 'assets/images/event_weekend_basketball_cup.webp',
  'weekend cricket showcase':
      'assets/images/event_weekend_cricket_showcase.webp',
  'pottery for beginners': 'assets/images/event_pottery_for_beginners.webp',
  'classic stories reimagined':
      'assets/images/event_classic_stories_reimagined.webp',
  'build your first robot': 'assets/images/event_build_your_first_robot.webp',
  'water fun weekend': 'assets/images/event_water_fun_weekend.webp',
  'adventure day pass': 'assets/images/event_adventure_day_pass.webp',
  'fusion beats festival': 'assets/images/event_fusion_beats_festival.webp',
  'zipline experience': 'assets/images/event_zipline_experience.webp',
  'pottery & tea evening': 'assets/images/event_pottery_tea_evening.webp',
  'family night festival': 'assets/images/event_family_night_festival.webp',
  'community charity gala': 'assets/images/event_community_charity_gala.webp',
};

String listingPosterAsset(Listing listing) {
  final eventBanner = ticketHubEventBanner(listing);
  if (eventBanner != null) return eventBanner;
  final haystack =
      '${listing.title} ${listing.eventType ?? ''} ${listing.categoryId ?? ''}'
          .toLowerCase();
  if (haystack.contains('cinema') || haystack.contains('movie')) {
    return 'assets/images/poster_cinema.png';
  }
  if (haystack.contains('theatre') ||
      haystack.contains('drama') ||
      haystack.contains('comedy')) {
    return 'assets/images/poster_theatre.png';
  }
  if (haystack.contains('concert') ||
      haystack.contains('music') ||
      haystack.contains('acoustic') ||
      haystack.contains('beats')) {
    return 'assets/images/poster_concerts.png';
  }
  if (haystack.contains('sport') ||
      haystack.contains('football') ||
      haystack.contains('basketball') ||
      haystack.contains('cricket')) {
    return 'assets/images/poster_sports.png';
  }
  if (haystack.contains('workshop') ||
      haystack.contains('masterclass') ||
      haystack.contains('bootcamp')) {
    return 'assets/images/poster_workshops.png';
  }
  if (haystack.contains('experience') ||
      haystack.contains('hike') ||
      haystack.contains('food') ||
      haystack.contains('walk') ||
      haystack.contains('pottery')) {
    return 'assets/images/poster_experiences.png';
  }
  if (haystack.contains('attraction') ||
      haystack.contains('park') ||
      haystack.contains('safari') ||
      haystack.contains('water')) {
    return 'assets/images/poster_attractions.png';
  }
  if (haystack.contains('conference') ||
      haystack.contains('expo') ||
      haystack.contains('career') ||
      haystack.contains('networking') ||
      haystack.contains('fair') ||
      haystack.contains('gala')) {
    return 'assets/images/poster_other.png';
  }
  if (haystack.contains('festival') || haystack.contains('event')) {
    return 'assets/images/poster_events.png';
  }
  return 'assets/images/poster_other.png';
}

IconData _listingIcon(Listing listing) {
  final haystack =
      '${listing.title} ${listing.eventType ?? ''} ${listing.categoryId ?? ''}'
          .toLowerCase();
  if (haystack.contains('cinema') || haystack.contains('movie')) {
    return Icons.local_movies_rounded;
  }
  if (haystack.contains('theatre') ||
      haystack.contains('drama') ||
      haystack.contains('comedy')) {
    return Icons.theater_comedy_rounded;
  }
  if (haystack.contains('concert') ||
      haystack.contains('music') ||
      haystack.contains('acoustic') ||
      haystack.contains('beats')) {
    return Icons.music_note_rounded;
  }
  if (haystack.contains('sport') ||
      haystack.contains('football') ||
      haystack.contains('basketball') ||
      haystack.contains('cricket')) {
    return Icons.sports_soccer_rounded;
  }
  if (haystack.contains('workshop') ||
      haystack.contains('masterclass') ||
      haystack.contains('bootcamp')) {
    return Icons.school_rounded;
  }
  if (haystack.contains('experience') ||
      haystack.contains('hike') ||
      haystack.contains('walk')) {
    return Icons.explore_rounded;
  }
  if (haystack.contains('food')) return Icons.restaurant_rounded;
  if (haystack.contains('attraction') ||
      haystack.contains('park') ||
      haystack.contains('safari')) {
    return Icons.attractions_rounded;
  }
  if (haystack.contains('conference') ||
      haystack.contains('expo') ||
      haystack.contains('career') ||
      haystack.contains('networking')) {
    return Icons.event_note_rounded;
  }
  return Icons.confirmation_number_rounded;
}

List<Color> _listingGradient(Listing listing) {
  final haystack =
      '${listing.title} ${listing.eventType ?? ''} ${listing.categoryId ?? ''}'
          .toLowerCase();
  if (haystack.contains('cinema') || haystack.contains('movie')) {
    return const [Color(0xFF5B3CF5), Color(0xFF3E2A92)];
  }
  if (haystack.contains('concert') || haystack.contains('music')) {
    return const [Color(0xFFD845D8), Color(0xFF5B3CF5)];
  }
  if (haystack.contains('sport') ||
      haystack.contains('football') ||
      haystack.contains('cricket') ||
      haystack.contains('basketball')) {
    return const [Color(0xFF0F9D58), Color(0xFF155D3B)];
  }
  if (haystack.contains('workshop') ||
      haystack.contains('masterclass') ||
      haystack.contains('bootcamp')) {
    return const [Color(0xFFFF8C42), Color(0xFFE25D2A)];
  }
  if (haystack.contains('attraction') ||
      haystack.contains('park') ||
      haystack.contains('safari')) {
    return const [Color(0xFF00A6A6), Color(0xFF0F6B6E)];
  }
  if (haystack.contains('experience') ||
      haystack.contains('hike') ||
      haystack.contains('food') ||
      haystack.contains('walk')) {
    return const [Color(0xFFFF6B4A), Color(0xFFB53A27)];
  }
  return const [AppColors.primary, Color(0xFF6B57E8)];
}
