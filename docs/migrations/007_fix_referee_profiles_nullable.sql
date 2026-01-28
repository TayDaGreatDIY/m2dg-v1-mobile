-- M2DG Database Migration - Fix Referee Profiles Table (Make columns nullable)
-- Run this in your Supabase SQL Editor if you got errors with the previous migration

-- Drop existing table if it has issues
-- DROP TABLE IF EXISTS referee_profiles CASCADE;

-- Alternative: If table exists, alter the columns to be nullable
ALTER TABLE referee_profiles ALTER COLUMN display_name DROP NOT NULL;
ALTER TABLE referee_profiles ALTER COLUMN games_refereed_total SET DEFAULT 0;
ALTER TABLE referee_profiles ALTER COLUMN average_rating SET DEFAULT 0.0;
ALTER TABLE referee_profiles ALTER COLUMN is_verified SET DEFAULT FALSE;
ALTER TABLE referee_profiles ALTER COLUMN years_experience SET DEFAULT 0;
ALTER TABLE referee_profiles ALTER COLUMN bad_calls SET DEFAULT 0;

-- If you get an error that the table doesn't exist, run this to create it fresh:
-- CREATE TABLE IF NOT EXISTS referee_profiles (
--   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--   display_name TEXT,
--   profile_picture_url TEXT,
--   games_refereed_total INTEGER DEFAULT 0,
--   average_rating DECIMAL(3,1) DEFAULT 0.0,
--   is_verified BOOLEAN DEFAULT FALSE,
--   years_experience INTEGER DEFAULT 0,
--   bio TEXT,
--   availability TEXT,
--   certificates TEXT[],
--   social_media_links TEXT[],
--   bad_calls INTEGER DEFAULT 0,
--   created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
--   updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
-- );
