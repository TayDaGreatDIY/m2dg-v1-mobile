import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/session_manager.dart';
import 'screens/courts_page.dart';
import 'screens/court_details_page.dart';
import 'screens/sign_in_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/role_selection_page.dart';
import 'screens/profile_setup_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/challenges_page.dart';
import 'screens/create_challenge_page.dart';
import 'screens/challenge_details_page.dart';
import 'screens/opponent_search_page.dart';
import 'screens/leaderboard_page.dart';
import 'screens/profile_page.dart';
import 'screens/player_profile_page.dart';
import 'screens/notifications_page.dart';
import 'screens/active_game_page.dart';
import 'screens/game_waiting_page.dart';
import 'screens/social_page.dart';
import 'screens/messages_page.dart';
import 'screens/messages_inbox_page.dart';
import 'screens/court_admin_page.dart';
import 'screens/referee_dashboard_page.dart';
import 'screens/referee_profile_page.dart';
import 'screens/developer_panel_page.dart';
import 'screens/game_scoring_page.dart';
import 'widgets/main_shell.dart';

/// M2DGv1 - Mobile (Flutter)
/// Step A: Courts list -> Court details
/// Step B: Courts list UX polish
/// Step C: Check-in (Location REQUIRED)
///
/// Update: Sticky confirmation modal after successful check-in
/// (stays until user dismisses)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('Missing SUPABASE_URL in .env');
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_ANON_KEY in .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,
  );

  runApp(const M2DGApp());
}

final supabase = Supabase.instance.client;
late SessionManager sessionManager; // Global session manager for activity tracking

class M2DGApp extends StatefulWidget {
  const M2DGApp({super.key});

  @override
  State<M2DGApp> createState() => _M2DGAppState();
}

class _M2DGAppState extends State<M2DGApp> {
  late final GoRouter _router;
  late final ValueNotifier<bool> _authStateNotifier;

