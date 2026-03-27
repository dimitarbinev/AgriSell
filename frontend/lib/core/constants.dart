class AppConstants {
  AppConstants._();

  static const String appName = 'Agro Street Market';
  static const String tagline = 'Fresh from farm to street';

  // ─── Product Categories ───
  static const List<String> productCategories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Herbs',
    'Nuts',
    'Honey',
    'Meat',
    'Eggs',
    'Other',
  ];

  // ─── Bulgarian Cities ───
  static const List<String> cities = [
    'Sofia',
    'Plovdiv',
    'Varna',
    'Burgas',
    'Ruse',
    'Stara Zagora',
    'Pleven',
    'Sliven',
    'Dobrich',
    'Shumen',
    'Pernik',
    'Haskovo',
    'Yambol',
    'Pazardzhik',
    'Blagoevgrad',
    'Veliko Tarnovo',
    'Vratsa',
    'Gabrovo',
    'Asenovgrad',
    'Vidin',
    'Kazanlak',
    'Kyustendil',
    'Montana',
    'Dimitrovgrad',
    'Lovech',
  ];

  static const Map<String, ({double lat, double lng})> cityLocations = {
    'Sofia': (lat: 42.6977, lng: 23.3219),
    'Plovdiv': (lat: 42.1354, lng: 24.7453),
    'Varna': (lat: 43.2141, lng: 27.9147),
    'Burgas': (lat: 42.5048, lng: 27.4626),
    'Ruse': (lat: 43.8356, lng: 25.9657),
    'Stara Zagora': (lat: 42.4258, lng: 25.6345),
    'Pleven': (lat: 43.4170, lng: 24.6067),
    'Sliven': (lat: 42.6817, lng: 26.3229),
    'Dobrich': (lat: 43.5725, lng: 27.8273),
    'Shumen': (lat: 43.2712, lng: 26.9361),
    'Pernik': (lat: 42.6106, lng: 23.0292),
    'Haskovo': (lat: 41.9344, lng: 25.5555),
    'Yambol': (lat: 42.4842, lng: 26.5035),
    'Pazardzhik': (lat: 42.1939, lng: 24.3333),
    'Blagoevgrad': (lat: 42.0209, lng: 23.0943),
    'Veliko Tarnovo': (lat: 43.0757, lng: 25.6172),
    'Vratsa': (lat: 43.2102, lng: 23.5529),
    'Gabrovo': (lat: 42.8742, lng: 25.3186),
    'Asenovgrad': (lat: 42.0125, lng: 24.8772),
    'Vidin': (lat: 43.9961, lng: 22.8679),
    'Kazanlak': (lat: 42.6244, lng: 25.3929),
    'Kyustendil': (lat: 42.2839, lng: 22.6911),
    'Montana': (lat: 43.4125, lng: 23.2250),
    'Dimitrovgrad': (lat: 42.0641, lng: 25.5721),
    'Lovech': (lat: 43.1333, lng: 24.7167),
  };

  static List<String> get cities => cityLocations.keys.toList()..sort();

  // ─── Seasons ───
  static const List<String> seasons = [
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
    'Year-round',
  ];

  // ─── Listing Statuses ───
  static const String statusDraft = 'draft';
  static const String statusActive = 'active';
  static const String statusThresholdReached = 'threshold_reached';
  static const String statusGoConfirmed = 'go_confirmed';
  static const String statusCancelled = 'cancelled';
  static const String statusCompleted = 'completed';

  // ─── Reservation Statuses ───
  static const String reservationPending = 'pending';
  static const String reservationConfirmed = 'confirmed';
  static const String reservationCancelled = 'cancelled';
  static const String reservationCompleted = 'completed';
}
