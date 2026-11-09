create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    handle text not null,
    first_name text not null,
    surname text,
    avatar_url text,
    birth_date date not null,
    created_at timestamptz not null default now(),
    constraint profiles_handle_format check (handle ~ '^@[A-Za-z0-9_]{3,24}$'),
    constraint profiles_first_name_nonempty check (length(trim(first_name)) > 0)
);
create unique index profiles_handle_unique_ci on public.profiles (lower(handle));

-- Reserves a public handle as soon as Auth receives a sign-up, before email confirmation.
create table private.handle_reservations (
    normalized_handle text primary key,
    user_id uuid not null unique references auth.users(id) on delete cascade,
    handle text not null,
    expires_at timestamptz not null default (now() + interval '72 hours')
);
alter table private.handle_reservations enable row level security;
revoke all on private.handle_reservations from public, anon, authenticated;
create policy handle_reservations_deny_client_access on private.handle_reservations
    for all to anon, authenticated using (false) with check (false);

-- Only these fields participate in user discovery; birth date stays in profiles.
create table public.public_profiles (
    id uuid primary key references public.profiles(id) on delete cascade,
    handle text not null,
    first_name text not null,
    surname text,
    avatar_url text
);
create index public_profiles_name_search on public.public_profiles (lower(first_name), lower(coalesce(surname, '')));
create index public_profiles_handle_search on public.public_profiles (lower(handle) text_pattern_ops);

create table public.conversations (
    id uuid primary key default gen_random_uuid(),
    kind text not null check (kind in ('notes', 'direct')),
    title text not null,
    owner_id uuid references auth.users(id) on delete cascade,
    direct_user_a uuid references auth.users(id) on delete cascade,
    direct_user_b uuid references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint conversations_kind_shape check (
        (kind = 'notes' and owner_id is not null and direct_user_a is null and direct_user_b is null)
        or (kind = 'direct' and owner_id is null and direct_user_a is not null and direct_user_b is not null and direct_user_a < direct_user_b)
    )
);
create unique index conversations_one_notes_per_owner on public.conversations(owner_id) where kind = 'notes';
create unique index conversations_one_direct_pair on public.conversations(direct_user_a, direct_user_b) where kind = 'direct';
create index conversations_direct_user_b_idx on public.conversations(direct_user_b);

create table public.conversation_members (
    conversation_id uuid not null references public.conversations(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    joined_at timestamptz not null default now(),
    primary key (conversation_id, user_id)
);
create index conversation_members_by_user on public.conversation_members(user_id, conversation_id);

create table public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null,
    sender_id uuid not null,
    body text not null check (length(body) between 1 and 16000),
    created_at timestamptz not null default now(),
    foreign key (conversation_id, sender_id)
        references public.conversation_members(conversation_id, user_id) on delete cascade
);
create index messages_conversation_cursor on public.messages(conversation_id, created_at desc, id desc);
create index messages_sender_membership_idx on public.messages(conversation_id, sender_id);

alter table public.profiles enable row level security;
alter table public.public_profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

revoke all on public.profiles, public.public_profiles, public.conversations, public.conversation_members, public.messages from anon, authenticated;
grant select on public.profiles to authenticated;
grant select on public.public_profiles, public.conversations, public.conversation_members, public.messages to authenticated;
grant insert on public.messages to authenticated;

create policy profiles_read_self on public.profiles
    for select to authenticated using ((select auth.uid()) = id);
create policy public_profiles_search on public.public_profiles
    for select to authenticated using (true);
create policy conversations_read_member on public.conversations
    for select to authenticated using (
        exists (select 1 from public.conversation_members m where m.conversation_id = id and m.user_id = (select auth.uid()))
    );
create policy memberships_read_self on public.conversation_members
    for select to authenticated using (user_id = (select auth.uid()));
create policy messages_read_member on public.messages
    for select to authenticated using (
        exists (select 1 from public.conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = (select auth.uid()))
    );
create policy messages_send_as_member on public.messages
    for insert to authenticated with check (
        sender_id = (select auth.uid()) and
        exists (select 1 from public.conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = (select auth.uid()))
    );

