import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:ui';
import 'package:glass_kit/glass_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_providers.dart';
import '../providers/auth_providers.dart';
import '../data/models/dashboard_model.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import 'login_screen.dart';
import 'create_appointment_screen.dart';
import 'create_prescription_screen.dart';
import 'doctor_calendar_screen.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'medical_records_screen.dart';
import 'invoices_screen_modern.dart';
import 'create_medical_record_screen.dart';
import '../core/config/api_constants.dart';
import '../widgets/app_drawer.dart';

final dashboardFilterProvider = StateProvider<String>((ref) => 'All Doctors');

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
    _backgroundController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final timeRange = ref.watch(timeRangeProvider);

    final dashboardAsync = authState.isAuth == true
        ? ref.watch(dashboardDataProvider(timeRange))
        : const AsyncValue<Result<DashboardModel>>.loading();

    final refresh = ref.watch(dashboardRefreshProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuth == false && previous?.isAuth == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });

    if (authState.isAuth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isAuth == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: _buildModernAppBar(context, authState, timeRange, ref),
      body: Stack(
        children: [
          _buildAnimatedBackground(context),
          dashboardAsync.when(
            data: (result) {
              if (result is Success<DashboardModel>) {
                final dashboardData = result.data;
                return RefreshIndicator(
                  onRefresh: () async {
                    refresh(timeRange);
                    await ref.read(dashboardDataProvider(timeRange).future);
                  },
                  child: _buildResponsiveLayout(context, authState,
                      dashboardData, ref, timeRange, refresh),
                );
              } else if (result is Failure<DashboardModel>) {
                return CustomErrorWidget(
                  message: result.message,
                  onRetry: () => refresh(timeRange),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) => CustomErrorWidget(
              message: error.toString(),
              onRetry: () => refresh(timeRange),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildModernFAB(context, authState.user, ref),
    );
  }

  Widget _buildAnimatedBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                0.3 + (_backgroundAnimation.value * 0.2),
                0.7 + (_backgroundAnimation.value * 0.2),
                1.0,
              ],
              colors: isDark
                  ? [
                      const Color(0xFF0A0A0F),
                      const Color(0xFF1A1A2E)
                          .withOpacity(0.8 + _backgroundAnimation.value * 0.2),
                      primaryColor
                          .withOpacity(0.1 + _backgroundAnimation.value * 0.1),
                      const Color(0xFF16213E).withOpacity(0.6),
                    ]
                  : [
                      const Color(0xFFF8FAFC),
                      Colors.white.withOpacity(0.9),
                      primaryColor.withOpacity(
                          0.05 + _backgroundAnimation.value * 0.05),
                      const Color(0xFFF1F5F9).withOpacity(0.8),
                    ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingShapes(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        // Floating circle 1
        Positioned(
          top: 100,
          right: -50,
          child: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _backgroundAnimation.value * 30,
                  _backgroundAnimation.value * 20,
                ),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.1),
                        primaryColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Floating circle 2
        Positioned(
          bottom: 200,
          left: -100,
          child: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -_backgroundAnimation.value * 20,
                  _backgroundAnimation.value * 15,
                ),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color(0xFF6366F1).withOpacity(0.08)
                            : const Color(0xFF8B5CF6).withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Floating circle 3
        Positioned(
          top: 300,
          left: MediaQuery.of(context).size.width * 0.3,
          child: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _backgroundAnimation.value * 25,
                  -_backgroundAnimation.value * 10,
                ),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context,
    AuthState authState,
    String timeRange,
    WidgetRef ref,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallMobile = screenWidth < 450;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF0F0F23).withOpacity(0.8)
          : Colors.white.withOpacity(0.8),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0F0F23).withOpacity(0.9),
                        const Color(0xFF1A1A2E).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      title: const Text(
        'Dashboard',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      actions: [
        // Calendar & Appointment buttons for mobile (prioritized/conditional on very small screens)
        if (screenWidth < 600) ...[
          if (authState.user != null &&
              (authState.user!.isAdmin == 1 ||
                  authState.user!.isDoctor == 1 ||
                  authState.user!.isReceptionist == 1))
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              ),
            ),
          if (authState.user != null &&
              (authState.user!.isAdmin == 1 ||
                  authState.user!.isReceptionist == 1 ||
                  authState.user!.isPatient == 1))
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              tooltip: 'Créer un Rendez-vous',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateAppointmentScreen()),
              ),
            ),
          // On very small, hide medication if crowding
          if (!isVerySmallMobile &&
              authState.user != null &&
              (authState.user!.isAdmin == 1 || authState.user!.isDoctor == 1))
            IconButton(
              icon: const Icon(Icons.medication_rounded, size: 20),
              tooltip: 'Créer une Ordonnance',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreatePrescriptionScreen()),
              ),
            ),
        ],

        // Time Range Chips (smaller on mobile)
        if (!isVerySmallMobile ||
            screenWidth >
                400) // Hide chips on tiniest screens to prevent overflow
          _buildTimeRangeChips(context, timeRange, ref, isVerySmallMobile),

        const SizedBox(width: 8),

        // User Menu (modern from old)
        if (authState.user != null)
          PopupMenuButton(
            offset: const Offset(0, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      (authState.user!.name ?? authState.user!.email ?? 'U')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (MediaQuery.of(context).size.width > 600) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        authState.user!.name ?? authState.user!.email ?? 'User',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<dynamic>>[
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18),
                    const SizedBox(width: 12),
                    Text(authState.user!.name ?? 'User'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: () => _showLogoutDialog(context, ref),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTimeRangeChips(
      BuildContext context, String timeRange, WidgetRef ref, bool isVerySmall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: ['day', 'week', 'month'].map((range) {
          final isSelected = timeRange == range;
          return GestureDetector(
            onTap: () => ref.read(timeRangeProvider.notifier).state = range,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: isVerySmall ? 6 : 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                range[0].toUpperCase() + range.substring(1),
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontSize: isVerySmall ? 10 : 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    AuthState authState,
    DashboardModel dashboardData,
    WidgetRef ref,
    String timeRange,
    Function(String) refresh,
  ) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600 && size.width < 1024;
    final isDesktop = size.width >= 1024;

    return Stack(
      children: [
        // Floating background shapes
        _buildFloatingShapes(context),
        // Main content
        SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Welcome Banner
              if (authState.user != null)
                _buildModernWelcomeBanner(context, authState.user!),

              const SizedBox(height: 28),

              // Create Appointment Card
              if (authState.user != null &&
                  (authState.user!.isAdmin == 1 ||
                      authState.user!.isReceptionist == 1 ||
                      authState.user!.isPatient == 1))
                _buildCreateAppointmentCard(context),

              // Create Prescription Card
              if (authState.user != null &&
                  (authState.user!.isDoctor == 1 ||
                      authState.user!.isAdmin == 1))
                _buildCreatePrescriptionCard(context),

              const SizedBox(height: 28),

              // Navigation Cards Section
              if (authState.user != null)
                _buildNavigationCards(
                    context, authState.user!, isDesktop, isTablet),

              // Main Content based on role
              if (authState.user != null) ...[
                if (authState.user!.isAdmin == 1 && dashboardData.admin != null)
                  _buildAdminDashboard(context, dashboardData.admin!, ref,
                      timeRange, isDesktop, isTablet),
                if (authState.user!.isDoctor == 1 &&
                    dashboardData.doctor != null)
                  _buildDoctorDashboard(
                      context, dashboardData.doctor!, isDesktop, isTablet),
                if (authState.user!.isPatient == 1 &&
                    dashboardData.patient != null)
                  _buildPatientDashboard(
                      context, dashboardData.patient!, isDesktop, isTablet),
                if (authState.user!.isReceptionist == 1 &&
                    dashboardData.receptionist != null)
                  _buildReceptionistDashboard(context,
                      dashboardData.receptionist!, isDesktop, isTablet),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernWelcomeBanner(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentHour = DateTime.now().hour;
    String greeting = 'Good morning';
    IconData greetingIcon = Icons.wb_sunny_rounded;

    if (currentHour >= 12 && currentHour < 17) {
      greeting = 'Good afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (currentHour >= 17) {
      greeting = 'Good evening';
      greetingIcon = Icons.nights_stay_rounded;
    }

    return GlassContainer.clearGlass(
      height: 140,
      width: double.infinity,
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF1A1A2E).withOpacity(0.9),
                const Color(0xFF16213E).withOpacity(0.7),
                primaryColor.withOpacity(0.3),
              ]
            : [
                Colors.white.withOpacity(0.9),
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.2),
              ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(isDark ? 0.2 : 0.4),
          primaryColor.withOpacity(0.3),
        ],
      ),
      borderColor: Colors.white.withOpacity(isDark ? 0.2 : 0.3),
      blur: 20,
      borderWidth: 1.5,
      elevation: 12,
      shadowColor: primaryColor.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        greetingIcon,
                        size: 18,
                        color: isDark ? Colors.amber : primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name ?? 'User',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                      height: 1.1,
                    ),
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withOpacity(0.8),
                    primaryColor.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
        begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  // Placeholder methods for other components
  Widget _buildCreateAppointmentCard(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Create Appointment Card'),
      ),
    );
  }

  Widget _buildCreatePrescriptionCard(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Create Prescription Card'),
      ),
    );
  }

  Widget _buildNavigationCards(
      BuildContext context, dynamic user, bool isDesktop, bool isTablet) {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Navigation Cards'),
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, Map<String, dynamic> data,
      WidgetRef ref, String timeRange, bool isDesktop, bool isTablet) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Admin Dashboard'),
      ),
    );
  }

  Widget _buildDoctorDashboard(BuildContext context, Map<String, dynamic> data,
      bool isDesktop, bool isTablet) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Doctor Dashboard'),
      ),
    );
  }

  Widget _buildPatientDashboard(BuildContext context, Map<String, dynamic> data,
      bool isDesktop, bool isTablet) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Patient Dashboard'),
      ),
    );
  }

  Widget _buildReceptionistDashboard(BuildContext context,
      Map<String, dynamic> data, bool isDesktop, bool isTablet) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Receptionist Dashboard'),
      ),
    );
  }

  Widget _buildModernFAB(BuildContext context, dynamic user, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickActionsSheet(context, user, ref),
      label: const Text('Quick Actions'),
      icon: const Icon(Icons.add_rounded),
      elevation: 4,
    );
  }

  void _showQuickActionsSheet(
      BuildContext context, dynamic user, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh Dashboard'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(dashboardRefreshProvider)(ref.read(timeRangeProvider));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
