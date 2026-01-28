import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Update user profile with role
      await supabase.from('profiles').upsert({
        'user_id': userId,
        'user_role': role,
        'orientation_completed': false,
      });

      if (!mounted) return;
      
      // Navigate to profile setup
      context.go('/profile-setup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What describes you best?',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a role to customize your experience',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Athlete
            _RoleCard(
              title: '🏀 Athlete',
              description: 'Challenge other athletes and compete in games',
              icon: Icons.sports_basketball,
              onTap: _isLoading ? null : () => _selectRole('athlete'),
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Referee
            _RoleCard(
              title: '🏆 Referee',
              description: 'Officiate games and ensure fair play',
              icon: Icons.gavel,
              onTap: _isLoading ? null : () => _selectRole('referee'),
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Verified Scorer
            _RoleCard(
              title: '📊 Verified Scorer',
              description: 'Keep official game scores and stats',
              icon: Icons.assessment,
              onTap: _isLoading ? null : () => _selectRole('verified_scorer'),
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Parent
            _RoleCard(
              title: '👨‍👩‍👧‍👦 Parent/Guardian',
              description: 'Manage challenges for your children',
              icon: Icons.people,
              onTap: _isLoading ? null : () => _selectRole('parent'),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
