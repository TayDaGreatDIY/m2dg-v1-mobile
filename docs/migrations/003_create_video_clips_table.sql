-- Create video_clips table for athlete challenge videos
CREATE TABLE video_clips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  duration_seconds INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  views INT DEFAULT 0,
  likes INT DEFAULT 0
);

-- Enable RLS on video_clips table
ALTER TABLE video_clips ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can read all video clips
CREATE POLICY "Users can read all video clips" ON video_clips
  FOR SELECT USING (true);

-- RLS Policy: Users can insert their own video clips
CREATE POLICY "Users can insert their own video clips" ON video_clips
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own video clips
CREATE POLICY "Users can update their own video clips" ON video_clips
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can delete their own video clips
CREATE POLICY "Users can delete their own video clips" ON video_clips
  FOR DELETE USING (auth.uid() = user_id);

-- Create index on user_id and created_at for faster queries
CREATE INDEX idx_video_clips_user_id ON video_clips(user_id);
CREATE INDEX idx_video_clips_created_at ON video_clips(created_at DESC);
