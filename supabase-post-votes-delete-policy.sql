-- Dozvoli prijavljenim članovima da ponište isključivo sopstveni glas.
GRANT DELETE ON TABLE public.post_votes TO authenticated;

ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can delete their own votes" ON public.post_votes;

CREATE POLICY "Members can delete their own votes"
ON public.post_votes
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
