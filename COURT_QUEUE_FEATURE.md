# Court Queue System - Feature Documentation

**Status:** ✅ Complete and Ready for Testing  
**Date:** January 27, 2026  
**Phase:** Phase 1 Feature #2

---

## Overview

The Court Queue system manages player wait queues at courts. Players can join a queue, see their position, and leave whenever they want. The system updates in real-time using Supabase subscriptions.

### Key Features
- ✅ **Join Queue** - Add yourself to a court's waiting list
- ✅ **Position Tracking** - See your position and total players waiting
- ✅ **Leave Queue** - Remove yourself from the queue anytime
- ✅ **Real-time Updates** - Queue changes sync instantly via Supabase subscriptions
- ✅ **Queue Display** - Visual list showing all waiting players and their status
- ✅ **User-Friendly UI** - Clear status indicators and actionable buttons

---

## Architecture

### Database Schema

Table: `court_queues` (defined in `/docs/sql/create_court_queues_table_v2.sql`)

```sql
CREATE TABLE court_queues (
  id UUID PRIMARY KEY,
  court_id UUID REFERENCES courts(id),
  user_id UUID REFERENCES auth.users(id),
  team_size INT DEFAULT 1,
  additional_players TEXT[],
  status TEXT DEFAULT 'waiting' -- waiting, playing, called_next, checked_in
  position_in_queue INT NOT NULL,
  created_at TIMESTAMP,
  called_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**Row Level Security (RLS):**
- All users can VIEW queue entries (transparency)
- Users can INSERT their own queue entries (join)
- Users can DELETE their own entries (leave)
- System can UPDATE queue status (admin/service)

### Data Model

`CourtQueue` model in [lib/models/court_queue.dart](lib/models/court_queue.dart):
- Immutable data class
- JSON serialization support
- Properties: `id`, `courtId`, `userId`, `teamSize`, `status`, `positionInQueue`, timestamps

### Service Layer

`CourtQueueService` in [lib/services/court_queue_service.dart](lib/services/court_queue_service.dart):

**Core Methods:**
- `joinQueue(courtId, teamSize)` - Add player to queue
- `leaveQueue(queueId)` - Remove player from queue
- `getCourtQueue(courtId)` - Fetch all waiting players
- `callNextPlayer(courtId)` - Mark next player as called
- `checkInPlayer(queueId)` - Confirm player is ready to play
- `getWaitingCount(courtId)` - Get queue size
- `getNextUp(courtId)` - Get the next player

### UI Implementation

**Screen:** [lib/screens/court_details_page.dart](lib/screens/court_details_page.dart)

The court details page includes a **"Court Queue"** section displaying:

#### Queue Actions
1. **Join Queue Button** (if not in queue)
   - Shows loading indicator while joining
   - Displays your position once joined
   
2. **Leave Queue Button** (if in queue)
   - Red error-style button
   - Shows loading state while leaving
   - Removes you from queue immediately

#### Queue Display
- **Queue Stats:** Shows "X players waiting"
- **Your Position:** Blue card showing your position and status
- **Queue List:** Numbered list of all players
  - Current position indicator (circle)
  - Player info and team size
  - Status badge (waiting, called_next, checked_in)
  - Highlights your own entry

#### Real-Time Updates
- **Refresh Button:** Manual refresh in header
- **Auto-Subscribe:** Supabase listens for changes on `court_queues` table
- **Instant Sync:** When anyone joins/leaves, all clients update automatically

---

## User Flows

### Joining a Queue

```
1. User opens Court Details page
2. Sees "Court Queue" section with "Join Queue" button
3. Clicks "Join Queue" → CourtQueueService.joinQueue()
4. Server calculates position based on existing queue
5. UI updates showing:
   - Your position (e.g., "#5")
   - Your status ("waiting")
   - "Leave Queue" button becomes available
6. User's join triggers Supabase subscription
7. All other clients see updated queue instantly
```

### Viewing Queue Position

```
1. User in queue sees blue card with:
   - "Your Position: #5"
   - "Status: waiting"
2. Real-time updates show position changes:
   - Players ahead of you leave → position decreases
   - New players join behind you → position stays same
   - You're called next → status changes to "called_next"
   - You check in → status changes to "checked_in"
```

### Leaving a Queue

```
1. User in queue sees red "Leave Queue" button
2. Clicks button → CourtQueueService.leaveQueue()
3. Row deleted from database
4. Subscription triggers for all clients
5. Others see you removed from list
6. You see "Join Queue" button again
7. Your position becomes available to others
```

---

## Technical Details

### Real-Time Subscription Setup

```dart
void _setupQueueSubscription() {
  _queueChannel = supabase
      .channel('court_queue:${courtId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,  // INSERT, UPDATE, DELETE
        schema: 'public',
        table: 'court_queues',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'court_id',
          value: courtId,
        ),
        callback: (payload) {
          _loadQueue();  // Refresh queue on any change
        },
      )
      .subscribe();
}
```

### Queue Position Calculation

When joining, the service calculates position:
```dart
// Get current highest position
final queueResponse = await supabase
    .from('court_queues')
    .select('position_in_queue')
    .eq('court_id', courtId)
    .eq('status', 'waiting')
    .order('position_in_queue', ascending: false)
    .limit(1);

// Next position is highest + 1
final nextPosition = queueResponse.isEmpty
    ? 1
    : (queueResponse[0]['position_in_queue'] as int) + 1;
```

### Status Transitions

```
waiting ──────→ called_next ──────→ checked_in ──────→ (playing)
         (admin)           (user)           (user)
