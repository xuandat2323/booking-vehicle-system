import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import 'go_router_refresh.dart';
import '../../features/auth/forgot_password/forgot_password_screen.dart';
import '../../features/auth/login/login_screen.dart';
import '../../features/auth/register/register_screen.dart';
import '../../features/auth/reset_password/reset_password_screen.dart';
import '../../features/bookings/booking_create_screen.dart';
import '../../features/bookings/booking_detail_screen.dart';
import '../../features/bookings/booking_history_screen.dart';
import '../../features/bookings/payment_webview_screen.dart';
import '../../features/booking/booking_pickup_dropoff_screen.dart';
import '../../features/branches/branch_list_screen.dart';
import '../../features/cars/car_detail_screen.dart';
import '../../features/cars/car_list_screen.dart';
import '../../features/cars/car_tracking_screen.dart';
import '../../features/chatbot/chatbot_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/main_layout.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/invoices/invoice_list_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/notifications/notification_screen.dart';
import '../../features/verification/verification_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_cars_screen.dart';
import '../../features/admin/admin_bookings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);
  final refresh = GoRouterRefreshNotifier(auth);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final isSplash = state.matchedLocation == '/';
      final inAuthFlow = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      if (isSplash) return null;
      if (!loggedIn && !inAuthFlow) return '/login';
      if (loggedIn && inAuthFlow) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),

      // ── Main shell with Bottom Navigation Bar ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainLayout(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cars',
              builder: (c, s) => CarListScreen(
                branchId: s.uri.queryParameters['branchId'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/bookings', builder: (c, s) => const BookingHistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/invoices', builder: (c, s) => const InvoiceListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ──
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/cars/:id',
        builder: (context, state) => CarDetailScreen(carId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/cars/:id/book',
        builder: (context, state) => BookingCreateScreen(carId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/cars/:id/tracking',
        builder: (context, state) => CarTrackingScreen(carId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bookings/:id/pickup-dropoff',
        builder: (context, state) => BookingPickupDropoffScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationScreen()),
      GoRoute(path: '/verification', builder: (context, state) => const VerificationScreen()),
      GoRoute(path: '/chatbot', builder: (context, state) => const ChatbotScreen()),
      GoRoute(path: '/branches', builder: (context, state) => const BranchListScreen()),
      GoRoute(
        path: '/payment-webview',
        builder: (context, state) => PaymentWebviewScreen(paymentUrl: state.extra as String),
      ),

      // ── Admin routes ──
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersScreen()),
      GoRoute(path: '/admin/cars', builder: (context, state) => const AdminCarsScreen()),
      GoRoute(path: '/admin/bookings', builder: (context, state) => const AdminBookingsScreen()),
    ],
  );
});
