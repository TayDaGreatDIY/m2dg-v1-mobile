import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/referee_profile.dart';
import 'package:mobile/services/referee_service.dart';

final supabase = Supabase.instance.client;

class RefereeProfilePage extends StatefulWidget {
  final String? refereeId;

  const RefereeProfilePage({this.refereeId, super.key});

  @override
  State<RefereeProfilePage> createState() => _RefereeProfilePageState();
}

class _RefereeProfilePageState extends State<RefereeProfilePage> {
  late Future<RefereeProfile> _profileFuture;
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    final userId = widget.refereeId ?? supabase.auth.currentUser?.id;
    if (userId != null) {
      _profileFuture = RefereeService.fetchRefereeProfile(userId);
      _statsFuture = RefereeService.getRefereeStats(userId);
    }
  }

  String get refereeId => widget.refereeId ?? supabase.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏀 Referee Profile'),
        centerTitle: true,
        leading: widget.refereeId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<RefereeProfile>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('❌ Failed to load referee profile'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      final userId = refereeId;
                      if (userId.isNotEmpty) {
                        _profileFuture =
                            RefereeService.fetchRefereeProfile(userId);
                        _statsFuture = RefereeService.getRefereeStats(userId);
                      }
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final profile = profileSnapshot.data;
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profile.profilePictureUrl != null
                            ? NetworkImage(profile.profilePictureUrl!)
                            : null,
                        backgroundColor: cs.primaryContainer,
                        child: profile.profilePictureUrl == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: cs.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.displayName,
                        style: tt.headlineSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile.isVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            label: const Text('✅ Verified Referee'),
                            backgroundColor: Colors.green.withValues(alpha: 0.3),
                            labelStyle: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _statsFuture,
                    builder: (context, statsSnapshot) {
                      final stats = statsSnapshot.data ?? {};
                      final gamesRefereed =
                          stats['games_refereed'] as int? ?? 0;
                      final rating = stats['average_rating'] as double? ?? 0.0;
                      final yearsExp =
                          stats['years_experience'] as int? ?? 0;

                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Games Refereed',
                              value: gamesRefereed.toString(),
                              icon: Icons.sports_basketball,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Average Rating',
                              value: rating.toStringAsFixed(1),
                              icon: Icons.star,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Years Experience',
                              value: yearsExp.toString(),
                              icon: Icons.calendar_month,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Bio section
                if (profile.bio != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.bio!,
                          style: tt.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                if (profile.bio != null) const SizedBox(height: 24),

                // Availability
                if (profile.availability != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Availability',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(profile.availability!),
                          backgroundColor: cs.secondaryContainer,
                          labelStyle: TextStyle(
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (profile.availability != null) const SizedBox(height: 24),

                // Certificates
                if (profile.certificates != null && profile.certificates!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Certificates & Qualifications',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: profile.certificates!.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    profile.certificates![index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHigh,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (profile.certificates != null && profile.certificates!.isNotEmpty)
                  const SizedBox(height: 24),

                // Social media links
                if (profile.socialMediaLinks != null && profile.socialMediaLinks!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Follow On Social Media',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: profile.socialMediaLinks!
                              .map((link) => Chip(
                                    label: const Text('View Profile'),
                                    avatar: const Icon(Icons.open_in_new),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                if (profile.socialMediaLinks != null && profile.socialMediaLinks!.isNotEmpty)
                  const SizedBox(height: 24),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
