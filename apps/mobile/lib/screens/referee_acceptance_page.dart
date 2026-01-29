import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';

class RefereeAcceptancePage extends StatefulWidget {
  final String challengeId;
  final Map<String, dynamic>? notificationData;

  const RefereeAcceptancePage({
    Key? key,
    required this.challengeId,
    this.notificationData,
  }) : super(key: key);

  @override
  State<RefereeAcceptancePage> createState() => _RefereeAcceptancePageState();
}

class _RefereeAcceptancePageState extends State<RefereeAcceptancePage> {
  late Future<Challenge?> _challengeFuture;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _challengeFuture = _fetchChallenge();
  }

  Future<Challenge?> _fetchChallenge() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('challenges')
          .select()
          .eq('id', widget.challengeId)
          .single();

      return Challenge.fromJson(response);
    } catch (e) {
      print('Error fetching challenge: $e');
      return null;
    }
  }

  Future<void> _acceptReferee() async {
    setState(() => _isAccepting = true);
    try {
      await ChallengeService.acceptRefereRequest(widget.challengeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Referee acceptance confirmed!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Return to referee courts page after 1 second
        await Future.delayed(Duration(seconds: 1));
        if (mounted) context.go('/referee-courts');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting referee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _declineReferee() async {
    setState(() => _isDeclining = true);
    try {
      await ChallengeService.declineRefereRequest(widget.challengeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Referee request declined'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // Return to referee courts page after 1 second
        await Future.delayed(Duration(seconds: 1));
        if (mounted) context.go('/referee-courts');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining referee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeclining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Referee Request'),
        centerTitle: true,
      ),
      body: FutureBuilder<Challenge?>(
        future: _challengeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Challenge not found'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/referee-courts'),
                    child: Text('Back to Courts'),
                  ),
                ],
              ),
            );
          }

          final challenge = snapshot.data!;
          final courtName = widget.notificationData?['court_name'] ?? 'Court';

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.gavel,
                          size: 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Referee Needed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'at $courtName',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Game Details
                Text(
                  'Game Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),

                _buildDetailRow('Challenge ID', challenge.id),
                _buildDetailRow('Court', courtName),
                if (challenge.createdAt != null)
                  _buildDetailRow(
                    'Created',
                    _formatDateTime(challenge.createdAt!),
                  ),

                SizedBox(height: 32),

                // Action Buttons
                Text(
                  'Do you accept this referee assignment?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),

                // Accept Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAccepting ? null : _acceptReferee,
                    icon: _isAccepting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Icon(Icons.check_circle),
                    label: Text(
                      _isAccepting ? 'Accepting...' : 'Accept & Ready to Ref',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Decline Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDeclining ? null : _declineReferee,
                    icon: _isDeclining
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.orange),
                            ),
                          )
                        : Icon(Icons.close),
                    label: Text(
                      _isDeclining ? 'Declining...' : 'Decline',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }
}
