-- Yours Tutor: full database setup. Run this ONCE in Supabase -> SQL Editor -> New query -> Run.
create extension if not exists "uuid-ossp";

-- ===== Tables =====
create table public.students (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  full_name text not null check (length(full_name) between 2 and 120),
  phone_number text not null check (length(phone_number) between 7 and 20),
  student_id text not null,
  semester int not null check (semester in (1, 2)),
  stream text not null,
  payment_method text not null,
  transaction_ref text not null unique,
  proof_path text,
  payment_status text not null default 'pending' check (payment_status in ('pending','verified','rejected')),
  notes_access_granted boolean not null default false
);
create table public.course_views (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  course_code text not null,
  stream text
);
create table public.announcements (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  title text not null,
  message text not null,
  tag text not null default 'Important',
  is_active boolean not null default true
);
create table public.resources (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  course_code text not null,
  title text not null,
  kind text not null default 'pdf',
  url text not null,
  visible boolean not null default true
);
create table public.settings (key text primary key, value text);
insert into public.settings (key, value) values ('price','499'), ('deadline',''), ('hotline','0943143416')
  on conflict (key) do nothing;
create table public.support_tickets (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  student_name text not null check (length(student_name) between 1 and 120),
  phone text not null check (length(phone) between 5 and 30),
  issue_description text not null check (length(issue_description) between 1 and 2000),
  status text not null default 'open' check (status in ('open','resolved'))
);
create table public.chat_messages (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamptz default timezone('utc', now()) not null,
  session_id uuid not null,
  sender text not null check (sender in ('student','bot','admin')),
  body text not null check (length(body) between 1 and 1500),
  who text
);
create index chat_session_idx on public.chat_messages (session_id, created_at);

-- ===== Row Level Security =====
alter table public.students enable row level security;
alter table public.course_views enable row level security;
alter table public.announcements enable row level security;
alter table public.resources enable row level security;
alter table public.settings enable row level security;
alter table public.support_tickets enable row level security;
alter table public.chat_messages enable row level security;

-- Visitors (anon) can only do these things:
create policy "anon register" on public.students for insert to anon
  with check (payment_status = 'pending' and notes_access_granted = false);
create policy "anon course view" on public.course_views for insert to anon, authenticated with check (true);
create policy "anon read announcements" on public.announcements for select to anon using (is_active);
create policy "anon read resources" on public.resources for select to anon using (visible);
create policy "anon read settings" on public.settings for select to anon, authenticated using (true);
create policy "anon open ticket" on public.support_tickets for insert to anon with check (status = 'open');

-- Signed-in admins can do everything:
create policy "admin students" on public.students for all to authenticated using (true) with check (true);
create policy "admin course views" on public.course_views for select to authenticated using (true);
create policy "admin announcements" on public.announcements for all to authenticated using (true) with check (true);
create policy "admin resources" on public.resources for all to authenticated using (true) with check (true);
create policy "admin settings" on public.settings for all to authenticated using (true) with check (true);
create policy "admin tickets" on public.support_tickets for all to authenticated using (true) with check (true);
create policy "admin chat" on public.chat_messages for all to authenticated using (true) with check (true);

-- ===== Functions used by the public website =====
-- Students check their registration without being able to read the students table.
create or replace function public.check_registration(q text)
returns table(masked_name text, masked_id text, semester int, stream text, payment_status text)
language sql security definer set search_path = public as $$
  select regexp_replace(s.full_name, '(\S)\S*', '\1***', 'g'), left(s.student_id, 4) || '***',
         s.semester, s.stream, s.payment_status
  from students s
  where length(trim(q)) >= 4
    and (upper(s.student_id) = upper(trim(q)) or s.phone_number = trim(q) or lower(s.full_name) = lower(trim(q)))
  order by s.created_at desc limit 5
$$;
-- Support chat (students use these two functions with a private session id).
create or replace function public.chat_send(sid uuid, msg text, bot_reply text default null, who_in text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(trim(msg)) < 1 or length(msg) > 1500 then raise exception 'Invalid message'; end if;
  if (select count(*) from chat_messages where session_id = sid and sender = 'student' and created_at > now() - interval '1 hour') >= 20
    then raise exception 'Too many messages, please try again later'; end if;
  insert into chat_messages (session_id, sender, body, who) values (sid, 'student', trim(msg), left(who_in, 80));
  if bot_reply is not null then
    insert into chat_messages (session_id, sender, body) values (sid, 'bot', left(bot_reply, 1500));
  end if;
end $$;
create or replace function public.chat_fetch(sid uuid)
returns table(sender text, body text, created_at timestamptz)
language sql security definer set search_path = public as $$
  select sender, body, created_at from chat_messages where session_id = sid order by created_at limit 200
$$;
revoke all on function public.check_registration(text) from public;
revoke all on function public.chat_send(uuid, text, text, text) from public;
revoke all on function public.chat_fetch(uuid) from public;
grant execute on function public.check_registration(text) to anon, authenticated;
grant execute on function public.chat_send(uuid, text, text, text) to anon, authenticated;
grant execute on function public.chat_fetch(uuid) to anon, authenticated;

-- ===== Storage for payment screenshots (private) =====
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('payment-proofs', 'payment-proofs', false, 5242880, array['image/jpeg','image/png','image/webp'])
  on conflict (id) do nothing;
create policy "anon upload proofs" on storage.objects for insert to anon, authenticated with check (bucket_id = 'payment-proofs');
create policy "admin read proofs" on storage.objects for select to authenticated using (bucket_id = 'payment-proofs');

-- ===== Realtime (live updates in the admin dashboard) =====
do $$ begin
  alter publication supabase_realtime add table public.students, public.support_tickets, public.chat_messages;
exception when others then null; end $$;
