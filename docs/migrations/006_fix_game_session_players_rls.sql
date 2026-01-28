-- M2DG Database Migration - Fix Game Session Players RLS Policy
-- Run this in your Supabase SQL Editor

-- The issue: game_session_players RLS policy is too restrictive
-- Players cannot insert records when starting a game

-- Drop existing restrictive policies on game_session_players if they exist
DROP POLICY IF EXISTS "Players can join games" ON game_session_players;
DROP POLICY IF EXISTS "Players can leave games" ON game_session_players;

-- Create new, correct RLS policy for game_session_players
ALTER TABLE game_session_players ENABLE ROW LEVEL SECURITY;

-- Allow anyone to view game session players
CREATE POLICY "Anyone can view game session players" ON game_session_players
  FOR SELECT USING (true);

-- Allow authenticated users to insert (system will enforce business logic)
CREATE POLICY "Authenticated users can add players to games" ON game_session_players
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to remove themselves from games
CREATE POLICY "Players can remove themselves from games" ON game_session_players
  FOR DELETE USING (auth.uid() = user_id);

-- Allow updates for admin/system (if needed)
CREATE POLICY "System can update game session players" ON game_session_players
  FOR UPDATE USING (true);
