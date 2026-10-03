import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class TicketHubRepository {
  TicketHubRepository(this.client);
  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;

  Future<Profile?> currentProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({required String fullName, required String email, required String phone, required String password, required UserRole role}) async {
    final safeRole = role == UserRole.owner ? 'owner' : 'customer';
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'phone': phone.trim(), 'requested_role': safeRole},
    );
  }

  Future<void> signOut() => client.auth.signOut();

  Future<List<Category>> categories() async {
    final rows = await client.from('categories').select().eq('is_active', true).order('sort_order');
    return (rows as List).map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Business>> businesses({String? search, String? categoryId, String? city}) async {
    dynamic q = client.from('businesses').select().eq('status', 'approved');
    if (search != null && search.trim().isNotEmpty) q = q.ilike('name', '%${search.trim()}%');
    if (categoryId != null && categoryId.isNotEmpty) q = q.eq('category_id', categoryId);
    if (city != null && city.trim().isNotEmpty) q = q.ilike('city', '%${city.trim()}%');
    final rows = await q.order('rating_avg', ascending: false);
    return (rows as List).map((e) => Business.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Business> business(String id) async => Business.fromJson(await client.from('businesses').select().eq('id', id).single());

  Future<List<Listing>> listings({String? businessId, String? categoryId, String? search, bool featuredOnly = false}) async {
    dynamic q = client.from('listings').select().eq('status', 'active').eq('booking_open', true);
    if (businessId != null) q = q.eq('business_id', businessId);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (featuredOnly) q = q.eq('is_featured', true);
    if (search != null && search.trim().isNotEmpty) q = q.ilike('title', '%${search.trim()}%');
    final rows = await q.order('created_at', ascending: false);
    return (rows as List).map((e) => Listing.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Listing> listing(String id) async => Listing.fromJson(await client.from('listings').select().eq('id', id).single());


  Future<List<ListingSearchResult>> searchListings({
    String? query,
    String? businessQuery,
    String? categoryId,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? minPrice,
    double? maxPrice,
    String? eventType,
    bool availableOnly = true,
    String sort = 'newest',
    int limit = 100,
  }) async {
    final data = await client.rpc('search_listings', params: {
      'p_query': query,
      'p_business_query': businessQuery,
      'p_category_id': categoryId,
      'p_location': location,
      'p_start_date': startDate?.toUtc().toIso8601String(),
      'p_end_date': endDate?.toUtc().toIso8601String(),
      'p_min_price': minPrice,
      'p_max_price': maxPrice,
      'p_event_type': eventType,
      'p_available_only': availableOnly,
      'p_sort': sort.toLowerCase(),
      'p_limit': limit,
    });
    return (data as List)
        .map((e) => ListingSearchResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Schedule>> schedules(String listingId) async {
    await releaseExpiredHolds();
    final rows = await client.from('schedules').select().eq('listing_id', listingId).eq('status', 'active').gte('starts_at', DateTime.now().toUtc().toIso8601String()).order('starts_at');
    return (rows as List).map((e) => Schedule.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Schedule> schedule(String id) async => Schedule.fromJson(await client.from('schedules').select().eq('id', id).single());

  Future<List<TicketType>> ticketTypes(String scheduleId) async {
    await releaseExpiredHolds();
    final rows = await client.from('ticket_types').select().eq('schedule_id', scheduleId).order('sort_order');
    return (rows as List).map((e) => TicketType.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SeatAvailability>> seats(String scheduleId) async {
    await releaseExpiredHolds();
    final data = await client.rpc('get_schedule_seats', params: {'p_schedule_id': scheduleId});
    return (data as List).map((e) => SeatAvailability.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<String> holdTickets({required String scheduleId, required Map<String, int> quantities, required List<String> seatIds}) async {
    final items = quantities.entries.where((e) => e.value > 0).map((e) => {'ticket_type_id': e.key, 'quantity': e.value}).toList();
    final result = await client.rpc('hold_tickets', params: {'p_schedule_id': scheduleId, 'p_items': items, 'p_seat_ids': seatIds});
    return result.toString();
  }

  Future<void> updatePendingBookingContact({
    required String bookingId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
  }) async {
    await client.rpc('update_pending_booking_contact', params: {
      'p_booking_id': bookingId,
      'p_customer_name': customerName.trim(),
      'p_customer_phone': customerPhone.trim(),
      'p_customer_email': customerEmail.trim(),
    });
  }

  Future<void> confirmBooking({required String bookingId, required String paymentMethod, required String providerRef}) async {
    await client.rpc('confirm_booking', params: {'p_booking_id': bookingId, 'p_payment_method': paymentMethod, 'p_provider_ref': providerRef});
  }

  Future<void> cancelBooking(String bookingId) async => client.rpc('cancel_booking', params: {'p_booking_id': bookingId});
  Future<void> releaseExpiredHolds() async => client.rpc('release_expired_holds');

  Future<List<Booking>> myBookings() async {
    final rows = await client.from('bookings').select().order('created_at', ascending: false);
    return (rows as List).map((e) => Booking.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Booking> booking(String id) async => Booking.fromJson(await client.from('bookings').select().eq('id', id).single());

  Future<List<DigitalTicket>> myTickets() async {
    final data = await client.rpc('my_ticket_details');
    return (data as List).map((e) => DigitalTicket.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<DigitalTicket> ticket(String id) async {
    final data = await client.rpc('ticket_detail', params: {'p_ticket_id': id});
    final list = data as List;
    if (list.isEmpty) throw StateError('Ticket not found');
    return DigitalTicket.fromJson(Map<String, dynamic>.from(list.first));
  }

  Future<Map<String, dynamic>> validateTicket(String token) async {
    final data = await client.rpc('validate_ticket', params: {'p_qr_token': token, 'p_scanner_id': userId});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<AppNotification>> notifications() async {
    final rows = await client.from('notifications').select().order('created_at', ascending: false).limit(100);
    return (rows as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> markNotificationRead(String id) async => client.from('notifications').update({'is_read': true}).eq('id', id);

  Future<List<String>> favoriteBusinessIds() async {
    final rows = await client.from('favorites').select('business_id');
    return (rows as List).map((e) => e['business_id'].toString()).toList();
  }

  Future<void> toggleFavorite(String businessId, bool favorite) async {
    final uid = userId!;
    if (favorite) {
      await client.from('favorites').upsert({'customer_id': uid, 'business_id': businessId});
    } else {
      await client.from('favorites').delete().eq('customer_id', uid).eq('business_id', businessId);
    }
  }

  Future<List<Business>> favoriteBusinesses() async {
    final ids = await favoriteBusinessIds();
    if (ids.isEmpty) return [];
    final rows = await client.from('businesses').select().inFilter('id', ids);
    return (rows as List).map((e) => Business.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Map<String, dynamic>>> paymentHistory() async {
    final rows = await client.from('payments').select('id,booking_id,method,provider_ref,amount,status,created_at').order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Review>> reviewsForBusiness(String businessId) async {
    final data = await client.rpc('business_reviews_public', params: {'p_business_id': businessId});
    return (data as List).map((e) => Review.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> createReview({required String bookingId, required String businessId, required String listingId, required int rating, required String comment}) async {
    await client.from('reviews').insert({'booking_id': bookingId, 'customer_id': userId, 'business_id': businessId, 'listing_id': listingId, 'rating': rating, 'comment': comment.trim()});
  }

  Future<void> updateProfile({required String fullName, required String phone}) async {
    await client.from('profiles').update({'full_name': fullName.trim(), 'phone': phone.trim()}).eq('id', userId!);
  }

  Future<String> uploadImage({required Uint8List bytes, required String bucket, required String path, required String contentType}) async {
    await client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return client.storage.from(bucket).getPublicUrl(path);
  }

  // Owner
  Future<Business?> ownerBusiness() async {
    final row = await client.from('businesses').select().eq('owner_id', userId!).order('created_at').limit(1).maybeSingle();
    return row == null ? null : Business.fromJson(row);
  }

  Future<void> registerBusiness(Map<String, dynamic> values) async => client.from('businesses').insert({...values, 'owner_id': userId, 'status': 'pending'});

  Future<void> updateBusiness(String id, Map<String, dynamic> values) async {
    final safe = Map<String, dynamic>.from(values)..remove('status')..remove('owner_id')..remove('rating_avg')..remove('rating_count');
    await client.from('businesses').update(safe).eq('id', id);
  }

  Future<List<Listing>> ownerListings(String businessId) async {
    final rows = await client.from('listings').select().eq('business_id', businessId).order('created_at', ascending: false);
    return (rows as List).map((e) => Listing.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<String> saveListing(Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      final row = await client.from('listings').insert(values).select('id').single();
      return row['id'].toString();
    }
    await client.from('listings').update(values).eq('id', id);
    return id;
  }

  Future<void> deleteListing(String id) async => client.from('listings').delete().eq('id', id);

  Future<String> saveSchedule(Map<String, dynamic> values, {String? id}) async {
    if (id == null) return (await client.from('schedules').insert(values).select('id').single())['id'].toString();
    await client.from('schedules').update(values).eq('id', id);
    return id;
  }

  Future<String> saveTicketType(Map<String, dynamic> values, {String? id}) async {
    if (id == null) return (await client.from('ticket_types').insert(values).select('id').single())['id'].toString();
    final safe = Map<String, dynamic>.from(values)..remove('sold_qty')..remove('held_qty');
    await client.from('ticket_types').update(safe).eq('id', id);
    return id;
  }

  Future<String> createSimpleSeatMap({required String businessId, required String name, required int rows, required int seatsPerRow}) async {
    final map = await client.from('seat_maps').insert({'business_id': businessId, 'name': name, 'layout': {'rows': rows, 'seats_per_row': seatsPerRow}}).select('id').single();
    final id = map['id'].toString();
    final batch = <Map<String, dynamic>>[];
    for (var r = 0; r < rows; r++) {
      final row = String.fromCharCode(65 + r);
      for (var n = 1; n <= seatsPerRow; n++) {
        batch.add({'seat_map_id': id, 'row_label': row, 'seat_number': '$n', 'category': 'General', 'x': n.toDouble(), 'y': r.toDouble()});
      }
    }
    if (batch.isNotEmpty) await client.from('seats').insert(batch);
    return id;
  }

  Future<void> configureScheduleSeatMap({required String scheduleId, required String seatMapId, required String ticketTypeId}) async {
    await client.rpc('configure_schedule_seat_map', params: {'p_schedule_id': scheduleId, 'p_seat_map_id': seatMapId, 'p_ticket_type_id': ticketTypeId});
  }

  Future<List<Schedule>> ownerSchedules(String listingId) async {
    final rows = await client.from('schedules').select().eq('listing_id', listingId).order('starts_at');
    return (rows as List).map((e) => Schedule.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Map<String, dynamic>>> ownerBookings(String businessId) async {
    final data = await client.rpc('owner_bookings', params: {'p_business_id': businessId});
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<DashboardStats> ownerDashboard(String businessId) async => DashboardStats.fromJson(Map<String, dynamic>.from(await client.rpc('owner_dashboard_stats', params: {'p_business_id': businessId}) as Map));
  Future<List<Map<String, dynamic>>> ownerSales(String businessId) async => (await client.rpc('owner_sales_by_event', params: {'p_business_id': businessId}) as List).map((e) => Map<String, dynamic>.from(e)).toList();

  // Admin
  Future<DashboardStats> adminDashboard() async => DashboardStats.fromJson(Map<String, dynamic>.from(await client.rpc('admin_dashboard_stats') as Map));
  Future<List<Map<String, dynamic>>> adminBusinesses() async => (await client.from('businesses').select('*,profiles!businesses_owner_id_fkey(full_name)').order('created_at', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<List<Map<String, dynamic>>> adminUsers() async => (await client.from('profiles').select().order('created_at', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<List<Map<String, dynamic>>> adminRows(String table) async => (await client.from(table).select().order('created_at', ascending: false).limit(250) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<void> setBusinessStatus(String businessId, String status, {String? reason}) async => client.rpc('admin_set_business_status', params: {'p_business_id': businessId, 'p_status': status, 'p_reason': reason});
  Future<void> moderateReview(String reviewId, bool hidden) async => client.from('reviews').update({'is_hidden': hidden}).eq('id', reviewId);
  Future<void> upsertCategory({String? id, required String name, required String slug, required String icon, required bool active, required int sortOrder}) async {
    final data = {'name': name, 'slug': slug, 'icon': icon, 'is_active': active, 'sort_order': sortOrder};
    if (id == null) {
      await client.from('categories').insert(data);
    } else {
      await client.from('categories').update(data).eq('id', id);
    }
  }
  Future<Map<String, dynamic>> platformSettings() async {
    final rows = await client.from('platform_settings').select();
    return {for (final row in rows as List) row['key'].toString(): row['value']};
  }
  Future<void> setPlatformSetting(String key, dynamic value) async => client.from('platform_settings').upsert({'key': key, 'value': value});
}
