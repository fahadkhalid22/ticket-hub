import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  Future<void> _refresh() async => setState(() {});
  @override Widget build(BuildContext context) => FutureBuilder<Business?>(
    future: ref.read(repositoryProvider).ownerBusiness(),
    builder: (c, b) {
      if (b.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (b.hasError) return Scaffold(body: ErrorState(message: '${b.error}'));
      final business = b.data;
      if (business == null) return Scaffold(appBar: AppBar(title: const Text('Business Owner')), body: EmptyState(message: 'Register your business to start selling tickets.', action: FilledButton(onPressed: () => context.push('/owner/register'), child: const Text('Register Business'))));
      return AppShell(title: business.name, actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: StatusChip(business.status.name)))], child: FutureBuilder<DashboardStats>(future: ref.read(repositoryProvider).ownerDashboard(business.id), builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return ErrorState(message: '${s.error}');
        final d = s.data!;
        return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (business.status == BusinessStatus.suspended) Card(color: Colors.red.withValues(alpha: .08), child: const ListTile(leading: Icon(Icons.warning_amber_rounded, color: Colors.red), title: Text('Business suspended'), subtitle: Text('Public listings are hidden until an admin reactivates the business.'))),
          GridView.count(crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.45, children: [
            _Kpi('Bookings', '${d['bookings']}', Icons.receipt_long_outlined),
            _Kpi('Tickets Sold', '${d['tickets_sold']}', Icons.confirmation_number_outlined),
            _Kpi('Revenue', money(d['revenue']), Icons.payments_outlined),
            _Kpi('Upcoming Events', '${d['upcoming_events']}', Icons.upcoming_outlined),
            _Kpi('Active Listings', '${d['active_listings']}', Icons.event_available_outlined),
            _Kpi('Available Tickets', '${d['available_tickets']}', Icons.inventory_2_outlined),
            _Kpi('Cancelled', '${d['cancelled_bookings']}', Icons.event_busy_outlined),
          ]),
          const SectionHeader('Quick Actions'), Wrap(spacing: 10, runSpacing: 10, children: [FilledButton.icon(onPressed: () => context.push('/owner/listing/new'), icon: const Icon(Icons.add), label: const Text('Add Event / Service')), FilledButton.tonalIcon(onPressed: () => context.push('/owner/scanner'), icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan Tickets')), FilledButton.tonalIcon(onPressed: () => context.push('/owner/listings'), icon: const Icon(Icons.list_alt), label: const Text('Listings'))]),
          const SectionHeader('Revenue Snapshot'), SizedBox(height: 190, child: LineChart(LineChartData(titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), gridData: const FlGridData(show: false), lineBarsData: [LineChartBarData(isCurved: true, spots: [const FlSpot(0, 0), FlSpot(1, (d['revenue'] / 4).toDouble()), FlSpot(2, (d['revenue'] / 2).toDouble()), FlSpot(3, d['revenue'].toDouble())])]))),
          const SizedBox(height: 12), ...[
            ('Business Profile','/owner/profile',Icons.storefront_outlined),('Ticket Management','/owner/listings',Icons.local_activity_outlined),('Inventory / Availability','/owner/inventory',Icons.inventory_2_outlined),('Bookings','/owner/bookings',Icons.receipt_long_outlined),('Sales Analytics','/owner/analytics',Icons.analytics_outlined),('Settings','/owner/settings',Icons.settings_outlined)
          ].map((x)=>Card(child:ListTile(leading:Icon(x.$3),title:Text(x.$1),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push(x.$2))))
        ]));
      }));
    },
  );
}
class _Kpi extends StatelessWidget { const _Kpi(this.label,this.value,this.icon); final String label,value; final IconData icon; @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const Spacer(),Text(value,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),Text(label,style:const TextStyle(fontSize:12))]))); }

class BusinessRegistrationScreen extends ConsumerStatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  ConsumerState<BusinessRegistrationScreen> createState() => _BusinessRegistrationState();
}

