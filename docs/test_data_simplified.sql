-- Run each query one at a time in Supabase SQL Editor

-- PLAYER 1
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES ('9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid, 'courtking', 'Court King', 'advanced', 'Defensive specialist')
ON CONFLICT (user_id) DO UPDATE SET username = 'courtking', display_name = 'Court King', skill_level = 'advanced';

INSERT INTO player_stats (user_id, total_wins, total_losses, total_games, total_points_scored, total_points_against)
VALUES ('9a276cc0-32bd-4671-a856-ce9dec276ec0'::uuid, 45, 12, 57, 1250, 980)
ON CONFLICT (user_id) DO UPDATE SET total_wins = 45, total_losses = 12, total_games = 57, total_points_scored = 1250, total_points_against = 980;

-- PLAYER 2
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES ('7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid, 'threepointshooter', 'Three Point Shooter', 'intermediate', 'Long range expert')
ON CONFLICT (user_id) DO UPDATE SET username = 'threepointshooter', display_name = 'Three Point Shooter', skill_level = 'intermediate';

INSERT INTO player_stats (user_id, total_wins, total_losses, total_games, total_points_scored, total_points_against)
VALUES ('7d53a862-769c-4dcd-bce5-116cf14159b1'::uuid, 28, 19, 47, 980, 1050)
ON CONFLICT (user_id) DO UPDATE SET total_wins = 28, total_losses = 19, total_games = 47, total_points_scored = 980, total_points_against = 1050;

-- PLAYER 3
INSERT INTO profiles (user_id, username, display_name, skill_level, bio)
VALUES ('1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid, 'quickhands', 'Quick Hands', 'beginner', 'Speed and agility')
ON CONFLICT (user_id) DO UPDATE SET username = 'quickhands', display_name = 'Quick Hands', skill_level = 'beginner';

INSERT INTO player_stats (user_id, total_wins, total_losses, total_games, total_points_scored, total_points_against)
VALUES ('1574aef6-25c5-4075-b773-e5f8aebedd7a'::uuid, 12, 8, 20, 450, 380)
ON CONFLICT (user_id) DO UPDATE SET total_wins = 12, total_losses = 8, total_games = 20, total_points_scored = 450, total_points_against = 380;

-- Verify
SELECT username, display_name, skill_level FROM profiles WHERE username IN ('courtking', 'threepointshooter', 'quickhands');
