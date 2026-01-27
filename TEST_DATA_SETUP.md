# Setting Up Test Data for M2DG

To test the social, messaging, and notifications features, you need test player accounts.

## Quick Setup (3 Steps)

### Step 1: Create Auth Users
1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Create 3 test users:
   - `player1@test.com` / password: `Test123!`
   - `player2@test.com` / password: `Test123!`
   - `player3@test.com` / password: `Test123!`
3. Note their user IDs (UUID) from the auth table

### Step 2: Run Test Data SQL
1. Go to **Supabase Dashboard** → **SQL Editor**
2. Create a new query and paste the contents of `/docs/test_data.sql`
3. **Replace** the placeholder UUIDs with the actual user IDs you created:
   ```sql
   -- Replace these with your actual user IDs:
   '550e8400-e29b-41d4-a716-446655440001'::uuid  -- player1 ID
   '550e8400-e29b-41d4-a716-446655440002'::uuid  -- player2 ID
   '550e8400-e29b-41d4-a716-446655440003'::uuid  -- player3 ID
   ```
4. Click **Run** to execute

### Step 3: Test in App
1. Sign in with `player1@test.com`
2. Navigate to **Profile** → **Friends & Social**
3. Go to the **Find** tab and search for "courtking", "threepointshooter", or "quickhands"
4. Send friend requests
5. Switch to another test user and accept requests
6. Use **Messages & Inbox** to chat with friends

---

## What's Created

| Player | Username | Level | Wins | Losses | Games |
|--------|----------|-------|------|--------|-------|
| Court King | courtking | Advanced | 45 | 12 | 57 |
| Three Point | threepointshooter | Intermediate | 28 | 19 | 47 |
| Quick Hands | quickhands | Beginner | 12 | 8 | 20 |

---

## Testing Checklist

- [ ] Sign up with test users
- [ ] View profile stats (wins, losses, level, point diff)
- [ ] Search for opponents in Challenges
- [ ] Send friend requests
- [ ] Accept/decline friend requests
- [ ] Send messages between friends
- [ ] See notification badge update
- [ ] View admin panel (if admin user)

---

**Note:** Test data is sample data only. Delete after testing if needed.
