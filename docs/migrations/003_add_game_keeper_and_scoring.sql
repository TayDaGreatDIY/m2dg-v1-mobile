-- Create game_keeper_profiles table for verified game scorekeepers
CREATE TABLE IF NOT EXISTS game_keeper_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  display_name TEXT NOT NULL,
  profile_picture_url TEXT,
  games_kept_total INTEGER DEFAULT 0 NOT NULL,
  average_accuracy DECIMAL(5,2) DEFAULT 0.0 NOT NULL,
  bio TEXT,
  certification_date TIMESTAMP WITH TIME ZONE,
  is_verified BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE game_keeper_profiles ENABLE ROW LEVEL SECURITY;

-- Game keeper policies
CREATE POLICY "Game keepers can view their own profile" ON game_keeper_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view verified game keepers" ON game_keeper_profiles
  FOR SELECT USING (is_verified = true);

CREATE POLICY "Game keepers can update their own profile" ON game_keeper_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Create game_session_scores table for storing game final scores
CREATE TABLE IF NOT EXISTS game_session_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE NOT NULL,
  game_keeper_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  creator_score INTEGER NOT NULL,
  opponent_score INTEGER NOT NULL,
  winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(challenge_id)
);

-- Enable RLS on game_session_scores
ALTER TABLE game_session_scores ENABLE ROW LEVEL SECURITY;

-- Policies for game scores
CREATE POLICY "Challenge participants can view scores" ON game_session_scores
  FOR SELECT USING (
    challenge_id IN (
      SELECT id FROM challenges 
      WHERE auth.uid() = creator_id OR auth.uid() = opponent_id
    )
  );

CREATE POLICY "Game keepers can record scores" ON game_session_scores
  FOR INSERT WITH CHECK (
    game_keeper_id = auth.uid() OR 
    game_keeper_id IS NULL
  );
