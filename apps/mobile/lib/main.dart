import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/courts_page.dart';
import 'screens/court_details_page.dart';

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
