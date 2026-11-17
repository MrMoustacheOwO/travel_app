alter table public.trips
  add column if not exists app_data jsonb not null default '{}'::jsonb;

alter table public.trip_members
  add column if not exists app_data jsonb not null default '{}'::jsonb;

alter table public.itinerary_items
  add column if not exists app_data jsonb not null default '{}'::jsonb;

alter table public.expenses
  add column if not exists app_data jsonb not null default '{}'::jsonb;
