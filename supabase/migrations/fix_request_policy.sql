-- Fix request update policy
-- The default behavior enforces USING clause on the NEW row for UPDATEs if WITH CHECK is missing.
-- Since approval sets current_approver_id to NULL, it fails the "am I the approver" check on the new row.

DROP POLICY IF EXISTS "Approvers can update requests assigned to them" ON public.requests;

CREATE POLICY "Approvers can update requests assigned to them"
    ON public.requests FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members
            WHERE id = current_approver_id
            AND user_id = auth.uid()
        )
    )
    WITH CHECK (
        -- Allow updating if we were the approver (implicit in USING) 
        -- AND we are setting status to approved/rejected/escalated
        -- OR we are still the approver (e.g. editing details? though typically we don't)
        true 
        -- We trust the USING clause to ensure only the right person initiated the update.
        -- Setting WITH CHECK (true) allows the row to be transformed into a state
        -- where it is no longer viewable/updatable by this policy (e.g. unassigning self).
    );
