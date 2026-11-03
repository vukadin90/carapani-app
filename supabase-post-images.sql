-- Fotografije za moto vožnje, događaje i klupska obaveštenja
-- Slike se čuvaju u postojećem Supabase Storage bucket-u "club-gallery".
ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS storage_path text;

ALTER TABLE public.club_events
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS storage_path text;

ALTER TABLE public.club_announcements
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS storage_path text;
