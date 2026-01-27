-- Test Data Setup for M2DG Mobile App
-- This script creates test players for feature validation

-- NOTE: You'll need to replace the UUIDs with real auth.users IDs from your Supabase instance
-- These are placeholder UUIDs - get actual user IDs from Supabase Authentication page

-- Example: Run this in Supabase SQL Editor after replacing UUIDs
-- Or use: psql -h db.supabase.co -U postgres -d postgres < test_data.sql

-- Create test profiles (these reference auth.users - you must create auth users first)
-- For testing, you can create dummy auth records or use existing user IDs

-- Assuming you have a test user already, create profiles for test players:
-- Player 1: "CourtKing"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES 
  (
    '550e8400-e29b-41d4-a716-446655440001'::uuid, 
    'courtking',
    'Court King',
    'advanced',
    'Defensive specialist'
  )
ON CONFLICT (user_id) DO UPDATE SET username = 'courtking', display_name = 'Court King', skill_level = 'advanced';

-- Player 2: "ThreePointShooter"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio) 
VALUES 
  (
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    'threepointshooter',
    'Three Point Shooter',
    'intermediate',
    'Long range expert'
  )
ON CONFLICT (user_id) DO UPDATE SET username = 'threepointshooter', display_name = 'Three Point Shooter', skill_level = 'intermediate';

-- Player 3: "QuickHands"
INSERT INTO profiles (user_id, username, display_name, skill_level, bio)
VALUES
  (
    '550e8400-e29b-41d4-a716-446655440003'::uuid,
    'quickhands',
    'Quick Hands',
    'beginner',
    'Speed and agility'
  )
ON CONFLICT (user_id) DO UPDATE SET username = 'quickhands', display_name = 'Quick Hands', skill_level = 'beginner';

-- Create player stats for test players
-- Player 1 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  (
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    45,
    12,
    57,
    1250,
    980
  )
ON CONFLICT (user_id) DO UPDATE SET wins = 45, losses = 12, games_played = 57, total_points_for = 1250, total_points_against = 980;

-- Player 2 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  (
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    28,
    19,
    47,
    980,
    1050
  )
ON CONFLICT (user_id) DO UPDATE SET wins = 28, losses = 19, games_played = 47, total_points_for = 980, total_points_against = 1050;

-- Player 3 Stats
INSERT INTO player_stats (user_id, wins, losses, games_played, total_points_for, total_points_against)
VALUES
  (
    '550e8400-e29b-41d4-a716-446655440003'::uuid,
    12,
    8,
    20,
    450,
    380
  )
ON CONFLICT (user_id) DO UPDATE SET wins = 12, losses = 8, games_played = 20, total_points_for = 450, total_points_against = 380;

-- Create user levels for test players
INSERT INTO user_levels (user_id, level, exp_points)
VALUES
  ('550e8400-e29b-41d4-a716-446655440001'::uuid, 'elite', 5000),
  ('550e8400-e29b-41d4-a716-446655440002'::uuid, 'intermediate', 2500),
  ('550e8400-e29b-41d4-a716-446655440003'::uuid, 'rookie', 500)
ON CONFLICT (user_id) DO UPDATE SET level = EXCLUDED.level, exp_points = EXCLUDED.exp_points;

-- Display the created data
SELECT 'Test players created successfully!' as message;
SELECT username, display_name, skill_level FROM profiles WHERE user_id IN (
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  '550e8400-e29b-41d4-a716-446655440002'::uuid,
  '550e8400-e29b-41d4-a716-446655440003'::uuid
);
