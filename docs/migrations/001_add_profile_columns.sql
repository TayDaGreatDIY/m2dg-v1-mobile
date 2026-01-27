-- M2DG Database Migration - Add Profile Columns
-- Run this in your Supabase SQL Editor if columns don't exist

-- Add missing columns to profiles table if they don't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS favorite_court_id UUID REFERENCES courts(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS orientation_completed BOOLEAN DEFAULT false;

-- If you get a notice that columns already exist, that's fine - they're being used already
