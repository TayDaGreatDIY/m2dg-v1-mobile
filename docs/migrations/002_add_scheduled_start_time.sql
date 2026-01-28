-- Add scheduled_start_time to challenges table
-- This tracks when the game is scheduled to begin

ALTER TABLE challenges
ADD COLUMN scheduled_start_time TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Add creator_ready and opponent_ready flags to track game readiness
ALTER TABLE challenges
ADD COLUMN creator_ready BOOLEAN DEFAULT FALSE NOT NULL;

ALTER TABLE challenges
ADD COLUMN opponent_ready BOOLEAN DEFAULT FALSE NOT NULL;

-- Add referee_requested flag and assigned_referee_id
ALTER TABLE challenges
ADD COLUMN referee_requested BOOLEAN DEFAULT FALSE NOT NULL;

ALTER TABLE challenges
ADD COLUMN assigned_referee_id UUID REFERENCES auth.users ON DELETE SET NULL;

-- Create referee_assignments table for referee notification system
CREATE TABLE IF NOT EXISTS referee_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE NOT NULL,
  referee_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  responded_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(challenge_id, referee_id)
);

-- Enable RLS on referee_assignments
ALTER TABLE referee_assignments ENABLE ROW LEVEL SECURITY;

-- Referee assignment policies
CREATE POLICY "Referees can view their own assignments" ON referee_assignments
  FOR SELECT USING (auth.uid() = referee_id);

CREATE POLICY "Challenge participants can view referee assignments" ON referee_assignments
  FOR SELECT USING (
    challenge_id IN (
      SELECT id FROM challenges 
      WHERE auth.uid() = creator_id OR auth.uid() = opponent_id
    )
  );

CREATE POLICY "Referees can update their own assignments" ON referee_assignments
  FOR UPDATE USING (auth.uid() = referee_id);
