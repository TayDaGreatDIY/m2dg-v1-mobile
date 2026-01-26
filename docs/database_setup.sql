-- Game Sessions Table
CREATE TABLE IF NOT EXISTS game_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  court_id UUID REFERENCES courts(id) ON DELETE CASCADE,
  challenge_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active, completed, cancelled
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ended_at TIMESTAMP WITH TIME ZONE,
  winner_team TEXT, -- team_a or team_b
  team_a_score INTEGER DEFAULT 0,
  team_b_score INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Game Session Players
CREATE TABLE IF NOT EXISTS game_session_players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_session_id UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  team TEXT NOT NULL, -- team_a or team_b
  position INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(game_session_id, user_id)
);

-- Player Stats Table
CREATE TABLE IF NOT EXISTS player_stats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  total_games INTEGER DEFAULT 0,
  total_wins INTEGER DEFAULT 0,
  total_losses INTEGER DEFAULT 0,
  total_points_scored INTEGER DEFAULT 0,
  total_points_against INTEGER DEFAULT 0,
  favorite_court_id UUID REFERENCES courts(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Friends/Connections Table
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, blocked
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, friend_id),
  CHECK (user_id != friend_id)
);

-- Messages Table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- queue_update, game_invite, friend_request, etc
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Court Admins Table
CREATE TABLE IF NOT EXISTS court_admins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  court_id UUID REFERENCES courts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'admin', -- owner, admin, moderator
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(court_id, user_id)
);

-- User Profiles (extended info)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  username TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  skill_level TEXT, -- beginner, intermediate, advanced, pro
  preferred_position TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_game_sessions_court ON game_sessions(court_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_status ON game_sessions(status);
CREATE INDEX IF NOT EXISTS idx_game_session_players_user ON game_session_players(user_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_user ON player_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_court_admins_court ON court_admins(court_id);
CREATE INDEX IF NOT EXISTS idx_court_admins_user ON court_admins(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Row Level Security Policies

-- Game Sessions: Anyone can view, only admins can create/update
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view game sessions" ON game_sessions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create game sessions" ON game_sessions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Court admins can update game sessions" ON game_sessions FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM court_admins 
    WHERE court_admins.court_id = game_sessions.court_id 
    AND court_admins.user_id = auth.uid()
  )
);

-- Game Session Players: Anyone can view, players and admins can manage
ALTER TABLE game_session_players ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view game session players" ON game_session_players FOR SELECT USING (true);
CREATE POLICY "Players can join games" ON game_session_players FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Players can leave games" ON game_session_players FOR DELETE USING (auth.uid() = user_id);

-- Player Stats: Anyone can view, users can update their own
ALTER TABLE player_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view player stats" ON player_stats FOR SELECT USING (true);
CREATE POLICY "Users can update own stats" ON player_stats FOR ALL USING (auth.uid() = user_id);

-- Friendships: Users can view their own and manage
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their friendships" ON friendships FOR SELECT USING (auth.uid() IN (user_id, friend_id));
CREATE POLICY "Users can create friendships" ON friendships FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their friendships" ON friendships FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their friendships" ON friendships FOR DELETE USING (auth.uid() IN (user_id, friend_id));

-- Messages: Users can view their own messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their messages" ON messages FOR SELECT USING (auth.uid() IN (sender_id, recipient_id));
CREATE POLICY "Users can send messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Recipients can update messages" ON messages FOR UPDATE USING (auth.uid() = recipient_id);

-- Notifications: Users can view and manage their own
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can create notifications" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update their notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their notifications" ON notifications FOR DELETE USING (auth.uid() = user_id);

-- Court Admins: Anyone can view, only owners can manage
ALTER TABLE court_admins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view court admins" ON court_admins FOR SELECT USING (true);
CREATE POLICY "Owners can manage admins" ON court_admins FOR ALL USING (
  EXISTS (
    SELECT 1 FROM court_admins ca
    WHERE ca.court_id = court_admins.court_id 
    AND ca.user_id = auth.uid()
    AND ca.role = 'owner'
  )
);

-- Profiles: Anyone can view, users can update their own
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR ALL USING (auth.uid() = user_id);
