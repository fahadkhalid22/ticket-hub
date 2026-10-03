import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'TicketHub Admin',
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/admin/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: FutureBuilder<DashboardStats>(
        future: ref.read(repositoryProvider).adminDashboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final data = snapshot.data!;
          final width = MediaQuery.sizeOf(context).width;
          final columns = width >= 1000 ? 4 : 2;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: width >= 700 ? 1.9 : 1.35,
                children: [
                  _AdminKpi('Users', '${data['users']}', Icons.people_alt_outlined),
                  _AdminKpi('Businesses', '${data['businesses']}', Icons.storefront_outlined),
                  _AdminKpi('Events', '${data['events']}', Icons.event_outlined),
                  _AdminKpi('Bookings', '${data['bookings']}', Icons.receipt_long_outlined),
                  _AdminKpi('Tickets Sold', '${data['tickets_sold']}', Icons.confirmation_number_outlined),
                  _AdminKpi('Revenue', money(data['revenue']), Icons.payments_outlined),
                  _AdminKpi('Active Businesses', '${data['active_businesses']}', Icons.verified_outlined),
                  _AdminKpi('Pending', '${data['pending_businesses']}', Icons.hourglass_top_outlined),
                ],
              ),
              const SectionHeader('Platform Activity'),
              SizedBox(
                height: 210,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    barGroups: [
                      _bar(0, data['users'].toDouble()),
                      _bar(1, data['businesses'].toDouble()),
                      _bar(2, data['events'].toDouble()),
                      _bar(3, data['bookings'].toDouble()),
                      _bar(4, data['tickets_sold'].toDouble()),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Management'),
              ...[
                ('Business Approvals', '/admin/businesses', Icons.domain_verification_outlined),
                ('Users', '/admin/users', Icons.people_outline),
                ('Listings', '/admin/listings', Icons.event_note_outlined),
                ('Tickets', '/admin/tickets', Icons.local_activity_outlined),
                ('Bookings', '/admin/bookings', Icons.receipt_long_outlined),
                ('Payments', '/admin/payments', Icons.payments_outlined),
                ('Review Moderation', '/admin/reviews', Icons.reviews_outlined),
                ('Categories', '/admin/categories', Icons.category_outlined),
                ('Reports', '/admin/reports', Icons.analytics_outlined),
                ('Audit Log', '/admin/audit', Icons.history_outlined),
                ('Platform Settings', '/admin/settings', Icons.tune_outlined),
              ].map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(item.$3),
                    title: Text(item.$1),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(item.$2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  BarChartGroupData _bar(int x, double value) {
    return BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: value, width: 18, borderRadius: BorderRadius.circular(6))],
    );
  }
}

