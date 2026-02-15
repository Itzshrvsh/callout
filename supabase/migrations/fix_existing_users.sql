-- Fix for existing users not in public.users table
-- Run this ONCE in Supabase SQL Editor

-- Insert any auth.users that are missing from public.users
INSERT INTO public.users (id, email, full_name, avatar_url)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', ''),
    COALESCE(raw_user_meta_data->>'avatar_url', '')
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.users);
