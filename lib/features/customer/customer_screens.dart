import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final businesses = ref.watch(homeBusinessesProvider);
    final listings = ref.watch(featuredListingsProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeBusinessesProvider);
          ref.invalidate(featuredListingsProvider);
          ref.invalidate(categoriesProvider);
          await ref.read(homeBusinessesProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: profile.when(
                data: (value) => Text(
                  'Hello, ${value?.fullName.split(' ').first ?? 'there'} 👋',
                ),
                loading: () => const Text('TicketHub'),
                error: (_, _) => const Text('TicketHub'),
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  onPressed: () => context.push('/profile'),
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InkWell(
                  onTap: () => context.push('/search'),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search events, businesses, experiences...',
                          ),
                        ),
                        Icon(Icons.tune),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _HomePromoBanners()),
            const SliverToBoxAdapter(child: SectionHeader('Categories')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 90,
                child: categories.when(
                  data: (data) => ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = data[index];
                      return ActionChip(
                        avatar: const Icon(
                          Icons.local_activity_outlined,
                          size: 18,
                        ),
                        label: Text(category.name),
                        onPressed: () => context.push(
                          '/category/${category.id}?name=${Uri.encodeComponent(category.name)}',
                        ),
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader('Featured Businesses'),
            ),
            SliverToBoxAdapter(
              child: businesses.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const EmptyState(
                      message: 'No approved businesses yet.',
                    );
                  }
                  final shown = data.take(8).toList();
                  return SizedBox(
                    height: 150,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 320,
                        child: BusinessCard(
                          business: shown[index],
                          onTap: () =>
                              context.push('/business/${shown[index].id}'),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(message: '$e'),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Featured Events')),
            listings.when(
              data: (data) {
                if (data.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyState(
                      message: 'Featured listings will appear here.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => ListingCard(
                      listing: data[index],
                      onTap: () => context.push('/listing/${data[index].id}'),
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SliverToBoxAdapter(child: ErrorState(message: '$e')),
            ),
            const _HomeDiscoverySection(
              title: 'Popular Tickets',
              sort: 'Popular',
            ),
            const _HomeDiscoverySection(
              title: 'Upcoming Events',
              sort: 'Upcoming',
            ),
            const _HomeDiscoverySection(
              title: 'Recommended For You',
              sort: 'Highest Rated',
              bottomPadding: 120,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.push('/search');
          if (index == 2) context.push('/my-tickets');
          if (index == 3) context.push('/profile');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomePromoBanners extends StatelessWidget {
  const _HomePromoBanners();

  @override
  Widget build(BuildContext context) {
    final banners = const [
      _BannerData(
        assetPath: 'assets/images/home_banner_live_events.png',
        title: 'Live Events This Week',
        subtitle: 'Concerts, sports and shows ready to book now.',
      ),
      _BannerData(
        assetPath: 'assets/images/home_banner_family_fun.png',
        title: 'Family Fun & Attractions',
        subtitle: 'Find cinemas, parks and exciting attractions.',
      ),
      _BannerData(
        assetPath: 'assets/images/home_banner_learn_explore.png',
        title: 'Learn, Explore, Experience',
        subtitle: 'Workshops, tours and unique activities in one place.',
      ),
    ];

    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return SizedBox(
            width: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(banner.assetPath, fit: BoxFit.cover),
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
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          banner.subtitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerData {
  const _BannerData({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;
}

class _HomeDiscoverySection extends ConsumerWidget {
  const _HomeDiscoverySection({
    required this.title,
    required this.sort,
    this.bottomPadding = 16,
  });

  final String title;
  final String sort;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title,
          action: TextButton(
            onPressed: () => context.push('/search'),
            child: const Text('See all'),
          ),
        ),
        FutureBuilder<List<ListingSearchResult>>(
          future: ref
              .read(repositoryProvider)
              .searchListings(sort: sort, limit: 6),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorState(message: '${snapshot.error}'),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Nothing to show yet.'),
              );
            }
            return SizedBox(
              height: 344,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListingCard(
                          listing: item.listing,
                          onTap: () =>
                              context.push('/listing/${item.listing.id}'),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${item.minPrice == null ? 'Price TBA' : 'From ${money(item.minPrice!)}'} • ${item.remaining} left',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        SizedBox(height: bottomPadding),
      ],
    ),
  );
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final queryController = TextEditingController();
  final businessController = TextEditingController();
  final locationController = TextEditingController();
  final eventTypeController = TextEditingController();
  String? categoryId;
  String sort = 'Newest';
  bool availableOnly = true;
  bool priceFilterEnabled = false;
  RangeValues priceRange = const RangeValues(0, 10000);
  DateTimeRange? dateRange;
  bool loading = false;
  Object? error;
  List<ListingSearchResult> listings = [];
  List<Business> businesses = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_search);
  }

  @override
  void dispose() {
    queryController.dispose();
    businessController.dispose();
    locationController.dispose();
    eventTypeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final listingResult = await repo.searchListings(
        query: queryController.text,
        businessQuery: businessController.text,
        categoryId: categoryId,
        location: locationController.text,
        startDate: dateRange?.start,
        endDate: dateRange == null
            ? null
            : DateTime(
                dateRange!.end.year,
                dateRange!.end.month,
                dateRange!.end.day,
                23,
                59,
                59,
              ),
        minPrice: priceFilterEnabled ? priceRange.start : null,
        maxPrice: priceFilterEnabled ? priceRange.end : null,
        eventType: eventTypeController.text,
        availableOnly: availableOnly,
        sort: sort,
      );
      final businessResult = await repo.businesses(
        search: queryController.text.isNotEmpty
            ? queryController.text
            : businessController.text,
        categoryId: categoryId,
        city: locationController.text,
      );
      if (!mounted) return;
      setState(() {
        listings = listingResult;
        businesses = businessResult;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openFilters() async {
    var tempRange = priceRange;
    var tempPriceEnabled = priceFilterEnabled;
    var tempAvailable = availableOnly;
    var tempDateRange = dateRange;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: businessController,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location / city',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eventTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Event type',
                    hintText: 'Concert, workshop, match...',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDateRange: tempDateRange,
                    );
                    if (picked != null) {
                      setSheetState(() => tempDateRange = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    tempDateRange == null
                        ? 'Any date'
                        : '${tempDateRange!.start.day}/${tempDateRange!.start.month}/${tempDateRange!.start.year} – ${tempDateRange!.end.day}/${tempDateRange!.end.month}/${tempDateRange!.end.year}',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: tempPriceEnabled,
                  onChanged: (value) =>
                      setSheetState(() => tempPriceEnabled = value),
                  title: const Text('Filter by price'),
                  subtitle: Text(
                    '${money(tempRange.start)} – ${money(tempRange.end)}',
                  ),
                ),
                if (tempPriceEnabled)
                  RangeSlider(
                    values: tempRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      money(tempRange.start),
                      money(tempRange.end),
                    ),
                    onChanged: (value) =>
                        setSheetState(() => tempRange = value),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: tempAvailable,
                  onChanged: (value) =>
                      setSheetState(() => tempAvailable = value),
                  title: const Text('Available tickets only'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          businessController.clear();
                          locationController.clear();
                          eventTypeController.clear();
                          setSheetState(() {
                            tempDateRange = null;
                            tempPriceEnabled = false;
                            tempRange = const RangeValues(0, 10000);
                            tempAvailable = true;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            dateRange = tempDateRange;
                            priceFilterEnabled = tempPriceEnabled;
                            priceRange = tempRange;
                            availableOnly = tempAvailable;
                          });
                          Navigator.pop(sheetContext);
                          _search();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get activeFilterCount {
    var count = 0;
    if (businessController.text.trim().isNotEmpty) count++;
    if (locationController.text.trim().isNotEmpty) count++;
    if (eventTypeController.text.trim().isNotEmpty) count++;
    if (dateRange != null) count++;
    if (priceFilterEnabled) count++;
    if (!availableOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Search',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: queryController,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search events or services',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 360;
                    final categoryDropdown = FutureBuilder<List<Category>>(
                      future: ref.read(repositoryProvider).categories(),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return CompactFilterDropdown<String?>(
                          label: 'Category',
                          leading: Icons.grid_view_rounded,
                          value: categoryId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All categories'),
                            ),
                            ...categories.map(
                              (e) => DropdownMenuItem<String?>(
                                value: e.id,
                                child: Text(e.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => categoryId = value);
                            _search();
                          },
                        );
                      },
                    );
                    final sortDropdown = CompactFilterDropdown<String>(
                      label: 'Sort',
                      leading: Icons.swap_vert_rounded,
                      value: sort,
                      items:
                          const [
                                'Popular',
                                'Newest',
                                'Price Low-High',
                                'Price High-Low',
                                'Highest Rated',
                                'Upcoming',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => sort = value ?? sort);
                        _search();
                      },
                    );
                    if (stacked) {
                      return Column(
                        children: [
                          categoryDropdown,
                          const SizedBox(height: 10),
                          sortDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: categoryDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: sortDropdown),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeFilterCount == 0
                              ? 'More filters'
                              : 'More filters ($activeFilterCount active)',
                        ),
                        if (activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$activeFilterCount',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: error != null
                ? ErrorState(message: '$error', onRetry: _search)
                : RefreshIndicator(
                    onRefresh: _search,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        if (businesses.isNotEmpty) ...[
                          const SectionHeader('Businesses'),
                          ...businesses.map(
                            (business) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: BusinessCard(
                                business: business,
                                onTap: () =>
                                    context.push('/business/${business.id}'),
                              ),
                            ),
                          ),
                        ],
                        if (listings.isNotEmpty) ...[
                          const SectionHeader('Listings'),
                          ...listings.map(
                            (result) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListingCard(
                                    listing: result.listing,
                                    onTap: () => context.push(
                                      '/listing/${result.listing.id}',
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      7,
                                      12,
                                      0,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Chip(label: Text(result.businessName)),
                                        if (result.minPrice != null)
                                          Chip(
                                            label: Text(
                                              'From ${money(result.minPrice!)}',
                                            ),
                                          ),
                                        if (result.nextStart != null)
                                          Chip(
                                            label: Text(
                                              prettyDate(result.nextStart!),
                                            ),
                                          ),
                                        Chip(
                                          label: Text(
                                            '${result.remaining} remaining',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (!loading && businesses.isEmpty && listings.isEmpty)
                          const SizedBox(
                            height: 320,
                            child: EmptyState(
                              message: 'No matching results. Try changing your search or filters.',
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.id, required this.name});
  final String id;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: name,
      child: FutureBuilder<List<Listing>>(
        future: ref.read(repositoryProvider).listings(categoryId: id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const EmptyState(
              message: 'No active listings in this category yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => ListingCard(
              listing: data[index],
              onTap: () => context.push('/listing/${data[index].id}'),
            ),
          );
        },
      ),
    );
  }
}

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  const BusinessDetailsScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BusinessDetailsScreen> createState() => _BusinessDetailsState();
}

class _BusinessDetailsState extends ConsumerState<BusinessDetailsScreen> {
  bool? favorite;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        repo.business(widget.id),
        repo.listings(businessId: widget.id),
        repo.reviewsForBusiness(widget.id),
        repo.favoriteBusinessIds(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorState(message: '${snapshot.error}'));
        }
        final business = snapshot.data![0] as Business;
        final listings = snapshot.data![1] as List<Listing>;
        final reviews = snapshot.data![2] as List<Review>;
        final favoriteIds = snapshot.data![3] as List<String>;
        favorite ??= favoriteIds.contains(widget.id);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                actions: [
                  IconButton(
                    onPressed: () async {
                      final next = !(favorite ?? false);
                      await repo.toggleFavorite(widget.id, next);
                      if (mounted) setState(() => favorite = next);
                      ref.invalidate(favoriteIdsProvider);
                    },
                    icon: Icon(
                      (favorite ?? false)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: (favorite ?? false) ? Colors.red : null,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: business.coverUrl == null
                      ? Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.storefront, size: 80),
                        )
                      : Image.network(
                          business.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              Text(
                                '★ ${business.ratingAvg.toStringAsFixed(1)} • ${business.ratingCount} reviews',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(business.description ?? 'No description provided.'),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        [business.address, business.city]
                            .whereType<String>()
                            .where((e) => e.isNotEmpty)
                            .join(', '),
                      ),
                    ),
                    if (business.phone != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined),
                        title: Text(business.phone!),
                      ),
                    const SectionHeader('Upcoming Events'),
                    ...listings.map(
                      (listing) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListingCard(
                          listing: listing,
                          onTap: () => context.push('/listing/${listing.id}'),
                        ),
                      ),
                    ),
                    const SectionHeader('Reviews'),
                    if (reviews.isEmpty) const Text('No visible reviews yet.'),
                    ...reviews.map(
                      (review) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${'★' * review.rating}${'☆' * (5 - review.rating)}  ${review.customerName ?? 'Customer'}',
                        ),
                        subtitle: Text(review.comment),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ListingDetailsScreen extends ConsumerWidget {
  const ListingDetailsScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([repo.listing(id), repo.schedules(id)]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorState(message: '${snapshot.error}'));
        }
        final listing = snapshot.data![0] as Listing;
        final schedules = snapshot.data![1] as List<Schedule>;
        return Scaffold(
          appBar: AppBar(title: Text(listing.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ListingArtwork(
                  listing: listing,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                listing.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (listing.eventType != null)
                    Chip(label: Text(listing.eventType!)),
                  if (listing.locationText != null)
                    Chip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(listing.locationText!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(listing.description ?? ''),
              const SectionHeader('Choose date & time'),
              if (schedules.isEmpty)
                const EmptyState(
                  message: 'No bookable schedules are available.',
                ),
              ...schedules.map(
                (schedule) => Card(
                  child: ListTile(
                    title: Text(prettyDate(schedule.startsAt)),
                    subtitle: Text(
                      '${schedule.venueOrHall ?? listing.locationText ?? 'Venue'} • Limit ${schedule.bookingLimitPerUser}',
                    ),
                    trailing: FilledButton(
                      onPressed: () => context.push(
                        schedule.isSeated
                            ? '/seat-select/${schedule.id}'
                            : '/ticket-select/${schedule.id}',
                      ),
                      child: Text(
                        schedule.isSeated ? 'Select seats' : 'Tickets',
                      ),
                    ),
                  ),
                ),
              ),
              if (listing.terms != null && listing.terms!.isNotEmpty) ...[
                const SectionHeader('Terms & Conditions'),
                Text(listing.terms!),
              ],
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }
}

class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTicketsProvider);
    return AppShell(
      title: 'My Tickets',
      child: async.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(
              message: 'You have no digital tickets yet.',
            );
          }
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Used'),
                    Tab(text: 'Cancelled'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ticketList(
                        context,
                        data
                            .where((e) => e.status == TicketStatus.valid)
                            .toList(),
                      ),
                      _ticketList(
                        context,
                        data
                            .where((e) => e.status == TicketStatus.used)
                            .toList(),
                      ),
                      _ticketList(
                        context,
                        data
                            .where(
                              (e) =>
                                  e.status == TicketStatus.cancelled ||
                                  e.status == TicketStatus.refunded,
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: '$e'),
      ),
    );
  }

  Widget _ticketList(BuildContext context, List<DigitalTicket> data) {
    if (data.isEmpty) {
      return const EmptyState(message: 'No tickets in this tab.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = data[index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/ticket/${ticket.id}'),
            leading: const CircleAvatar(child: Icon(Icons.qr_code_2)),
            title: Text(ticket.eventTitle ?? ticket.ticketCode),
            subtitle: Text(
              [
                ticket.businessName,
                ticket.startsAt == null ? null : prettyDate(ticket.startsAt!),
              ].whereType<String>().join('\n'),
            ),
            trailing: StatusChip(ticket.status.name),
          ),
        );
      },
    );
  }
}

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBookingsProvider);
    return AppShell(
      title: 'Booking History',
      child: async.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(message: 'No bookings yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final booking = data[index];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/booking/${booking.id}'),
                  title: Text(booking.bookingCode),
                  subtitle: Text(
                    '${booking.customerName}\n${money(booking.totalAmount)} • ${prettyDate(booking.createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: StatusChip(booking.status.name),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: '$e'),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return AppShell(
      title: 'Notifications',
      child: async.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(message: 'No notifications yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      item.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead
                          ? FontWeight.w500
                          : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text('${item.body}\n${prettyDate(item.createdAt)}'),
                  isThreeLine: true,
                  onTap: () async {
                    await ref
                        .read(repositoryProvider)
                        .markNotificationRead(item.id);
                    ref.invalidate(notificationsProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: '$e'),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentProfileProvider);
    return AppShell(
      title: 'Account',
      child: async.when(
        data: (profile) {
          if (profile == null) {
            return const EmptyState(message: 'Please sign in.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(
                radius: 42,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? const Icon(Icons.person, size: 42)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                profile.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                profile.role.name.toUpperCase(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _edit(context, ref, profile),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Personal Information'),
              ),
              const SizedBox(height: 24),
              _link(
                context,
                Icons.confirmation_number_outlined,
                'My Tickets',
                '/my-tickets',
              ),
              _link(context, Icons.history, 'Booking History', '/history'),
              _link(
                context,
                Icons.favorite_border,
                'Favorite Businesses',
                '/favorites',
              ),
              _link(
                context,
                Icons.receipt_long_outlined,
                'Payment History',
                '/payments',
              ),
              _link(
                context,
                Icons.notifications_outlined,
                'Notifications',
                '/notifications',
              ),
              _link(context, Icons.settings_outlined, 'Settings', '/settings'),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(repositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: '$e'),
      ),
    );
  }

  Widget _link(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final name = TextEditingController(text: profile.fullName);
    final phone = TextEditingController(text: profile.phone ?? '');
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Personal Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await ref
          .read(repositoryProvider)
          .updateProfile(fullName: name.text, phone: phone.text);
      ref.invalidate(currentProfileProvider);
    }
    name.dispose();
    phone.dispose();
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Favorites',
      child: FutureBuilder<List<Business>>(
        future: ref.read(repositoryProvider).favoriteBusinesses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const EmptyState(
              message: 'Favorite businesses you save will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => BusinessCard(
              business: data[index],
              onTap: () => context.push('/business/${data[index].id}'),
            ),
          );
        },
      ),
    );
  }
}

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Payment History',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(repositoryProvider).paymentHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const EmptyState(message: 'No payment records yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = data[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.payments_outlined),
                  ),
                  title: Text(
                    '${row['method']} • ${money((row['amount'] as num?) ?? 0)}',
                  ),
                  subtitle: Text(
                    'Booking: ${row['booking_id']}\n${row['provider_ref'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: StatusChip('${row['status']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool reducedMotion = false;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Booking and event reminders'),
            value: notifications,
            onChanged: (value) => setState(() => notifications = value),
          ),
          SwitchListTile(
            title: const Text('Reduced motion'),
            subtitle: const Text('Limit non-essential animations'),
            value: reducedMotion,
            onChanged: (value) => setState(() => reducedMotion = value),
          ),
          const ListTile(
            leading: Icon(Icons.brightness_6_outlined),
            title: Text('Appearance'),
            subtitle: Text('Uses your device light/dark setting'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Terms & conditions'),
          ),
          const ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Help & support'),
          ),
        ],
      ),
    );
  }
}
