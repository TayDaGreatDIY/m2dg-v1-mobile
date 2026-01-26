# M2DG Mobile v1 - Feature Implementation Summary

## Overview
This document summarizes all the major features implemented in the M2DG mobile application, including database schema, services, models, and UI pages.

## Database Schema

### Tables Created
All tables are located in `/docs/database_setup.sql` - paste this SQL into your Supabase SQL editor.

1. **game_sessions** - Tracks active and completed games
2. **game_session_players** - Junction table for game participants
3. **player_stats** - Aggregated player statistics (wins, losses, points)
4. **friendships** - Friend relationships between users
5. **messages** - Direct messages between friends
6. **notifications** - User notifications for various events
7. **court_admins** - Court administration permissions
8. **profiles** - Extended user profile information

### Key Features
- Row Level Security (RLS) policies for all tables
- Indexes for performance optimization
- Foreign key relationships
- Automatic timestamp updates

## Data Models

Located in `/workspaces/m2dg-v1-mobile/apps/mobile/lib/models/`

### GameSession (`game_session.dart`)
- Tracks games with status, scores, winner
- Methods: `fromJson()`, `toJson()`, `copyWith()`
- Properties: id, courtId, challengeType, status, team1Score, team2Score, winner, timestamps

### PlayerStats (`player_stats.dart`)
- Aggregated player statistics
- Calculated properties: `winRate`, `pointDifferential`
- Properties: totalGames, wins, losses, totalPoints, timestamps

### UserProfile (`user_profile.dart`)
- Extended user information
- Properties: username, displayName, avatarUrl, bio, skillLevel, location, timestamps

### AppNotification (`notification.dart`)
- Notification management
- Computed property: `isRead`
- Properties: type, title, message, data, userId, readAt, timestamps

## Services

Located in `/workspaces/m2dg-v1-mobile/apps/mobile/lib/services/`

### GameSessionService (`game_session_service.dart`)
**Core Functions:**
- `startGame(courtId, challengeType, team1Players, team2Players)` - Initialize new game
- `updateScore(gameId, team1Score, team2Score)` - Update game scores
- `endGame(gameId, winnerId)` - Complete game and update player stats
- `getActiveGame(courtId)` - Get current active game at court
- `getUserGames(userId)` - Get player's game history

**Features:**
- Automatic player stats updates on game completion
- Transaction support for data consistency
- Real-time game state management

### NotificationService (`notification_service.dart`)
**Core Functions:**
- `createNotification(userId, type, title, message, data)` - Create notification
- `getUserNotifications(limit)` - Get user's notifications
- `markAsRead(notificationId)` - Mark single notification as read
- `markAllAsRead()` - Mark all notifications as read
- `deleteNotification(notificationId)` - Delete notification
- `notifyQueueUpdate(courtId, challengeType, waitingCount)` - Queue notification
- `notifyGameInvite(userId, courtId, courtName, inviterId, inviterName)` - Game invite

## UI Pages

Located in `/workspaces/m2dg-v1-mobile/apps/mobile/lib/screens/`

### NotificationsPage (`notifications_page.dart`)
**Features:**
- Real-time notification list
- Swipe-to-delete functionality
- Mark as read/unread toggle
- Type-based icons and colors
- Pull-to-refresh
- Relative timestamps (timeago)

**Notification Types:**
- Queue Updates (blue)
- Game Invites (purple)
- Friend Requests (green)
- Messages (orange)
- General (grey)

### ActiveGamePage (`active_game_page.dart`)
**Features:**
- Live score tracking
- Increment/decrement score controls
- Team player lists
- End game with winner selection
- Real-time updates via Supabase subscriptions
- Automatic navigation on game end

**Actions:**
- Update scores for both teams
- End game and declare winner
- Navigate back to court details

### SocialPage (`social_page.dart`)
**Three Tabs:**

1. **Friends Tab**
   - List of accepted friends
   - Friend actions: Message, Challenge, Remove
   - Display name, username, skill level
   - Pull-to-refresh

2. **Requests Tab**
   - Pending friend requests (received)
   - Accept/reject buttons
   - Automatic reciprocal friendship creation

3. **Find Tab**
   - Search for users by username
   - Send friend requests
   - User search delegate with live results

### MessagesPage (`messages_page.dart`)
**Features:**
- Direct messaging between friends
- Real-time message delivery
- Message bubbles (sender vs receiver styling)
- Relative timestamps
- Auto-scroll to latest message
- Mark messages as read automatically
- Send button with loading state

### CourtAdminPage (`court_admin_page.dart`)
**Admin Features:**

1. **Check-ins Tab**
   - View all active check-ins
   - Remove individual check-ins
   - User details with timestamps

2. **Queues Tab**
   - View all queue entries by challenge type
   - Remove individual players from queue
   - Clear all queues (with confirmation)
   - Display wait times

**Access Control:**
- Verifies user is admin via `court_admins` table
- Auto-redirects non-admins
- Refresh button for manual updates

