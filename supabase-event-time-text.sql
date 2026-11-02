-- Dodaje polje za opis vremena događaja kada tačan sat polaska nije poznat.
-- Pokrenuti jednom u Supabase Dashboard > SQL Editor.
ALTER TABLE public.club_events
ADD COLUMN IF NOT EXISTS event_time_text text;
