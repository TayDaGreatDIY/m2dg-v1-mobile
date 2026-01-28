import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

final supabase = Supabase.instance.client;

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  String? _userRole;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final profile = await supabase
          .from('profiles')
          .select('user_role')
          .eq('user_id', userId)
          .single();

      setState(() {
        _userRole = profile['user_role'] as String? ?? 'athlete';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading profile: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadUserRole();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show role-specific form
    if (_userRole == 'referee') {
      return const _RefereeProfileSetup();
    } else if (_userRole == 'verified_scorer') {
      return const _VerifiedScorerProfileSetup();
    } else if (_userRole == 'parent') {
      return const _ParentProfileSetup();
    } else {
      return const _AthleteProfileSetup();
    }
  }
}

// ==================== REFEREE PROFILE ====================
class _RefereeProfileSetup extends StatefulWidget {
  const _RefereeProfileSetup();

  @override
  State<_RefereeProfileSetup> createState() => _RefereeProfileSetupState();
}

class _RefereeProfileSetupState extends State<_RefereeProfileSetup> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  final TextEditingController _yearsExperienceCtrl = TextEditingController();
  final TextEditingController _gamesPerWeekCtrl = TextEditingController();

  File? _selectedImage;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _yearsExperienceCtrl.dispose();
    _gamesPerWeekCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameCtrl.text.isEmpty || _displayNameCtrl.text.isEmpty) {
      setState(() => _error = 'Username and display name are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      String? avatarUrl;
      if (_selectedImage != null && !kIsWeb) {
        // Upload image (mobile only)
        final fileName = 'referee_$userId.jpg';
        await supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // Update profile
      await supabase.from('profiles').upsert(
        {
          'user_id': userId,
          'username': _usernameCtrl.text,
          'display_name': _displayNameCtrl.text,
          'avatar_url': avatarUrl,
          'orientation_completed': true,
          'user_role': 'referee',
        },
        onConflict: 'user_id',
      );

      // Create/update referee profile
      await supabase.from('referee_profiles').upsert(
        {
          'user_id': userId,
          'display_name': _displayNameCtrl.text,
          'profile_picture_url': avatarUrl,
          'years_experience': int.tryParse(_yearsExperienceCtrl.text) ?? 0,
          'bio': _bioCtrl.text,
          'games_refereed_total': 0,
          'average_rating': 0.0,
          'is_verified': false,
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error saving profile: $e');
      }
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
        title: const Text('Referee Profile Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : null,
                    backgroundColor: cs.primaryContainer,
                    child: _selectedImage == null
                        ? Icon(Icons.person, size: 50, color: cs.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Username
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: 'Username *',
                hintText: 'referee_username',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Display Name
            TextField(
              controller: _displayNameCtrl,
              decoration: InputDecoration(
                labelText: 'Display Name *',
                hintText: 'Your Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Years of Experience
            TextField(
              controller: _yearsExperienceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Years of Refereeing Experience',
                hintText: '5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Games Per Week
            TextField(
              controller: _gamesPerWeekCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Games Looking to Ref Per Week',
                hintText: '3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Bio/About You',
                hintText: 'Tell other players about your refereeing experience...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
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
              const SizedBox(height: 16),
            ],

            FilledButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== VERIFIED SCORER PROFILE ====================
class _VerifiedScorerProfileSetup extends StatefulWidget {
  const _VerifiedScorerProfileSetup();

  @override
  State<_VerifiedScorerProfileSetup> createState() =>
      _VerifiedScorerProfileSetupState();
}

class _VerifiedScorerProfileSetupState
    extends State<_VerifiedScorerProfileSetup> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _certificationCtrl = TextEditingController();
  final TextEditingController _accuracyGoalCtrl = TextEditingController();

  File? _selectedImage;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _certificationCtrl.dispose();
    _accuracyGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameCtrl.text.isEmpty || _displayNameCtrl.text.isEmpty) {
      setState(() => _error = 'Username and display name are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      String? avatarUrl;
      if (_selectedImage != null && !kIsWeb) {
        final fileName = 'scorer_$userId.jpg';
        await supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // Update profile
      await supabase.from('profiles').upsert(
        {
          'user_id': userId,
          'username': _usernameCtrl.text,
          'display_name': _displayNameCtrl.text,
          'avatar_url': avatarUrl,
          'orientation_completed': true,
          'user_role': 'verified_scorer',
        },
        onConflict: 'user_id',
      );

      // Create game keeper profile
      await supabase.from('game_keeper_profiles').upsert(
        {
          'user_id': userId,
          'display_name': _displayNameCtrl.text,
          'profile_picture_url': avatarUrl,
          'certification_date': DateTime.now().toIso8601String(),
          'bio': _certificationCtrl.text,
          'games_kept_total': 0,
          'average_accuracy': double.tryParse(_accuracyGoalCtrl.text) ?? 95.0,
          'is_verified': false,
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error saving profile: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Scorer Profile Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : null,
                    backgroundColor: cs.primaryContainer,
                    child: _selectedImage == null
                        ? Icon(Icons.person, size: 50, color: cs.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: 'Username *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameCtrl,
              decoration: InputDecoration(
                labelText: 'Display Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _certificationCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Certifications/Experience',
                hintText: 'List your scoring certifications...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accuracyGoalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Accuracy Goal (%)',
                hintText: '98',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
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
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PARENT PROFILE ====================
class _ParentProfileSetup extends StatefulWidget {
  const _ParentProfileSetup();

  @override
  State<_ParentProfileSetup> createState() => _ParentProfileSetupState();
}

class _ParentProfileSetupState extends State<_ParentProfileSetup> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _childrenNamesCtrl = TextEditingController();

  File? _selectedImage;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _childrenNamesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameCtrl.text.isEmpty || _displayNameCtrl.text.isEmpty) {
      setState(() => _error = 'Username and display name are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      String? avatarUrl;
      if (_selectedImage != null && !kIsWeb) {
        final fileName = 'parent_$userId.jpg';
        await supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      await supabase.from('profiles').upsert(
        {
          'user_id': userId,
          'username': _usernameCtrl.text,
          'display_name': _displayNameCtrl.text,
          'avatar_url': avatarUrl,
          'bio': _childrenNamesCtrl.text,
          'orientation_completed': true,
          'user_role': 'parent',
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error saving profile: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent/Guardian Profile Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : null,
                    backgroundColor: cs.primaryContainer,
                    child: _selectedImage == null
                        ? Icon(Icons.person, size: 50, color: cs.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: 'Username *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameCtrl,
              decoration: InputDecoration(
                labelText: 'Display Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _childrenNamesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Children\'s Names & Ages',
                hintText: 'John (12), Sarah (14)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
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
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ATHLETE PROFILE ====================
class _AthleteProfileSetup extends StatefulWidget {
  const _AthleteProfileSetup();

  @override
  State<_AthleteProfileSetup> createState() => _AthleteProfileSetupState();
}

class _AthleteProfileSetupState extends State<_AthleteProfileSetup> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();

  String? _selectedPosition;
  String? _selectedSkillLevel;
  File? _selectedImage;
  bool _loading = false;
  String? _error;

  static const List<String> positions = [
    'Point Guard',
    'Shooting Guard',
    'Small Forward',
    'Power Forward',
    'Center',
  ];

  static const List<String> skillLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Pro',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameCtrl.text.isEmpty || _displayNameCtrl.text.isEmpty) {
      setState(() => _error = 'Username and display name are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      String? avatarUrl;
      if (_selectedImage != null && !kIsWeb) {
        final fileName = 'athlete_$userId.jpg';
        await supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      await supabase.from('profiles').upsert(
        {
          'user_id': userId,
          'username': _usernameCtrl.text,
          'display_name': _displayNameCtrl.text,
          'avatar_url': avatarUrl,
          'preferred_position': _selectedPosition,
          'skill_level': _selectedSkillLevel,
          'orientation_completed': true,
          'user_role': 'athlete',
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error saving profile: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete Profile Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : null,
                    backgroundColor: cs.primaryContainer,
                    child: _selectedImage == null
                        ? Icon(Icons.person, size: 50, color: cs.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: 'Username *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameCtrl,
              decoration: InputDecoration(
                labelText: 'Display Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPosition,
              items: positions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPosition = v),
              decoration: InputDecoration(
                labelText: 'Preferred Position *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSkillLevel,
              items: skillLevels
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSkillLevel = v),
              decoration: InputDecoration(
                labelText: 'Skill Level *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
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
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