### ProfilePage (Updated)
**Enhanced Features:**
- Real player stats from database
- Win rate calculation
- Point differential display
- Color-coded stats (green/red for positive/negative)
- Skill level from profile
- "Friends & Social" navigation button
- Stats breakdown: Wins, Losses, Games, Win Rate, Point Diff

## Navigation Updates

### New Routes in `main.dart`
```dart
'/notifications' - NotificationsPage
'/active-game/:courtId' - ActiveGamePage (with optional gameId param)
'/social' - SocialPage
'/messages/:recipientId' - MessagesPage
'/court-admin/:courtId' - CourtAdminPage
```

### Enhanced MainShell (`main_shell.dart`)
**New Features:**
- Notification badge with unread count
- Real-time notification counter updates
- Notification icon in app bar
- Navigate to notifications page
- Red badge with count (shows 9+ for >9 notifications)

## Dependencies Added

### pubspec.yaml
```yaml
timeago: ^3.7.0  # Relative time formatting (e.g., "5 minutes ago")
```

## Integration Points

### Court Details Page
- Admin button in app bar (navigates to court admin)
- Link to active game page when game is in progress

### Profile Page
- "Friends & Social" button navigates to social features
- Real-time stats display from player_stats table

### Social Features
- Message button navigates to MessagesPage
- Challenge button (placeholder for future implementation)
- Friend request notifications

## Real-time Features

All pages use Supabase real-time subscriptions:

1. **Notifications** - Auto-update on new notifications
2. **Active Game** - Live score updates
3. **Messages** - Instant message delivery
4. **Social** - Friend request updates
5. **Main Shell** - Notification badge count

## Key Behaviors

### Game Flow
1. Players check in at court
2. Players join queue for challenge type
3. Admin or system starts game
4. Navigate to ActiveGamePage
5. Track scores in real-time
6. End game and select winner
7. Stats automatically updated

### Friend Flow
1. Search for users
2. Send friend request
3. Recipient accepts/rejects
4. Reciprocal friendship created on accept
5. Message or challenge friend

### Notification Flow
1. Event occurs (queue update, game invite, etc.)
2. Notification created via NotificationService
3. Badge count updates in main shell
4. User views notifications
5. Mark as read or swipe to delete

## Security

### RLS Policies
- Users can only see their own notifications
- Users can only see their own messages
- Users can only modify their own stats
- Court admins verified before access
- Friend requests visible to both parties

## Testing Checklist

- [ ] Database tables created successfully
- [ ] Check-in and queue management working
- [ ] Game session start/end flow
- [ ] Score updates in real-time
- [ ] Notifications appear and update badge
- [ ] Friend requests send/accept/reject
- [ ] Direct messaging between friends
- [ ] Court admin access control
- [ ] Player stats update on game completion
- [ ] Profile displays real stats

## Future Enhancements

Mentioned but not implemented:
- Challenge friend functionality (placeholder in social page)
- Court search and filtering
- Leaderboard integration with player stats
- Push notifications (mobile)
- Photo uploads for profiles/courts
- Game video/photo sharing
- Tournament brackets
- Court reservations

## Files Modified/Created

### Created
- `models/game_session.dart`
- `models/player_stats.dart`
- `models/user_profile.dart`
- `models/notification.dart`
- `services/game_session_service.dart`
- `services/notification_service.dart`
- `screens/notifications_page.dart`
- `screens/active_game_page.dart`
- `screens/social_page.dart`
- `screens/messages_page.dart`
- `screens/court_admin_page.dart`
- `docs/database_setup.sql`

### Modified
- `main.dart` - Added routes for new pages
- `widgets/main_shell.dart` - Added notification badge
- `screens/profile_page.dart` - Added real stats and social button
- `screens/court_details_page.dart` - Added admin button
- `pubspec.yaml` - Added timeago dependency
- `services/checkin_service.dart` - Updated cooldown timer
- `screens/courts_page.dart` - Queue exclusivity logic

## Notes

1. **Cooldown Timer Issue**: The 20-minute cooldown timer reset issue when leaving court has been identified but deferred for later fix per user request.

2. **Database Setup**: User must manually paste the SQL from `/docs/database_setup.sql` into Supabase SQL editor.

3. **Admin Permissions**: Court admins must be added manually to `court_admins` table initially.

4. **Message Filtering**: The messages query uses complex OR conditions - may need optimization for large datasets.

5. **Real-time Subscriptions**: Each page sets up its own Supabase channel - consider cleanup on dispose for production.

6. **Avatar Images**: Currently using initial letters in circles - future enhancement could support image uploads.

## Next Steps

1. Test all features in Supabase dashboard
2. Add court admin users to `court_admins` table
3. Test game flow end-to-end
4. Test friend requests and messaging
5. Monitor real-time subscription performance
6. Fix cooldown timer issue
7. Add error tracking/logging
8. Implement challenge friend feature
9. Add push notifications
10. Performance optimization for large datasets
