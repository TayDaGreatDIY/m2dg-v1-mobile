-- M2DG Database Migration - Create Referee Profiles Table
-- Run this in your Supabase SQL Editor

-- Create referee_profiles table
CREATE TABLE IF NOT EXISTS referee_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  display_name TEXT NOT NULL,
  profile_picture_url TEXT,
  games_refereed_total INTEGER DEFAULT 0 NOT NULL,
  average_rating DECIMAL(3,1) DEFAULT 0.0 NOT NULL,
  is_verified BOOLEAN DEFAULT FALSE NOT NULL,
  years_experience INTEGER DEFAULT 0,
  bio TEXT,
  availability TEXT,
  certificates TEXT[],
  social_media_links TEXT[],
  bad_calls INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE referee_profiles ENABLE ROW LEVEL SECURITY;

-- Referee profile policies
CREATE POLICY "Anyone can view referee profiles" ON referee_profiles
  FOR SELECT USING (true);

CREATE POLICY "Referees can update their own profile" ON referee_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Referees can insert their own profile" ON referee_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX idx_referee_profiles_user_id ON referee_profiles(user_id);
CREATE INDEX idx_referee_profiles_games_refereed ON referee_profiles(games_refereed_total DESC);
CREATE INDEX idx_referee_profiles_rating ON referee_profiles(average_rating DESC);
