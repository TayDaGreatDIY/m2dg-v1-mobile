# M2DG Database Migration Guide

## How to Apply Migrations

### Step 1: Open Supabase SQL Editor
1. Go to your Supabase project: https://app.supabase.com
2. Navigate to SQL Editor
3. Click "New Query"

### Step 2: Apply Migration 002
Copy and paste the entire contents of `docs/migrations/002_add_scheduled_start_time.sql` into the SQL editor and click "Run".

This will add:
- `scheduled_start_time` column to challenges
- `creator_ready` boolean column to challenges
- `opponent_ready` boolean column to challenges
- `referee_requested` boolean column to challenges
- `assigned_referee_id` UUID column to challenges
- New `referee_assignments` table for referee notifications

### Step 3: Verify Changes
In Supabase, go to Table Editor and verify:
- `challenges` table has the 5 new columns
- `referee_assignments` table exists with proper columns

### Step 4: Restart Your App
After migrations are applied, refresh your Flutter web app to see the changes take effect.

## Migration Status
- [ ] Step 1: Open Supabase SQL Editor
- [ ] Step 2: Apply Migration 002
- [ ] Step 3: Verify columns exist
- [ ] Step 4: Refresh app

Once completed, the "I'm Ready" and "Request Referee" buttons will work!
