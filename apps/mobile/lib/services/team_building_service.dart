import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/team_roster.dart';

final supabase = Supabase.instance.client;

class TeamBuildingService {
  /// Create a new team roster
  static Future<TeamRoster> createTeam({
    required String teamName,
    required String gameType, // '5v5' or '3v3'
    required List<String> playerIds,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('team_rosters')
          .insert({
            'user_id': userId,
            'team_name': teamName,
            'game_type': gameType,
            'player_ids': playerIds,
          })
          .select()
          .single();

      print('✅ Team created: $teamName');
      return TeamRoster.fromJson(response);
    } catch (e) {
      print('❌ Error creating team: $e');
      rethrow;
    }
  }

  /// Get all teams for current user
  static Future<List<TeamRoster>> getUserTeams() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('team_rosters')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TeamRoster.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching user teams: $e');
      return [];
    }
  }

  /// Get all public teams (for browsing/challenging)
  static Future<List<TeamRoster>> getAllPublicTeams() async {
    try {
      final response = await supabase
          .from('team_rosters')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TeamRoster.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching public teams: $e');
      return [];
    }
  }

  /// Get teams by game type
  static Future<List<TeamRoster>> getTeamsByType(String gameType) async {
    try {
      final response = await supabase
          .from('team_rosters')
          .select()
          .eq('game_type', gameType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TeamRoster.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching teams by type: $e');
      return [];
    }
  }

  /// Get a specific team
  static Future<TeamRoster?> getTeam(String teamId) async {
    try {
      final response = await supabase
          .from('team_rosters')
          .select()
          .eq('id', teamId)
          .maybeSingle();

      if (response == null) return null;
      return TeamRoster.fromJson(response);
    } catch (e) {
      print('❌ Error fetching team: $e');
      return null;
    }
  }

  /// Update team roster (add/remove players)
  static Future<TeamRoster> updateTeam({
    required String teamId,
    String? teamName,
    List<String>? playerIds,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (teamName != null) updates['team_name'] = teamName;
      if (playerIds != null) updates['player_ids'] = playerIds;
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await supabase
          .from('team_rosters')
          .update(updates)
          .eq('id', teamId)
          .select()
          .single();

      print('✅ Team updated: $teamId');
      return TeamRoster.fromJson(response);
    } catch (e) {
      print('❌ Error updating team: $e');
      rethrow;
    }
  }

  /// Add player to team
  static Future<TeamRoster> addPlayerToTeam({
    required String teamId,
    required String playerId,
  }) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Team not found');

      if (team.isComplete) {
        throw Exception('Team is already full (${team.requiredSize} players)');
      }

      if (team.playerIds.contains(playerId)) {
        throw Exception('Player already on this team');
      }

      final updatedPlayerIds = [...team.playerIds, playerId];
      return updateTeam(teamId: teamId, playerIds: updatedPlayerIds);
    } catch (e) {
      print('❌ Error adding player to team: $e');
      rethrow;
    }
  }

  /// Remove player from team
  static Future<TeamRoster> removePlayerFromTeam({
    required String teamId,
    required String playerId,
  }) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Team not found');

      final updatedPlayerIds = team.playerIds.where((id) => id != playerId).toList();
      return updateTeam(teamId: teamId, playerIds: updatedPlayerIds);
    } catch (e) {
      print('❌ Error removing player from team: $e');
      rethrow;
    }
  }

  /// Delete a team
  static Future<void> deleteTeam(String teamId) async {
    try {
      await supabase
          .from('team_rosters')
          .delete()
          .eq('id', teamId);

      print('✅ Team deleted: $teamId');
    } catch (e) {
      print('❌ Error deleting team: $e');
      rethrow;
    }
  }

  /// Get users teams for a specific game type
  static Future<List<TeamRoster>> getUserTeamsByType(String gameType) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('team_rosters')
          .select()
          .eq('user_id', userId)
          .eq('game_type', gameType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TeamRoster.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching user teams by type: $e');
      return [];
    }
  }
}