class _BusinessRegistrationState extends ConsumerState<BusinessRegistrationScreen> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController();
  final desc = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  String? categoryId;
  String? logo;
  String? cover;
  bool busy = false;

  @override
  void dispose() {
    for (final controller in [name, desc, address, city, phone, email]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String?> pick(String kind) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final uid = ref.read(repositoryProvider).userId!;
    return ref.read(repositoryProvider).uploadImage(
          bytes: bytes,
          bucket: 'business-media',
          path: '$uid/${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
  }

  Future<void> submit() async {
    if (!key.currentState!.validate() || categoryId == null) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).registerBusiness({
        'category_id': categoryId,
        'name': name.text.trim(),
        'logo_url': logo,
        'cover_url': cover,
        'description': desc.text.trim(),
        'address': address.text.trim(),
        'city': city.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business submitted for admin approval.')),
        );
        context.go('/owner/dashboard');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Business Registration',
      child: FutureBuilder<List<Category>>(
        future: ref.read(repositoryProvider).categories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final categories = snapshot.data ?? const <Category>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: key,
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Business name'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Enter business name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                          .toList(),
                      onChanged: (value) => setState(() => categoryId = value),
                      validator: (value) => value == null ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: desc,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description'),
                      validator: (value) => value == null || value.trim().length < 20
                          ? 'Add a helpful description'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter city' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                    const SizedBox(height: 10),
                    TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Business email')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              logo = await pick('logo');
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.image_outlined),
                            label: Text(logo == null ? 'Upload Logo' : 'Logo Selected'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              cover = await pick('cover');
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.wallpaper_outlined),
                            label: Text(cover == null ? 'Upload Cover' : 'Cover Selected'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Submit for Approval',
                        busy: busy,
                        onPressed: submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OwnerProfileScreen extends ConsumerWidget{
  const OwnerProfileScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref)=>AppShell(title:'Business Profile',child:FutureBuilder<Business?>(future:ref.read(repositoryProvider).ownerBusiness(),builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.data==null)return const EmptyState(message:'No business registered.');final b=s.data!;return ListView(padding:const EdgeInsets.all(16),children:[if(b.coverUrl!=null)ClipRRect(borderRadius:BorderRadius.circular(20),child:Image.network(b.coverUrl!,height:180,fit:BoxFit.cover)),const SizedBox(height:14),Row(children:[CircleAvatar(radius:32,backgroundImage:b.logoUrl==null?null:NetworkImage(b.logoUrl!)),const SizedBox(width:12),Expanded(child:Text(b.name,style:Theme.of(context).textTheme.titleLarge)),StatusChip(b.status.name)]),const SizedBox(height:16),Text(b.description??''),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined),title:Text('${b.address??''}, ${b.city??''}')),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.phone_outlined),title:Text(b.phone??'Not set')),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.email_outlined),title:Text(b.email??'Not set')),const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>_edit(context,ref,b),icon:const Icon(Icons.edit_outlined),label:const Text('Edit Business Information'))]);}));
  Future<void> _edit(BuildContext context,WidgetRef ref,Business b)async{final name=TextEditingController(text:b.name),desc=TextEditingController(text:b.description),address=TextEditingController(text:b.address),city=TextEditingController(text:b.city),phone=TextEditingController(text:b.phone),email=TextEditingController(text:b.email);final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Edit Business'),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),const SizedBox(height:8),TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'Description')),const SizedBox(height:8),TextField(controller:address,decoration:const InputDecoration(labelText:'Address')),const SizedBox(height:8),TextField(controller:city,decoration:const InputDecoration(labelText:'City')),const SizedBox(height:8),TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),const SizedBox(height:8),TextField(controller:email,decoration:const InputDecoration(labelText:'Email'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))]))??false;if(ok){await ref.read(repositoryProvider).updateBusiness(b.id,{'name':name.text,'description':desc.text,'address':address.text,'city':city.text,'phone':phone.text,'email':email.text});if(context.mounted)(context as Element).markNeedsBuild();}}
}

class OwnerListingsScreen extends ConsumerStatefulWidget {
  const OwnerListingsScreen({super.key});

