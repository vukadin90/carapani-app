-- Ispravka RLS dozvola za glasanje u aplikaciji ČARAPANI.
-- Omogućava prijavljenim članovima da vide glasove, upisuju svoj glas
-- i ponište isključivo svoj glas.

GRANT SELECT, INSERT, DELETE ON TABLE public.post_votes TO authenticated;

ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view votes" ON public.post_votes;
CREATE POLICY "Members can view votes"
ON public.post_votes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Members can insert their own votes" ON public.post_votes;
CREATE POLICY "Members can insert their own votes"
ON public.post_votes
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Members can delete their own votes" ON public.post_votes;
CREATE POLICY "Members can delete their own votes"
ON public.post_votes
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
