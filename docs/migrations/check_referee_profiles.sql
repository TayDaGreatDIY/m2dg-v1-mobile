-- Check if referee_profiles table exists and view its structure
SELECT * FROM information_schema.columns 
WHERE table_name = 'referee_profiles' 
ORDER BY ordinal_position;

-- If the above returns results, the table exists. 
-- If it returns nothing, the table wasn't created and you need to run the creation migration.

-- To verify the table works, try inserting test data:
-- INSERT INTO referee_profiles (user_id, display_name)
-- VALUES ('test-uuid-here'::uuid, 'Test Referee');

-- View all referee profiles currently in the database:
-- SELECT user_id, display_name, games_refereed_total, average_rating, is_verified 
-- FROM referee_profiles 
-- ORDER BY created_at DESC;