class _AdminKpi extends StatelessWidget {
  const _AdminKpi(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  ConsumerState<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(repositoryProvider).adminBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Business Management',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: () => setState(_reload));
          }
          final businesses = snapshot.data ?? const [];
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Pending'),
                    Tab(text: 'Approved'),
                    Tab(text: 'Rejected'),
                    Tab(text: 'Suspended'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: ['pending', 'approved', 'rejected', 'suspended'].map((status) {
                      final filtered = businesses.where((row) => row['status'] == status).toList();
                      if (filtered.isEmpty) return EmptyState(message: 'No $status businesses.');
                      return RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = filtered[index];
                            final profile = row['profiles'];
                            final ownerName = profile is Map ? profile['full_name'] : null;
                            return Card(
                              child: ListTile(
                                title: Text('${row['name'] ?? 'Business'}'),
                                subtitle: Text(
                                  '${row['city'] ?? ''}\nOwner: ${ownerName ?? row['owner_id'] ?? 'Unknown'}',
                                ),
                                isThreeLine: true,
                                leading: StatusChip(status),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Business actions',
                                  onSelected: (value) => _setStatus(
                                    context,
                                    row['id'].toString(),
                                    value,
                                  ),
                                  itemBuilder: (_) => [
                                    if (status != 'approved')
                                      const PopupMenuItem(value: 'approved', child: Text('Approve')),
                                    if (status != 'rejected')
                                      const PopupMenuItem(value: 'rejected', child: Text('Reject')),
                                    if (status != 'suspended')
                                      const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                                    if (status == 'suspended')
                                      const PopupMenuItem(value: 'approved', child: Text('Reactivate')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, String businessId, String status) async {
    String? reason;
    if (status == 'rejected' || status == 'suspended') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(status == 'rejected' ? 'Reject business' : 'Suspend business'),
              content: TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      reason = controller.text.trim();
    }

    try {
      await ref.read(repositoryProvider).setBusinessStatus(businessId, status, reason: reason);
      if (!context.mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Business updated to $status.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Users',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(repositoryProvider).adminUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const EmptyState(message: 'No users found.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = rows[index];
              final name = '${row['full_name'] ?? 'User'}';
              final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(initial)),
                  title: Text(name),
                  subtitle: Text('${row['id']}'),
                  trailing: StatusChip('${row['role'] ?? 'customer'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminTableScreen extends ConsumerWidget {
  const AdminTableScreen({super.key, required this.title, required this.table});

  final String title;
  final String table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: title,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(repositoryProvider).adminRows(table),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return EmptyState(message: 'No $title records.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = rows[index];
              final primary = row['title'] ??
                  row['booking_code'] ??
                  row['ticket_code'] ??
                  row['provider_ref'] ??
                  row['id'];
              final status = row['status'];
              return Card(
                child: ExpansionTile(
                  title: Text('$primary'),
                  subtitle: status == null ? null : Text('$status'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(const JsonEncoder.withIndent('  ').convert(row)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminReviewsScreen extends ConsumerStatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  ConsumerState<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends ConsumerState<AdminReviewsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(repositoryProvider).adminRows('reviews');
  }

  void _reload() {
    setState(() => _future = ref.read(repositoryProvider).adminRows('reviews'));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Review Moderation',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const EmptyState(message: 'No reviews to moderate.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = rows[index];
              final rating = (row['rating'] as num?)?.toInt() ?? 0;
              final hidden = row['is_hidden'] == true;
              return Card(
                child: ListTile(
                  title: Text('${List.filled(rating, '★').join()} ($rating/5)'),
                  subtitle: Text('${row['comment'] ?? ''}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(repositoryProvider).moderateReview(row['id'].toString(), !hidden);
                      _reload();
                    },
                    child: Text(hidden ? 'Restore' : 'Hide'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(repositoryProvider).categories();
  }

  void _reload() {
    setState(() => _future = ref.read(repositoryProvider).categories());
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Categories',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editCategory(context),
        child: const Icon(Icons.add),
      ),
      child: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const EmptyState(message: 'No categories found.');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final category = rows[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(category.name),
                  subtitle: Text(category.slug),
                  trailing: IconButton(
                    tooltip: 'Edit category',
                    onPressed: () => _editCategory(context, current: category),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editCategory(BuildContext context, {Category? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final slug = TextEditingController(text: current?.slug ?? '');
    final icon = TextEditingController(text: current?.icon ?? 'local_activity');
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(current == null ? 'Add Category' : 'Edit Category'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
                const SizedBox(height: 8),
                TextField(controller: icon, decoration: const InputDecoration(labelText: 'Icon key')),
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
    if (!confirmed) return;
    await ref.read(repositoryProvider).upsertCategory(
          id: current?.id,
          name: name.text.trim(),
          slug: slug.text.trim(),
          icon: icon.text.trim(),
          active: true,
          sortOrder: 0,
        );
    _reload();
  }
}

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Reports',
      child: FutureBuilder<DashboardStats>(
        future: ref.read(repositoryProvider).adminDashboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final data = snapshot.data!;
          const metrics = [
            'users',
            'businesses',
            'events',
            'bookings',
            'tickets_sold',
            'revenue',
            'active_businesses',
            'pending_businesses',
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Platform Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Metric')),
                    DataColumn(label: Text('Value')),
                  ],
                  rows: metrics
                      .map(
                        (key) => DataRow(
                          cells: [
                            DataCell(Text(key.replaceAll('_', ' '))),
                            DataCell(Text(key == 'revenue' ? money(data[key]) : '${data[key]}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _fee = TextEditingController();
  final _hold = TextEditingController();
  final _cancel = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(repositoryProvider).platformSettings();
      _fee.text = '${settings['service_fee_percent'] ?? 0}';
      _hold.text = '${settings['hold_minutes'] ?? 10}';
      _cancel.text = '${settings['cancellation_hours'] ?? 24}';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repository = ref.read(repositoryProvider);
      await repository.setPlatformSetting('service_fee_percent', double.tryParse(_fee.text) ?? 0);
      await repository.setPlatformSetting('hold_minutes', int.tryParse(_hold.text) ?? 10);
      await repository.setPlatformSetting('cancellation_hours', int.tryParse(_cancel.text) ?? 24);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _fee.dispose();
    _hold.dispose();
    _cancel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Platform Settings',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Service fee %'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _hold,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hold minutes'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cancel,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cancellation window (hours before start)'),
                ),
                const SizedBox(height: 18),
                GradientButton(label: 'Save Settings', busy: _saving, onPressed: _save),
              ],
            ),
    );
  }
}
