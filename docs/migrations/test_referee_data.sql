-- M2DG Test Data - Create Test Referee Profile
-- Run this in Supabase SQL Editor to populate test referee data

-- First, find a valid user_id from your profiles table
-- Uncomment this to see all users:
-- SELECT id, display_name FROM profiles LIMIT 10;

-- Option 1: If you already have a user, use their UUID
-- Replace 'USER_UUID_HERE' with an actual UUID from profiles table
-- Example format: '550e8400-e29b-41d4-a716-446655440000'

-- Find an athlete user to convert to referee
SELECT id, display_name FROM profiles WHERE user_role = 'athlete' LIMIT 5;

-- After finding a user_id, run this to create a test referee:
-- INSERT INTO referee_profiles (
--   user_id,
--   display_name,
--   games_refereed_total,
--   average_rating,
--   years_experience,
--   bio,
--   is_verified,
--   bad_calls
-- ) VALUES (
--   'INSERT_USER_UUID_HERE',
--   'John Referee',
--   42,
--   4.8,
--   5,
--   'Experienced referee with 5+ years in court sports',
--   true,
--   3
-- );

-- ============ STEP-BY-STEP INSTRUCTIONS ============
-- 1. First, run this query to see available users:
--    SELECT id, display_name FROM profiles LIMIT 10;
--
-- 2. Copy a UUID from the results (from the 'id' column)
--
-- 3. Replace 'INSERT_USER_UUID_HERE' below with that UUID (keep the quotes)
--
-- 4. Run the INSERT statement below:

INSERT INTO referee_profiles (
  user_id,
  display_name,
  games_refereed_total,
  average_rating,
  years_experience,
  bio,
  is_verified,
  bad_calls
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000'::uuid,
  'John Referee',
  42,
  4.8,
  5,
  'Experienced referee with 5+ years in court sports',
  true,
  3
);

-- If successful, verify with:
-- SELECT * FROM referee_profiles ORDER BY created_at DESC LIMIT 1;

-- ============ CREATE MULTIPLE TEST REFEREES ============
-- Run this to create 3 test referees:
-- INSERT INTO referee_profiles (user_id, display_name, games_refereed_total, average_rating, years_experience, bio, is_verified, bad_calls)
-- VALUES
-- ('UUID_1_HERE'::uuid, 'Alice Ref', 35, 4.9, 4, 'Expert referee', true, 2),
-- ('UUID_2_HERE'::uuid, 'Bob Ref', 28, 4.5, 3, 'Good referee', true, 5),
-- ('UUID_3_HERE'::uuid, 'Charlie Ref', 50, 4.7, 6, 'Very experienced', true, 1);
