// lib/screens/court_details_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';
import '../models/court_queue.dart';
import '../services/checkin_service.dart';
import '../services/court_queue_service.dart';
import '../services/developer_mode_service.dart';

class CourtDetailsPage extends StatefulWidget {
  final String courtId;

  /// Optional: if you navigate from list you can pass the whole court map via `state.extra`
  final Map<String, dynamic>? court;

  /// Only used in debug builds (lets you “pretend” your GPS is at the court)
  final bool debugPinToCourtCoordsDefault;

  const CourtDetailsPage({
    super.key,
    required this.courtId,
    this.court,
    this.debugPinToCourtCoordsDefault = false,
  });

  @override
  State<CourtDetailsPage> createState() => _CourtDetailsPageState();
}

class _CourtDetailsPageState extends State<CourtDetailsPage> {
  final supabase = Supabase.instance.client;

  late final CheckInService _checkins;

  bool _loading = true;
  bool _checkingIn = false;
  bool _leavingGame = false;

  // Court data
  Map<String, dynamic>? _court;
  bool _courtLoading = false;

  DateTime? _lastCheckinUtc;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _tick;

  int? _distanceMeters;
  double? _accuracyMeters;

  int _myTotalHere = 0;
  List<Map<String, dynamic>> _recentCheckins = const [];

  bool _devPinToCourtCoords = false;
  bool _devModeEnabled = false;
  bool _devSimulateGps = false;

  // Track if user is in queue/game
  bool _inQueueOrGame = false;

  // Queue management
  List<CourtQueue> _queueList = const [];
  CourtQueue? _userQueueEntry;
  bool _joiningQueue = false;
  bool _loadingQueue = false;

  // Challenges management
  List<Challenge> _activeChallenges = const [];
  bool _loadingChallenges = false;

  // Real-time subscriptions
  late final RealtimeChannel _queueChannel;
  late final RealtimeChannel _challengesChannel;

  @override
  void initState() {
    super.initState();

    _checkins = CheckInService(supabase);
    _devPinToCourtCoords = kDebugMode && widget.debugPinToCourtCoordsDefault;

    _court = widget.court;

    _loadDeveloperSettings();
    _loadCourtIfNeeded();
    _loadActivity();
    _loadQueue();
    _setupQueueSubscription();
    _loadChallenges();
    _setupChallengesSubscription();
  }

  Future<void> _loadDeveloperSettings() async {
    final devMode = await DeveloperModeService.isDeveloperMode();
    final simGps = await DeveloperModeService.isGpsSimulationEnabled();
    if (mounted) {
      setState(() {
        _devModeEnabled = devMode;
        _devSimulateGps = simGps;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    supabase.removeChannel(_queueChannel);
    supabase.removeChannel(_challengesChannel);
    super.dispose();
  }

  // ----------------------------
  // Court load (if not provided)
  // ----------------------------

  Future<void> _loadCourtIfNeeded() async {
    if (_court != null) return;

    setState(() => _courtLoading = true);

    try {
      final row = await supabase
          .from('courts')
          .select()
          .eq('id', widget.courtId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _court = (row is Map<String, dynamic>) ? row : null;
        _courtLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _courtLoading = false);
      _toast('Failed to load court: $e');
    }
  }

  // ----------------------------
  // Data loading / cooldown timer
  // ----------------------------

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        // still show court UI; activity will be empty
        setState(() {
          _loading = false;
          _myTotalHere = 0;
          _recentCheckins = const [];
          _lastCheckinUtc = null;
          _cooldownRemaining = Duration.zero;
        });
        return;
      }

      // 1) last check-in (for cooldown)
      final lastRows = await supabase
          .from('checkins')
          .select('created_at')
          .eq('court_id', widget.courtId)
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      DateTime? lastUtc;
      final lastList = (lastRows as List).cast<dynamic>();
      if (lastList.isNotEmpty) {
        final createdAt = (lastList.first as Map)['created_at'];
        if (createdAt is String) {
          lastUtc = DateTime.tryParse(createdAt)?.toUtc();
        }
      }

      // 2) total check-ins here (simple count)
      final myRows = await supabase
          .from('checkins')
          .select('id')
          .eq('court_id', widget.courtId)
          .eq('user_id', user.id);

      final myTotalHere = (myRows as List).length;

      // 3) recent check-ins at this court (last 5)
      final recent = await supabase
          .from('checkins')
          .select('user_id, created_at')
          .eq('court_id', widget.courtId)
          .order('created_at', ascending: false)
          .limit(5);

      final recentList = (recent as List).cast<Map<String, dynamic>>();

      // 4) check if user is in queue/game (court_queues)
      final queueRows = await supabase
          .from('court_queues')
          .select('id, status')
          .eq('court_id', widget.courtId)
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      bool inQueueOrGame = false;
      if (queueRows.isNotEmpty) {
        final status = (queueRows.first as Map)['status'] as String?;
        if (status == 'waiting' || status == 'called_next' || status == 'checked_in') {
          inQueueOrGame = true;
        }
      }

      setState(() {
        _lastCheckinUtc = lastUtc;
        _myTotalHere = myTotalHere;
        _recentCheckins = recentList;
        _inQueueOrGame = inQueueOrGame;
        _loading = false;
      });

      // Cooldown starts when you check in (lastUtc exists)
      // Shows regardless of queue status - it's a court-wide cooldown
      if (lastUtc != null) {
        _recomputeCooldownAndTicker();
      } else {
        _cooldownRemaining = Duration.zero;
        _tick?.cancel();
        _tick = null;
      }
    } catch (e) {
      setState(() => _loading = false);
      _toast('Failed to load court activity: $e');
    }
  }

