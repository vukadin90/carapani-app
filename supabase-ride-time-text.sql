-- Dodaje polje za tekstualni opis vremena polaska moto vožnje.
-- Pokrenuti jednom u Supabase Dashboard > SQL Editor.
ALTER TABLE public.rides
ADD COLUMN IF NOT EXISTS departure_time_text text;
