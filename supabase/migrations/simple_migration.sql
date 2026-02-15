-- =====================================================
-- SIMPLIFIED MIGRATION - No Recursion Issues
-- Run this in Supabase SQL Editor
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop everything (CASCADE removes deps)
DROP TABLE IF EXISTS public.request_approvals CASCADE;
DROP TABLE IF EXISTS public.requests CASCADE;
DROP TABLE IF EXISTS public.join_requests CASCADE;
DROP TABLE IF EXISTS public.organization_members CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

DROP FUNCTION IF EXISTS public.update_request_timestamp() CASCADE;
DROP FUNCTION IF EXISTS public.assign_next_approver(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

DROP TYPE IF EXISTS approval_action;
DROP TYPE IF EXISTS importance_level;
DROP TYPE IF EXISTS request_status;
DROP TYPE IF EXISTS join_request_status;
DROP TYPE IF EXISTS member_status;
DROP TYPE IF EXISTS member_role;

-- =====================================================
-- TABLES
-- =====================================================

CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.organizations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    admin_id UUID REFERENCES public.users(id) NOT NULL,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TYPE member_role AS ENUM ('admin', 'ceo', 'manager', 'team_leader', 'member');
CREATE TYPE member_status AS ENUM ('pending', 'active', 'inactive');

CREATE TABLE public.organization_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    role member_role DEFAULT 'member' NOT NULL,
    status member_status DEFAULT 'pending' NOT NULL,
    department TEXT,
    reports_to UUID REFERENCES public.organization_members(id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

CREATE TYPE join_request_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE public.join_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    status join_request_status DEFAULT 'pending' NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by UUID REFERENCES public.users(id),
    UNIQUE(organization_id, user_id, status)
);

CREATE TYPE request_status AS ENUM ('pending', 'approved', 'rejected', 'escalated');
CREATE TYPE importance_level AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TABLE public.requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE NOT NULL,
    created_by UUID REFERENCES public.organization_members(id) ON DELETE CASCADE NOT NULL,
    request_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    importance_level importance_level DEFAULT 'medium',
    status request_status DEFAULT 'pending' NOT NULL,
    current_approver_id UUID REFERENCES public.organization_members(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TYPE approval_action AS ENUM ('approved', 'rejected', 'escalated');

CREATE TABLE public.request_approvals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    request_id UUID REFERENCES public.requests(id) ON DELETE CASCADE NOT NULL,
    approver_id UUID REFERENCES public.organization_members(id) NOT NULL,
    action approval_action NOT NULL,
    comments TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- ROW LEVEL SECURITY - SIMPLIFIED (No Recursion)
-- =====================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_approvals ENABLE ROW LEVEL SECURITY;

-- Users: can only see themselves
CREATE POLICY "users_select" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "users_update" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "users_insert" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Organizations: disable RLS for now (we'll control via app logic)
ALTER TABLE public.organizations DISABLE ROW LEVEL SECURITY;

-- Members: disable RLS for now  
ALTER TABLE public.organization_members DISABLE ROW LEVEL SECURITY;

-- Join requests: users see own + admins see their orgs
CREATE POLICY "join_requests_select" ON public.join_requests FOR SELECT 
    USING (auth.uid() = user_id OR auth.uid() IN (
        SELECT admin_id FROM public.organizations WHERE id = organization_id
    ));

CREATE POLICY "join_requests_insert" ON public.join_requests FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "join_requests_update" ON public.join_requests FOR UPDATE 
    USING (auth.uid() IN (
        SELECT admin_id FROM public.organizations WHERE id = organization_id
    ));

-- Requests: disable RLS for now
ALTER TABLE public.requests DISABLE ROW LEVEL SECURITY;

-- Approvals: disable RLS for now
ALTER TABLE public.request_approvals DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.assign_next_approver(
    p_request_id UUID,
    p_current_approver_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_organization_id UUID;
    v_created_by UUID;
    v_next_approver_id UUID;
    v_current_role member_role;
BEGIN
    SELECT organization_id, created_by
    INTO v_organization_id, v_created_by
    FROM public.requests
    WHERE id = p_request_id;

    IF p_current_approver_id IS NULL THEN
        SELECT reports_to
        INTO v_next_approver_id
        FROM public.organization_members
        WHERE id = v_created_by;
    ELSE
        SELECT role INTO v_current_role
        FROM public.organization_members
        WHERE id = p_current_approver_id;

        IF v_current_role = 'team_leader' THEN
            SELECT id INTO v_next_approver_id
            FROM public.organization_members
            WHERE organization_id = v_organization_id
            AND role = 'manager'
            AND status = 'active'
            LIMIT 1;
        ELSIF v_current_role = 'manager' THEN
            SELECT id INTO v_next_approver_id
            FROM public.organization_members
            WHERE organization_id = v_organization_id
            AND role = 'ceo'
            AND status = 'active'
            LIMIT 1;
        ELSIF v_current_role = 'ceo' THEN
            SELECT om.id INTO v_next_approver_id
            FROM public.organization_members om
            JOIN public.organizations o ON om.organization_id = o.id
            WHERE om.organization_id = v_organization_id
            AND om.role = 'admin'
            AND om.status = 'active'
            LIMIT 1;
        END IF;
    END IF;

    RETURN v_next_approver_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_request_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER update_request_timestamp
    BEFORE UPDATE ON public.requests
    FOR EACH ROW
    EXECUTE FUNCTION public.update_request_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_organization_members_org_user ON public.organization_members(organization_id, user_id);
CREATE INDEX idx_organization_members_user ON public.organization_members(user_id);
CREATE INDEX idx_join_requests_org_status ON public.join_requests(organization_id, status);
CREATE INDEX idx_requests_org ON public.requests(organization_id);
CREATE INDEX idx_requests_approver ON public.requests(current_approver_id);
CREATE INDEX idx_requests_created_by ON public.requests(created_by);
CREATE INDEX idx_request_approvals_request ON public.request_approvals(request_id);
