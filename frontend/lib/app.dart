import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shared/services/storage_service.dart';
import 'shared/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/seller/seller_shell.dart';
import 'features/seller/seller_dashboard_screen.dart';
import 'features/seller/add_product_screen.dart';
import 'features/seller/create_listing_screen.dart';
import 'features/seller/seller_listing_detail_screen.dart';
import 'features/seller/my_listings_screen.dart';
import 'features/seller/my_products_screen.dart';
import 'features/seller/route_planning_screen.dart';
import 'features/seller/seller_profile_screen.dart';
import 'features/seller/settings_screen.dart';
import 'features/buyer/buyer_shell.dart';
import 'features/buyer/buyer_home_screen.dart';
import 'features/buyer/buyer_map_screen.dart';
import 'features/buyer/buyer_listing_detail_screen.dart';
import 'features/buyer/buyer_seller_profile_screen.dart';
import 'features/buyer/saved_sellers_screen.dart';
import 'features/buyer/my_reservations_screen.dart';
import 'features/buyer/leave_review_screen.dart';
import 'features/buyer/buyer_profile_screen.dart';
import 'features/notifications/notifications_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _sellerNavigatorKey = GlobalKey<NavigatorState>();
final _buyerNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final storage = ref.read(storageServiceProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/splash',
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ─── Seller Shell ───
      ShellRoute(
        navigatorKey: _sellerNavigatorKey,
        builder: (context, state, child) => SellerShell(child: child),
        routes: [
          GoRoute(
            path: '/seller/dashboard',
            builder: (context, state) => const SellerDashboardScreen(),
          ),
          GoRoute(
            path: '/seller/listings',
            builder: (context, state) => const MyListingsScreen(),
          ),
          GoRoute(
            path: '/seller/products',
            builder: (context, state) => const MyProductsScreen(),
          ),
          GoRoute(
            path: '/seller/route',
            builder: (context, state) => const RoutePlanningScreen(),
          ),
          GoRoute(
            path: '/seller/profile',
            builder: (context, state) => const SellerProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/seller/add-product',
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: '/seller/create-listing',
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: '/seller/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/seller/listing/:id',
        builder: (context, state) => SellerListingDetailScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),

      // ─── Buyer Shell ───
      ShellRoute(
        navigatorKey: _buyerNavigatorKey,
        builder: (context, state, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: '/buyer/home',
            builder: (context, state) => const BuyerHomeScreen(),
          ),
          GoRoute(
            path: '/buyer/map',
            builder: (context, state) => const BuyerMapScreen(),
          ),
          GoRoute(
            path: '/buyer/reservations',
            builder: (context, state) => const MyReservationsScreen(),
          ),
          GoRoute(
            path: '/buyer/profile',
            builder: (context, state) => const BuyerProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/buyer/listing/:id',
        builder: (context, state) => BuyerListingDetailScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/buyer/seller/:id',
        builder: (context, state) => BuyerSellerProfileScreen(sellerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/buyer/saved-sellers',
        builder: (context, state) => const SavedSellersScreen(),
      ),
      GoRoute(
        path: '/buyer/review/:sellerId',
        builder: (context, state) => LeaveReviewScreen(
          sellerId: state.pathParameters['sellerId']!,
        ),
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.toString();
      if (!location.contains('login') && 
          !location.contains('register') && 
          !location.contains('splash')) {
        storage.saveLastRoute(location);
      }
      return null;
    },
  );
});

// Remove old observer classes
