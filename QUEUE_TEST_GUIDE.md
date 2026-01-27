# Court Queue - Quick Test Guide

**Ready to Test?** ✅ Yes! The Court Queue feature is built and deployed.

---

## 🚀 How to Test the Court Queue

### Access the App
```
URL: http://localhost:8080
Status: ✅ Running on Python HTTP server
```

### Test Scenario: Join & Leave Queue

#### Step 1: Navigate to Court Details
1. Open http://localhost:8080
2. Sign in with your Supabase account
3. Tap **Courts** tab
4. Select any court → Opens **Court Details**

#### Step 2: Find the Queue Section
```
Court Details Page Layout:
├─ Court name & info (top)
├─ Check-in button + cooldown timer
│
└─ ┌─────────────────────────────┐
   │ 🎫 COURT QUEUE (NEW!)       │ ← You are here
   ├─────────────────────────────┤
   │ ↻ Refresh  [Stats]           │
   │ [Join Queue] or [Leave]       │
   │ Queue list with players      │
   └─────────────────────────────┘
│
├─ Your check-ins history (below)
└─ Recent check-ins at court
```

#### Step 3: Join the Queue
1. Tap blue **[Join Queue]** button
2. Button shows loading spinner
3. ✅ Position card appears: **Your Position: #1**
4. ✅ Button changes to red **[Leave Queue]**
5. ✅ Queue list shows you with position indicator

#### Step 4: Test Real-Time Sync (2 Browser Tabs)
1. **Tab 1:** In queue at position #1
2. **Tab 2:** Open same court (different browser tab)
3. **Tab 2:** ✅ You see Tab 1 user in queue (no refresh!)
4. **Tab 2:** Tap **[Join Queue]**
5. **Tab 1:** ✅ Instantly see Tab 2 user at position #2
6. **Tab 2:** ✅ Your position shows #2

#### Step 5: Leave Queue
1. Tap red **[Leave Queue]** button
2. Button shows loading spinner
3. ✅ Queue card disappears
4. ✅ **[Join Queue]** button reappears
5. ✅ Other users see you removed (real-time)

#### Step 6: Empty Queue
1. Leave queue (all players leave)
2. ✅ See message: **"Queue is empty"**
3. ✅ Still can join again

---

## 🎯 What to Look For

### ✅ Correct Behavior

| Test | Expected | Status |
|------|----------|--------|
| Join button | Appears when not in queue | Watch for this |
| Join loading | Shows spinner while joining | Watch for this |
| Position card | Shows your position & status | Watch for this |
| Leave button | Red button appears when in queue | Watch for this |
| Queue list | All players shown with positions | Watch for this |
| Real-time sync | Changes appear instantly in other tabs | Watch for this |
| Refresh button | Manual refresh icon works | Watch for this |
| Empty state | Message when no one waiting | Watch for this |

### ❌ What Would Be Wrong

| Issue | Fix |
|-------|-----|
| Join button disabled | Check Supabase auth |
| Queue not loading | Check `court_queues` table exists |
| Real-time not syncing | Check RLS policies allow SELECT |
| Position not updating | Try manual refresh |
| Old position showing | Clear browser cache |

---

## 📱 Features Being Tested

### Core Features
- **Join Queue:** Add to court's waiting list
- **Leave Queue:** Remove yourself anytime  
- **Position Tracking:** See your spot in queue
- **Queue Display:** List all waiting players
- **Real-Time Updates:** Changes sync instantly
- **Refresh Button:** Manual sync available

### Statuses
```
waiting ← [Default when joining]
↓
called_next ← [Admin calls next player in Phase 2]
↓
checked_in ← [Player confirms ready in Phase 2]
```

---

## 📊 Test Data Checklist

### Required Setup
- [ ] Supabase project created
- [ ] `court_queues` table exists (see `/docs/sql/`)
- [ ] RLS policies enabled
- [ ] Test court created in database
- [ ] Authenticated user account

### To Create Test Court (if needed)
```sql
INSERT INTO courts (name, location, is_active) VALUES
('Test Court 1', 'Central Park', true);
```

---

## 🐛 If Something Breaks

### Queue Not Loading
```
Check browser console (F12):
- Any errors about 'court_queues'?
- Any auth errors?
- Network tab: requests failing?
```

