-- Test Data Setup for M2DG Mobile App
-- Replace the UUIDs below with your actual user IDs from Supabase Authentication

-- Player 1: "CourtKing"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES 
  ('9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid, 'courtking', 'Court King', 'advanced', 'Defensive specialist')
ON CONFLICT (user_id) DO UPDATE SET username = 'courtking', display_name = 'Court King', skill_level = 'advanced';

-- Player 2: "ThreePointShooter"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES 
  ('7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid, 'threepointshooter', 'Three Point Shooter', 'intermediate', 'Long range expert')
ON CONFLICT (user_id) DO UPDATE SET username = 'threepointshooter', display_name = 'Three Point Shooter', skill_level = 'intermediate';

-- Player 3: "QuickHands"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio)
VALUES
  ('1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid, 'quickhands', 'Quick Hands', 'beginner', 'Speed and agility')
ON CONFLICT (user_id) DO UPDATE SET username = 'quickhands', display_name = 'Quick Hands', skill_level = 'beginner';

-- Player 1 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  ('9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid, 45, 12, 57, 1250, 980)
ON CONFLICT (user_id) DO UPDATE SET wins = 45, losses = 12, games_played = 57, total_points_for = 1250, total_points_against = 980;

-- Player 2 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  ('7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid, 28, 19, 47, 980, 1050)
ON CONFLICT (user_id) DO UPDATE SET wins = 28, losses = 19, games_played = 47, total_points_for = 980, total_points_against = 1050;

-- Player 3 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  ('1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid, 12, 8, 20, 450, 380)
ON CONFLICT (user_id) DO UPDATE SET wins = 12, losses = 8, games_played = 20, total_points_for = 450, total_points_against = 380;

-- Create user levels for test players
INSERT INTO user_levels (user_id, level, exp_points)
VALUES
  ('9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid, 'elite', 5000),
  ('7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid, 'intermediate', 2500),
  ('1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid, 'rookie', 500)
ON CONFLICT (user_id) DO UPDATE SET level = EXCLUDED.level, exp_points = EXCLUDED.exp_points;

-- Verify test players created
SELECT username, display_name, skill_level FROM profiles WHERE user_id IN (
  '9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid,
  '7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid,
  '1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid
);