  // ----------------------------
  // Queue loading and refresh
  // ----------------------------

  Future<void> _loadQueue() async {
    if (_loadingQueue) return;

    setState(() => _loadingQueue = true);

    try {
      // Get the full queue for this court
      final queue = await CourtQueueService.getCourtQueue(widget.courtId);

      // Check if current user is in queue
      final user = supabase.auth.currentUser;
      CourtQueue? userEntry;
      if (user != null) {
        userEntry = queue.where((q) => q.userId == user.id).firstOrNull;
      }

      if (!mounted) return;

      setState(() {
        _queueList = queue;
        _userQueueEntry = userEntry;
        _loadingQueue = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingQueue = false);
      print('Error loading queue: $e');
    }
  }

  Future<void> _joinQueue() async {
    if (_joiningQueue) return;

    setState(() => _joiningQueue = true);

    try {
      final queueEntry = await CourtQueueService.joinQueue(widget.courtId);
      
      if (!mounted) return;

      setState(() {
        _userQueueEntry = queueEntry;
        _joiningQueue = false;
      });

      _toast('Joined queue at position ${queueEntry.positionInQueue}');
      
      // Reload the full queue
      await _loadQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningQueue = false);
      _toast('Failed to join queue: $e');
    }
  }

  Future<void> _leaveQueue() async {
    if (_joiningQueue || _userQueueEntry == null) return;

    setState(() => _joiningQueue = true);

    try {
      final queueIdToRemove = _userQueueEntry!.id;
      
      await CourtQueueService.leaveQueue(queueIdToRemove);

      if (!mounted) return;

      // Immediately remove from local list to update UI instantly
      setState(() {
        _userQueueEntry = null;
        _queueList = _queueList.where((q) => q.id != queueIdToRemove).toList();
        _joiningQueue = false;
      });

      _toast('Left queue');
      
      // Reload the full queue to sync with DB (subscription will also trigger this)
      await _loadQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningQueue = false);
      _toast('Failed to leave queue: $e');
    }
  }

  Future<void> _refreshQueue() async {
    await _loadQueue();
  }

  // ----------------------------
  // Real-time subscription setup
  // ----------------------------

  void _setupQueueSubscription() {
    try {
      // Subscribe to changes in the court_queues table for this court
      _queueChannel = supabase
          .channel('court_queue:${widget.courtId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'court_queues',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'court_id',
              value: widget.courtId,
            ),
            callback: (payload) {
              // When queue changes, reload the queue data
              _loadQueue();
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up queue subscription: $e');
    }
  }

  Future<void> _loadChallenges() async {
    if (_loadingChallenges) return;

    setState(() => _loadingChallenges = true);

    try {
      // Fetch all active challenges for this court
      final allChallenges = await supabase
          .from('challenges')
          .select()
          .eq('court_id', widget.courtId)
          .inFilter('status', ['open', 'pending_approval', 'accepted', 'in_progress']);

      final challenges = (allChallenges as List)
          .map((json) => Challenge.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        _activeChallenges = challenges;
        _loadingChallenges = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingChallenges = false);
      print('Error loading challenges: $e');
    }
  }

  void _setupChallengesSubscription() {
    try {
      _challengesChannel = supabase
          .channel('court_challenges_${widget.courtId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'challenges',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'court_id',
              value: widget.courtId,
            ),
            callback: (payload) {
              if (mounted) {
                _loadChallenges();
              }
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up challenges subscription: $e');
    }
  }

  void _recomputeCooldownAndTicker() {
    // Always cancel any existing ticker first
    _tick?.cancel();
    _tick = null;

    final last = _lastCheckinUtc;
    if (last == null) {
      setState(() => _cooldownRemaining = Duration.zero);
      return;
    }

    // ✅ IMPORTANT: call with ONE arg (matches your service)
    final remaining = _checkins.computeCooldownRemaining(last);
    setState(() => _cooldownRemaining = remaining);

    // tick each second until zero
    if (remaining > Duration.zero) {
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        // Safety check: if user left court, stop the timer
        if (_lastCheckinUtc == null) {
          t.cancel();
          return;
        }
        
        final r = _checkins.computeCooldownRemaining(last);
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _cooldownRemaining = r);
        if (r == Duration.zero) {
          t.cancel();
        }
      });
    }
  }

  // ----------------------------
  // Check-in action
  // ----------------------------

  Future<void> _checkIn() async {
    if (_checkingIn) return;

    final c = _court;
    if (c == null) {
      _toast('Court not loaded yet.');
      return;
    }

    final lat = _readDouble(c, ['lat', 'latitude']);
    final lng = _readDouble(c, ['lng', 'lon', 'longitude']);
    if (lat == null || lng == null) {
      _toast('Court is missing coordinates (lat/lng).');
      return;
    }

    final radius = _readInt(c, ['radius_meters']) ?? 120;

    setState(() {
      _checkingIn = true;
      _distanceMeters = null;
      _accuracyMeters = null;
    });

    try {
      final res = await _checkins.checkIn(
        courtId: widget.courtId,
        courtLat: lat,
        courtLng: lng,
        radiusMeters: radius,
        debugPinToCourtCoords: kDebugMode && _devPinToCourtCoords,
        devSimulateGps: _devSimulateGps,
      );

      setState(() {
        _distanceMeters = res.distanceMeters;
        _accuracyMeters = res.accuracyMeters;
      });

      if (!res.ok) {
        _toast(res.message);
      } else {
        _toast('Checked in ✅');
      }

      // refresh activity + cooldown
      await _loadActivity();
    } catch (e) {
      _toast('Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _leaveGame() async {
    if (_leavingGame) return;

    setState(() => _leavingGame = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Remove from queue at this court
      await supabase
          .from('court_queues')
          .delete()
          .eq('user_id', user.id)
          .eq('court_id', widget.courtId);

      // Also remove check-in
      await _checkins.leaveGame(widget.courtId);

      // Immediately clear the cooldown, last check-in, and queue/game flag
      setState(() {
        _lastCheckinUtc = null;
        _cooldownRemaining = Duration.zero;
        _inQueueOrGame = false;
      });

      // Cancel the cooldown ticker
      _tick?.cancel();
      _tick = null;

      _toast('You have left the game ✅');

      // Refresh activity to update the recent checkins list and queue/game status
      await _loadActivity();
    } catch (e) {
      _toast('Failed to leave game: $e');
    } finally {
      if (mounted) setState(() => _leavingGame = false);
    }
  }

  Future<void> _leaveCourt() async {
    if (_leavingGame) return;

    setState(() => _leavingGame = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // DELETE from court_queues (remove player from queue only)
      // NOTE: Do NOT clear cooldown - it persists globally for anti-spam
      await supabase
          .from('court_queues')
          .delete()
          .eq('court_id', widget.courtId)
          .eq('user_id', user.id);

      _toast('You have left the court ✅');

      // Update UI state - just clear queue, keep cooldown
      if (mounted) {
        setState(() {
          _inQueueOrGame = false;
          _userQueueEntry = null;
          _queueList = const [];
        });
      }
    } catch (e) {
      _toast('Failed to leave court: $e');
    } finally {
      if (mounted) setState(() => _leavingGame = false);
    }
  }

  // ----------------------------
  // UI helpers
  // ----------------------------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _pill(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // ✅ avoids deprecated surfaceVariant warning
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  // Active challenges display section
  Widget _buildChallengesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Challenges',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!_loadingChallenges)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadChallenges,
                tooltip: 'Refresh challenges',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingChallenges)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_activeChallenges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No active challenges on this court.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeChallenges.length,
            itemBuilder: (context, index) {
              final challenge = _activeChallenges[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                                    challenge.challengeType.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${challenge.status}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                challenge.status == 'open'
                                    ? '🟢 Open'
                                    : challenge.status == 'in_progress'
                                        ? '🔴 Playing'
                                        : '⏳ ${challenge.status}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (challenge.hasWager)
                          Text(
                            '💰 Wager: \$${challenge.wagerAmount?.toStringAsFixed(2) ?? '0.00'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                        if (challenge.status == 'open')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonal(
                                onPressed: () {
                                  _toast('Join challenge feature coming soon!');
                                },
                                child: const Text('Join Challenge'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Queue display section
  Widget _buildQueueSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Court Queue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!_loadingQueue)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshQueue,
                tooltip: 'Refresh queue',
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Queue stats - show count based on actual queue list
        if (_queueList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_queueList.length} player${_queueList.length == 1 ? '' : 's'} waiting',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          )
        else if (!_loadingQueue)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '0 players waiting',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),

        // Join/Leave buttons
        if (_userQueueEntry == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _joiningQueue ? null : _joinQueue,
              child: _joiningQueue
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Queue'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Position: #${_userQueueEntry!.positionInQueue}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${_userQueueEntry!.status}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _joiningQueue ? null : _leaveQueue,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: _joiningQueue
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Leave Queue'),
                ),
              ),
            ],
          ),

        const SizedBox(height: 12),

        // Queue list
        if (_loadingQueue)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_queueList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Queue is empty',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          )
        else
          ..._queueList.map((queue) {
            final isUser = _userQueueEntry?.id == queue.id;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '${queue.positionInQueue}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              title: Text(
                isUser ? 'You' : 'Player ${queue.userId.substring(0, 8)}',
                style: isUser
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )
                    : Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                '${queue.teamSize} player${queue.teamSize == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  queue.status,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            );
          }),
      ],
    );
  }

  bool _isActive(Map<String, dynamic> c) {
    final v = c['is_active'];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  String _courtName(Map<String, dynamic> c) =>
      (c['name'] ?? c['court_name'] ?? '').toString();

  String _courtCity(Map<String, dynamic> c) => (c['city'] ?? '').toString();

  String _courtState(Map<String, dynamic> c) => (c['state'] ?? '').toString();

  int? _readInt(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final v = c[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final v = c[k];
      if (v == null) continue;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }

  // ----------------------------
  // Build
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final c = _court;

    if (_courtLoading && c == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final safe = c ?? <String, dynamic>{};

    final name = _courtName(safe).isEmpty ? 'Court' : _courtName(safe);
    final city = _courtCity(safe);
    final state = _courtState(safe);

    final radius = _readInt(safe, ['radius_meters']);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  [city, state].where((s) => s.trim().isNotEmpty).join(', '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_isActive(safe)) _pill(context, 'Active'),
                    if (radius != null && radius > 0)
                      _pill(context, '$radius m radius'),
                    if (_cooldownRemaining > Duration.zero)
                      _pill(context, 'Cooldown ${_fmt(_cooldownRemaining)}'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: (_checkingIn ||
                                _cooldownRemaining > Duration.zero ||
                                c == null)
                            ? null
                            : _checkIn,
                        child: _checkingIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Check in'),
                      ),
                    ),
                    if (_inQueueOrGame) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _leavingGame ? null : _leaveGame,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: _leavingGame
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Leave Game'),
                        ),
                      ),
                    ],
                    if (!_inQueueOrGame && _cooldownRemaining > Duration.zero) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _leavingGame ? null : _leaveCourt,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: _leavingGame
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Leave Court'),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_distanceMeters != null || _accuracyMeters != null) ...[
                  const SizedBox(height: 12),
                  if (_distanceMeters != null)
                    Text('Distance: ${_distanceMeters}m'),
                  if (_accuracyMeters != null)
                    Text('GPS accuracy: ${_accuracyMeters!.round()}m'),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('DEV: Pin GPS to court coords'),
                    subtitle: const Text(
                      'Pretend your phone is exactly on the court when checking in.',
                    ),
                    value: _devPinToCourtCoords,
                    onChanged: (v) {
                      setState(() => _devPinToCourtCoords = v);
                    },
                  ),
                ],
                if (_devModeEnabled) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🔧 GPS Simulation (Dev)'),
                    subtitle: const Text(
                      'Simulate being close to the court for testing check-ins',
                    ),
                    value: _devSimulateGps,
                    onChanged: (v) async {
                      await DeveloperModeService.setSimulateGps(v);
                      if (mounted) {
                        setState(() => _devSimulateGps = v);
                        _toast(v ? '✅ GPS Simulation ON' : '❌ GPS Simulation OFF');
                      }
                    },
                  ),
                ],
                const SizedBox(height: 18),
                _buildChallengesSection(context),
                const SizedBox(height: 18),
                _buildQueueSection(context),
                const SizedBox(height: 18),
                Text(
                  'Your check-ins here: $_myTotalHere',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Recent check-ins (last 5):',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_recentCheckins.isEmpty)
                  Text(
                    'No recent check-ins yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ..._recentCheckins.map((row) {
                    final createdAt = row['created_at']?.toString() ?? '';
                    final when = DateTime.tryParse(createdAt)?.toLocal();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(when?.toString() ?? createdAt),
                      subtitle: Text('user: ${row['user_id'] ?? ''}'),
                    );
                  }),
              ],
            ),
    );
  }
}
