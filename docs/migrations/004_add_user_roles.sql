-- Add user_role column to profiles table for role-based access
ALTER TABLE profiles
ADD COLUMN user_role TEXT DEFAULT 'athlete' NOT NULL CHECK (user_role IN ('athlete', 'referee', 'verified_scorer', 'parent'));

-- Create index for role-based queries
CREATE INDEX idx_profiles_user_role ON profiles(user_role);
