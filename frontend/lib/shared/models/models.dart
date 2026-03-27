import 'package:cloud_firestore/cloud_firestore.dart';

class Seller {
  final String id;
  final String name;
  final String mainCity;
  final String? photoUrl;
  final String phone;
  final String email;
  final double rating;
  final int totalReviews;
  final int completedOrders;
  final double cancelRate;
  final DateTime createdAt;

  const Seller({
    required this.id,
    required this.name,
    required this.mainCity,
    this.photoUrl,
    required this.phone,
    required this.email,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.completedOrders = 0,
    this.cancelRate = 0.0,
    required this.createdAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json, String id) {
    return Seller(
      id: id,
      name: json['name'] as String? ?? '',
      mainCity: json['mainCity'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] ?? json['reviewCount'] as num?)?.toInt() ?? 0,
      completedOrders: json['completedOrders'] as int? ?? 0,
      cancelRate: (json['cancelRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mainCity': mainCity,
    'photoUrl': photoUrl,
    'phone': phone,
    'email': email,
    'rating': rating,
    'totalReviews': totalReviews,
    'completedOrders': completedOrders,
    'cancelRate': cancelRate,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class Buyer {
  final String id;
  final String name;
  final String preferredCity;
  final String email;
  final DateTime createdAt;

  const Buyer({
    required this.id,
    required this.name,
    required this.preferredCity,
    required this.email,
    required this.createdAt,
  });

  factory Buyer.fromJson(Map<String, dynamic> json, String id) {
    return Buyer(
      id: id,
      name: json['name'] as String? ?? '',
      preferredCity: json['preferredCity'] as String? ?? '',
      email: json['email'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'preferredCity': preferredCity,
    'email': email,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class Product {
  final String id;
  final String sellerId;
  final String name;
  final String category;
  final String origin;
  final double pricePerKg;
  final double availableQuantity;
  final double minThreshold;
  final double maxCapacity;
  final String season;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.origin,
    required this.pricePerKg,
    required this.availableQuantity,
    required this.minThreshold,
    required this.maxCapacity,
    required this.season,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json, String id) {
    return Product(
      id: id,
      sellerId: json['sellerId'] as String? ?? '',
      name: (json['productName'] ?? json['name']) as String? ?? '',
      category: json['category'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      availableQuantity:
          (json['availableQuantity'] as num?)?.toDouble() ?? 0.0,
      minThreshold: (json['minThreshold'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (json['maxCapacity'] as num?)?.toDouble() ?? 0.0,
      season: json['season'] as String? ?? '',
      imageUrl: (json['image'] ?? json['imageUrl']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sellerId': sellerId,
    'name': name,
    'category': category,
    'origin': origin,
    'pricePerKg': pricePerKg,
    'availableQuantity': availableQuantity,
    'minThreshold': minThreshold,
    'maxCapacity': maxCapacity,
    'season': season,
    'imageUrl': imageUrl,
  };
}

class Listing {
  final String id;
  final String sellerId;
  final String productId;
  final String productName;
  final String productCategory;
  final String city;
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerKg;
  final double availableQuantity;
  final double minThreshold;
  final double requestedQuantity;
  final double depositsTotal;
  final String status;
  final bool? goDecision;
  final String? sellerName;
  final String? sellerPhotoUrl;
  final double? sellerRating;
  final String? productImageUrl;

  const Listing({
    required this.id,
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.pricePerKg,
    required this.availableQuantity,
    required this.minThreshold,
    this.requestedQuantity = 0,
    this.depositsTotal = 0,
    this.status = 'draft',
    this.goDecision,
    this.sellerName,
    this.sellerPhotoUrl,
    this.sellerRating,
    this.productImageUrl,
  });

  factory Listing.fromJson(Map<String, dynamic> json, String id) {
    return Listing(
      id: id,
      sellerId: json['sellerId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      productCategory: (json['productCategory'] ?? json['category']) as String? ?? '',
      city: json['city'] as String? ?? '',
      startDate: _parseDateTime(json['startDate'], _parseDateTime(json['date'])),
      endDate: _parseDateTime(json['endDate']),
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      availableQuantity:
          (json['availableQuantity'] ?? json['maxCapacity'] ?? 0) is num
              ? (json['availableQuantity'] ?? json['maxCapacity'] ?? 0).toDouble()
              : 0.0,
      minThreshold: (json['minThreshold'] as num?)?.toDouble() ?? 0.0,
      requestedQuantity:
          (json['requestedQuantity'] as num?)?.toDouble() ?? 0.0,
      depositsTotal: (json['depositsTotal'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] is int
          ? _mapStatus(json['status'] as int)
          : json['status'] as String? ?? 'active',
      goDecision: json['goDecision'] as bool?,
      sellerName: json['sellerName'] as String?,
      sellerPhotoUrl: json['sellerPhotoUrl'] as String?,
      sellerRating: (json['sellerRating'] as num?)?.toDouble(),
      productImageUrl: (json['productImageUrl'] ?? json['image']) as String?,
    );
  }

  static String _mapStatus(int status) {
    switch (status) {
      case 0:
        return 'pending'; // Draft/Pending
      case 1:
        return 'active'; // Initial Active state
      case 2:
        return 'confirmed'; // Confirmed GO!
      case 3:
        return 'cancelled';
      default:
        return 'draft';
    }
  }

  static Listing fromFirestore({
    required Map<String, dynamic> productData,
    required Map<String, dynamic> listingData,
    required String listingId,
    required String sellerId,
    required String productId,
  }) {
    return Listing(
      id: listingId,
      sellerId: sellerId,
      productId: productId,
      productName: productData['productName'] as String? ?? '',
      productCategory: productData['category'] as String? ?? '',
      city: (listingData['city'] ?? productData['origin'] ?? productData['mainCity']) as String? ?? '',
      startDate: _parseDateTime(listingData['startDate'], _parseDateTime(listingData['date'])),
      endDate: _parseDateTime(listingData['endDate']),
      pricePerKg: (productData['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: (productData['maxCapacity'] as num?)?.toDouble() ?? 0.0,
      minThreshold: (productData['minThreshold'] as num?)?.toDouble() ?? 0.0,
      requestedQuantity:
          (listingData['requestedQuantity'] as num?)?.toDouble() ?? 0.0,
      depositsTotal: (listingData['depositsTotal'] as num?)?.toDouble() ?? 0.0,
      status: listingData['status'] is int
          ? _mapStatus(listingData['status'] as int)
          : listingData['status'] as String? ?? 'active',
      productImageUrl: productData['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sellerId': sellerId,
    'productId': productId,
    'productName': productName,
    'productCategory': productCategory,
    'city': city,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'pricePerKg': pricePerKg,
    'availableQuantity': availableQuantity,
    'minThreshold': minThreshold,
    'requestedQuantity': requestedQuantity,
    'depositsTotal': depositsTotal,
    'status': status,
    'goDecision': goDecision,
    'sellerName': sellerName,
    'sellerPhotoUrl': sellerPhotoUrl,
    'sellerRating': sellerRating,
    'productImageUrl': productImageUrl,
  };

  double get progressPercentage =>
      minThreshold > 0 ? (requestedQuantity / minThreshold).clamp(0.0, 1.0) : 0;

  bool get thresholdReached => requestedQuantity >= minThreshold;
}

class Reservation {
  final String id;
  final String buyerId;
  final String listingId;
  final double quantity;
  final double deposit;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? buyerName;
  final String? productName;
  final String? city;
  final double? pricePerKg;
  final String? sellerId;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.buyerId,
    required this.listingId,
    required this.quantity,
    required this.deposit,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.status = 'pending',
    this.buyerName,
    this.productName,
    this.city,
    this.pricePerKg,
    this.sellerId,
  });

  factory Reservation.fromJson(Map<String, dynamic> json, String id) {
    final rawStatus = json['status'] as String?;
    return Reservation(
      id: id,
      buyerId: json['buyerId'] as String? ?? '',
      listingId: json['listingId'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0.0,
      startDate: _parseDateTime(json['startDate'], _parseDateTime(json['attendanceDate'])),
      endDate: _parseDateTime(json['endDate'], _parseDateTime(json['attendanceDate'])),
      status: rawStatus == 'pending' ? 'active' : (rawStatus ?? 'active'),
      buyerName: json['buyerName'] as String?,
      productName: json['productName'] as String?,
      city: json['city'] as String?,
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble(),
      sellerId: json['sellerId'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'buyerId': buyerId,
    'listingId': listingId,
    'quantity': quantity,
    'deposit': deposit,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'status': status,
    'buyerName': buyerName,
    'productName': productName,
    'city': city,
    'pricePerKg': pricePerKg,
    'sellerId': sellerId,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class Review {
  final String id;
  final String buyerId;
  final String sellerId;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? buyerName;

  const Review({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.buyerName,
  });

  factory Review.fromJson(Map<String, dynamic> json, String id) {
    return Review(
      id: id,
      buyerId: json['buyerId'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      buyerName: json['buyerName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'buyerId': buyerId,
    'sellerId': sellerId,
    'rating': rating,
    'comment': comment,
    'createdAt': Timestamp.fromDate(createdAt),
    'buyerName': buyerName,
  };
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json, String id) {
    return AppNotification(
      id: id,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'referenceId': referenceId,
    'read': read,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

DateTime _parseDateTime(dynamic value, [DateTime? defaultValue]) {
  if (value == null) return defaultValue ?? DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return defaultValue ?? DateTime.now();
    }
  }
  return defaultValue ?? DateTime.now();
}
