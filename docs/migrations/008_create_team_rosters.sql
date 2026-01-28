-- M2DG Database Migration - Create Team Rosters Table
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS team_rosters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_name TEXT NOT NULL,
  game_type TEXT NOT NULL CHECK (game_type IN ('5v5', '3v3')), -- 5v5 or 3v3
  player_ids UUID[] NOT NULL, -- Array of player UUIDs
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, team_name)
);

-- Enable RLS
ALTER TABLE team_rosters ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can view all team rosters" ON team_rosters
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own teams" ON team_rosters
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own teams" ON team_rosters
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own teams" ON team_rosters
  FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX idx_team_rosters_user_id ON team_rosters(user_id);
CREATE INDEX idx_team_rosters_game_type ON team_rosters(game_type);
CREATE INDEX idx_team_rosters_created_at ON team_rosters(created_at DESC);
