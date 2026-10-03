enum UserRole { customer, owner, admin }
enum BusinessStatus { pending, approved, rejected, suspended }
enum ListingStatus { draft, active, paused, cancelled, completed }
enum BookingStatus { pending, confirmed, paid, cancelled, completed, used, refunded }
enum TicketStatus { valid, used, cancelled, refunded }

typedef Json = Map<String, dynamic>;

String _s(dynamic value, [String fallback = '']) => value?.toString() ?? fallback;
int _i(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
double _d(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
DateTime? _dt(dynamic value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
T _enumByName<T extends Enum>(Iterable<T> values, String name, T fallback) { for (final value in values) { if (value.name == name) return value; } return fallback; }

class Profile {
  const Profile({required this.id, required this.fullName, required this.role, this.phone, this.avatarUrl});
  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? avatarUrl;

  factory Profile.fromJson(Json j) => Profile(
    id: _s(j['id']),
    fullName: _s(j['full_name'], 'TicketHub User'),
    role: _enumByName(UserRole.values, _s(j['role']), UserRole.customer),
    phone: j['phone']?.toString(),
    avatarUrl: j['avatar_url']?.toString(),
  );
}

class Category {
  const Category({required this.id, required this.name, required this.slug, this.icon});
  final String id;
  final String name;
  final String slug;
  final String? icon;
  factory Category.fromJson(Json j) => Category(id: _s(j['id']), name: _s(j['name']), slug: _s(j['slug']), icon: j['icon']?.toString());
}

class Business {
  const Business({
    required this.id, required this.name, required this.status,
    this.ownerId, this.categoryId, this.logoUrl, this.coverUrl, this.description,
    this.address, this.city, this.phone, this.email, this.ratingAvg = 0, this.ratingCount = 0,
  });
  final String id;
  final String? ownerId;
  final String? categoryId;
  final String name;
  final BusinessStatus status;
  final String? logoUrl, coverUrl, description, address, city, phone, email;
  final double ratingAvg;
  final int ratingCount;
  factory Business.fromJson(Json j) => Business(
    id: _s(j['id']), ownerId: j['owner_id']?.toString(), categoryId: j['category_id']?.toString(),
    name: _s(j['name']), status: _enumByName(BusinessStatus.values, _s(j['status']), BusinessStatus.pending),
    logoUrl: j['logo_url']?.toString(), coverUrl: j['cover_url']?.toString(), description: j['description']?.toString(),
    address: j['address']?.toString(), city: j['city']?.toString(), phone: j['phone']?.toString(), email: j['email']?.toString(),
    ratingAvg: _d(j['rating_avg']), ratingCount: _i(j['rating_count']),
  );
}

class Listing {
  const Listing({
    required this.id, required this.businessId, required this.title, required this.status,
    this.categoryId, this.description, this.posterUrl, this.eventType, this.locationText,
    this.terms, this.isFeatured = false, this.bookingOpen = true,
  });
  final String id, businessId, title;
  final String? categoryId, description, posterUrl, eventType, locationText, terms;
  final ListingStatus status;
  final bool isFeatured, bookingOpen;
  factory Listing.fromJson(Json j) => Listing(
    id: _s(j['id']), businessId: _s(j['business_id']), categoryId: j['category_id']?.toString(), title: _s(j['title']),
    description: j['description']?.toString(), posterUrl: j['poster_url']?.toString(), eventType: j['event_type']?.toString(),
    locationText: j['location_text']?.toString(), terms: j['terms']?.toString(),
    status: _enumByName(ListingStatus.values, _s(j['status']), ListingStatus.draft),
    isFeatured: j['is_featured'] == true, bookingOpen: j['booking_open'] != false,
  );
}

class Schedule {
  const Schedule({
    required this.id, required this.listingId, required this.startsAt, required this.endsAt,
    required this.capacity, required this.bookingLimitPerUser,
    this.venueOrHall, this.seatMapId, this.status = 'active',
  });
  final String id, listingId;
  final DateTime startsAt, endsAt;
  final String? venueOrHall, seatMapId;
  final int capacity, bookingLimitPerUser;
  final String status;
  bool get isSeated => seatMapId != null && seatMapId!.isNotEmpty;
  factory Schedule.fromJson(Json j) => Schedule(
    id: _s(j['id']), listingId: _s(j['listing_id']),
    startsAt: _dt(j['starts_at']) ?? DateTime.now(), endsAt: _dt(j['ends_at']) ?? DateTime.now(),
    venueOrHall: j['venue_or_hall']?.toString(), seatMapId: j['seat_map_id']?.toString(), capacity: _i(j['capacity']),
    bookingLimitPerUser: _i(j['booking_limit_per_user'], 10), status: _s(j['status'], 'active'),
  );
}

class TicketType {
  const TicketType({
    required this.id, required this.scheduleId, required this.name, required this.price,
    required this.totalQty, required this.soldQty, required this.heldQty,
    this.seatCategory, this.sortOrder = 0,
  });
  final String id, scheduleId, name;
  final double price;
  final int totalQty, soldQty, heldQty, sortOrder;
  final String? seatCategory;
  int get remaining => totalQty - soldQty - heldQty;
  factory TicketType.fromJson(Json j) => TicketType(
    id: _s(j['id']), scheduleId: _s(j['schedule_id']), name: _s(j['name']), price: _d(j['price']),
    totalQty: _i(j['total_qty']), soldQty: _i(j['sold_qty']), heldQty: _i(j['held_qty']),
    seatCategory: j['seat_category']?.toString(), sortOrder: _i(j['sort_order']),
  );
}

class SeatAvailability {
  const SeatAvailability({required this.scheduleSeatId, required this.seatId, required this.rowLabel, required this.seatNumber, required this.category, required this.status, required this.ticketTypeId, required this.price, required this.x, required this.y});
  final String scheduleSeatId, seatId, rowLabel, seatNumber, category, status, ticketTypeId;
  final double price, x, y;
  String get label => '$rowLabel$seatNumber';
  factory SeatAvailability.fromJson(Json j) => SeatAvailability(
    scheduleSeatId: _s(j['schedule_seat_id']), seatId: _s(j['seat_id']), rowLabel: _s(j['row_label']), seatNumber: _s(j['seat_number']),
    category: _s(j['category']), status: _s(j['status']), ticketTypeId: _s(j['ticket_type_id']), price: _d(j['price']), x: _d(j['x']), y: _d(j['y']),
  );
}

class Booking {
  const Booking({required this.id, required this.bookingCode, required this.scheduleId, required this.status, required this.totalAmount, required this.customerName, required this.createdAt, this.customerPhone, this.customerEmail, this.holdExpiresAt});
  final String id, bookingCode, scheduleId, customerName;
  final String? customerPhone, customerEmail;
  final BookingStatus status;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime? holdExpiresAt;
  factory Booking.fromJson(Json j) => Booking(
    id: _s(j['id']), bookingCode: _s(j['booking_code']), scheduleId: _s(j['schedule_id']),
    status: _enumByName(BookingStatus.values, _s(j['status']), BookingStatus.pending),
    totalAmount: _d(j['total_amount']), customerName: _s(j['customer_name']), customerPhone: j['customer_phone']?.toString(), customerEmail: j['customer_email']?.toString(), createdAt: _dt(j['created_at']) ?? DateTime.now(), holdExpiresAt: _dt(j['hold_expires_at']),
  );
}

class DigitalTicket {
  const DigitalTicket({required this.id, required this.ticketCode, required this.qrToken, required this.status, required this.bookingId, this.usedAt, this.eventTitle, this.businessName, this.startsAt, this.location, this.ticketType, this.seatLabel, this.customerName, this.totalAmount});
  final String id, ticketCode, qrToken, bookingId;
  final TicketStatus status;
  final DateTime? usedAt, startsAt;
  final String? eventTitle, businessName, location, ticketType, seatLabel, customerName;
  final double? totalAmount;
  factory DigitalTicket.fromJson(Json j) => DigitalTicket(
    id: _s(j['id']), ticketCode: _s(j['ticket_code']), qrToken: _s(j['qr_token']), bookingId: _s(j['booking_id']),
    status: _enumByName(TicketStatus.values, _s(j['status']), TicketStatus.valid),
    usedAt: _dt(j['used_at']), eventTitle: j['event_title']?.toString(), businessName: j['business_name']?.toString(),
    startsAt: _dt(j['starts_at']), location: j['location']?.toString(), ticketType: j['ticket_type']?.toString(),
    seatLabel: j['seat_label']?.toString(), customerName: j['customer_name']?.toString(), totalAmount: j['total_amount'] == null ? null : _d(j['total_amount']),
  );
}

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, required this.isRead, required this.createdAt, this.type = 'general'});
  final String id, title, body, type;
  final bool isRead;
  final DateTime createdAt;
  factory AppNotification.fromJson(Json j) => AppNotification(id: _s(j['id']), title: _s(j['title']), body: _s(j['body']), type: _s(j['type'], 'general'), isRead: j['is_read'] == true, createdAt: _dt(j['created_at']) ?? DateTime.now());
}

