import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DeveloperPanelPage extends StatefulWidget {
  const DeveloperPanelPage({super.key});

  @override
  State<DeveloperPanelPage> createState() => _DeveloperPanelPageState();
}

class _DeveloperPanelPageState extends State<DeveloperPanelPage> {
  bool _isLoading = false;

  Future<void> _createTestReferee() async {
    setState(() => _isLoading = true);
    try {
      // Create referee account with valid email format
      final authResponse = await supabase.auth.signUp(
        email: 'testreferee123@example.com',
        password: 'referee123',
      );

      if (authResponse.user == null) throw Exception('Failed to create user');

      final userId = authResponse.user!.id;

      // Update profile
      await supabase.from('profiles').upsert({
        'user_id': userId,
        'display_name': 'Test Referee',
        'orientation_completed': true,
      });

      // Create referee profile
      await supabase.from('referee_profiles').upsert({
        'user_id': userId,
        'display_name': 'Test Referee',
        'games_refereed_total': 42,
        'average_rating': 4.8,
        'is_verified': true,
        'years_experience': 5,
        'bio': 'Experienced referee with 5+ years in court sports',
        'availability': 'Weekends',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Referee created: testreferee123@example.com / referee123'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTestGameKeeper() async {
    setState(() => _isLoading = true);
    try {
      // Create game keeper account with valid email format
      final authResponse = await supabase.auth.signUp(
        email: 'testgamekeeper123@example.com',
        password: 'keeper123',
      );

      if (authResponse.user == null) throw Exception('Failed to create user');

      final userId = authResponse.user!.id;

      // Update profile
      await supabase.from('profiles').upsert({
        'user_id': userId,
        'display_name': 'Test Game Keeper',
        'orientation_completed': true,
      });

      // Create game keeper profile
      await supabase.from('game_keeper_profiles').insert({
        'user_id': userId,
        'display_name': 'Test Game Keeper',
        'games_kept_total': 156,
        'average_accuracy': 98.5,
        'is_verified': true,
        'certification_date': DateTime.now().toIso8601String(),
        'bio': 'Experienced game keeper with verified accuracy',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Game Keeper created: testgamekeeper123@example.com / keeper123'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAllReferees() async {
    setState(() => _isLoading = true);
    try {
      // Update all referees to verified
      await supabase
          .from('referee_profiles')
          .update({'is_verified': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All referees approved!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAllGameKeepers() async {
    setState(() => _isLoading = true);
    try {
      // Update all game keepers to verified
      await supabase
          .from('game_keeper_profiles')
          .update({'is_verified': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All game keepers approved!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Developer Panel'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                '⚠️ Developer panel - for testing only',
                style: tt.labelSmall?.copyWith(color: Colors.orange[900]),
              ),
            ),
            const SizedBox(height: 24),

            // Test Referee Section
            Text(
              'Test Referee Account',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: testreferee123@example.com\nPassword: referee123',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _createTestReferee,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Test Referee'),
            ),
            const SizedBox(height: 24),

            // Test Game Keeper Section
            Text(
              'Test Game Keeper Account',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: testgamekeeper123@example.com\nPassword: keeper123',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _createTestGameKeeper,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Test Game Keeper'),
            ),
            const SizedBox(height: 24),

            // Approval Section
            Divider(),
            const SizedBox(height: 24),
            Text(
              'Bypass Approval (Testing)',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _approveAllReferees,
              child: const Text('Approve All Referees'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _approveAllGameKeepers,
              child: const Text('Approve All Game Keepers'),
            ),
          ],
        ),
      ),
    );
  }
}
