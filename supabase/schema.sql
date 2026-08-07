-- הכספים של העסק — מבנה הנתונים בענן
-- להריץ פעם אחת ב-Supabase: SQL Editor ← New query ← להדביק הכל ← Run

-- ── רישומים: שורה לכל הוצאה או הכנסה ──────────────────────────────────────
create table if not exists public.records (
  id          text primary key,
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  type        text not null check (type in ('in','out')),
  date        date not null,
  title       text,
  descr       text,
  cat         text,
  amount      numeric not null,
  pay         text,
  instal      jsonb,
  receipt     jsonb,          -- {name, mime, data} — התמונה עצמה
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now()
);

create index if not exists records_user_updated on public.records (user_id, updated_at desc);
create index if not exists records_user_date    on public.records (user_id, date desc);

-- ── הגדרות: שורה אחת למשתמשת ──────────────────────────────────────────────
create table if not exists public.settings (
  user_id     uuid primary key default auth.uid() references auth.users on delete cascade,
  name        text,
  opening     numeric default 0,
  budget      jsonb,
  updated_at  timestamptz not null default now()
);

-- ── הרשאות: כל אחת רואה ועורכת רק את השורות שלה ──────────────────────────
alter table public.records  enable row level security;
alter table public.settings enable row level security;

drop policy if exists "records are private" on public.records;
create policy "records are private" on public.records
  for all
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "settings are private" on public.settings;
create policy "settings are private" on public.settings
  for all
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── חותמת זמן אוטומטית בכל עדכון, כדי שהסנכרון ידע מה חדש יותר ───────────
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists records_touch  on public.records;
create trigger records_touch  before update on public.records
  for each row execute function public.touch_updated_at();

drop trigger if exists settings_touch on public.settings;
create trigger settings_touch before update on public.settings
  for each row execute function public.touch_updated_at();
