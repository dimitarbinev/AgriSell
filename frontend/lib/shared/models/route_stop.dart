/// One map/routing stop — typically one Firestore reservation (or depot).
class SellerRouteStop {
  final String id;
  final String city;
  final String label;

  const SellerRouteStop({
    required this.id,
    required this.city,
    required this.label,
  });
}
