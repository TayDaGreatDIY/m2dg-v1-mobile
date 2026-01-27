import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/services/challenge_service.dart';

final supabase = Supabase.instance.client;

class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({super.key});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  // Challenge type definitions with display name and max players
  final Map<String, Map<String, dynamic>> _challengeTypes = {
    // Core challenges
    '1v1': {'displayName': '1v1', 'maxPlayers': 2, 'category': 'Core'},
    '3pt': {'displayName': '3pt Shoot Out', 'maxPlayers': 2, 'category': 'Core'},
    'free-throw': {'displayName': 'Free Throw', 'maxPlayers': 2, 'category': 'Core'},
    '5v5': {'displayName': '5v5', 'maxPlayers': 10, 'category': 'Core'},
    '3v3': {'displayName': '3v3', 'maxPlayers': 6, 'category': 'Core'},
    '2-ball': {'displayName': '2 Ball', 'maxPlayers': 4, 'category': 'Core'},
    'knock-out': {'displayName': 'Knock Out', 'maxPlayers': 6, 'category': 'Core'},
    'horse': {'displayName': 'H.O.R.S.E', 'maxPlayers': 4, 'category': 'Core'},
    '2dribble-1shot': {'displayName': '2 Dribble, 1 Shot', 'maxPlayers': 5, 'category': 'Core'},

    // Shooting challenges
    'around-world': {'displayName': 'Around the World', 'maxPlayers': 4, 'category': 'Shooting'},
    'beat-pro': {'displayName': 'Beat the Pro', 'maxPlayers': 2, 'category': 'Shooting'},
    '5-spot': {'displayName': '5-Spot Shooting', 'maxPlayers': 2, 'category': 'Shooting'},
    '7-spot': {'displayName': '7-Spot Shooting', 'maxPlayers': 2, 'category': 'Shooting'},
    'swish-only': {'displayName': 'Swish Only', 'maxPlayers': 2, 'category': 'Shooting'},
    'nothing-but-net': {'displayName': 'Nothing But Net Ladder', 'maxPlayers': 4, 'category': 'Shooting'},
    'make-2-miss-1': {'displayName': 'Make 2 Miss 1', 'maxPlayers': 2, 'category': 'Shooting'},
    'perfect-10': {'displayName': 'Perfect 10', 'maxPlayers': 2, 'category': 'Shooting'},
    '3-in-row': {'displayName': '3-in-a-Row to Move', 'maxPlayers': 4, 'category': 'Shooting'},
    'ft-pressure': {'displayName': 'Free-Throw Pressure', 'maxPlayers': 2, 'category': 'Shooting'},
    'bank-it': {'displayName': 'Bank It', 'maxPlayers': 2, 'category': 'Shooting'},
    'game-winner': {'displayName': 'Game Winner', 'maxPlayers': 2, 'category': 'Shooting'},

    // Finishing / Layup challenges
    'mikan-drill': {'displayName': 'Mikan Drill', 'maxPlayers': 1, 'category': 'Finishing'},
    'reverse-mikan': {'displayName': 'Reverse Mikan', 'maxPlayers': 1, 'category': 'Finishing'},
    'power-finishes': {'displayName': 'Power Finishes', 'maxPlayers': 2, 'category': 'Finishing'},
    'inside-hand': {'displayName': 'Inside-Hand Only', 'maxPlayers': 2, 'category': 'Finishing'},
    'weak-hand': {'displayName': 'Weak-Hand Only', 'maxPlayers': 2, 'category': 'Finishing'},
    'contact-finish': {'displayName': 'Contact Finishing', 'maxPlayers': 2, 'category': 'Finishing'},
    '3-move-finish': {'displayName': '3-Move Finish', 'maxPlayers': 2, 'category': 'Finishing'},

    // Ball-handling / Dribble challenges
    'dribble-ko': {'displayName': 'Dribble Knockout', 'maxPlayers': 6, 'category': 'Ball-Handling'},
    'cone-gauntlet': {'displayName': 'Cone Gauntlet', 'maxPlayers': 2, 'category': 'Ball-Handling'},
    'figure-8': {'displayName': 'Figure-8 Dribble', 'maxPlayers': 1, 'category': 'Ball-Handling'},
    'tennis-ball': {'displayName': 'Tennis Ball Dribble', 'maxPlayers': 1, 'category': 'Ball-Handling'},
    '2-ball-series': {'displayName': '2-Ball Dribbling Series', 'maxPlayers': 1, 'category': 'Ball-Handling'},
    'mirror-drills': {'displayName': 'Mirror Drills', 'maxPlayers': 2, 'category': 'Ball-Handling'},
    'red-light': {'displayName': 'Red Light / Green Light', 'maxPlayers': 4, 'category': 'Ball-Handling'},

    // 1v1 / Small-sided competitive
    'king-court': {'displayName': 'King/Queen of the Court', 'maxPlayers': 4, 'category': 'Competitive'},
    'cutthroat': {'displayName': 'Cutthroat 1v1', 'maxPlayers': 3, 'category': 'Competitive'},
    '1-dribble-1v1': {'displayName': '1-Dribble 1v1', 'maxPlayers': 2, 'category': 'Competitive'},
    '3-dribble-1v1': {'displayName': '3-Dribble 1v1', 'maxPlayers': 2, 'category': 'Competitive'},
    'advantage-1v1': {'displayName': 'Advantage 1v1', 'maxPlayers': 2, 'category': 'Competitive'},
    'closeout-1v1': {'displayName': 'Closeout 1v1', 'maxPlayers': 2, 'category': 'Competitive'},
    '3v3-make-it': {'displayName': '3v3 Make It Take It', 'maxPlayers': 6, 'category': 'Competitive'},
    '21': {'displayName': '21', 'maxPlayers': 3, 'category': 'Competitive'},

    // Conditioning + Skill Combo
    '10-in-2': {'displayName': '10-in-2 Minutes', 'maxPlayers': 2, 'category': 'Conditioning'},
    'suicide-shot': {'displayName': 'Suicide + Shot', 'maxPlayers': 2, 'category': 'Conditioning'},
    'beat-time': {'displayName': 'Beat Your Time', 'maxPlayers': 2, 'category': 'Conditioning'},
    '5-5-5': {'displayName': '5-5-5', 'maxPlayers': 2, 'category': 'Conditioning'},
    'down-back': {'displayName': 'Down & Back Series', 'maxPlayers': 2, 'category': 'Conditioning'},
    'sprint-spot': {'displayName': 'Sprint-to-Spot Shooting', 'maxPlayers': 2, 'category': 'Conditioning'},
  };

  String _challengeType = '1v1';
  String? _selectedCourtId;
  String? _selectedCourtName;
  String? _selectedOpponentId;
  String? _selectedOpponentName; // NEW: Store opponent name
  bool _hasWager = false;
  double? _wagerAmount;
  bool _isRookie = true;
  bool _isLoading = false;
  String? _error;

  final TextEditingController _wagerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserLevel();
  }

  Future<void> _checkUserLevel() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final level = await ChallengeService.fetchUserLevel(userId);
      setState(() => _isRookie = level.isRookie);
    } catch (e) {
      print('Error checking user level: $e');
    }
  }

  Future<void> _showCourtSelectionModal() async {
    try {
      final response = await supabase
          .from('courts')
          .select()
          .order('name');

      if (!mounted) return;

      final courts = List<Map<String, dynamic>>.from(response as List);

      showModalBottomSheet(
        context: context,
        builder: (context) => ListView.builder(
          itemCount: courts.length,
          itemBuilder: (context, index) {
            final court = courts[index];
            return ListTile(
              title: Text(court['name'] ?? 'Unknown Court'),
              subtitle: Text(court['city'] ?? ''),
              onTap: () {
                setState(() {
                  _selectedCourtId = court['id'];
                  _selectedCourtName = court['name'];
                });
                Navigator.pop(context);
              },
            );
          },
        ),
      );
    } catch (e) {
      setState(() => _error = 'Failed to load courts: $e');
    }
  }

  Future<void> _createChallenge() async {
    if (_selectedCourtId == null) {
      setState(() => _error = 'Please select a court');
      return;
    }

    if (_hasWager && _wagerAmount == null) {
      setState(() => _error = 'Please enter wager amount');
      return;
    }

    if (_hasWager && _isRookie) {
      setState(() => _error = 'Rookies cannot create wagers');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');
      if (_selectedOpponentId == null) throw Exception('Please select an opponent');

      final challenge = await ChallengeService.createChallenge(
        creatorId: userId,
        challengeType: _challengeType,
        courtId: _selectedCourtId!,
        opponentId: _selectedOpponentId!,
        wagerAmount: _hasWager ? _wagerAmount : null,
        hasWager: _hasWager,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge created!'),
          duration: Duration(seconds: 2),
        ),
      );

      context.go('/challenge/${challenge.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to create challenge: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _wagerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Challenge'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rookie warning
              if (_isRookie)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: cs.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your challenges are pending admin approval',
                          style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Challenge Type
              Text(
                'Challenge Type',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _challengeType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _challengeTypes.entries.map((entry) {
                    final key = entry.key;
                    final value = entry.value;
                    final category = value['category'] ?? '';
                    final displayName = value['displayName'] ?? '';
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text('$displayName ($category)'),
                    );
                  }).toList(),
                  onChanged: (newType) {
                    if (newType != null) {
                      setState(() => _challengeType = newType);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Court Selection
              Text(
                'Select Court',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _showCourtSelectionModal,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCourtName ?? 'Tap to select court',
                          style: tt.bodyMedium?.copyWith(
                            color: _selectedCourtName != null
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: cs.outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Opponent Selection
              Text(
                'Select Opponent',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectedCourtId == null
                    ? null
                    : () => context.push('/opponent-search?courtId=$_selectedCourtId').then((opponentData) {
                          if (opponentData != null) {
                            final data = opponentData as Map<String, dynamic>;
                            setState(() {
                              _selectedOpponentId = data['id'] as String;
                              _selectedOpponentName = data['name'] as String;
                            });
                          }
                        }),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedCourtId == null
                          ? Colors.grey[300]!
                          : cs.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _selectedCourtId == null
                        ? Colors.grey[100]
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: _selectedCourtId == null
                            ? Colors.grey[400]
                            : cs.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedOpponentName ?? 'Tap to select opponent',
                          style: tt.bodyMedium?.copyWith(
                            color: _selectedOpponentName != null
                                ? cs.onSurface
                                : _selectedCourtId == null
                                    ? Colors.grey[500]
                                    : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward,
                          color: _selectedCourtId == null
                              ? Colors.grey[400]
                              : cs.outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Wager Toggle
              if (_selectedOpponentId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Wager',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (_isRookie)
                        Text(
                          'Not available for Rookies',
                          style: tt.labelSmall?.copyWith(color: cs.error),
                        ),
                    ],
                  ),
                  Switch(
                    value: _hasWager && !_isRookie,
                    onChanged: _isRookie
                        ? null
                        : (value) => setState(() => _hasWager = value),
                  ),
                ],
              ),

              if (_hasWager && !_isRookie) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _wagerCtrl,
                  decoration: InputDecoration(
                    labelText: 'Wager Amount (\$)',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(
                      () => _wagerAmount =
                          double.tryParse(value) ?? 0,
                    );
                  },
                ),
              ],
              ],

              const SizedBox(height: 24),

              // Error message
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

              // Create button
              FilledButton(
                onPressed: _isLoading ? null : _createChallenge,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create Challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
