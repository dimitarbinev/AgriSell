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