create or replace function private.complete_profile(
    p_handle text,
    p_first_name text,
    p_surname text default null,
    p_avatar_url text default null,
    p_birth_date date default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_handle text := trim(p_handle);
    v_conversation_id uuid;
begin
    if v_user_id is null then raise exception 'authentication required' using errcode = '42501'; end if;
    if v_handle !~ '^@[A-Za-z0-9_]{3,24}$' then raise exception 'invalid handle' using errcode = '22023'; end if;
    if length(trim(coalesce(p_first_name, ''))) = 0 then raise exception 'first name required' using errcode = '22023'; end if;
    if p_birth_date is null then raise exception 'birth date required' using errcode = '22023'; end if;

    insert into public.profiles(id, handle, first_name, surname, avatar_url, birth_date)
    values (v_user_id, v_handle, trim(p_first_name), nullif(trim(p_surname), ''), nullif(trim(p_avatar_url), ''), p_birth_date)
    on conflict (id) do update set handle = excluded.handle, first_name = excluded.first_name,
        surname = excluded.surname, avatar_url = excluded.avatar_url, birth_date = excluded.birth_date;

    insert into public.public_profiles(id, handle, first_name, surname, avatar_url)
    values (v_user_id, v_handle, trim(p_first_name), nullif(trim(p_surname), ''), nullif(trim(p_avatar_url), ''))
    on conflict (id) do update set handle = excluded.handle, first_name = excluded.first_name,
        surname = excluded.surname, avatar_url = excluded.avatar_url;

    insert into public.conversations(kind, title, owner_id) values ('notes', 'Нотатник', v_user_id)
    on conflict (owner_id) where kind = 'notes' do nothing;
    select id into v_conversation_id from public.conversations where owner_id = v_user_id and kind = 'notes';
    insert into public.conversation_members(conversation_id, user_id) values (v_conversation_id, v_user_id)
    on conflict do nothing;
    return v_user_id;
end;
$$;

-- Supabase Auth email sign-up stores the pending profile fields in user metadata.
-- Create the discoverable profile and the real Notes conversation only after email confirmation.
create or replace function private.create_profile_after_email_confirmation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_handle text := trim(coalesce(new.raw_user_meta_data ->> 'handle', ''));
    v_first_name text := trim(coalesce(new.raw_user_meta_data ->> 'first_name', ''));
    v_surname text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'surname', '')), '');
    v_birth_date date;
    v_conversation_id uuid;
begin
    if tg_op = 'INSERT' then
        if v_handle !~ '^@[A-Za-z0-9_]{3,24}$' or v_first_name = '' then
            raise exception 'profile metadata is invalid';
        end if;
        delete from private.handle_reservations where expires_at < now();
        if exists (select 1 from public.profiles where lower(handle) = lower(v_handle)) then
            raise exception 'handle is unavailable';
        end if;
        insert into private.handle_reservations(normalized_handle, user_id, handle)
        values (lower(v_handle), new.id, v_handle);
    end if;
    if new.email_confirmed_at is null then return new; end if;
    if tg_op = 'UPDATE' and old.email_confirmed_at is not null then return new; end if;
    v_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;

    insert into public.profiles(id, handle, first_name, surname, birth_date)
    values (new.id, v_handle, v_first_name, v_surname, v_birth_date);
    insert into public.public_profiles(id, handle, first_name, surname)
    values (new.id, v_handle, v_first_name, v_surname);
    insert into public.conversations(kind, title, owner_id) values ('notes', 'Нотатник', new.id)
    on conflict (owner_id) where kind = 'notes' do nothing;
    select id into v_conversation_id from public.conversations where owner_id = new.id and kind = 'notes';
    insert into public.conversation_members(conversation_id, user_id) values (v_conversation_id, new.id)
    on conflict do nothing;
    delete from private.handle_reservations where user_id = new.id;
    return new;
end;
$$;

revoke all on function private.create_profile_after_email_confirmation() from public, anon, authenticated;
create trigger on_auth_user_email_confirmed
    after insert or update of email_confirmed_at on auth.users
    for each row execute function private.create_profile_after_email_confirmation();

