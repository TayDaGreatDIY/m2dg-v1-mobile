import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Store profile in database (upsert profiles table)
      await supabase.from('profiles').upsert(
        {
          'id': user.id,
          'username': username,
          'display_name': displayName.isEmpty ? username : displayName,
          'show_onboarding': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (!mounted) return;
      _toast('Profile created!');
      context.go('/onboarding');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete Your Profile',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a username and display name to get started.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.outline,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _usernameCtrl.text.isEmpty
                          ? '?'
                          : _usernameCtrl.text.substring(0, 1).toUpperCase(),
                      style: tt.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Avatar (generated from username)',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'hooper_2024',
                  helperText: 'This is your unique identifier',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_loading,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Your Full Name',
                  helperText: 'Optional - defaults to username',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_loading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