class Review {
  const Review({required this.id, required this.rating, required this.comment, required this.createdAt, this.customerName});
  final String id, comment;
  final int rating;
  final DateTime createdAt;
  final String? customerName;
  factory Review.fromJson(Json j) => Review(id: _s(j['id']), rating: _i(j['rating']), comment: _s(j['comment']), createdAt: _dt(j['created_at']) ?? DateTime.now(), customerName: j['customer_name']?.toString());
}

class DashboardStats {
  const DashboardStats({this.values = const {}});
  final Map<String, num> values;
  num operator [](String key) => values[key] ?? 0;
  factory DashboardStats.fromJson(Json j) => DashboardStats(values: j.map((k, v) => MapEntry(k, v is num ? v : num.tryParse('$v') ?? 0)));
}

class ListingSearchResult {
  const ListingSearchResult({
    required this.listing,
    required this.businessName,
    required this.businessRating,
    required this.soldCount,
    required this.remaining,
    this.nextStart,
    this.minPrice,
  });

  final Listing listing;
  final String businessName;
  final double businessRating;
  final int soldCount;
  final int remaining;
  final DateTime? nextStart;
  final double? minPrice;

  factory ListingSearchResult.fromJson(Json j) => ListingSearchResult(
        listing: Listing.fromJson(j),
        businessName: _s(j['business_name']),
        businessRating: _d(j['business_rating']),
        soldCount: _i(j['sold_count']),
        remaining: _i(j['remaining']),
        nextStart: _dt(j['next_start']),
        minPrice: j['min_price'] == null ? null : _d(j['min_price']),
      );
}
