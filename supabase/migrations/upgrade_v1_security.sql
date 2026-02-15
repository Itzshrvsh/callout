-- =====================================================
-- UPGRADE V1: SECURITY & PERFORMANCE
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Create a SECURITY DEFINER function to bypass recursion securely
-- This function runs with the privileges of the creator (postgres/admin),
-- allowing it to read tables even if RLS would normally block it.
CREATE OR REPLACE FUNCTION public.get_user_org_ids(user_uuid UUID)
RETURNS TABLE (org_id UUID) 
SECURITY DEFINER -- Critical: Runs as owner
SET search_path = public -- Secure search path
AS $$
BEGIN
    RETURN QUERY
    SELECT organization_id 
    FROM public.organization_members 
    WHERE user_id = user_uuid 
    AND status = 'active';
END;
$$ LANGUAGE plpgsql;

-- 2. Re-enable RLS on all tables (Fixing the major security hole)
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_approvals ENABLE ROW LEVEL SECURITY;

-- 3. Drop old, insecure/recursive policies
DROP POLICY IF EXISTS "Users can view organizations they belong to" ON public.organizations;
DROP POLICY IF EXISTS "Users can view members of their organizations" ON public.organization_members;
DROP POLICY IF EXISTS "Admins can manage organization members" ON public.organization_members;
DROP POLICY IF EXISTS "Users can view requests in their organizations" ON public.requests;
DROP POLICY IF EXISTS "Members can create requests" ON public.requests;
DROP POLICY IF EXISTS "Approvers can update requests assigned to them" ON public.requests;

-- 4. Create NEW Optimized & Secure Policies using the helper function

-- Organizations: Visible if you are a member
CREATE POLICY "secure_view_orgs" ON public.organizations
    FOR SELECT USING (
        id IN (SELECT org_id FROM public.get_user_org_ids(auth.uid()))
    );

-- Members: Visible if you share an org
CREATE POLICY "secure_view_members" ON public.organization_members
    FOR SELECT USING (
        organization_id IN (SELECT org_id FROM public.get_user_org_ids(auth.uid()))
    );

-- Requests: Visible if you share an org
CREATE POLICY "secure_view_requests" ON public.requests
    FOR SELECT USING (
        organization_id IN (SELECT org_id FROM public.get_user_org_ids(auth.uid()))
    );

-- Requests: Create only if you are an active member
CREATE POLICY "secure_create_requests" ON public.requests
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT org_id FROM public.get_user_org_ids(auth.uid()))
        AND created_by IN (
            SELECT id FROM public.organization_members 
            WHERE user_id = auth.uid()
        )
    );

-- Requests: Approvers can update
CREATE POLICY "secure_update_requests" ON public.requests
    FOR UPDATE USING (
        current_approver_id IN (
            SELECT id FROM public.organization_members 
            WHERE user_id = auth.uid()
        )
    );

-- 5. Performance Indexes (Based on "Architecture & Roadmap")

-- Speed up "My Approvals" dashboard (Critical for managers)
CREATE INDEX IF NOT EXISTS idx_requests_pending_approver 
ON public.requests (current_approver_id) 
WHERE status = 'pending';

-- Speed up "My Recent Requests"
CREATE INDEX IF NOT EXISTS idx_requests_my_recent 
ON public.requests (created_by, created_at DESC);

-- Speed up Organization switching
CREATE INDEX IF NOT EXISTS idx_org_members_user_active 
ON public.organization_members (user_id) 
WHERE status = 'active';

-- Support generic metadata searching (if needed later)
CREATE INDEX IF NOT EXISTS idx_requests_metadata_gin 
ON public.requests USING GIN (metadata);