```

- **waiting:** Player joined, waiting for their turn
- **called_next:** Admin called them to play next
- **checked_in:** Player confirmed ready to play
- **playing:** Game started (managed separately)

---

## Testing Guide

### Prerequisites
1. Test user account(s) with Supabase auth
2. At least one court in database
3. `court_queues` table created and RLS enabled

### Test Scenarios

#### Test 1: Join Queue
```
1. Open Court Details page
2. Tap "Join Queue" button
3. ✅ Button shows loading state
4. ✅ Position card appears with "#1"
5. ✅ Button changes to red "Leave Queue"
6. ✅ Toast shows "Joined queue at position 1"
```

#### Test 2: Multiple Players
```
1. User A joins → Position #1
2. User B joins → Position #2 (for User B), User A still #1
3. User C joins → Position #3 (for User C)
4. ✅ Each user sees correct position
5. ✅ All users see same queue list
```

#### Test 3: Real-Time Sync
```
1. Open court in 2 browser tabs
2. In Tab 1: Join Queue → Position #1
3. In Tab 2: ✅ Queue updates instantly (no refresh needed)
4. In Tab 1: Leave Queue
5. In Tab 2: ✅ You disappear from queue instantly
```

#### Test 4: Leave Queue
```
1. User in queue (Position #2)
2. Taps red "Leave Queue" button
3. ✅ Button shows loading state
4. ✅ Queue card disappears
5. ✅ "Join Queue" button reappears
6. ✅ Toast shows "Left queue"
7. ✅ Other users see you removed from list
```

#### Test 5: Refresh Button
```
1. User in queue
2. Taps refresh icon in queue header
3. ✅ Loading spinner appears
4. ✅ Queue reloads from database
5. ✅ Position updates if changed
```

---

## Integration Notes

### Cooldown & Queue Independence
- Cooldown timer (from check-ins) is separate from queue
- Players can join queue without checking in
- Checking in establishes cooldown; joining queue doesn't

### Check-In vs. Queue
- **Check-in:** Confirms you're at the court (location-based)
- **Queue:** Marks you as wanting to play (position-based)
- Both can be active simultaneously

### Admin Panel Integration (Phase 2)
The `CourtAdminPage` will eventually add:
- View waiting queue
- Call next player: `CourtQueueService.callNextPlayer(courtId)`
- Check in player: `CourtQueueService.checkInPlayer(queueId)`
- Remove from queue: `CourtQueueService.leaveQueue(queueId)`
- Clear all queues: batch delete

---

## Performance Considerations

### Database Indexes
```sql
CREATE INDEX idx_court_queues_court_id ON court_queues(court_id);
CREATE INDEX idx_court_queues_user_id ON court_queues(user_id);
CREATE INDEX idx_court_queues_status ON court_queues(status);
CREATE INDEX idx_court_queues_position ON court_queues(court_id, position_in_queue);
CREATE INDEX idx_court_queues_created ON court_queues(created_at DESC);
```

### Query Optimization
- Always filter by `court_id` first (indexed)
- Use `position_in_queue` ordering for efficient "next player" queries
- Batch operations use single transaction when possible

### Real-Time Limits
- Subscriptions refresh on every change (INSERT/UPDATE/DELETE)
- Handles high concurrency without slowdown
- Network bandwidth: minimal (only changed rows sent)

---

## Known Limitations & Future Work

### Current Limitations
- No persistence of team composition (just `team_size` count)
- No queue priority system (FIFO only)
- No auto-move between statuses (manual admin action)
- No time-based queue cleanup (stale entries remain)

### Phase 2 Enhancements
- [ ] Multi-player team queueing
- [ ] Admin can re-order queue
- [ ] Auto-advance status transitions
- [ ] Queue timeout and cleanup
- [ ] Notifications when called to play
- [ ] Wager system integration
- [ ] Replay queue history

---

## File Structure

```
libs/
├── models/
│   └── court_queue.dart          ← Data model
├── services/
│   └── court_queue_service.dart  ← Business logic
├── screens/
│   └── court_details_page.dart   ← UI (includes _buildQueueSection)
└── widgets/
    └── (future: standalone queue widget)

docs/
├── database_setup.sql            ← Main schema (doesn't include court_queues yet)
└── sql/
    └── create_court_queues_table_v2.sql  ← Queue table setup
```

---

## Environment Setup

### Before Testing

1. **Create court_queues table in Supabase:**
   ```sql
   -- Copy & paste from: /docs/sql/create_court_queues_table_v2.sql
   -- Into: Supabase SQL Editor
   ```

2. **Verify RLS is enabled:**
   ```sql
   -- Run in Supabase SQL Editor
   SELECT * FROM pg_tables 
   WHERE tablename = 'court_queues';
   ```
   Look for `rowsecurity = true`

3. **Check .env file has Supabase credentials:**
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

---

## Commit History

```
b01e20d - feat(queue): add real-time queue updates with Supabase subscriptions
8e6b041 - feat(court_queue): implement court queue system with join/leave, 
          position tracking, and real-time updates
```

---

## Support & Troubleshooting

### Queue Not Showing?
- ✅ Check `court_queues` table exists in Supabase
- ✅ Verify RLS policies allow your user to SELECT
- ✅ Check browser console for errors

### Join Button Does Nothing?
- ✅ Ensure user is authenticated
- ✅ Check Supabase `auth.users` has your user
- ✅ Verify INSERT policy on `court_queues`

### Real-Time Not Working?
- ✅ Check Supabase Realtime is enabled (project settings)
- ✅ Browser network tab: should see WebSocket connection
- ✅ Try manual refresh button to verify data loads

### Position Not Updating?
- ✅ Manual refresh shows correct position
- ✅ Subscription might not be connected: check browser console
- ✅ Try rejoining queue

---

**Questions?** Check the embedded code comments in `court_details_page.dart` and `court_queue_service.dart`!
