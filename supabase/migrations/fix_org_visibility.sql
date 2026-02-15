-- Fix organization RLS to allow searching
-- Currently users can only see organizations they are members of

-- Drop the restrictive policy
DROP POLICY IF EXISTS "Users can view organizations they belong to" ON public.organizations;

-- Create new policy to allow authenticated users to view all organizations (needed for search/join)
CREATE POLICY "Authenticated users can view all organizations"
    ON public.organizations FOR SELECT
    TO authenticated
    USING (true);
