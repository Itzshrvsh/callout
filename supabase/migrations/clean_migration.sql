-- =====================================================
-- CLEAN START - Safe Migration Script
-- Run this in Supabase SQL Editor
-- =====================================================

-- Enable UUID extension (safe - won't error if exists)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing objects if they exist (safe cleanup)
-- Drop tables first (CASCADE will drop triggers automatically)
DROP TABLE IF EXISTS public.request_approvals CASCADE;
DROP TABLE IF EXISTS public.requests CASCADE;
DROP TABLE IF EXISTS public.join_requests CASCADE;
DROP TABLE IF EXISTS public.organization_members CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS public.update_request_timestamp();
DROP FUNCTION IF EXISTS public.assign_next_approver(UUID, UUID);
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Drop types
DROP TYPE IF EXISTS approval_action;
DROP TYPE IF EXISTS importance_level;
DROP TYPE IF EXISTS request_status;
DROP TYPE IF EXISTS join_request_status;
DROP TYPE IF EXISTS member_status;
DROP TYPE IF EXISTS member_role;

-- =====================================================
-- CREATE TABLES
-- =====================================================

-- Users table (extends auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizations table
CREATE TABLE public.organizations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    admin_id UUID REFERENCES public.users(id) NOT NULL,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organization members
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

-- Join requests
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

-- Requests
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

-- Request approvals
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
-- ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_approvals ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view their own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- Organizations policies
CREATE POLICY "Users can view organizations they belong to"
    ON public.organizations FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE organization_id = organizations.id
            AND user_id = auth.uid()
            AND status = 'active'
        )
    );

CREATE POLICY "Users can create organizations"
    ON public.organizations FOR INSERT
    WITH CHECK (auth.uid() = admin_id);

CREATE POLICY "Admins can update their organizations"
    ON public.organizations FOR UPDATE
    USING (auth.uid() = admin_id);

-- Organization members policies
CREATE POLICY "Users can view members of their organizations"
    ON public.organization_members FOR SELECT
    USING (user_id = auth.uid() OR organization_id IN (
        SELECT organization_id FROM public.organization_members 
        WHERE user_id = auth.uid() AND status = 'active'
    ));

CREATE POLICY "Admins can manage organization members"
    ON public.organization_members FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organizations
            WHERE id = organization_members.organization_id
            AND admin_id = auth.uid()
        )
    );

-- Join requests policies
CREATE POLICY "Users can view their own join requests"
    ON public.join_requests FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create join requests"
    ON public.join_requests FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view join requests for their organizations"
    ON public.join_requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organizations
            WHERE id = join_requests.organization_id
            AND admin_id = auth.uid()
        )
    );

CREATE POLICY "Admins can update join requests"
    ON public.join_requests FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.organizations
            WHERE id = join_requests.organization_id
            AND admin_id = auth.uid()
        )
    );

-- Requests policies
CREATE POLICY "Users can view requests in their organizations"
    ON public.requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE organization_id = requests.organization_id
            AND user_id = auth.uid()
            AND status = 'active'
        )
    );

CREATE POLICY "Members can create requests"
    ON public.requests FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE id = created_by
            AND user_id = auth.uid()
            AND status = 'active'
        )
    );

CREATE POLICY "Approvers can update requests assigned to them"
    ON public.requests FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE id = current_approver_id
            AND user_id = auth.uid()
        )
    );

-- Request approvals policies
CREATE POLICY "Users can view approvals in their organizations"
    ON public.request_approvals FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.requests r
            JOIN public.organization_members om ON r.organization_id = om.organization_id
            WHERE r.id = request_approvals.request_id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
        )
    );

CREATE POLICY "Approvers can create approval records"
    ON public.request_approvals FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE id = approver_id
            AND user_id = auth.uid()
        )
    );

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