### Real-Time Not Working
```
Check Supabase:
1. Project settings → Realtime → Is it ON?
2. Table: court_queues → Is RLS enabled?
3. Policy: Can SELECT on court_queues?
```

### Position Shows Wrong
```
Solutions:
1. Manual refresh button (↻)
2. Close and reopen court details
3. Check database directly (Supabase console)
```

---

## 📋 Full Test Checklist

### UI Tests
- [ ] Join button visible when not in queue
- [ ] Join button disabled while loading
- [ ] Join button hidden when in queue
- [ ] Position card shows correct position (#1, #2, etc)
- [ ] Position card shows status ("waiting")
- [ ] Leave button visible when in queue
- [ ] Leave button red/error styled
- [ ] Queue list shows all players
- [ ] Queue list numbers are 1, 2, 3... (ordered)
- [ ] Your name highlighted in list
- [ ] Empty state shows "Queue is empty"
- [ ] Queue stats show "X players waiting"
- [ ] Refresh icon visible and clickable

### Functional Tests
- [ ] Can join queue
- [ ] Can leave queue
- [ ] Position correct when joining
- [ ] Position updates when others join
- [ ] Position decreases when others leave
- [ ] Real-time sync works (2 tabs)
- [ ] Refresh button manually syncs
- [ ] Can rejoin after leaving

### Data Tests
- [ ] Position is persistent (refresh page)
- [ ] Can join same court again
- [ ] Team size shows correctly
- [ ] Status badge shows correctly
- [ ] Timestamps work

---

## 💬 Examples of What You'll See

### Join Queue (Success)
```
Before Join:
┌─────────────────────┐
│ COURT QUEUE         │
│ [Join Queue]        │
│ (empty queue)       │
└─────────────────────┘

After Join:
┌─────────────────────┐
│ COURT QUEUE         │
│ Your Position: #1   │
│ Status: waiting     │
│ [Leave Queue]       │
├─────────────────────┤
│ 1. You (1 player)   │
│    Status: waiting  │
└─────────────────────┘
```

### Multiple Players
```
┌──────────────────────────┐
│ COURT QUEUE              │
│ 3 players waiting        │
├──────────────────────────┤
│ 1. Alice (1 player)      │
│    Status: waiting       │
│                          │
│ 2. Bob (1 player)        │
│    Status: waiting       │
│                          │
│ 3. You (1 player) ⭐    │
│    Status: waiting       │
│    [Leave Queue]         │
└──────────────────────────┘
```

---

## 🎮 Extended Test (Optional)

### Load Test (if you're thorough)
1. Simulate multiple users joining:
   - Open 5+ browser tabs
   - Each joins the same court queue
   - Watch positions update correctly
   - Verify no duplicates or errors

### Performance Test
1. Open queue
2. Measure load time
3. Open developer console → Performance
4. Join queue, measure response time
5. Should be < 500ms

### Edge Cases
1. **Rapid Join/Leave:** Click buttons quickly
2. **Page Refresh:** While in queue, refresh page
3. **Network Lag:** Developer tools → Slow 3G
4. **Offline:** Toggle offline, try to join

---

## 📞 Need Help?

### Check These Files
- [COURT_QUEUE_FEATURE.md](../COURT_QUEUE_FEATURE.md) - Full documentation
- [lib/screens/court_details_page.dart](../apps/mobile/lib/screens/court_details_page.dart) - Source code
- [lib/services/court_queue_service.dart](../apps/mobile/lib/services/court_queue_service.dart) - Business logic

### Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| "Can't see queue section" | Scroll down on court details page |
| "Join button doesn't work" | Check signed in to Supabase |
| "Position shows #0" | Refresh page (F5) |
| "Real-time not syncing" | Check Supabase Realtime enabled |
| "Different position in tabs" | Manual refresh in one tab |

---

## ✨ Next Steps After Testing

### If Everything Works ✅
1. Create a GitHub issue marking this complete
2. Move to Phase 2 features
3. Consider load testing with real data

### If You Find Issues 🐛
1. Note down specific steps to reproduce
2. Check database directly (Supabase console)
3. Review error in browser console (F12)
4. Create GitHub issue with details

---

**Web Server Status:** ✅ Running on http://localhost:8080  
**Queue Feature Status:** ✅ Ready for Testing  
**Test Guide Version:** 1.0  
**Last Updated:** January 27, 2026
