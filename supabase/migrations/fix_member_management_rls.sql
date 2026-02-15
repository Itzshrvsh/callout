-- Allow Admins to manage members
-- Currently, likely only the user themselves can insert their own record, or policies are too restrictive.

-- Policy: Admins can insert/update/delete members for their organizations
DROP POLICY IF EXISTS "Admins can manage members" ON public.organization_members;
CREATE POLICY "Admins can manage members"
    ON public.organization_members
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members as admin_check
            WHERE admin_check.organization_id = organization_members.organization_id
            AND admin_check.user_id = auth.uid()
            AND admin_check.role IN ('admin', 'owner')
            AND admin_check.status = 'active'
        )
    );

-- Policy: Users can view public profile of other users (so we can see names in join requests)
-- Assuming public.users is intended to be visible to authenticated users
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.users;
CREATE POLICY "Authenticated users can view profiles"
    ON public.users FOR SELECT
    TO authenticated
    USING (true);

-- Ensure join_requests inserts include user data if possible, generally handled by app logic
-- But let's make sure we can VIEW the join requests if we are admin
DROP POLICY IF EXISTS "Admins can view join requests" ON public.join_requests;
CREATE POLICY "Admins can view join requests"
    ON public.join_requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE organization_id = join_requests.organization_id
            AND user_id = auth.uid()
            AND role IN ('admin', 'owner')
        )
    );

-- Allow users to create join requests for themselves
DROP POLICY IF EXISTS "Users can create join requests" ON public.join_requests;
CREATE POLICY "Users can create join requests"
    ON public.join_requests FOR INSERT
    WITH CHECK (auth.uid() = user_id);