  @override
  ConsumerState<OwnerListingsScreen> createState() => _OwnerListingsScreenState();
}

class _OwnerListingsScreenState extends ConsumerState<OwnerListingsScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Business?>(
      future: ref.read(repositoryProvider).ownerBusiness(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (businessSnapshot.hasError) {
          return Scaffold(body: ErrorState(message: '${businessSnapshot.error}'));
        }
        final business = businessSnapshot.data;
        if (business == null) {
          return const Scaffold(body: EmptyState(message: 'Register a business first.'));
        }
        return AppShell(
          title: 'Listings',
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/owner/listing/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add Listing'),
          ),
          child: FutureBuilder<List<Listing>>(
            future: ref.read(repositoryProvider).ownerListings(business.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
              final listings = snapshot.data ?? const <Listing>[];
              if (listings.isEmpty) {
                return const EmptyState(message: 'Create your first event or ticketed service.');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event)),
                      title: Text(listing.title),
                      subtitle: Text('${listing.eventType ?? 'Service'} • ${listing.status.name}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            context.push('/owner/listing/${listing.id}');
                          } else if (value == 'tickets') {
                            context.push('/owner/tickets/${listing.id}');
                          } else if (value == 'delete') {
                            await ref.read(repositoryProvider).deleteListing(listing.id);
                            if (mounted) setState(() {});
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'tickets', child: Text('Schedules & tickets')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<ListingEditorScreen> createState() => _ListingEditorState();
}

class _ListingEditorState extends ConsumerState<ListingEditorScreen> {
  final key = GlobalKey<FormState>();
  final title = TextEditingController();
  final desc = TextEditingController();
  final location = TextEditingController();
  final terms = TextEditingController();
  final type = TextEditingController();
  String status = 'draft';
  String? categoryId;
  String? poster;
  bool busy = false;
  bool loaded = false;

  @override
  void dispose() {
    for (final controller in [title, desc, location, terms, type]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    if (loaded || widget.listingId == null) return;
    loaded = true;
    final listing = await ref.read(repositoryProvider).listing(widget.listingId!);
    title.text = listing.title;
    desc.text = listing.description ?? '';
    location.text = listing.locationText ?? '';
    terms.text = listing.terms ?? '';
    type.text = listing.eventType ?? '';
    categoryId = listing.categoryId;
    poster = listing.posterUrl;
    status = listing.status.name;
    if (mounted) setState(() {});
  }

  Future<void> submit() async {
    if (!key.currentState!.validate() || categoryId == null) return;
    setState(() => busy = true);
    try {
      final business = await ref.read(repositoryProvider).ownerBusiness();
      if (business == null) throw StateError('Register business first');
      final id = await ref.read(repositoryProvider).saveListing(
        {
          'business_id': business.id,
          'category_id': categoryId,
          'title': title.text.trim(),
          'description': desc.text.trim(),
          'poster_url': poster,
          'event_type': type.text.trim(),
          'location_text': location.text.trim(),
          'terms': terms.text.trim(),
          'status': status,
          'booking_open': true,
        },
        id: widget.listingId,
      );
      if (mounted) context.go('/owner/tickets/$id');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (image == null) return;
    final business = await ref.read(repositoryProvider).ownerBusiness();
    if (business == null) return;
    poster = await ref.read(repositoryProvider).uploadImage(
          bytes: await image.readAsBytes(),
          bucket: 'listing-media',
          path: '${business.id}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    load();
    return AppShell(
      title: widget.listingId == null ? 'Add Event / Service' : 'Edit Listing',
      child: FutureBuilder<List<Category>>(
        future: ref.read(repositoryProvider).categories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final categories = snapshot.data ?? const <Category>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: key,
                child: Column(
                  children: [
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Event / service name'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: type,
                      decoration: const InputDecoration(labelText: 'Event type (concert, workshop, attraction...)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                          .toList(),
                      onChanged: (value) => setState(() => categoryId = value),
                      validator: (value) => value == null ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: desc,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: location,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: terms,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Terms & conditions'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['draft', 'active', 'paused', 'cancelled', 'completed']
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) => setState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pick,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(poster == null ? 'Upload Poster' : 'Replace Poster'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Save & Manage Tickets',
                        busy: busy,
                        onPressed: submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class TicketManagementScreen extends ConsumerWidget {
  const TicketManagementScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
        title: 'Schedules & Tickets',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addSchedule(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Schedule'),
        ),
        child: FutureBuilder<List<Schedule>>(
          future: ref.read(repositoryProvider).ownerSchedules(listingId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
            final schedules = snapshot.data ?? [];
            if (schedules.isEmpty) {
              return const EmptyState(
                message: 'Add a schedule, then create ticket types and inventory.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(prettyDate(schedule.startsAt)),
                    subtitle: Text(
                      '${schedule.venueOrHall ?? 'Venue'} • Capacity ${schedule.capacity}${schedule.isSeated ? ' • Seated' : ''}',
                    ),
                    children: [
                      FutureBuilder<List<TicketType>>(
                        future: ref.read(repositoryProvider).ticketTypes(schedule.id),
                        builder: (context, ticketSnapshot) {
                          if (ticketSnapshot.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (ticketSnapshot.hasError) {
                            return ErrorState(message: '${ticketSnapshot.error}');
                          }
                          final types = ticketSnapshot.data ?? [];
                          return Column(
                            children: [
                              ...types.map(
                                (type) => ListTile(
                                  title: Text('${type.name} • ${money(type.price)}'),
                                  subtitle: Text(
                                    'Total ${type.totalQty} • Sold ${type.soldQty} • Held ${type.heldQty} • Remaining ${type.remaining}',
                                  ),
                                ),
                              ),
                              OverflowBar(
                                alignment: MainAxisAlignment.end,
                                spacing: 8,
                                overflowSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _addTicket(context, ref, schedule.id),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Ticket Type'),
                                  ),
                                  TextButton.icon(
                                    onPressed: types.isEmpty
                                        ? null
                                        : () => _seatMap(
                                              context,
                                              ref,
                                              schedule,
                                              types.first,
                                            ),
                                    icon: const Icon(Icons.event_seat),
                                    label: const Text('Seat Map'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );

  Future<void> _addSchedule(BuildContext context, WidgetRef ref) async {
    final venue = TextEditingController();
    final capacity = TextEditingController(text: '100');
    final limit = TextEditingController(text: '6');
    var start = DateTime.now().add(const Duration(days: 7));
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Add Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: venue,
                      decoration: const InputDecoration(labelText: 'Venue / hall'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacity'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: limit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Booking limit per user',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(prettyDate(start)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                          initialDate: start,
                        );
                        if (date != null) {
                          setDialogState(
                            () => start = DateTime(date.year, date.month, date.day, 19),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).saveSchedule({
        'listing_id': listingId,
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': start.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'venue_or_hall': venue.text.trim(),
        'capacity': int.tryParse(capacity.text) ?? 100,
        'booking_limit_per_user': int.tryParse(limit.text) ?? 6,
        'status': 'active',
      });
      if (context.mounted) (context as Element).markNeedsBuild();
    } finally {
      venue.dispose();
      capacity.dispose();
      limit.dispose();
    }
  }

  Future<void> _addTicket(
    BuildContext context,
    WidgetRef ref,
    String scheduleId,
  ) async {
    final name = TextEditingController(text: 'General');
    final price = TextEditingController(text: '1500');
    final qty = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add Ticket Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total quantity'),
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
                child: const Text('Add'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).saveTicketType({
        'schedule_id': scheduleId,
        'name': name.text.trim(),
        'price': double.tryParse(price.text) ?? 0,
        'total_qty': int.tryParse(qty.text) ?? 0,
        'sold_qty': 0,
        'held_qty': 0,
        'sort_order': 0,
      });
      if (context.mounted) (context as Element).markNeedsBuild();
    } finally {
      name.dispose();
      price.dispose();
      qty.dispose();
    }
  }

  Future<void> _seatMap(
    BuildContext context,
    WidgetRef ref,
    Schedule schedule,
    TicketType type,
  ) async {
    final business = await ref.read(repositoryProvider).ownerBusiness();
    if (business == null || !context.mounted) return;
    final rows = TextEditingController(text: '8');
    final perRow = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Create Simple Seat Map'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Creates General seats and maps them to the selected ticket type.',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rows,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rows'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: perRow,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seats per row'),
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
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      final mapId = await ref.read(repositoryProvider).createSimpleSeatMap(
            businessId: business.id,
            name: '${schedule.venueOrHall ?? 'Venue'} Seat Map',
            rows: int.tryParse(rows.text) ?? 8,
            seatsPerRow: int.tryParse(perRow.text) ?? 10,
          );
      await ref.read(repositoryProvider).configureScheduleSeatMap(
            scheduleId: schedule.id,
            seatMapId: mapId,
            ticketTypeId: type.id,
          );
      if (context.mounted) (context as Element).markNeedsBuild();
    } finally {
      rows.dispose();
      perRow.dispose();
    }
  }
}

class OwnerInventoryScreen extends ConsumerWidget {
  const OwnerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Business?>(
        future: ref.read(repositoryProvider).ownerBusiness(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (businessSnapshot.hasError) {
            return Scaffold(body: ErrorState(message: '${businessSnapshot.error}'));
          }
          final business = businessSnapshot.data;
          if (business == null) {
            return const Scaffold(body: EmptyState(message: 'No business.'));
          }
          return AppShell(
            title: 'Inventory / Availability',
            child: FutureBuilder<List<Listing>>(
              future: ref.read(repositoryProvider).ownerListings(business.id),
              builder: (context, listingSnapshot) {
                if (listingSnapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (listingSnapshot.hasError) {
                  return ErrorState(message: '${listingSnapshot.error}');
                }
                final listings = listingSnapshot.data ?? [];
                if (listings.isEmpty) {
                  return const EmptyState(message: 'Create a listing first.');
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: listings
                      .map(
                        (listing) => Card(
                          child: ExpansionTile(
                            title: Text(listing.title),
                            children: [
                              FutureBuilder<List<Schedule>>(
                                future: ref
                                    .read(repositoryProvider)
                                    .ownerSchedules(listing.id),
                                builder: (context, scheduleSnapshot) {
                                  if (scheduleSnapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (scheduleSnapshot.hasError) {
                                    return ErrorState(
                                      message: '${scheduleSnapshot.error}',
                                    );
                                  }
                                  final schedules = scheduleSnapshot.data ?? [];
                                  if (schedules.isEmpty) {
                                    return const ListTile(
                                      title: Text('No schedules yet'),
                                    );
                                  }
                                  return Column(
                                    children: schedules
                                        .map(
                                          (schedule) => FutureBuilder<List<TicketType>>(
                                            future: ref
                                                .read(repositoryProvider)
                                                .ticketTypes(schedule.id),
                                            builder: (context, typeSnapshot) {
                                              if (typeSnapshot.connectionState !=
                                                  ConnectionState.done) {
                                                return const LinearProgressIndicator();
                                              }
                                              if (typeSnapshot.hasError) {
                                                return ErrorState(
                                                  message: '${typeSnapshot.error}',
                                                );
                                              }
                                              final types = typeSnapshot.data ?? [];
                                              return ExpansionTile(
                                                title: Text(
                                                  prettyDate(schedule.startsAt),
                                                ),
                                                subtitle: Text(
                                                  schedule.venueOrHall ?? '',
                                                ),
                                                children: types
                                                    .map(
                                                      (type) => ListTile(
                                                        title: Text(type.name),
                                                        subtitle: Text(
                                                          'Total ${type.totalQty} • Sold ${type.soldQty} • Held ${type.heldQty} • Remaining ${type.remaining}',
                                                        ),
                                                        trailing: type.remaining <= 0
                                                            ? const Chip(
                                                                label: Text('Sold out'),
                                                              )
                                                            : null,
                                                      ),
                                                    )
                                                    .toList(),
                                              );
                                            },
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          );
        },
      );
}

class OwnerBookingsScreen extends ConsumerWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Business?>(
        future: ref.read(repositoryProvider).ownerBusiness(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (businessSnapshot.hasError) {
            return Scaffold(body: ErrorState(message: '${businessSnapshot.error}'));
          }
          final business = businessSnapshot.data;
          if (business == null) {
            return const Scaffold(body: EmptyState(message: 'No business.'));
          }
          return AppShell(
            title: 'Bookings',
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(repositoryProvider).ownerBookings(business.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const EmptyState(
                    message: 'No bookings for your listings yet.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${row['booking_code']} • ${row['customer_name']}',
                        ),
                        subtitle: Text(
                          '${row['listing_title']}\n${row['starts_at']}',
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
        },
      );
}

class OwnerAnalyticsScreen extends ConsumerWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Business?>(
        future: ref.read(repositoryProvider).ownerBusiness(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (businessSnapshot.hasError) {
            return Scaffold(body: ErrorState(message: '${businessSnapshot.error}'));
          }
          final business = businessSnapshot.data;
          if (business == null) {
            return const Scaffold(body: EmptyState(message: 'No business.'));
          }
          return AppShell(
            title: 'Sales Analytics',
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(repositoryProvider).ownerSales(business.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return const EmptyState(message: 'No sales data yet.');
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: List.generate(
                            data.length,
                            (index) => BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: ((data[index]['tickets_sold'] as num?) ?? 0)
                                      .toDouble(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SectionHeader('Sales per Event'),
                    ...data.map(
                      (row) => Card(
                        child: ListTile(
                          title: Text('${row['event_title']}'),
                          subtitle: Text('${row['tickets_sold']} tickets sold'),
                          trailing: Text(
                            money((row['revenue'] as num?) ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
}

class OwnerScannerScreen extends ConsumerStatefulWidget {
  const OwnerScannerScreen({super.key});

  @override
  ConsumerState<OwnerScannerScreen> createState() => _OwnerScannerState();
}

class _OwnerScannerState extends ConsumerState<OwnerScannerScreen> {
  bool processing = false;
  Map<String, dynamic>? result;

  Color _resultColor(String value) {
    if (value == 'Valid') return Colors.green;
    if (value == 'Already Used') return Colors.orange;
    return Colors.red;
  }

  IconData _resultIcon(String value) {
    if (value == 'Valid') return Icons.check_circle;
    if (value == 'Already Used') return Icons.warning_amber;
    return Icons.cancel;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QR Scanner')),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) async {
                if (processing) return;
                final raw = capture.barcodes.isEmpty
                    ? null
                    : capture.barcodes.first.rawValue;
                if (raw == null || raw.isEmpty) return;
                setState(() => processing = true);
                try {
                  final value = await ref
                      .read(repositoryProvider)
                      .validateTicket(raw);
                  if (mounted) setState(() => result = value);
                } catch (e) {
                  if (mounted) {
                    setState(
                      () => result = {
                        'result': 'Invalid',
                        'message': '$e',
                      },
                    );
                  }
                } finally {
                  await Future<void>.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => processing = false);
                }
              },
            ),
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            if (result != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _resultIcon('${result!['result']}'),
                            size: 54,
                            color: _resultColor('${result!['result']}'),
                          ),
                          Text(
                            '${result!['result']}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (result!['event_title'] != null)
                            Text('${result!['event_title']}'),
                          if (result!['starts_at'] != null)
                            Text('${result!['starts_at']}'),
                          if (result!['seat_label'] != null)
                            Text('Seat ${result!['seat_label']}'),
                          if (result!['message'] != null)
                            Text(
                              '${result!['message']}',
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class OwnerSettingsScreen extends ConsumerWidget {
  const OwnerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
        title: 'Owner Settings',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('Staff & scanner access'),
              subtitle: Text(
                'Staff authorization is stored in the staff table.',
              ),
            ),
            const ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Owner notifications'),
            ),
            const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Appearance'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(repositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      );
}

