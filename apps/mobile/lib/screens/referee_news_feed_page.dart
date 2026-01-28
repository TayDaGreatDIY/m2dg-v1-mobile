import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RefereeNewsFeedPage extends StatefulWidget {
  const RefereeNewsFeedPage({super.key});

  @override
  State<RefereeNewsFeedPage> createState() => _RefereeNewsFeedPageState();
}

class _RefereeNewsFeedPageState extends State<RefereeNewsFeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _newsFeed = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _videos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFeed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Load all posts/news
      final newsResponse = await supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      // Load challenge questions
      final challengesResponse = await supabase
          .from('challenges')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      // Load video clips (if we have a videos table)
      List<Map<String, dynamic>> videos = [];
      try {
        final videosResponse = await supabase
            .from('video_clips')
            .select('*')
            .order('created_at', ascending: false)
            .limit(50);
        videos = (videosResponse as List).cast<Map<String, dynamic>>();
      } catch (e) {
        print('Note: video_clips table not found: $e');
        videos = [];
      }

      setState(() {
        _newsFeed = (newsResponse as List).cast<Map<String, dynamic>>();
        _challenges = (challengesResponse as List).cast<Map<String, dynamic>>();
        _videos = videos;
        _loading = false;
      });
    } catch (e) {
      print('Error loading feed: $e');
      setState(() {
        _error = 'Error loading feed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referee News Feed'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.newspaper), text: 'News'),
            Tab(icon: Icon(Icons.help), text: 'Questions'),
            Tab(icon: Icon(Icons.video_library), text: 'Challenges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // News Feed Tab
          _buildNewsFeed(cs, tt),
          // Questions Tab
          _buildQuestionsTab(cs, tt),
          // Video Challenges Tab
          _buildVideoChallengesTab(cs, tt),
        ],
      ),
    );
  }

  Widget _buildNewsFeed(ColorScheme cs, TextTheme tt) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_newsFeed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No news yet', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Check back for basketball news and updates',
                style: tt.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newsFeed.length,
        itemBuilder: (context, index) {
          final post = _newsFeed[index];
          return _buildPostCard(post, cs, tt);
        },
      ),
    );
  }

  Widget _buildQuestionsTab(ColorScheme cs, TextTheme tt) {
    if (_challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No questions yet', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Players will ask questions about game rules here',
                style: tt.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _challenges.length,
        itemBuilder: (context, index) {
          final challenge = _challenges[index];
          return _buildChallengeCard(challenge, cs, tt);
        },
      ),
    );
  }

  Widget _buildVideoChallengesTab(ColorScheme cs, TextTheme tt) {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No video challenges yet', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Athletes will upload clips wanting ref reviews',
                style: tt.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          return _buildVideoCard(video, cs, tt);
        },
      ),
    );
  }

  Widget _buildPostCard(
      Map<String, dynamic> post, ColorScheme cs, TextTheme tt) {
    final content = post['content'] as String? ?? '';
    final createdAt = post['created_at'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basketball News',
                        style:
                            tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt.substring(0, 10),
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Latest',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: tt.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    // TODO: Open full post
                  },
                  child: const Text('Read More'),
                ),
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 20, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${post['likes'] ?? 0}',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(
      Map<String, dynamic> challenge, ColorScheme cs, TextTheme tt) {
    final title = challenge['description'] as String? ?? 'Challenge';
    final status = challenge['status'] as String? ?? 'open';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Player Question',
                              style: tt.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: tt.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'open'
                    ? cs.tertiaryContainer
                    : cs.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: status == 'open'
                      ? cs.onTertiaryContainer
                      : cs.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                // TODO: Respond to question
              },
              child: const Text('Provide Answer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(
      Map<String, dynamic> video, ColorScheme cs, TextTheme tt) {
    final title = video['title'] as String? ?? 'Challenge Video';
    final description = video['description'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_camera_back, size: 24, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: tt.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: tt.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            // Video thumbnail placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      // TODO: Watch video
                    },
                    child: const Text('Watch'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: Comment/Review
                    },
                    child: const Text('Review'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