create or replace function public.search_users(p_query text)
returns table(id uuid, handle text, first_name text, surname text, avatar_url text)
language sql
stable
security invoker
set search_path = ''
as $$
    select p.id, p.handle, p.first_name, p.surname, p.avatar_url
    from public.public_profiles p
    where auth.uid() is not null
      and p.id <> auth.uid()
      and length(trim(coalesce(p_query, ''))) >= 2
      and (
          lower(p.handle) like lower(case when left(trim(p_query), 1) = '@' then trim(p_query) else '@' || trim(p_query) end) || '%'
          or lower(p.first_name) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.surname, '')) like '%' || lower(trim(p_query)) || '%'
      )
    order by (lower(p.handle) = lower(case when left(trim(p_query), 1) = '@' then trim(p_query) else '@' || trim(p_query) end)) desc, lower(p.handle)
    limit 25;
$$;

create or replace function private.start_direct_chat(p_other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_me uuid := auth.uid();
    v_a uuid;
    v_b uuid;
    v_conversation_id uuid;
begin
    if v_me is null then raise exception 'authentication required' using errcode = '42501'; end if;
    if p_other_user is null or p_other_user = v_me then raise exception 'invalid recipient' using errcode = '22023'; end if;
    if not exists (select 1 from public.profiles where id = p_other_user) then raise exception 'user not found' using errcode = 'P0002'; end if;
    v_a := least(v_me, p_other_user); v_b := greatest(v_me, p_other_user);
    insert into public.conversations(kind, title, direct_user_a, direct_user_b)
    values ('direct', '', v_a, v_b)
    on conflict (direct_user_a, direct_user_b) where kind = 'direct' do nothing;
    select id into v_conversation_id from public.conversations where kind = 'direct' and direct_user_a = v_a and direct_user_b = v_b;
    insert into public.conversation_members(conversation_id, user_id) values (v_conversation_id, v_a), (v_conversation_id, v_b)
    on conflict do nothing;
    return v_conversation_id;
end;
$$;

create or replace function public.list_conversations()
returns table(id uuid, kind text, title text)
language sql
stable
security invoker
set search_path = ''
as $$
    select c.id, c.kind,
        case when c.kind = 'notes' then c.title
             else coalesce((
                 select p.handle
                 from public.conversation_members other_member
                 join public.public_profiles p on p.id = other_member.user_id
                 where other_member.conversation_id = c.id
                   and other_member.user_id <> (select auth.uid())
                 limit 1
             ), 'Особистий чат')
        end as title
    from public.conversations c
    join public.conversation_members m on m.conversation_id = c.id
    where m.user_id = auth.uid()
    order by coalesce((select max(msg.created_at) from public.messages msg where msg.conversation_id = c.id), c.created_at) desc;
$$;

revoke all on function private.complete_profile(text, text, text, text, date) from public, anon, authenticated;
revoke all on function private.start_direct_chat(uuid) from public, anon, authenticated;
grant execute on function private.complete_profile(text, text, text, text, date) to authenticated;
grant execute on function private.start_direct_chat(uuid) to authenticated;
create or replace function public.complete_profile(
    p_handle text,
    p_first_name text,
    p_surname text default null,
    p_avatar_url text default null,
    p_birth_date date default null
) returns uuid
language sql
security invoker
set search_path = ''
as $$ select private.complete_profile(p_handle, p_first_name, p_surname, p_avatar_url, p_birth_date); $$;

create or replace function public.start_direct_chat(p_other_user uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $$ select private.start_direct_chat(p_other_user); $$;

revoke all on function public.complete_profile(text, text, text, text, date) from public, anon;
revoke all on function public.search_users(text) from public, anon;
revoke all on function public.start_direct_chat(uuid) from public, anon;
revoke all on function public.list_conversations() from public, anon;
grant execute on function public.complete_profile(text, text, text, text, date) to authenticated;
grant execute on function public.search_users(text) to authenticated;
grant execute on function public.start_direct_chat(uuid) to authenticated;
grant execute on function public.list_conversations() to authenticated;

do $$
begin
    alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;