  @override
  void initState() {
    super.initState();
    
    // Initialize session manager for inactivity timeout
    sessionManager = SessionManager(supabase: supabase);
    sessionManager.startMonitoring();
    
    // Initialize auth state notifier
    _authStateNotifier = ValueNotifier<bool>(supabase.auth.currentUser != null);
    
    // Listen to auth state changes and rebuild router
    supabase.auth.onAuthStateChange.listen((event) {
      _authStateNotifier.value = event.session != null;
    });
    
    _router = GoRouter(
      refreshListenable: _authStateNotifier,
      routes: [
        GoRoute(
          path: '/sign-in',
          name: 'signIn',
          builder: (context, state) => const SignInPage(),
        ),
        GoRoute(
          path: '/sign-up',
          name: 'signUp',
          builder: (context, state) => const SignUpPage(),
        ),
        GoRoute(
          path: '/role-selection',
          name: 'roleSelection',
          builder: (context, state) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: '/profile-setup',
          name: 'profileSetup',
          builder: (context, state) => const ProfileSetupPage(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        // Main app routes wrapped in MainShell (bottom nav)
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              name: 'courts',
              builder: (context, state) => const CourtsPage(),
            ),
            GoRoute(
              path: '/courts/:id',
              name: 'courtDetails',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final court = state.extra as Map<String, dynamic>?;
                return CourtDetailsPage(courtId: id, court: court);
              },
            ),
            GoRoute(
              path: '/challenges',
              name: 'challenges',
              builder: (context, state) => const ChallengesPage(),
            ),
            GoRoute(
              path: '/create-challenge',
              name: 'createChallenge',
              builder: (context, state) => const CreateChallengePage(),
            ),
            GoRoute(
              path: '/challenge/:id',
              name: 'challengeDetails',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ChallengeDetailsPage(challengeId: id);
              },
            ),
            GoRoute(
              path: '/game-waiting/:challengeId',
              name: 'gameWaiting',
              builder: (context, state) {
                final challengeId = state.pathParameters['challengeId']!;
                return GameWaitingPage(challengeId: challengeId);
              },
            ),
            GoRoute(
              path: '/opponent-search',
              name: 'opponentSearch',
              builder: (context, state) {
                final courtId = state.uri.queryParameters['courtId'] ?? '';
                return OpponentSearchPage(courtId: courtId);
              },
            ),
            GoRoute(
              path: '/leaderboard',
              name: 'leaderboard',
              builder: (context, state) => const LeaderboardPage(),
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
            GoRoute(
              path: '/player/:userId',
              name: 'playerProfile',
              builder: (context, state) {
                final userId = state.pathParameters['userId']!;
                return PlayerProfilePage(userId: userId);
              },
            ),
            GoRoute(
              path: '/notifications',
              name: 'notifications',
              builder: (context, state) => const NotificationsPage(),
            ),
            GoRoute(
              path: '/active-game/:courtId',
              name: 'activeGame',
              builder: (context, state) {
                final courtId = state.pathParameters['courtId']!;
                final gameId = state.uri.queryParameters['gameId'];
                return ActiveGamePage(courtId: courtId, gameId: gameId);
              },
            ),
            GoRoute(
              path: '/social',
              name: 'social',
              builder: (context, state) => const SocialPage(),
            ),
            GoRoute(
              path: '/messages-inbox',
              name: 'messagesInbox',
              builder: (context, state) => const MessagesInboxPage(),
            ),
            GoRoute(
              path: '/messages/:recipientId',
              name: 'messages',
              builder: (context, state) {
                final recipientId = state.pathParameters['recipientId']!;
                return MessagesPage(recipientId: recipientId);
              },
            ),
            GoRoute(
              path: '/court-admin/:courtId',
              name: 'courtAdmin',
              builder: (context, state) {
                final courtId = state.pathParameters['courtId']!;
                return CourtAdminPage(courtId: courtId);
              },
            ),
            GoRoute(
              path: '/referee-dashboard',
              name: 'refereeDashboard',
              builder: (context, state) => const RefereeDashboardPage(),
            ),
            GoRoute(
              path: '/referee-profile/:userId',
              name: 'refereeProfile',
              builder: (context, state) {
                final userId = state.pathParameters['userId'];
                return RefereeProfilePage(refereeId: userId);
              },
            ),
            GoRoute(
              path: '/game-scoring/:challengeId',
              name: 'gameScoring',
              builder: (context, state) {
                final challengeId = state.pathParameters['challengeId']!;
                return GameScoringPage(challengeId: challengeId);
              },
            ),
            GoRoute(
              path: '/dev-panel',
              name: 'devPanel',
              builder: (context, state) => const DeveloperPanelPage(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('M2DG')),
        body: Center(child: Text(state.error.toString())),
      ),
      redirect: (context, state) async {
        final user = supabase.auth.currentUser;
        final location = state.matchedLocation;
        final isSigningIn = location == '/sign-in';
        final isSigningUp = location == '/sign-up';
        final isProfileSetup = location == '/profile-setup';
        final isOnboarding = location == '/onboarding';

        print('🔐 AUTH: location=$location, user=${user?.id}');

        // No user: redirect to sign in
        if (user == null) {
          if (isSigningIn || isSigningUp) {
            return null;
          }
          print('🔐 No user, redirecting to /sign-in');
          return '/sign-in';
        }

        // User exists: redirect away from sign in/up pages
        if (isSigningIn || isSigningUp) {
          print('🔐 User logged in, redirecting to /');
          return '/';
        }

        // User exists: check orientation status
        try {
          final profile = await supabase
              .from('profiles')
              .select('orientation_completed')
              .eq('user_id', user.id)
              .single();
          
          final orientationCompleted = profile['orientation_completed'] as bool? ?? false;
          print('🔐 Orientation completed: $orientationCompleted, on page: $location');
          
          // If user hasn't completed orientation and not already there, send them there
          if (!orientationCompleted && !isOnboarding && !isProfileSetup) {
            print('🔐 User not oriented, sending to /onboarding');
            return '/onboarding';
          }
          
          // If user HAS completed orientation, don't show onboarding
          if (orientationCompleted && (isOnboarding || isProfileSetup)) {
            print('🔐 User oriented but on setup page, redirecting to /');
            return '/';
          }
        } catch (e) {
          print('🔐 Error checking orientation: $e');
          // If error, check if user needs profile setup
          if (!isProfileSetup && !isOnboarding) {
            return '/profile-setup';
          }
        }

        print('🔐 User exists, allowing access to current page');
        return null;
      },
    );
  }

  @override
  void dispose() {
    sessionManager.dispose();
    _authStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'M2DG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

/*
final supabase = Supabase.instance.client;

class M2DGApp extends StatelessWidget {
  const M2DGApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'courts',
          builder: (context, state) => const CourtsPage(),
        ),
        GoRoute(
          path: '/courts/:id',
          name: 'courtDetails',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final court = state.extra as Map<String, dynamic>?;
            return CourtDetailsPage(courtId: id, court: court);
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('M2DG')),
        body: Center(child: Text(state.error.toString())),
      ),
    );

    return MaterialApp.router(
      title: 'M2DG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
*/
