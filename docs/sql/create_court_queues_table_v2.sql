-- Create court_queues table with auth.users reference
CREATE TABLE IF NOT EXISTS court_queues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  court_id UUID NOT NULL REFERENCES courts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_size INT DEFAULT 1 CHECK (team_size >= 1 AND team_size <= 10),
  additional_players TEXT[],
  status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting', 'playing', 'called_next', 'checked_in')),
  position_in_queue INT NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  called_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_court_queues_court_id ON court_queues(court_id);
CREATE INDEX IF NOT EXISTS idx_court_queues_user_id ON court_queues(user_id);
CREATE INDEX IF NOT EXISTS idx_court_queues_status ON court_queues(status);
CREATE INDEX IF NOT EXISTS idx_court_queues_position ON court_queues(court_id, position_in_queue);
CREATE INDEX IF NOT EXISTS idx_court_queues_created ON court_queues(created_at DESC);

-- Enable RLS
ALTER TABLE court_queues ENABLE ROW LEVEL SECURITY;

-- RLS Policy 1: Users can view all queue entries for courts
CREATE POLICY "Users can view court queues"
ON court_queues FOR SELECT
USING (true);

-- RLS Policy 2: Users can insert their own queue entries
CREATE POLICY "Users can join queue"
ON court_queues FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- RLS Policy 3: Users can update their own queue status to check_in
CREATE POLICY "Users can check in themselves"
ON court_queues FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id AND status IN ('called_next', 'checked_in'));

-- RLS Policy 4: Users can delete their own queue entry (leave queue)
CREATE POLICY "Users can leave queue"
ON court_queues FOR DELETE
USING (auth.uid() = user_id);

-- RLS Policy 5: System/Service role can update queue status
CREATE POLICY "Service can manage queue state"
ON court_queues FOR UPDATE
USING (true)
WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON court_queues TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
