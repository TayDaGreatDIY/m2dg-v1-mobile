import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

final supabase = Supabase.instance.client;

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();

  String? _selectedPosition;
  String? _selectedHomeCourt;
  String? _selectedSkillLevel;
  File? _selectedImage;
  
  List<Map<String, dynamic>> _courts = [];
  bool _loading = false;
  bool _uploadingImage = false;
  String? _error;
  String? _avatarUrl;

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
  void initState() {
    super.initState();
    _loadCourts();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _loadCourts() async {
    try {
      final response = await supabase.from('courts').select('id, name, city').order('name');
      setState(() => _courts = (response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      print('Error loading courts: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      _toast('Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    try {
      setState(() => _uploadingImage = true);

      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/$fileName';

      // Upload to Supabase storage
      await supabase.storage.from('profiles').upload(
            path,
            _selectedImage!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get public URL
      final url = supabase.storage.from('profiles').getPublicUrl(path);
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }

    if (_selectedPosition == null) {
      setState(() => _error = 'Please select a player position.');
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

      // Upload image if selected
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await _uploadImage(user.id);
      }

      // Store profile in database
      await supabase.from('profiles').upsert(
        {
          'user_id': user.id,
          'username': username,
          'display_name': displayName.isEmpty ? username : displayName,
          'preferred_position': _selectedPosition,
          'skill_level': _selectedSkillLevel ?? 'Beginner',
          'bio': _bioCtrl.text.trim(),
          'avatar_url': avatarUrl,
          'favorite_court_id': _selectedHomeCourt,
          'orientation_completed': false,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
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
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Build Your Profile',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your profile so other players can find and connect with you.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Avatar Section
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _selectedImage == null ? cs.primaryContainer : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outline,
                        width: 2,
                      ),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImage == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: cs.onPrimaryContainer, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  'Add Photo',
                                  style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (_uploadingImage)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Username
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Username *',
                  hintText: 'hooper_2024',
                  helperText: 'Your unique identifier (cannot be changed)',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 16),

              // Display Name
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
              const SizedBox(height: 16),

              // Bio
              TextField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell others about yourself, your playing style, etc.',
                  helperText: 'Optional - up to 500 characters',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 16),

              // Player Position (Required)
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: InputDecoration(
                  labelText: 'Player Position *',
                  prefixIcon: const Icon(Icons.sports_basketball_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Required',
                ),
                items: positions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (val) => setState(() => _selectedPosition = val),
              ),
              const SizedBox(height: 16),

              // Skill Level
              DropdownButtonFormField<String>(
                value: _selectedSkillLevel ?? 'Beginner',
                decoration: InputDecoration(
                  labelText: 'Skill Level',
                  prefixIcon: const Icon(Icons.star_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: skillLevels
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (val) => setState(() => _selectedSkillLevel = val),
              ),
              const SizedBox(height: 16),

              // Home Court
              DropdownButtonFormField<String>(
                value: _selectedHomeCourt,
                decoration: InputDecoration(
                  labelText: 'Home Court',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Optional - your favorite court',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._courts.map((c) => DropdownMenuItem(
                        value: c['id'],
                        child: Text('${c['name']} (${c['city']})'),
                      )),
                ],
                onChanged: _loading
                    ? null
                    : (val) => setState(() => _selectedHomeCourt = val),
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

              // Buttons
              FilledButton(
                onPressed: (_loading || _uploadingImage) ? null : _saveProfile,
                child: (_loading || _uploadingImage)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Continue to Onboarding'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
