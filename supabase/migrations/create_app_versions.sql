-- Create app_versions table for update checking
CREATE TABLE public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    platform TEXT NOT NULL, -- 'android', 'ios', 'windows', 'macos', 'web'
    download_url TEXT NOT NULL,
    description TEXT,
    is_mandatory BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Policies
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow public read access (so app can check version without login if needed, or authenticated)
CREATE POLICY "Enable read access for all users" ON public.app_versions
    FOR SELECT
    USING (true);

-- Allow only admins to insert/update/delete (assuming admin role exists or using service role)
-- For now, we'll restrict write to service role or explicit admin check if you have an admin dashboard.
-- Simpler: Allow read only for now. Admin inserts via SQL Editor or Dashboard.
