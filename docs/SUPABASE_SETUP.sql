-- M2DG v1 - Supabase Database Setup
-- Run this SQL in the Supabase SQL Editor to create all required tables

-- ============================================================================
-- 1. PROFILES TABLE (already exists, but ensure it has the right fields)
-- ============================================================================
-- This table should already be created by auth.users trigger
-- But we need to ensure it has display_name and username fields

-- If profiles doesn't exist or needs updating, run:
-- CREATE TABLE IF NOT EXISTS profiles (
--   id uuid references auth.users on delete cascade primary key,
--   username text unique,
--   display_name text,
--   avatar_url text,
--   bio text,
--   created_at timestamp with time zone default timezone('utc'::text, now()) not null,
--   updated_at timestamp with time zone default timezone('utc'::text, now()) not null
-- );

-- ============================================================================
-- 2. USER_LEVELS TABLE
-- ============================================================================
-- Tracks player progression: rookie, intermediate, advanced, pro
CREATE TABLE IF NOT EXISTS user_levels (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null unique,
  level text default 'rookie' not null check (level in ('rookie', 'intermediate', 'advanced', 'pro')),
  xp integer default 0 not null,
  wins integer default 0 not null,
  losses integer default 0 not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table user_levels enable row level security;

-- Create policies
create policy "Users can view their own level" on user_levels
  for select using (auth.uid() = user_id);

create policy "Users can update their own level" on user_levels
  for update using (auth.uid() = user_id);

create policy "Service can insert user levels" on user_levels
  for insert with check (true);

-- ============================================================================
-- 3. USER_WALLET TABLE
-- ============================================================================
-- Manages user funds for wagers/stakes
CREATE TABLE IF NOT EXISTS user_wallet (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null unique,
  balance numeric(10,2) default 0.00 not null,
  total_wagered numeric(10,2) default 0.00 not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table user_wallet enable row level security;

-- Create policies
create policy "Users can view their own wallet" on user_wallet
  for select using (auth.uid() = user_id);

create policy "Users can update their own wallet" on user_wallet
  for update using (auth.uid() = user_id);

create policy "Service can insert wallets" on user_wallet
  for insert with check (true);

-- ============================================================================
-- 4. CHALLENGES TABLE
-- ============================================================================
-- Core challenges/matches system
CREATE TABLE IF NOT EXISTS challenges (
  id uuid default gen_random_uuid() primary key,
  creator_id uuid references auth.users on delete cascade not null,
  opponent_id uuid references auth.users on delete cascade not null,
  challenge_type text not null check (challenge_type in ('1v1', '3pt', 'FT', 'team')),
  court_id uuid references courts on delete set null,
  status text default 'open' not null check (status in ('pending_approval', 'open', 'accepted', 'declined', 'live', 'completed')),
  has_wager boolean default false not null,
  wager_amount numeric(10,2) default 0.00,
  scoring_method text check (scoring_method in ('self_ref', 'referee_requested')),
  creator_agreed_to_scoring boolean default false not null,
  opponent_agreed_to_scoring boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  winner_id uuid references auth.users on delete set null
);

-- Enable RLS
alter table challenges enable row level security;

-- Create policies
create policy "Users can view challenges they created or joined" on challenges
  for select using (auth.uid() = creator_id or auth.uid() = opponent_id);

create policy "Users can create challenges" on challenges
  for insert with check (auth.uid() = creator_id);

create policy "Users can update challenges they're involved in" on challenges
  for update using (auth.uid() = creator_id or auth.uid() = opponent_id);

-- Allow anyone to view open challenges for the "available" tab
create policy "Anyone can view open challenges" on challenges
  for select using (status = 'open');

-- ============================================================================
-- INDEXES (for performance)
-- ============================================================================
create index if not exists challenges_creator_id_idx on challenges(creator_id);
create index if not exists challenges_opponent_id_idx on challenges(opponent_id);
create index if not exists challenges_status_idx on challenges(status);
create index if not exists challenges_created_at_idx on challenges(created_at);
create index if not exists user_levels_user_id_idx on user_levels(user_id);
create index if not exists user_wallet_user_id_idx on user_wallet(user_id);

-- ============================================================================
-- Insert seed data (optional)
-- ============================================================================
-- You can manually insert test challenges here if needed
