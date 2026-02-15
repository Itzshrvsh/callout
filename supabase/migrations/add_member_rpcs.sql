-- Function to safely look up a user ID by email
-- This allows finding a user to add them without exposing the entire users table
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(email_input text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres) to bypass RLS
SET search_path = public
AS $$
DECLARE
    target_user_id uuid;
BEGIN
    SELECT id INTO target_user_id
    FROM public.users
    WHERE email = email_input;
    
    RETURN target_user_id;
END;
$$;

-- Function to atomically approve a join request
-- 1. Updates the request status
-- 2. Adds the user to organization_members
-- 3. Returns success/failure
CREATE OR REPLACE FUNCTION public.approve_join_request_transaction(
    request_id_input uuid,
    organization_id_input uuid,
    user_id_input uuid,
    role_input text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 1. Update the request status
    UPDATE public.join_requests
    SET status = 'approved'
    WHERE id = request_id_input;

    -- 2. Check if user is already a member (idempotency)
    IF NOT EXISTS (
        SELECT 1 FROM public.organization_members
        WHERE organization_id = organization_id_input
        AND user_id = user_id_input
    ) THEN
        -- 3. Insert into organization_members
        INSERT INTO public.organization_members (organization_id, user_id, role, status)
        VALUES (organization_id_input, user_id_input, role_input, 'active');
    END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_user_id_by_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_join_request_transaction TO authenticated;
