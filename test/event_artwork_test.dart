import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickethub/core/widgets/common.dart';
import 'package:tickethub/shared/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventArtwork = {
    'Adventure Park Day Pass':
        'assets/images/event_adventure_park_day_pass.webp',
    'Startup Networking Evening':
        'assets/images/event_startup_networking_evening.webp',
    'Flutter App Workshop': 'assets/images/event_flutter_app_workshop.webp',
    'Midnight Horizon': 'assets/images/event_midnight_horizon.webp',
    'Tech Conference Day Pass':
        'assets/images/event_tech_conference_day_pass.webp',
    'Capital Football Clash': 'assets/images/event_capital_football_clash.webp',
    'The Silent Stage': 'assets/images/event_the_silent_stage.webp',
    'Islamabad City Food Walk':
        'assets/images/event_islamabad_city_food_walk.webp',
    'Neon Nights Live': 'assets/images/event_neon_nights_live.webp',
    'Autumn Food Festival': 'assets/images/event_autumn_food_festival.webp',
    'Digital Marketing Bootcamp':
        'assets/images/event_digital_marketing_bootcamp.webp',
    'Margalla Sunrise Hike': 'assets/images/event_margalla_sunrise_hike.webp',
    'The Last Signal': 'assets/images/event_the_last_signal.webp',
    'National Basketball Night':
        'assets/images/event_national_basketball_night.webp',
    'Midnight Premiere': 'assets/images/event_midnight_premiere.webp',
    'Comedy Night Live': 'assets/images/event_comedy_night_live.webp',
    'Family Animation Weekend':
        'assets/images/event_family_animation_weekend.webp',
    'Night Safari Experience':
        'assets/images/event_night_safari_experience.webp',
    'Director Q&A Night': 'assets/images/event_director_q_a_night.webp',
    'Acoustic Under the Stars':
        'assets/images/event_acoustic_under_the_stars.webp',
    'Career Fair Entry': 'assets/images/event_career_fair_entry.webp',
    'Islamabad Live 2026': 'assets/images/event_islamabad_live_2026.webp',
    'Creative Expo 2026': 'assets/images/event_creative_expo_2026.webp',
    'Acoustic Sunset': 'assets/images/event_acoustic_sunset.webp',
    'Photography Masterclass':
        'assets/images/event_photography_masterclass.webp',
    'Capital Derby': 'assets/images/event_capital_derby.webp',
    'Weekend Basketball Cup': 'assets/images/event_weekend_basketball_cup.webp',
    'Weekend Cricket Showcase':
        'assets/images/event_weekend_cricket_showcase.webp',
    'Pottery for Beginners': 'assets/images/event_pottery_for_beginners.webp',
    'Classic Stories Reimagined':
        'assets/images/event_classic_stories_reimagined.webp',
    'Build Your First Robot': 'assets/images/event_build_your_first_robot.webp',
    'Water Fun Weekend': 'assets/images/event_water_fun_weekend.webp',
    'Adventure Day Pass': 'assets/images/event_adventure_day_pass.webp',
    'Fusion Beats Festival': 'assets/images/event_fusion_beats_festival.webp',
    'Zipline Experience': 'assets/images/event_zipline_experience.webp',
    'Pottery & Tea Evening': 'assets/images/event_pottery_tea_evening.webp',
    'Family Night Festival': 'assets/images/event_family_night_festival.webp',
    'Community Charity Gala': 'assets/images/event_community_charity_gala.webp',
  };

  test('every seeded event maps to a bundled banner image', () async {
    for (final entry in eventArtwork.entries) {
      final listing = Listing(
        id: entry.key,
        businessId: 'demo-business',
        title: entry.key,
        status: ListingStatus.active,
      );

      expect(ticketHubEventBanner(listing), entry.value);
      expect(
        (await rootBundle.load(entry.value)).lengthInBytes,
        greaterThan(0),
      );
    }
  });

  testWidgets('home discovery tile fits without vertical overflow', (
    tester,
  ) async {
    const listing = Listing(
      id: 'long-card',
      businessId: 'demo-business',
      title: 'A Long Event Title That Wraps Across Two Lines',
      status: ListingStatus.active,
      eventType: 'Workshop',
      locationText: 'A Long Venue Name, Islamabad',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 344,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListingCard(listing: listing, onTap: () {}),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'From Rs. 1,600 • 120 left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
