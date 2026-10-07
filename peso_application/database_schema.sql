-- WorkNest database schema
-- Normalized design:
--   public.users = common identity/account table
--   public.users.role selects exactly one role profile

create extension if not exists pgcrypto;

create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    email text not null unique,
    role text not null
        constraint users_role_valid
        check (role in ('admin', 'job_seeker', 'employer')),
    account_status text not null default 'active'
        check (account_status in ('active', 'suspended', 'deleted')),
    profile_image text,
    bio text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

do $$
declare
    has_role boolean;
    has_account_type boolean;
begin
    select exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'users'
          and column_name = 'role'
    ) into has_role;
    select exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'users'
          and column_name = 'account_type'
    ) into has_account_type;

    if has_account_type and not has_role then
        alter table public.users rename column account_type to role;
        alter table public.users
            drop constraint if exists users_account_type_valid;
    elsif has_account_type and has_role then
        if exists (
            select 1
            from public.users
            where role is not null
              and account_type is not null
              and role <> account_type
        ) then
            raise exception
                'Cannot rename users.account_type to users.role: conflicting values exist. Reconcile users.role and users.account_type first.';
        end if;

        update public.users
        set role = coalesce(role, account_type)
        where role is null;
        alter table public.users
            drop constraint if exists users_account_type_valid;
        alter table public.users drop column account_type;
    elsif not has_role then
        alter table public.users add column role text;
    end if;
end;
$$;

-- Migrate existing rows so the table primary key is independent of Auth IDs.
do $$
declare
    auth_column_missing boolean;
    constraint_name text;
    referencing_fk record;
    source_column text;
    delete_action text;
    update_action text;
    deferrability text;
begin
    select not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'users'
          and column_name = 'auth_user_id'
    ) into auth_column_missing;

    alter table public.users add column if not exists auth_user_id uuid;
    update public.users set auth_user_id = id where auth_user_id is null;

    create unique index if not exists idx_users_auth_user_id
        on public.users (auth_user_id);

    for referencing_fk in
        select c.conrelid::regclass as relation,
               c.conname as name,
               c.conkey[1] as source_attnum,
               c.confdeltype,
               c.confupdtype,
               c.condeferrable,
               c.condeferred
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.confrelid
         and a.attname = 'id'
        where c.contype = 'f'
          and c.confrelid = 'public.users'::regclass
          and a.attnum = any(c.confkey)
    loop
        select attname into source_column
        from pg_attribute
        where attrelid = referencing_fk.relation
          and attnum = referencing_fk.source_attnum;
        delete_action := case referencing_fk.confdeltype
            when 'r' then 'RESTRICT'
            when 'c' then 'CASCADE'
            when 'n' then 'SET NULL'
            when 'd' then 'SET DEFAULT'
            else 'NO ACTION'
        end;
        update_action := case referencing_fk.confupdtype
            when 'r' then 'RESTRICT'
            when 'c' then 'CASCADE'
            when 'n' then 'SET NULL'
            when 'd' then 'SET DEFAULT'
            else 'NO ACTION'
        end;
        deferrability := case
            when referencing_fk.condeferrable and referencing_fk.condeferred
                then ' DEFERRABLE INITIALLY DEFERRED'
            when referencing_fk.condeferrable
                then ' DEFERRABLE INITIALLY IMMEDIATE'
            else ''
        end;

        execute format(
            'alter table %s drop constraint %I',
            referencing_fk.relation,
            referencing_fk.name
        );
        execute format(
            'alter table %s add constraint %I foreign key (%I) references public.users(auth_user_id) on delete %s on update %s%s',
            referencing_fk.relation,
            referencing_fk.name,
            source_column,
            delete_action,
            update_action,
            deferrability
        );
    end loop;

    for constraint_name in
        select conname
        from pg_constraint
        where conrelid = 'public.users'::regclass
          and contype = 'f'
          and confrelid = 'auth.users'::regclass
    loop
        execute format('alter table public.users drop constraint %I', constraint_name);
    end loop;

    if auth_column_missing then
        update public.users set id = gen_random_uuid();
    end if;

    alter table public.users alter column id set default gen_random_uuid();
    alter table public.users alter column auth_user_id set not null;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.users'::regclass
          and conname = 'users_auth_user_id_fkey'
    ) then
        alter table public.users
            add constraint users_auth_user_id_fkey
            foreign key (auth_user_id) references auth.users(id) on delete cascade;
    end if;
end;
$$;

create table if not exists public.job_seekers (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references public.users(auth_user_id) on delete cascade,
    phone text,
    location text,
    resume_file_name text,
    resume_url text,
    resume_image_file_name text,
    resume_image_url text,
    skills text,
    work_experience text,
    education text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Upgrade installations where role profiles used `id` as their user key.
-- Renaming preserves existing primary-key and foreign-key constraints.
do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'job_seekers'
          and column_name = 'id'
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'job_seekers'
          and column_name = 'user_id'
    ) then
        alter table public.job_seekers rename column id to user_id;
    end if;
end;
$$;

create table if not exists public.employers (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references public.users(auth_user_id) on delete cascade,
    phone text,
    location text,
    company_name text not null,
    company_address text,
    company_description text,
    industry text,
    company_logo text,
    website text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'employers'
          and column_name = 'id'
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'employers'
          and column_name = 'user_id'
    ) then
        alter table public.employers rename column id to user_id;
    end if;
end;
$$;

-- Add employer profile fields when upgrading databases created from older
-- schema versions; CREATE TABLE IF NOT EXISTS does not alter existing tables.
alter table public.employers add column if not exists phone text;
alter table public.employers add column if not exists location text;
alter table public.employers add column if not exists company_name text;
alter table public.employers add column if not exists company_address text;
alter table public.employers add column if not exists company_description text;
alter table public.employers add column if not exists industry text;
alter table public.employers add column if not exists company_logo text;
alter table public.employers add column if not exists website text;

update public.employers e
set company_name = coalesce(
    nullif(trim(u.name), ''),
    nullif(split_part(u.email, '@', 1), ''),
    'Employer'
)
from public.users u
where u.auth_user_id = e.user_id
  and nullif(trim(e.company_name), '') is null;

update public.employers
set company_name = 'Employer'
where nullif(trim(company_name), '') is null;

alter table public.employers alter column company_name set not null;

create table if not exists public.admins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references public.users(auth_user_id) on delete cascade,
    phone text,
    location text,
    permissions text[] not null default ARRAY[]::text[],
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'admins'
          and column_name = 'id'
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'admins'
          and column_name = 'user_id'
    ) then
        alter table public.admins rename column id to user_id;
    end if;
end;
$$;

-- Upgrade role profiles that previously used their user foreign key as PK.
do $$
declare
    table_name text;
    constraint_name text;
    referencing_fks jsonb;
    referencing_fk jsonb;
begin
    foreach table_name in array array['job_seekers', 'employers', 'admins'] loop
        execute format(
            'alter table public.%I add column if not exists id uuid default gen_random_uuid()',
            table_name
        );
        execute format('alter table public.%I alter column id set default gen_random_uuid()', table_name);
        execute format('update public.%I set id = gen_random_uuid() where id is null', table_name);
        execute format('alter table public.%I alter column id set not null', table_name);

        select coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'relation_oid', c.conrelid,
                    'name', c.conname,
                    'definition', pg_get_constraintdef(c.oid)
                )
            ),
            '[]'::jsonb
        )
        into referencing_fks
        from pg_constraint c
        where c.contype = 'f'
          and c.confrelid = format('public.%I', table_name)::regclass;

        for referencing_fk in
            select value from jsonb_array_elements(referencing_fks)
        loop
            execute format(
                'alter table %s drop constraint %I',
                (referencing_fk->>'relation_oid')::oid::regclass,
                referencing_fk->>'name'
            );
        end loop;

        for constraint_name in
            select conname
            from pg_constraint
            where conrelid = format('public.%I', table_name)::regclass
              and contype = 'p'
        loop
            execute format('alter table public.%I drop constraint %I', table_name, constraint_name);
        end loop;

        for constraint_name in
            select conname
            from pg_constraint
            where conrelid = format('public.%I', table_name)::regclass
              and contype = 'f'
              and confrelid = 'public.users'::regclass
        loop
            execute format('alter table public.%I drop constraint %I', table_name, constraint_name);
        end loop;

        execute format(
            'alter table public.%I add constraint %I primary key (id)',
            table_name,
            table_name || '_pkey'
        );
        execute format(
            'create unique index if not exists %I on public.%I (user_id)',
            table_name || '_user_id_key',
            table_name
        );

        for referencing_fk in
            select value from jsonb_array_elements(referencing_fks)
        loop
            execute format(
                'alter table %s add constraint %I %s not valid',
                (referencing_fk->>'relation_oid')::oid::regclass,
                referencing_fk->>'name',
                referencing_fk->>'definition'
            );
        end loop;

        execute format(
            'alter table public.%I add constraint %I foreign key (user_id) references public.users(auth_user_id) on delete cascade',
            table_name,
            table_name || '_user_id_fkey'
        );
    end loop;
end;
$$;

-- Remove the obsolete role-profile trigger. It inserts profile rows with
-- users.id, but role profiles now reference users.auth_user_id through user_id.
do $$
declare
    legacy_trigger record;
begin
    for legacy_trigger in
        select t.tgname,
               t.tgrelid::regclass as relation
        from pg_trigger t
        join pg_proc p on p.oid = t.tgfoid
        join pg_namespace n on n.oid = p.pronamespace
        where not t.tgisinternal
          and n.nspname = 'public'
          and p.proname = 'create_role_profile'
    loop
        execute format(
            'drop trigger %I on %s',
            legacy_trigger.tgname,
            legacy_trigger.relation
        );
    end loop;

    drop function if exists public.create_role_profile();
end;
$$;

-- Replace this before legacy role backfills, since an older install may have
-- a prior profile trigger definition.
create or replace function public.guard_single_role_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform pg_advisory_xact_lock(12586, hashtext(new.user_id::text));

    if tg_table_name = 'job_seekers'
       and exists (
           select 1 from public.employers e
           where e.user_id = new.user_id
       ) then
        raise check_violation
            using message = 'A user may not have both job_seeker and employer profiles.';
    end if;

    if tg_table_name = 'employers'
       and exists (
           select 1 from public.job_seekers js
           where js.user_id = new.user_id
       ) then
        raise check_violation
            using message = 'A user may not have both job_seeker and employer profiles.';
    end if;

    return new;
end;
$$;

revoke all on function public.guard_single_role_profile() from public;

drop trigger if exists job_seekers_guard_single_role on public.job_seekers;
create trigger job_seekers_guard_single_role
before insert on public.job_seekers
for each row
execute function public.guard_single_role_profile();

drop trigger if exists employers_guard_single_role on public.employers;
create trigger employers_guard_single_role
before insert on public.employers
for each row
execute function public.guard_single_role_profile();

drop trigger if exists admins_guard_single_role on public.admins;
create trigger admins_guard_single_role
before insert on public.admins
for each row
execute function public.guard_single_role_profile();

-- Move legacy role values into the dedicated role profile tables.
do $$
declare
    has_legacy_role boolean;
begin
    select exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'users'
          and column_name = 'role'
    ) into has_legacy_role;

    if has_legacy_role then
        execute
            'insert into public.job_seekers (user_id)
             select auth_user_id
             from public.users
             where lower(replace(trim(role::text), ''-'', ''_'')) = ''job_seeker''
             on conflict (user_id) do nothing';

        execute
            'insert into public.employers (user_id, company_name)
             select auth_user_id,
                    coalesce(nullif(trim(name), ''''), nullif(split_part(email, ''@'', 1), ''''), ''Employer'')
             from public.users
             where lower(replace(trim(role::text), ''-'', ''_'')) = ''employer''
             on conflict (user_id) do nothing';

        execute
            'insert into public.admins (user_id)
             select auth_user_id
             from public.users
             where lower(replace(trim(role::text), ''-'', ''_'')) = ''admin''
             on conflict (user_id) do nothing';

        execute
            'select exists (
                select 1
                from public.users
                where role is not null
                  and lower(replace(trim(role::text), ''-'', ''_'')) not in
                      (''job_seeker'', ''employer'', ''admin'')
            )'
        into has_legacy_role;

        if has_legacy_role then
            raise exception
                'Cannot remove users.role: found unsupported role values. Map them to a role profile before rerunning.';
        end if;
    end if;

    insert into public.job_seekers (user_id)
    select u.auth_user_id
    from public.users u
    left join auth.users au on au.id = u.auth_user_id
    where (
        u.role = 'job_seeker'
        or (
            u.role is null
            and lower(replace(trim(au.raw_user_meta_data ->> 'role'), '-', '_'))
                = 'job_seeker'
        )
    )
      and not exists (
          select 1 from public.admins a where a.user_id = u.auth_user_id
      )
      and not exists (
          select 1 from public.job_seekers js where js.user_id = u.auth_user_id
      )
      and not exists (
          select 1 from public.employers e where e.user_id = u.auth_user_id
      )
    on conflict (user_id) do nothing;

    insert into public.employers (user_id, company_name)
    select u.auth_user_id,
           coalesce(nullif(trim(u.name), ''), nullif(split_part(u.email, '@', 1), ''), 'Employer')
    from public.users u
    left join auth.users au on au.id = u.auth_user_id
    where (
        u.role = 'employer'
        or (
            u.role is null
            and lower(replace(trim(au.raw_user_meta_data ->> 'role'), '-', '_'))
                = 'employer'
        )
    )
      and not exists (
          select 1 from public.admins a where a.user_id = u.auth_user_id
      )
      and not exists (
          select 1 from public.job_seekers js where js.user_id = u.auth_user_id
      )
      and not exists (
          select 1 from public.employers e where e.user_id = u.auth_user_id
      )
    on conflict (user_id) do nothing;

    -- Supabase app_metadata is server-controlled; unlike user_metadata, users
    -- cannot grant themselves admin access by editing it from the client.
    insert into public.admins (user_id)
    select au.id
    from auth.users au
    join public.users u on u.auth_user_id = au.id
    where au.raw_app_meta_data ->> 'role' = 'admin'
    on conflict (user_id) do nothing;

    -- Recover role from authoritative/legacy sources before cleaning
    -- conflicting profiles. Otherwise a null role prevents cleanup.
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'users'
          and column_name = 'role'
    ) then
        execute
            'update public.users
             set role = lower(replace(trim(role::text), ''-'', ''_''))
             where role is null
               and lower(replace(trim(role::text), ''-'', ''_'')) in
                   (''admin'', ''job_seeker'', ''employer'')';
    end if;

    update public.users u
    set role = case
        when au.raw_app_meta_data ->> 'role' = 'admin' then 'admin'
        when lower(replace(trim(au.raw_user_meta_data ->> 'role'), '-', '_'))
             in ('job_seeker', 'employer')
            then lower(replace(trim(au.raw_user_meta_data ->> 'role'), '-', '_'))
    end
    from auth.users au
    where u.auth_user_id = au.id
      and u.role is null
      and (
          au.raw_app_meta_data ->> 'role' = 'admin'
          or lower(replace(trim(au.raw_user_meta_data ->> 'role'), '-', '_'))
             in ('job_seeker', 'employer')
      );

    update public.users u
    set role = case
        when exists (select 1 from public.admins a where a.user_id = u.auth_user_id)
            then 'admin'
        when exists (select 1 from public.job_seekers js where js.user_id = u.auth_user_id)
            then 'job_seeker'
        when exists (select 1 from public.employers e where e.user_id = u.auth_user_id)
            then 'employer'
    end
    where u.role is null
      and (
          case when exists (
              select 1 from public.admins a where a.user_id = u.auth_user_id
          ) then 1 else 0 end
          + case when exists (
              select 1 from public.job_seekers js where js.user_id = u.auth_user_id
          ) then 1 else 0 end
          + case when exists (
              select 1 from public.employers e where e.user_id = u.auth_user_id
          ) then 1 else 0 end
      ) = 1;

    if exists (
        select 1
        from public.users
        where role is not null
          and role not in ('admin', 'job_seeker', 'employer')
    ) then
        raise exception
            'Cannot migrate users.role: unsupported values exist. Map each to admin, job_seeker, or employer before rerunning.';
    end if;

    -- Keep the profile selected by users.role when legacy data has
    -- conflicting role profiles. Profiles for users without a recognized
    -- role are left untouched so the validation below can report them.
    delete from public.admins a
    using public.users u
    where a.user_id = u.auth_user_id
      and u.role in ('job_seeker', 'employer');

    delete from public.job_seekers js
    using public.users u
    where js.user_id = u.auth_user_id
      and u.role in ('admin', 'employer');

    delete from public.employers e
    using public.users u
    where e.user_id = u.auth_user_id
      and u.role in ('admin', 'job_seeker');

    -- Ensure each recognized role has its matching profile, including
    -- accounts whose previous profile was removed as a role mismatch.
    insert into public.admins (user_id)
    select u.auth_user_id
    from public.users u
    where u.role = 'admin'
      and not exists (
          select 1 from public.admins a where a.user_id = u.auth_user_id
      )
    on conflict (user_id) do nothing;

    insert into public.job_seekers (user_id)
    select u.auth_user_id
    from public.users u
    where u.role = 'job_seeker'
      and not exists (
          select 1 from public.job_seekers js where js.user_id = u.auth_user_id
      )
    on conflict (user_id) do nothing;

    insert into public.employers (user_id, company_name)
    select u.auth_user_id,
           coalesce(
               nullif(trim(u.name), ''),
               nullif(split_part(u.email, '@', 1), ''),
               'Employer'
           )
    from public.users u
    where u.role = 'employer'
      and not exists (
          select 1 from public.employers e where e.user_id = u.auth_user_id
      )
    on conflict (user_id) do nothing;

    if exists (
        select 1
        from public.users u
        where (
            case when exists (
                select 1 from public.admins a where a.user_id = u.auth_user_id
            ) then 1 else 0 end
            + case when exists (
                select 1 from public.job_seekers js where js.user_id = u.auth_user_id
            ) then 1 else 0 end
            + case when exists (
                select 1 from public.employers e where e.user_id = u.auth_user_id
            ) then 1 else 0 end
        ) > 1
    ) then
        raise exception
            'Some accounts have conflicting role profiles and no usable role to select the correct one. Set role to admin, job_seeker, or employer for the listed accounts, then rerun.'
            using detail = (
                select string_agg(
                    format(
                        '%s (role=%s, profiles=%s)',
                        conflicts.auth_user_id,
                        coalesce(conflicts.role, 'NULL'),
                        conflicts.profiles
                    ),
                    E'\n'
                )
                from (
                    select u.auth_user_id,
                           u.role,
                           concat_ws(
                               ', ',
                               case when exists (
                                   select 1 from public.admins a
                                   where a.user_id = u.auth_user_id
                               ) then 'admin' end,
                               case when exists (
                                   select 1 from public.job_seekers js
                                   where js.user_id = u.auth_user_id
                               ) then 'job_seeker' end,
                               case when exists (
                                   select 1 from public.employers e
                                   where e.user_id = u.auth_user_id
                               ) then 'employer' end
                           ) as profiles
                    from public.users u
                    where (
                        case when exists (
                            select 1 from public.admins a where a.user_id = u.auth_user_id
                        ) then 1 else 0 end
                        + case when exists (
                            select 1 from public.job_seekers js where js.user_id = u.auth_user_id
                        ) then 1 else 0 end
                        + case when exists (
                            select 1 from public.employers e where e.user_id = u.auth_user_id
                        ) then 1 else 0 end
                    ) > 1
                    order by u.auth_user_id
                    limit 20
                ) conflicts
            );
    end if;

    if exists (
        select 1
        from public.users
        where role is not null
          and role not in ('admin', 'job_seeker', 'employer')
    ) then
        raise exception
            'Cannot migrate users.role: unsupported values exist. Map each to admin, job_seeker, or employer before rerunning.';
    end if;

    update public.users u
    set role = coalesce(
        u.role,
        case
            when exists (select 1 from public.admins a where a.user_id = u.auth_user_id)
                then 'admin'
            when exists (select 1 from public.job_seekers js where js.user_id = u.auth_user_id)
                then 'job_seeker'
            when exists (select 1 from public.employers e where e.user_id = u.auth_user_id)
                then 'employer'
        end
    );

    if exists (
        select 1
        from public.users u
        where u.role is null
           or (u.role = 'admin' and not exists (
                select 1 from public.admins a where a.user_id = u.auth_user_id
           ))
           or (u.role = 'job_seeker' and not exists (
                select 1 from public.job_seekers js where js.user_id = u.auth_user_id
           ))
           or (u.role = 'employer' and not exists (
                select 1 from public.employers e where e.user_id = u.auth_user_id
           ))
    ) then
        raise exception
            'Cannot enforce users.role: every user must have exactly one matching role profile. Create or correct the matching profile, then rerun.';
    end if;

    alter table public.users alter column role set not null;

    if not exists (
        select 1
        from pg_constraint
        where conrelid = 'public.users'::regclass
          and conname = 'users_role_valid'
    ) then
        alter table public.users
            add constraint users_role_valid
            check (role in ('admin', 'job_seeker', 'employer')) not valid;
    end if;
    alter table public.users validate constraint users_role_valid;
end;
$$;

create or replace function public.guard_single_role_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    expected_type text;
begin
    perform pg_advisory_xact_lock(12586, hashtext(new.user_id::text));

    select role
    into expected_type
    from public.users
    where auth_user_id = new.user_id;

    if expected_type is null then
        raise foreign_key_violation
            using message = 'A matching users account is required before creating a role profile.';
    end if;

    if (tg_table_name = 'admins' and expected_type <> 'admin')
       or (tg_table_name = 'job_seekers' and expected_type <> 'job_seeker')
       or (tg_table_name = 'employers' and expected_type <> 'employer') then
        raise check_violation
            using message = format(
                'The %s profile must match users.role (%s).',
                tg_table_name,
                expected_type
            );
    end if;

    if (tg_table_name <> 'admins' and exists (
            select 1 from public.admins a where a.user_id = new.user_id
        ))
       or (tg_table_name <> 'job_seekers' and exists (
            select 1 from public.job_seekers js where js.user_id = new.user_id
        ))
       or (tg_table_name <> 'employers' and exists (
            select 1 from public.employers e where e.user_id = new.user_id
        )) then
        raise check_violation
            using message = 'A user may have only one role profile matching users.role.';
    end if;

    return new;
end;
$$;

drop trigger if exists job_seekers_guard_single_role on public.job_seekers;
create trigger job_seekers_guard_single_role
before insert or update of user_id on public.job_seekers
for each row
execute function public.guard_single_role_profile();

drop trigger if exists employers_guard_single_role on public.employers;
create trigger employers_guard_single_role
before insert or update of user_id on public.employers
for each row
execute function public.guard_single_role_profile();

drop trigger if exists admins_guard_single_role on public.admins;
create trigger admins_guard_single_role
before insert or update of user_id on public.admins
for each row
execute function public.guard_single_role_profile();

-- This legacy trigger references columns being moved out of users.
drop trigger if exists users_sync_legacy_job_seeker_profile on public.users;

-- Add the role-specific contact columns when upgrading existing tables.
alter table public.job_seekers add column if not exists phone text;
alter table public.job_seekers add column if not exists location text;
alter table public.employers add column if not exists phone text;
alter table public.employers add column if not exists location text;
alter table public.admins add column if not exists phone text;
alter table public.admins add column if not exists location text;

-- Copy legacy contact details to every existing role profile before removing
-- them from users. Fail rather than silently losing data for users with no
-- role profile; create the correct profile for those accounts, then rerun.
do $$
declare
    contact_column text;
    has_legacy_column boolean;
begin
    foreach contact_column in array array['phone', 'location'] loop
        select exists (
            select 1
            from information_schema.columns
            where table_schema = 'public'
              and table_name = 'users'
              and column_name = contact_column
        ) into has_legacy_column;

        if has_legacy_column then
            execute format(
                'update public.job_seekers profile
                 set %1$I = coalesce(profile.%1$I, u.%1$I)
                 from public.users u
                 where profile.user_id = u.auth_user_id',
                contact_column
            );
            execute format(
                'update public.employers profile
                 set %1$I = coalesce(profile.%1$I, u.%1$I)
                 from public.users u
                 where profile.user_id = u.auth_user_id',
                contact_column
            );
            execute format(
                'update public.admins profile
                 set %1$I = coalesce(profile.%1$I, u.%1$I)
                 from public.users u
                 where profile.user_id = u.auth_user_id',
                contact_column
            );

            execute format(
                'select exists (
                    select 1
                    from public.users u
                    where u.%1$I is not null
                      and not exists (
                          select 1 from public.job_seekers js where js.user_id = u.auth_user_id
                      )
                      and not exists (
                          select 1 from public.employers e where e.user_id = u.auth_user_id
                      )
                      and not exists (
                          select 1 from public.admins a where a.user_id = u.auth_user_id
                      )
                )',
                contact_column
            ) into has_legacy_column;

            if has_legacy_column then
                raise exception
                    'Cannot move users.%. One or more users with a value have no job_seeker, employer, or admin profile. Create the correct role profile(s) and rerun.',
                    contact_column;
            end if;

            execute format(
                'alter table public.users drop column %I',
                contact_column
            );
        end if;
    end loop;
end;
$$;

-- Move any legacy resume fields out of users before removing them.
-- Only users without employer/admin profiles are migrated to job_seekers.
do $$
declare
    resume_columns text[] := array[
        'resume_file_name',
        'resume_url',
        'resume_image_file_name',
        'resume_image_url',
        'skills',
        'work_experience',
        'education'
    ];
    existing_columns text[] := array[]::text[];
    v_column_name text;
    insert_columns text;
    select_columns text;
    update_assignments text;
    nonnull_condition text;
begin
    foreach v_column_name in array resume_columns loop
        if exists (
            select 1
            from information_schema.columns as info
            where table_schema = 'public'
              and table_name = 'users'
              and info.column_name = v_column_name
        ) then
            existing_columns := array_append(existing_columns, v_column_name);
        end if;
    end loop;

    if cardinality(existing_columns) > 0 then
        select
            string_agg(format('%I', column_name), ', '),
            string_agg(format('u.%I', column_name), ', '),
            string_agg(
                format(
                    '%1$I = coalesce(public.job_seekers.%1$I, excluded.%1$I)',
                    column_name
                ),
                ', '
            ),
            string_agg(format('u.%I is not null', column_name), ' or ')
        into insert_columns, select_columns, update_assignments, nonnull_condition
        from unnest(existing_columns) as listed(column_name);

        execute format(
            'insert into public.job_seekers (user_id, %1$s)
             select u.auth_user_id, %2$s
             from public.users u
             left join public.employers e on e.user_id = u.auth_user_id
             left join public.admins a on a.user_id = u.auth_user_id
             where e.user_id is null
               and a.user_id is null
               and (%3$s)
             on conflict (user_id) do update set %4$s',
            insert_columns,
            select_columns,
            nonnull_condition,
            update_assignments
        );
    end if;

    alter table public.users drop column if exists resume_file_name;
    alter table public.users drop column if exists resume_url;
    alter table public.users drop column if exists resume_image_file_name;
    alter table public.users drop column if exists resume_image_url;
    alter table public.users drop column if exists skills;
    alter table public.users drop column if exists work_experience;
    alter table public.users drop column if exists education;
end;
$$;

create table if not exists public.jobs (
    id uuid primary key default gen_random_uuid(),
    employer_id uuid references public.employers(id) on delete cascade,
    admin_id uuid references public.admins(id) on delete cascade,
    title text not null,
    category text not null,
    description text not null,
    location text not null,
    salary text not null,
    is_full_time boolean not null default true,
    requirements text[] not null default ARRAY[]::text[],
    number_of_vacancies integer not null default 1 check (number_of_vacancies > 0),
    status text not null default 'active'
        check (status in ('active', 'closed', 'expired', 'archived')),
    applicant_count integer not null default 0,
    posted_date timestamptz not null default now(),
    deadline timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint jobs_exactly_one_owner
        check ((employer_id is not null) <> (admin_id is not null))
);

alter table public.jobs drop column if exists is_saved;

-- Upgrade existing jobs without removing rows. Legacy employer_id values
-- referenced employers.user_id; normalize them to employers.id.
alter table public.jobs add column if not exists employer_id uuid;
alter table public.jobs add column if not exists admin_id uuid;
alter table public.jobs add column if not exists created_by uuid;
alter table public.jobs add column if not exists number_of_vacancies integer;
alter table public.jobs add column if not exists status text;
alter table public.jobs alter column employer_id drop not null;

do $$
declare
    fk record;
begin
    for fk in
        select c.conname
        from pg_constraint c
        join pg_attribute source
          on source.attrelid = c.conrelid
         and source.attname = 'employer_id'
        where c.conrelid = 'public.jobs'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.employers'::regclass
          and c.conkey = array[source.attnum]::smallint[]
    loop
        execute format('alter table public.jobs drop constraint %I', fk.conname);
    end loop;
end;
$$;

update public.jobs j
set employer_id = e.id
from public.employers e
where j.employer_id = e.user_id;

update public.jobs j
set employer_id = e.id
from public.employers e
where j.employer_id is null
  and j.created_by = e.user_id;

update public.jobs j
set admin_id = a.id
from public.admins a
where j.employer_id is null
  and j.admin_id is null
  and j.created_by = a.user_id;

update public.jobs
set number_of_vacancies = 1
where number_of_vacancies is null;

update public.jobs
set status = 'active'
where status is null;

do $$
declare
    job_id_column smallint;
    created_by_column smallint;
    employer_name_column smallint;
    fk record;
    dependent_policy record;
begin
    if exists (
        select 1
        from public.jobs j
        where (j.employer_id is null and j.admin_id is null)
           or (j.employer_id is not null and j.admin_id is not null)
           or (j.employer_id is not null and not exists (
              select 1 from public.employers e where e.id = j.employer_id
          ))
           or (j.admin_id is not null and not exists (
              select 1 from public.admins a where a.id = j.admin_id
          ))
    ) then
        raise exception
            'Cannot enforce job ownership: every job must belong to exactly one employer or admin profile. Correct employer_id/admin_id for the listed jobs, then rerun.'
            using detail = (
                select string_agg(
                    format('job=%s employer_id=%s admin_id=%s created_by=%s',
                           problems.id,
                           coalesce(problems.employer_id::text, 'NULL'),
                           coalesce(problems.admin_id::text, 'NULL'),
                           coalesce(problems.created_by::text, 'NULL')),
                    '; '
                )
                from (
                    select j.id, j.employer_id, j.admin_id, j.created_by
                    from public.jobs j
                    where (j.employer_id is null and j.admin_id is null)
                       or (j.employer_id is not null and j.admin_id is not null)
                       or (j.employer_id is not null and not exists (
                           select 1 from public.employers e where e.id = j.employer_id
                       ))
                       or (j.admin_id is not null and not exists (
                           select 1 from public.admins a where a.id = j.admin_id
                       ))
                    order by j.id
                    limit 20
                ) problems
            );
    end if;

    select attnum into job_id_column
    from pg_attribute
    where attrelid = 'public.jobs'::regclass
      and attname = 'employer_id'
      and not attisdropped;

    for fk in
        select conname
        from pg_constraint
        where conrelid = 'public.jobs'::regclass
          and contype = 'f'
          and job_id_column = any(conkey)
          and confrelid <> 'public.employers'::regclass
    loop
        execute format('alter table public.jobs drop constraint %I', fk.conname);
    end loop;

    if not exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attname = 'employer_id'
        join pg_attribute target
          on target.attrelid = c.confrelid
         and target.attname = 'id'
        where c.conrelid = 'public.jobs'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.employers'::regclass
          and c.conkey = array[a.attnum]::smallint[]
          and c.confkey = array[target.attnum]::smallint[]
    ) then
        alter table public.jobs
            add constraint jobs_employer_id_fkey
            foreign key (employer_id) references public.employers(id)
            on delete cascade not valid;
    end if;

    if not exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attname = 'admin_id'
        join pg_attribute target
          on target.attrelid = c.confrelid
         and target.attname = 'id'
        where c.conrelid = 'public.jobs'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.admins'::regclass
          and c.conkey = array[a.attnum]::smallint[]
          and c.confkey = array[target.attnum]::smallint[]
    ) then
        alter table public.jobs
            add constraint jobs_admin_id_fkey
            foreign key (admin_id) references public.admins(id)
            on delete cascade not valid;
    end if;

    if not exists (
        select 1
        from pg_constraint
        where conrelid = 'public.jobs'::regclass
          and conname = 'jobs_exactly_one_owner'
    ) then
        alter table public.jobs
            add constraint jobs_exactly_one_owner
            check ((employer_id is not null) <> (admin_id is not null))
            not valid;
    end if;

    alter table public.jobs alter column number_of_vacancies set default 1;
    alter table public.jobs alter column number_of_vacancies set not null;
    alter table public.jobs alter column status set default 'active';
    alter table public.jobs alter column status set not null;
    alter table public.jobs validate constraint jobs_employer_id_fkey;
    alter table public.jobs validate constraint jobs_admin_id_fkey;
    alter table public.jobs validate constraint jobs_exactly_one_owner;

    select attnum into created_by_column
    from pg_attribute
    where attrelid = 'public.jobs'::regclass
      and attname = 'created_by'
      and not attisdropped;

    if created_by_column is not null then
        for dependent_policy in
            select distinct p.polrelid::regclass as table_name,
                            p.polname as policy_name
            from pg_depend d
            join pg_policy p on p.oid = d.objid
            where d.classid = 'pg_policy'::regclass
              and d.refclassid = 'pg_class'::regclass
              and d.refobjid = 'public.jobs'::regclass
              and d.refobjsubid = created_by_column
        loop
            execute format(
                'drop policy if exists %I on %s',
                dependent_policy.policy_name,
                dependent_policy.table_name
            );
        end loop;

        for fk in
            select conname
            from pg_constraint
            where conrelid = 'public.jobs'::regclass
              and created_by_column = any(conkey)
        loop
            execute format(
                'alter table public.jobs drop constraint %I',
                fk.conname
            );
        end loop;

        alter table public.jobs drop column created_by;
    end if;

    select attnum into employer_name_column
    from pg_attribute
    where attrelid = 'public.jobs'::regclass
      and attname = 'employer_name'
      and not attisdropped;

    if employer_name_column is not null then
        for dependent_policy in
            select distinct p.polrelid::regclass as table_name,
                            p.polname as policy_name
            from pg_depend d
            join pg_policy p on p.oid = d.objid
            where d.classid = 'pg_policy'::regclass
              and d.refclassid = 'pg_class'::regclass
              and d.refobjid = 'public.jobs'::regclass
              and d.refobjsubid = employer_name_column
        loop
            execute format(
                'drop policy if exists %I on %s',
                dependent_policy.policy_name,
                dependent_policy.table_name
            );
        end loop;

        alter table public.jobs drop column employer_name;
    end if;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.jobs'::regclass
          and conname = 'jobs_number_of_vacancies_positive'
    ) then
        alter table public.jobs
            add constraint jobs_number_of_vacancies_positive
            check (number_of_vacancies > 0) not valid;
        alter table public.jobs
            validate constraint jobs_number_of_vacancies_positive;
    end if;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.jobs'::regclass
          and conname = 'jobs_status_valid'
    ) then
        alter table public.jobs
            add constraint jobs_status_valid
            check (status in ('active', 'closed', 'expired', 'archived')) not valid;
        alter table public.jobs
            validate constraint jobs_status_valid;
    end if;
end;
$$;

create table if not exists public.saved_jobs (
    id uuid primary key default gen_random_uuid(),
    job_seeker_id uuid not null references public.job_seekers(id) on delete cascade,
    job_id uuid not null references public.jobs(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint saved_jobs_user_job_key unique (job_seeker_id, job_id)
);

-- Rename the legacy Auth-user link and migrate values to job_seekers.id.
do $$
declare
    seeker_column smallint;
    fk record;
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'saved_jobs'
          and column_name = 'user_id'
    ) and not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'saved_jobs'
          and column_name = 'job_seeker_id'
    ) then
        alter table public.saved_jobs rename column user_id to job_seeker_id;
    end if;

    select attnum into seeker_column
    from pg_attribute
    where attrelid = 'public.saved_jobs'::regclass
      and attname = 'job_seeker_id'
      and not attisdropped;

    for fk in
        select c.conname
        from pg_constraint c
        where c.conrelid = 'public.saved_jobs'::regclass
          and c.contype = 'f'
          and seeker_column = any(c.conkey)
    loop
        execute format('alter table public.saved_jobs drop constraint %I', fk.conname);
    end loop;

    update public.saved_jobs saved
    set job_seeker_id = seeker.id
    from public.job_seekers seeker
    where seeker.user_id = saved.job_seeker_id
      and seeker.id <> saved.job_seeker_id;

    if exists (
        select 1
        from public.saved_jobs saved
        where not exists (
            select 1 from public.job_seekers seeker
            where seeker.id = saved.job_seeker_id
        )
    ) then
        raise exception
            'Cannot migrate saved_jobs: some rows do not map to a job seeker profile. Resolve those rows before rerunning.';
    end if;

    alter table public.saved_jobs
        add constraint saved_jobs_job_seeker_id_fkey
        foreign key (job_seeker_id) references public.job_seekers(id)
        on delete cascade not valid;
    alter table public.saved_jobs
        validate constraint saved_jobs_job_seeker_id_fkey;

    if exists (
        select 1
        from public.saved_jobs
        group by job_seeker_id, job_id
        having count(*) > 1
    ) then
        raise exception
            'Cannot add saved-job uniqueness: duplicate rows exist. Review and merge/remove duplicates explicitly.'
            using detail = (
                select string_agg(
                    format(
                        'seeker=%s job=%s saved_rows=%s',
                        duplicates.job_seeker_id,
                        duplicates.job_id,
                        duplicates.saved_ids
                    ),
                    '; '
                )
                from (
                    select job_seeker_id,
                           job_id,
                           array_agg(ctid::text) as saved_ids
                    from public.saved_jobs
                    group by job_seeker_id, job_id
                    having count(*) > 1
                    order by job_seeker_id, job_id
                    limit 10
                ) duplicates
            );
    end if;

end;
$$;

do $$
declare
    constraint_name text;
begin
    alter table public.saved_jobs add column if not exists id uuid default gen_random_uuid();
    update public.saved_jobs set id = gen_random_uuid() where id is null;
    alter table public.saved_jobs alter column id set default gen_random_uuid();
    alter table public.saved_jobs alter column id set not null;
    for constraint_name in
        select conname from pg_constraint
        where conrelid = 'public.saved_jobs'::regclass and contype = 'p'
    loop
        execute format('alter table public.saved_jobs drop constraint %I', constraint_name);
    end loop;
    alter table public.saved_jobs
        add constraint saved_jobs_pkey primary key (id);
    create unique index if not exists saved_jobs_user_job_key
        on public.saved_jobs (job_seeker_id, job_id);
end;
$$;

create table if not exists public.applications (
    id uuid primary key default gen_random_uuid(),
    job_id uuid not null references public.jobs(id) on delete cascade,
    job_title_snapshot text not null,
    job_seeker_id uuid not null references public.job_seekers(id) on delete cascade,
    job_seeker_name_snapshot text not null,
    status text not null default 'new'
        check (status in (
            'new', 'shortlisted', 'pending', 'rejected', 'accepted',
            'reviewed', 'interview'
        )),
    cover_letter text,
    applied_date timestamptz not null default now(),
    reviewed_date timestamptz,
    interview_date timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

do $$
declare
    employer_column smallint;
    dependent_policy record;
begin
    select attnum into employer_column
    from pg_attribute
    where attrelid = 'public.applications'::regclass
      and attname = 'employer_id'
      and not attisdropped;

    if employer_column is not null then
        for dependent_policy in
            select distinct p.polrelid::regclass as table_name,
                            p.polname as policy_name
            from pg_depend d
            join pg_policy p on p.oid = d.objid
            where d.classid = 'pg_policy'::regclass
              and d.refclassid = 'pg_class'::regclass
              and d.refobjid = 'public.applications'::regclass
              and d.refobjsubid = employer_column
        loop
            execute format(
                'drop policy if exists %I on %s',
                dependent_policy.policy_name,
                dependent_policy.table_name
            );
        end loop;

        alter table public.applications drop column employer_id;
    end if;
end;
$$;

alter table public.applications
    add column if not exists job_title_snapshot text;
alter table public.applications
    add column if not exists job_seeker_name_snapshot text;

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'applications'
          and column_name = 'job_title'
    ) then
        execute
            'update public.applications
             set job_title_snapshot = coalesce(
                 nullif(job_title_snapshot, ''''),
                 job_title
             )
             where job_title is not null';
        alter table public.applications drop column job_title;
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'applications'
          and column_name = 'job_seeker_name'
    ) then
        execute
            'update public.applications
             set job_seeker_name_snapshot = coalesce(
                 nullif(job_seeker_name_snapshot, ''''),
                 job_seeker_name
             )
             where job_seeker_name is not null';
        alter table public.applications drop column job_seeker_name;
    end if;
end;
$$;

-- Existing application rows stored the seeker's Auth ID. Convert to the
-- independent role-profile PK while retaining the same child FK column.
do $$
declare
    seeker_column smallint;
    fk record;
begin
    select attnum into seeker_column
    from pg_attribute
    where attrelid = 'public.applications'::regclass
      and attname = 'job_seeker_id'
      and not attisdropped;

    for fk in
        select conname
        from pg_constraint
        where conrelid = 'public.applications'::regclass
          and contype = 'f'
          and seeker_column = any(conkey)
    loop
        execute format('alter table public.applications drop constraint %I', fk.conname);
    end loop;

    update public.applications application
    set job_seeker_id = seeker.id
    from public.job_seekers seeker
    where seeker.user_id = application.job_seeker_id
      and seeker.id <> application.job_seeker_id;

    update public.applications application
    set job_title_snapshot = coalesce(
            nullif(application.job_title_snapshot, ''),
            job.title
        )
    from public.jobs job
    where job.id = application.job_id
      and nullif(application.job_title_snapshot, '') is null;

    update public.applications application
    set job_seeker_name_snapshot = coalesce(
            nullif(application.job_seeker_name_snapshot, ''),
            app_user.name
        )
    from public.job_seekers seeker
    join public.users app_user on app_user.auth_user_id = seeker.user_id
    where seeker.id = application.job_seeker_id
      and nullif(application.job_seeker_name_snapshot, '') is null;

    if exists (
        select 1
        from public.applications
        where job_title_snapshot is null
           or job_seeker_name_snapshot is null
    ) then
        raise exception
            'Cannot enforce application history snapshots: some rows have no job title or seeker name snapshot. Resolve the incomplete application records before rerunning.';
    end if;

    alter table public.applications
        alter column job_title_snapshot set not null;
    alter table public.applications
        alter column job_seeker_name_snapshot set not null;

    if exists (
        select 1
        from public.applications application
        where not exists (
            select 1 from public.job_seekers seeker
            where seeker.id = application.job_seeker_id
        )
    ) then
        raise exception
            'Cannot migrate applications: some rows do not map to a job seeker profile. Resolve those rows before rerunning.';
    end if;

    alter table public.applications
        add constraint applications_job_seeker_id_fkey
        foreign key (job_seeker_id) references public.job_seekers(id)
        on delete cascade not valid;
    alter table public.applications
        validate constraint applications_job_seeker_id_fkey;

    if exists (
        select 1
        from public.applications
        group by job_id, job_seeker_id
        having count(*) > 1
    ) then
        raise exception
            'Cannot add one-application-per-job constraint: duplicate applications exist. Review and merge/remove duplicates explicitly.'
            using detail = (
                select string_agg(
                    format(
                        'job=%s seeker=%s applications=%s',
                        duplicates.job_id,
                        duplicates.job_seeker_id,
                        duplicates.application_ids
                    ),
                    '; '
                )
                from (
                    select job_id, job_seeker_id, array_agg(id order by created_at, id) as application_ids
                    from public.applications
                    group by job_id, job_seeker_id
                    having count(*) > 1
                    order by job_id, job_seeker_id
                    limit 10
                ) duplicates
            );
    end if;

    create unique index if not exists applications_job_seeker_job_key
        on public.applications (job_id, job_seeker_id);
end;
$$;

create table if not exists public.conversations (
    id uuid primary key default gen_random_uuid(),
    participant1_id uuid not null references public.users(auth_user_id) on delete cascade,
    participant2_id uuid not null references public.users(auth_user_id) on delete cascade,
    participant1_name text,
    participant2_name text,
    participant1_role text,
    participant2_role text,
    participant1_profile_image text,
    participant2_profile_image text,
    last_message text,
    last_message_timestamp timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint conversations_not_self check (participant1_id <> participant2_id)
);

do $$
declare
    self_conversation record;
begin
    if exists (
        select 1
        from public.conversations
        where participant1_id = participant2_id
    ) then
        select id into self_conversation
        from public.conversations
        where participant1_id = participant2_id
        order by id
        limit 1;
        raise exception
            'Cannot enforce conversations_not_self: a self-conversation exists.'
            using detail = format('conversation_id=%s', self_conversation.id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.conversations'::regclass
          and conname = 'conversations_not_self'
    ) then
        alter table public.conversations
            add constraint conversations_not_self
            check (participant1_id <> participant2_id) not valid;
        alter table public.conversations
            validate constraint conversations_not_self;
    end if;

    if exists (
        select 1
        from public.conversations
        group by least(participant1_id, participant2_id),
                 greatest(participant1_id, participant2_id)
        having count(*) > 1
    ) then
        raise exception
            'Cannot enforce one conversation per user pair: duplicate conversations exist. Review and merge them explicitly.'
            using detail = (
                select string_agg(
                    format(
                        'pair=%s/%s conversations=%s',
                        duplicates.participant_low,
                        duplicates.participant_high,
                        duplicates.conversation_ids
                    ),
                    '; '
                )
                from (
                    select least(participant1_id, participant2_id) as participant_low,
                           greatest(participant1_id, participant2_id) as participant_high,
                           array_agg(id order by created_at, id) as conversation_ids
                    from public.conversations
                    group by least(participant1_id, participant2_id),
                             greatest(participant1_id, participant2_id)
                    having count(*) > 1
                    order by participant_low, participant_high
                    limit 10
                ) duplicates
            );
    end if;
end;
$$;

create unique index if not exists conversations_participant_pair_key
    on public.conversations (
        least(participant1_id, participant2_id),
        greatest(participant1_id, participant2_id)
    );

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references public.conversations(id) on delete cascade,
    sender_id uuid not null references public.users(auth_user_id) on delete cascade,
    receiver_id uuid not null references public.users(auth_user_id) on delete cascade,
    sender_name_snapshot text not null default '',
    content text not null,
    timestamp timestamptz not null default now(),
    is_read boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.messages add column if not exists receiver_id uuid;
alter table public.messages
    add column if not exists sender_name_snapshot text;

do $$
declare
    sender_name_column smallint;
    dependent_policy record;
begin
    select attnum into sender_name_column
    from pg_attribute
    where attrelid = 'public.messages'::regclass
      and attname = 'sender_name'
      and not attisdropped;

    if sender_name_column is not null then
        execute
            'update public.messages
             set sender_name_snapshot = coalesce(
                 nullif(sender_name_snapshot, ''''),
                 sender_name
             )
             where sender_name is not null';

        for dependent_policy in
            select distinct p.polrelid::regclass as table_name,
                            p.polname as policy_name
            from pg_depend d
            join pg_policy p on p.oid = d.objid
            where d.classid = 'pg_policy'::regclass
              and d.refclassid = 'pg_class'::regclass
              and d.refobjid = 'public.messages'::regclass
              and d.refobjsubid = sender_name_column
        loop
            execute format(
                'drop policy if exists %I on %s',
                dependent_policy.policy_name,
                dependent_policy.table_name
            );
        end loop;

        alter table public.messages drop column sender_name;
    end if;

    update public.messages
    set sender_name_snapshot = ''
    where sender_name_snapshot is null;
    alter table public.messages
        alter column sender_name_snapshot set default '';
    alter table public.messages
        alter column sender_name_snapshot set not null;
end;
$$;

do $$
declare
    receiver_attnum smallint;
    fk record;
begin
    if exists (
        select 1
        from public.messages m
        where not exists (
            select 1 from public.conversations c
            where c.id = m.conversation_id
        )
    ) then
        raise exception
            'Cannot add messages.conversation_id foreign key: orphan messages exist. Resolve them explicitly before rerunning.';
    end if;

    if not exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attname = 'conversation_id'
        where c.conrelid = 'public.messages'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.conversations'::regclass
          and c.conkey = array[a.attnum]::smallint[]
    ) then
        alter table public.messages
            add constraint messages_conversation_id_fkey
            foreign key (conversation_id) references public.conversations(id)
            on delete cascade not valid;
        alter table public.messages
            validate constraint messages_conversation_id_fkey;
    end if;

    update public.messages message
    set receiver_id = case
        when message.sender_id = conversation.participant1_id
            then conversation.participant2_id
        when message.sender_id = conversation.participant2_id
            then conversation.participant1_id
        else null
    end
    from public.conversations conversation
    where conversation.id = message.conversation_id
      and message.receiver_id is null;

    if exists (
        select 1
        from public.messages message
        join public.conversations conversation
          on conversation.id = message.conversation_id
        where message.receiver_id is null
           or not (
               (message.sender_id = conversation.participant1_id
                and message.receiver_id = conversation.participant2_id)
               or
               (message.sender_id = conversation.participant2_id
                and message.receiver_id = conversation.participant1_id)
           )
    ) then
        raise exception
            'Cannot migrate messages.receiver_id: sender and receiver must be opposite participants in the conversation. Resolve inconsistent messages before rerunning.';
    end if;

    select attnum into receiver_attnum
    from pg_attribute
    where attrelid = 'public.messages'::regclass
      and attname = 'receiver_id'
      and not attisdropped;

    for fk in
        select conname
        from pg_constraint
        where conrelid = 'public.messages'::regclass
          and contype = 'f'
          and receiver_attnum = any(conkey)
    loop
        execute format(
            'alter table public.messages drop constraint %I',
            fk.conname
        );
    end loop;

    alter table public.messages alter column receiver_id set not null;
    alter table public.messages
        add constraint messages_receiver_id_fkey
        foreign key (receiver_id) references public.users(auth_user_id)
        on delete cascade not valid;
    alter table public.messages
        validate constraint messages_receiver_id_fkey;
end;
$$;

create or replace function public.guard_message_participants()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not exists (
        select 1
        from public.conversations conversation
        where conversation.id = new.conversation_id
          and (
              (
                  conversation.participant1_id = new.sender_id
                  and conversation.participant2_id = new.receiver_id
              )
              or (
                  conversation.participant2_id = new.sender_id
                  and conversation.participant1_id = new.receiver_id
              )
          )
    ) then
        raise check_violation
            using message = 'Message sender and receiver must be opposite participants in its conversation.';
    end if;

    return new;
end;
$$;

revoke all on function public.guard_message_participants() from public;

drop trigger if exists messages_guard_participants on public.messages;
create trigger messages_guard_participants
before insert or update of conversation_id, sender_id, receiver_id
on public.messages
for each row
execute function public.guard_message_participants();

create table if not exists public.announcements (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references public.admins(id) on delete restrict,
    created_by_user_id_snapshot uuid,
    title text not null,
    category text not null,
    description text not null,
    image_path text not null default '',
    publish_date timestamptz not null default now(),
    target_roles text[] not null default ARRAY['job_seeker', 'employer', 'admin']::text[]
        check (target_roles <@ ARRAY['job_seeker', 'employer', 'admin', 'all']::text[]),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.notification_read_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    read_keys text[] not null default '{}',
    last_read_at timestamptz,
    updated_at timestamptz not null default now()
);

do $$
declare
    constraint_name text;
    user_id_column smallint;
begin
    select attnum into user_id_column
    from pg_attribute
    where attrelid = 'public.notification_read_state'::regclass
      and attname = 'user_id'
      and not attisdropped;

    if exists (
        select 1
        from public.notification_read_state
        group by user_id
        having count(*) > 1
    ) then
        raise exception
            'Cannot make notification_read_state.user_id the primary key: duplicate read-state rows exist. Merge duplicate records, then rerun.';
    end if;

    for constraint_name in
        select conname from pg_constraint
        where conrelid = 'public.notification_read_state'::regclass
          and contype = 'p'
    loop
        execute format(
            'alter table public.notification_read_state drop constraint %I',
            constraint_name
        );
    end loop;

    for constraint_name in
        select conname from pg_constraint
        where conrelid = 'public.notification_read_state'::regclass
          and contype = 'f'
          and user_id_column = any(conkey)
    loop
        execute format(
            'alter table public.notification_read_state drop constraint %I',
            constraint_name
        );
    end loop;

    for constraint_name in
        select conname from pg_constraint
        where conrelid = 'public.notification_read_state'::regclass
          and contype = 'u'
          and conkey = array[user_id_column]::smallint[]
    loop
        execute format(
            'alter table public.notification_read_state drop constraint %I',
            constraint_name
        );
    end loop;

    drop index if exists public.notification_read_state_user_id_key;

    alter table public.notification_read_state drop column if exists id;
    alter table public.notification_read_state
        alter column user_id set not null;
    alter table public.notification_read_state
        add constraint notification_read_state_pkey primary key (user_id);

    alter table public.notification_read_state
        add constraint notification_read_state_user_id_fkey
        foreign key (user_id) references auth.users(id)
        on delete cascade not valid;
    alter table public.notification_read_state
        validate constraint notification_read_state_user_id_fkey;
end;
$$;

create table if not exists public.app_policies (
    id uuid primary key default gen_random_uuid(),
    policy_key text not null unique default 'default',
    title text not null,
    body text not null,
    created_by uuid references public.admins(id) on delete set null,
    created_by_user_id_snapshot uuid,
    updated_at timestamptz not null default now()
);

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references public.users(auth_user_id) on delete cascade,
    report_type text not null constraint reports_type_valid
        check (report_type in ('job_report', 'applicant_violation', 'user_report', 'other')),
    subject_job_id uuid references public.jobs(id) on delete set null,
    subject_job_id_snapshot uuid,
    subject_user_id uuid references public.users(auth_user_id) on delete set null,
    subject_user_id_snapshot uuid,
    title text not null,
    description text not null,
    status text not null default 'pending' constraint reports_status_valid
        check (status in ('pending', 'reviewed', 'resolved', 'dismissed')),
    category text not null
        constraint reports_category_valid
        check (category in (
            'inappropriate_content',
            'harassment',
            'fraud',
            'violates_policy',
            'other'
        )),
    admin_notes text,
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    reviewed_by_admin_id uuid references public.admins(id) on delete set null,
    reviewed_by_admin_id_snapshot uuid,
    constraint reports_subject_matches_type check (
        (report_type = 'job_report'
            and subject_user_id is null)
        or
        (report_type in ('applicant_violation', 'user_report')
            and subject_job_id is null)
        or
        (report_type = 'other'
            and (subject_job_id is null or subject_user_id is null))
    )
);

-- Upgrade legacy reports that stored every target in one polymorphic column.
alter table public.reports add column if not exists subject_job_id uuid;
alter table public.reports add column if not exists subject_job_id_snapshot uuid;
alter table public.reports add column if not exists subject_user_id uuid;
alter table public.reports add column if not exists subject_user_id_snapshot uuid;
alter table public.reports
    add column if not exists reviewed_by_admin_id_snapshot uuid;

do $$
declare
    has_legacy_subject boolean;
begin
    select exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'reports'
          and column_name = 'subject_id'
    ) into has_legacy_subject;

    if has_legacy_subject then
        execute
            'select exists (
                select 1 from public.reports
                where subject_id is not null
                  and report_type not in (
                      ''job_report'', ''applicant_violation'', ''user_report'', ''other''
                  )
            )'
        into has_legacy_subject;

        if has_legacy_subject then
            raise exception
                'Cannot migrate reports.subject_id: found non-null targets with unsupported report_type values.';
        end if;

        execute
            'select exists (
                select 1
                from public.reports r
                where r.report_type = ''other''
                  and r.subject_id is not null
                  and exists (select 1 from public.jobs j where j.id = r.subject_id::uuid)
                  and exists (select 1 from public.users u where u.auth_user_id = r.subject_id::uuid)
            )'
        into has_legacy_subject;

        if has_legacy_subject then
            raise exception
                'Cannot migrate reports.subject_id for report_type other: some subject IDs match both a job and a user. Resolve those targets explicitly.';
        end if;

        execute
            'select exists (
                select 1
                from public.reports r
                where r.report_type = ''other''
                  and r.subject_id is not null
                  and not exists (select 1 from public.jobs j where j.id = r.subject_id::uuid)
                  and not exists (select 1 from public.users u where u.auth_user_id = r.subject_id::uuid)
            )'
        into has_legacy_subject;

        if has_legacy_subject then
            raise exception
                'Cannot migrate reports.subject_id for report_type other: some targets do not map to a known job or user. Resolve those targets explicitly.';
        end if;

        execute
            'update public.reports
             set subject_job_id = case
                     when exists (
                         select 1 from public.jobs j
                         where j.id = coalesce(reports.subject_job_id, reports.subject_id::uuid)
                     )
                     then coalesce(subject_job_id, subject_id::uuid)
                     else null
                 end,
                 subject_job_id_snapshot = case
                     when not exists (
                         select 1 from public.jobs j
                         where j.id = coalesce(reports.subject_job_id, reports.subject_id::uuid)
                     )
                     then coalesce(subject_job_id_snapshot, subject_job_id, subject_id::uuid)
                     else subject_job_id_snapshot
                 end
             where report_type = ''job_report''
               and (subject_job_id is not null or subject_id is not null)';
        execute
            'update public.reports
             set subject_user_id = case
                     when exists (
                         select 1 from public.users u
                         where u.auth_user_id = coalesce(reports.subject_user_id, reports.subject_id::uuid)
                     )
                     then coalesce(subject_user_id, subject_id::uuid)
                     else null
                 end,
                 subject_user_id_snapshot = case
                     when not exists (
                         select 1 from public.users u
                         where u.auth_user_id = coalesce(reports.subject_user_id, reports.subject_id::uuid)
                     )
                     then coalesce(subject_user_id_snapshot, subject_user_id, subject_id::uuid)
                     else subject_user_id_snapshot
                 end
             where report_type in (''applicant_violation'', ''user_report'')
               and (subject_user_id is not null or subject_id is not null)';
        execute
            'update public.reports
             set subject_job_id = case
                     when exists (
                         select 1 from public.jobs j
                         where j.id = reports.subject_id::uuid
                     ) then reports.subject_id::uuid
                     else null
                 end,
                 subject_user_id = case
                     when exists (
                         select 1 from public.users u
                         where u.auth_user_id = reports.subject_id::uuid
                     ) then reports.subject_id::uuid
                     else null
                 end
             where report_type = ''other''
               and subject_id is not null';

        alter table public.reports drop column subject_id;
    end if;
end;
$$;

-- Keep historical target IDs where the referenced job/account was already
-- deleted, while leaving the actual FK columns valid and nullable.
update public.reports r
set subject_job_id_snapshot = coalesce(r.subject_job_id_snapshot, r.subject_job_id),
    subject_job_id = null
where r.subject_job_id is not null
  and not exists (
      select 1 from public.jobs j where j.id = r.subject_job_id
  );

update public.reports r
set subject_user_id_snapshot = coalesce(r.subject_user_id_snapshot, r.subject_user_id),
    subject_user_id = null
where r.subject_user_id is not null
  and not exists (
      select 1 from public.users u where u.auth_user_id = r.subject_user_id
  );

-- Retarget admin-owned content and report reviews to the independent admin
-- profile PK. Preserve the former Auth IDs in snapshot columns during upgrade.
do $$
declare
    relation_name text;
    fk record;
    source_attnum smallint;
    role_attnum smallint;
    dependent_policy record;
    missing_announcements_creator boolean;
begin
    foreach relation_name in array array['announcements', 'app_policies'] loop
        execute format(
            'alter table public.%I add column if not exists created_by_user_id_snapshot uuid',
            relation_name
        );

        select attnum into source_attnum
        from pg_attribute
        where attrelid = format('public.%I', relation_name)::regclass
          and attname = 'created_by'
          and not attisdropped;

        for fk in
            select conname
            from pg_constraint
            where conrelid = format('public.%I', relation_name)::regclass
              and contype = 'f'
              and source_attnum = any(conkey)
        loop
            execute format(
                'alter table public.%I drop constraint %I',
                relation_name,
                fk.conname
            );
        end loop;

        execute format(
            'update public.%1$I content
             set created_by = admin.id
             from public.admins admin
             where content.created_by = admin.user_id
               and content.created_by is distinct from admin.id',
            relation_name
        );
        execute format(
            'update public.%1$I content
             set created_by_user_id_snapshot =
                     coalesce(content.created_by_user_id_snapshot, content.created_by),
                 created_by = null
             where content.created_by is not null
               and not exists (
                   select 1 from public.admins admin
                   where admin.id = content.created_by
               )',
            relation_name
        );

        if relation_name = 'announcements' then
            -- These legacy rows have no recoverable creator. Attribute only
            -- the reported rows to the oldest admin as a migration owner.
            insert into public.admins (user_id)
            select u.auth_user_id
            from public.users u
            where u.role = 'admin'
              and not exists (
                  select 1
                  from public.admins admin
                  where admin.user_id = u.auth_user_id
              )
            on conflict (user_id) do nothing;

            update public.announcements announcement
            set created_by = admin.id
            from (
                select id
                from public.admins
                order by (
                    user_id = 'a374853f-79f4-438b-a63f-64432e681120'::uuid
                ) desc, created_at, id
                limit 1
            ) admin
            where announcement.id in (
                '8ce8b96a-b61f-488c-8a5c-22a9f80d4c09'::uuid,
                'a8f446ce-7687-4233-93f5-32eabc3bb4a8'::uuid
            )
              and announcement.created_by is null;

            execute
                'select exists (
                    select 1 from public.announcements
                    where created_by is null
                )'
            into missing_announcements_creator;

            if missing_announcements_creator then
                if not exists (select 1 from public.admins) then
                    raise exception
                        'Cannot assign legacy announcements: no admin profile exists. Restore an existing administrator account with users.role = ''admin'' and its matching admins profile, then rerun.';
                end if;

                raise exception
                    'Cannot enforce announcements.created_by: one or more announcements have no creator and could not be assigned to an admin profile. Assign a valid admin creator, then rerun.'
                    using detail = (
                        select string_agg(
                            format('announcement=%s creator_snapshot=%s',
                                   problems.id,
                                   coalesce(problems.created_by_user_id_snapshot::text, 'NULL')),
                            '; '
                        )
                        from (
                            select id, created_by_user_id_snapshot
                            from public.announcements
                            where created_by is null
                            order by id
                            limit 20
                        ) problems
                    );
            end if;
        end if;

        execute format(
            'alter table public.%1$I
             add constraint %1$I_created_by_admin_id_fkey
             foreign key (created_by) references public.admins(id)
             on delete %2$s not valid',
            relation_name,
            case when relation_name = 'announcements' then 'restrict' else 'set null' end
        );
        execute format(
            'alter table public.%I validate constraint %I',
            relation_name,
            relation_name || '_created_by_admin_id_fkey'
        );
        if relation_name = 'announcements' then
            alter table public.announcements alter column created_by set not null;
        end if;
    end loop;

    select attnum into source_attnum
    from pg_attribute
    where attrelid = 'public.reports'::regclass
      and attname = 'reviewed_by_admin_id'
      and not attisdropped;

    for fk in
        select conname
        from pg_constraint
        where conrelid = 'public.reports'::regclass
          and contype = 'f'
          and source_attnum = any(conkey)
    loop
        execute format('alter table public.reports drop constraint %I', fk.conname);
    end loop;

    update public.reports report
    set reviewed_by_admin_id = admin.id
    from public.admins admin
    where report.reviewed_by_admin_id = admin.user_id
      and report.reviewed_by_admin_id is distinct from admin.id;

    update public.reports report
    set reviewed_by_admin_id_snapshot =
            coalesce(report.reviewed_by_admin_id_snapshot, report.reviewed_by_admin_id),
        reviewed_by_admin_id = null
    where report.reviewed_by_admin_id is not null
      and not exists (
          select 1 from public.admins admin
          where admin.id = report.reviewed_by_admin_id
      );

    alter table public.reports
        add constraint reports_reviewed_by_admin_id_fkey
        foreign key (reviewed_by_admin_id)
        references public.admins(id) on delete set null not valid;
    alter table public.reports
        validate constraint reports_reviewed_by_admin_id_fkey;

    select attnum into role_attnum
    from pg_attribute
    where attrelid = 'public.reports'::regclass
      and attname = 'reporter_role'
      and not attisdropped;

    if role_attnum is not null then
        for dependent_policy in
            select distinct p.polrelid::regclass as table_name,
                            p.polname as policy_name
            from pg_depend d
            join pg_policy p on p.oid = d.objid
            where d.classid = 'pg_policy'::regclass
              and d.refclassid = 'pg_class'::regclass
              and d.refobjid = 'public.reports'::regclass
              and d.refobjsubid = role_attnum
        loop
            execute format(
                'drop policy if exists %I on %s',
                dependent_policy.policy_name,
                dependent_policy.table_name
            );
        end loop;
        alter table public.reports drop column reporter_role;
    end if;
end;
$$;

do $$
begin
    if not exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attname = 'subject_job_id'
        where c.conrelid = 'public.reports'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.jobs'::regclass
          and c.conkey = array[a.attnum]::smallint[]
    ) then
        alter table public.reports
            add constraint reports_subject_job_id_fkey
            foreign key (subject_job_id) references public.jobs(id)
            on delete set null not valid;
    end if;

    if not exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attname = 'subject_user_id'
        where c.conrelid = 'public.reports'::regclass
          and c.contype = 'f'
          and c.confrelid = 'public.users'::regclass
          and c.conkey = array[a.attnum]::smallint[]
    ) then
        alter table public.reports
            add constraint reports_subject_user_id_fkey
            foreign key (subject_user_id) references public.users(auth_user_id)
            on delete set null not valid;
    end if;

    alter table public.reports
        drop constraint if exists reports_subject_matches_type;
    alter table public.reports
        add constraint reports_subject_matches_type check (
            (report_type = 'job_report' and subject_user_id is null)
            or
            (report_type in ('applicant_violation', 'user_report')
                and subject_job_id is null)
            or
            (report_type = 'other'
                and (subject_job_id is null or subject_user_id is null))
        ) not valid;

    alter table public.reports
        drop constraint if exists reports_type_valid;
    alter table public.reports
        add constraint reports_type_valid
        check (report_type in (
            'job_report', 'applicant_violation', 'user_report', 'other'
        )) not valid;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.reports'::regclass
          and conname = 'reports_status_valid'
    ) then
        alter table public.reports
            add constraint reports_status_valid
            check (status in ('pending', 'reviewed', 'resolved', 'dismissed'))
            not valid;
    end if;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.reports'::regclass
          and conname = 'reports_category_valid'
    ) then
        alter table public.reports
            add constraint reports_category_valid
            check (category in (
                'inappropriate_content',
                'harassment',
                'fraud',
                'violates_policy',
                'other'
            )) not valid;
    end if;

    alter table public.reports
        validate constraint reports_subject_matches_type;
    alter table public.reports validate constraint reports_type_valid;
    alter table public.reports validate constraint reports_status_valid;
    alter table public.reports validate constraint reports_category_valid;
end;
$$;

-- Preserve the singleton policy key while replacing legacy text IDs with UUID PKs.
do $$
declare
    id_type text;
    constraint_name text;
begin
    select data_type into id_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_policies'
      and column_name = 'id';

    if id_type <> 'uuid' then
        alter table public.app_policies add column if not exists policy_key text;
        execute 'update public.app_policies set policy_key = id::text where policy_key is null';
        alter table public.app_policies add column id_replacement uuid default gen_random_uuid();
        update public.app_policies set id_replacement = gen_random_uuid();

        for constraint_name in
            select conname from pg_constraint
            where conrelid = 'public.app_policies'::regclass and contype = 'p'
        loop
            execute format('alter table public.app_policies drop constraint %I', constraint_name);
        end loop;

        alter table public.app_policies drop column id;
        alter table public.app_policies rename column id_replacement to id;
        alter table public.app_policies alter column id set default gen_random_uuid();
        alter table public.app_policies alter column id set not null;
        alter table public.app_policies alter column policy_key set default 'default';
        alter table public.app_policies alter column policy_key set not null;
        alter table public.app_policies
            add constraint app_policies_pkey primary key (id);
        create unique index if not exists app_policies_policy_key_key
            on public.app_policies (policy_key);
    end if;
end;
$$;

do $$
begin
    update public.app_policies
    set policy_key = id::text
    where policy_key is null;

    alter table public.app_policies
        alter column policy_key set default 'default';
    alter table public.app_policies
        alter column policy_key set not null;

    if exists (
        select 1
        from public.app_policies
        group by policy_key
        having count(*) > 1
    ) then
        raise exception
            'Cannot enforce unique app_policies.policy_key: duplicate keys exist. Keep one policy per key and assign distinct keys to the others, then rerun.'
            using detail = (
                select string_agg(
                    format('policy_key=%s policy_ids=%s',
                           duplicates.policy_key,
                           duplicates.policy_ids),
                    '; '
                )
                from (
                    select policy_key,
                           array_agg(id order by id) as policy_ids
                    from public.app_policies
                    group by policy_key
                    having count(*) > 1
                    order by policy_key
                    limit 20
                ) duplicates
            );
    end if;

    create unique index if not exists app_policies_policy_key_key
        on public.app_policies (policy_key);
end;
$$;

create index if not exists idx_users_account_status on public.users (account_status);
create index if not exists idx_jobs_employer_id on public.jobs (employer_id);
create index if not exists idx_jobs_posted_date on public.jobs (posted_date desc);
create index if not exists idx_saved_jobs_job_id on public.saved_jobs (job_id);
create index if not exists idx_applications_job_id on public.applications (job_id);
create index if not exists idx_applications_job_seeker_id on public.applications (job_seeker_id);
create index if not exists idx_applications_status on public.applications (status);
create index if not exists idx_conversations_participant1 on public.conversations (participant1_id);
create index if not exists idx_conversations_participant2 on public.conversations (participant2_id);
create index if not exists idx_messages_conversation_id on public.messages (conversation_id, timestamp);
create index if not exists idx_announcements_publish_date on public.announcements (publish_date desc);
create index if not exists idx_reports_reporter_created on public.reports (reporter_id, created_at desc);
create index if not exists idx_reports_status_created on public.reports (status, created_at desc);
create index if not exists idx_reports_subject_job_id on public.reports (subject_job_id);
create index if not exists idx_reports_subject_user_id on public.reports (subject_user_id);
create index if not exists idx_reports_reviewed_by_admin_id on public.reports (reviewed_by_admin_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
before update on public.users
for each row
execute function public.set_updated_at();

drop trigger if exists job_seekers_set_updated_at on public.job_seekers;
create trigger job_seekers_set_updated_at
before update on public.job_seekers
for each row
execute function public.set_updated_at();

drop trigger if exists employers_set_updated_at on public.employers;
create trigger employers_set_updated_at
before update on public.employers
for each row
execute function public.set_updated_at();

drop trigger if exists admins_set_updated_at on public.admins;
create trigger admins_set_updated_at
before update on public.admins
for each row
execute function public.set_updated_at();

drop trigger if exists jobs_set_updated_at on public.jobs;
create trigger jobs_set_updated_at
before update on public.jobs
for each row
execute function public.set_updated_at();

drop trigger if exists applications_set_updated_at on public.applications;
create trigger applications_set_updated_at
before update on public.applications
for each row
execute function public.set_updated_at();

create or replace function public.sync_job_applicant_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        update public.jobs
        set applicant_count = applicant_count + 1
        where id = new.job_id;
        return new;
    elsif tg_op = 'DELETE' then
        update public.jobs
        set applicant_count = greatest(applicant_count - 1, 0)
        where id = old.job_id;
        return old;
    elsif old.job_id is distinct from new.job_id then
        update public.jobs
        set applicant_count = greatest(applicant_count - 1, 0)
        where id = old.job_id;
        update public.jobs
        set applicant_count = applicant_count + 1
        where id = new.job_id;
    end if;

    return new;
end;
$$;

revoke all on function public.sync_job_applicant_count() from public;

update public.jobs job
set applicant_count = (
    select count(*)::integer
    from public.applications application
    where application.job_id = job.id
);

drop trigger if exists applications_sync_job_applicant_count on public.applications;
create trigger applications_sync_job_applicant_count
after insert or delete or update of job_id on public.applications
for each row
execute function public.sync_job_applicant_count();

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

drop trigger if exists announcements_set_updated_at on public.announcements;
create trigger announcements_set_updated_at
before update on public.announcements
for each row
execute function public.set_updated_at();

drop trigger if exists notification_read_state_set_updated_at on public.notification_read_state;
create trigger notification_read_state_set_updated_at
before update on public.notification_read_state
for each row
execute function public.set_updated_at();

drop trigger if exists app_policies_set_updated_at on public.app_policies;
create trigger app_policies_set_updated_at
before update on public.app_policies
for each row
execute function public.set_updated_at();

-- Seed default app policy
insert into public.app_policies (policy_key, title, body)
values (
    'default',
    'WorkNest Terms and Conditions',
    'This application is for job matching and hiring workflow management. Users must provide accurate information, respect platform policies, and use the platform in compliance with local laws.'
)
on conflict (policy_key) do update set
    title = excluded.title,
    body = excluded.body,
    updated_at = now();

-- Preserve the legacy client-facing `role` name while using role as
-- the authoritative, three-value account type.
create or replace view public.user_roles as
select u.auth_user_id as user_id, u.role as role
from public.users u;

alter view public.user_roles set (security_invoker = true);

-- RLS helper used by profile policies. The fixed search_path and fully
-- qualified table reference prevent object-shadowing attacks.
create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
select exists (
    select 1
    from public.users u
    join public.admins a on a.user_id = u.auth_user_id
    where u.auth_user_id = (select auth.uid())
      and u.role = 'admin'
      and u.account_status = 'active'
);
$$;

revoke all on function public.is_admin_user() from public;
grant execute on function public.is_admin_user() to authenticated;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(
        (
            select u.role
            from public.users u
            where u.auth_user_id = (select auth.uid())
        ),
        case
            when (select public.is_admin_user()) then 'admin'
            else 'unknown'
        end
    );
$$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;

create or replace function public.is_active_job_seeker()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.job_seekers js
        join public.users u on u.auth_user_id = js.user_id
        where js.user_id = (select auth.uid())
          and u.role = 'job_seeker'
          and u.account_status = 'active'
    );
$$;

revoke all on function public.is_active_job_seeker() from public;
grant execute on function public.is_active_job_seeker() to authenticated;

create or replace function public.is_active_employer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.employers e
        join public.users u on u.auth_user_id = e.user_id
        where e.user_id = (select auth.uid())
          and u.role = 'employer'
          and u.account_status = 'active'
    );
$$;

revoke all on function public.is_active_employer() from public;
grant execute on function public.is_active_employer() to authenticated;

-- Keep employer access to applicants out of the job_seekers RLS policy's
-- direct query of applications, whose own policy reads job_seekers.
create or replace function public.can_employer_view_job_seeker(
    p_job_seeker_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select (select public.is_active_employer())
        and exists (
            select 1
            from public.applications app
            join public.jobs job on job.id = app.job_id
            join public.employers employer on employer.id = job.employer_id
            where app.job_seeker_id = p_job_seeker_id
              and employer.user_id = (select auth.uid())
        );
$$;

revoke all on function public.can_employer_view_job_seeker(uuid) from public;
grant execute on function public.can_employer_view_job_seeker(uuid)
    to authenticated;

-- Return applicant details without requiring employers to read public.users.
-- Access is limited to admins and employers who own a job the seeker applied to.
-- Accept both job_seekers.id and job_seekers.user_id: application models expose
-- the Auth user ID after application hydration.
create or replace function public.get_job_seeker_applicant(
    p_job_seeker_profile_id uuid
)
returns table (
    id uuid,
    name text,
    email text,
    role text,
    account_status text,
    phone text,
    location text,
    profile_image text,
    bio text,
    resume_file_name text,
    resume_url text,
    resume_image_file_name text,
    resume_image_url text,
    skills text,
    work_experience text,
    education text,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select u.auth_user_id,
           u.name,
           u.email,
           u.role,
           u.account_status,
           seeker.phone,
           seeker.location,
           u.profile_image,
           u.bio,
           seeker.resume_file_name,
           seeker.resume_url,
           seeker.resume_image_file_name,
           seeker.resume_image_url,
           seeker.skills,
           seeker.work_experience,
           seeker.education,
           u.created_at
    from public.job_seekers seeker
    join public.users u on u.auth_user_id = seeker.user_id
    where (
          seeker.id = p_job_seeker_profile_id
          or seeker.user_id = p_job_seeker_profile_id
      )
      and u.role = 'job_seeker'
      and (
          (select public.is_admin_user())
          or (
              (select public.is_active_employer())
              and exists (
                  select 1
                  from public.applications app
                  join public.jobs job on job.id = app.job_id
                  join public.employers employer
                    on employer.id = job.employer_id
                  where app.job_seeker_id = seeker.id
                    and employer.user_id = (select auth.uid())
              )
          )
      );
$$;

revoke all on function public.get_job_seeker_applicant(uuid) from public;
grant execute on function public.get_job_seeker_applicant(uuid)
    to authenticated;

-- Expose only display fields needed by job cards and conversation headers.
create or replace function public.public_user_profiles(p_user_ids uuid[])
returns table (
    auth_user_id uuid,
    name text,
    profile_image text,
    role text,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select u.auth_user_id,
           u.name,
           u.profile_image,
           u.role,
           u.created_at
    from public.users u
    where u.auth_user_id = any(coalesce(p_user_ids, array[]::uuid[]))
      and u.account_status <> 'deleted'
      and (
          u.auth_user_id = (select auth.uid())
          or (select public.is_admin_user())
          or exists (
              select 1
              from public.jobs j
              join public.employers e on e.id = j.employer_id
              where e.user_id = u.auth_user_id
          )
          or exists (
              select 1 from public.conversations c
              where (c.participant1_id = (select auth.uid())
                     and c.participant2_id = u.auth_user_id)
                 or (c.participant2_id = (select auth.uid())
                     and c.participant1_id = u.auth_user_id)
          )
      );
$$;

revoke all on function public.public_user_profiles(uuid[]) from public;
grant execute on function public.public_user_profiles(uuid[]) to authenticated;

-- Provide the minimal active account directory required by the conversation
-- picker without exposing auth.users or admin-only account management data.
create or replace function public.conversation_user_directory()
returns table (
    id uuid,
    name text,
    email text,
    role text,
    account_status text,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select u.auth_user_id,
           u.name,
           u.email,
           u.role,
           u.account_status,
           u.created_at
    from public.users u
    where u.auth_user_id <> (select auth.uid())
      and u.account_status = 'active'
      and (
          (u.role = 'job_seeker' and exists (
              select 1 from public.job_seekers seeker
              where seeker.user_id = u.auth_user_id
          ))
          or (u.role = 'employer' and exists (
              select 1 from public.employers employer
              where employer.user_id = u.auth_user_id
          ))
          or (u.role = 'admin' and exists (
              select 1 from public.admins administrator
              where administrator.user_id = u.auth_user_id
          ))
      )
      and (
          (select public.is_active_job_seeker())
          or (select public.is_active_employer())
          or (select public.is_admin_user())
      )
    order by u.name, u.auth_user_id;
$$;

revoke all on function public.conversation_user_directory() from public;
grant execute on function public.conversation_user_directory()
    to authenticated;

create or replace function public.public_employer_profiles(p_employer_ids uuid[])
returns table (
    employer_id uuid,
    user_id uuid,
    name text,
    profile_image text
)
language sql
stable
security definer
set search_path = ''
as $$
    select e.id,
           e.user_id,
           e.company_name,
           u.profile_image
    from public.employers e
    join public.users u on u.auth_user_id = e.user_id
    where e.id = any(coalesce(p_employer_ids, array[]::uuid[]))
      and u.account_status <> 'deleted'
      and exists (
          select 1 from public.jobs j
          where j.employer_id = e.id
      );
$$;

revoke all on function public.public_employer_profiles(uuid[]) from public;
grant execute on function public.public_employer_profiles(uuid[]) to authenticated;

create or replace function public.public_admin_job_profiles(p_admin_ids uuid[])
returns table (
    admin_id uuid,
    user_id uuid,
    name text,
    profile_image text
)
language sql
stable
security definer
set search_path = ''
as $$
    select a.id,
           a.user_id,
           u.name,
           u.profile_image
    from public.admins a
    join public.users u on u.auth_user_id = a.user_id
    where a.id = any(coalesce(p_admin_ids, array[]::uuid[]))
      and u.account_status <> 'deleted'
      and exists (
          select 1 from public.jobs j
          where j.admin_id = a.id
      );
$$;

revoke all on function public.public_admin_job_profiles(uuid[]) from public;
grant execute on function public.public_admin_job_profiles(uuid[]) to authenticated;

-- Return only account-list fields, and only to a verified admin. A dedicated
-- function avoids granting the client broad SELECT access to users/profiles.
create or replace function public.admin_list_users()
returns table (
    id uuid,
    name text,
    email text,
    role text,
    account_status text,
    created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if not public.is_admin_user() then
        raise insufficient_privilege using message = 'Admin access is required.';
    end if;

    return query
    select au.id,
           coalesce(
               nullif(u.name, ''),
               nullif(au.raw_user_meta_data ->> 'name', ''),
               split_part(coalesce(au.email, ''), '@', 1)
           ),
           coalesce(u.email, au.email, ''),
           coalesce(u.role, 'unknown'),
           coalesce(u.account_status, 'active'),
           coalesce(u.created_at, au.created_at)
    from auth.users au
    left join public.users u on u.auth_user_id = au.id
    order by coalesce(u.created_at, au.created_at) desc;
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_reports_count bigint := 0;
begin
    if not public.is_admin_user() then
        raise insufficient_privilege using message = 'Admin access is required.';
    end if;

    if to_regclass('public.reports') is not null then
        execute 'select count(*) from public.reports' into v_reports_count;
    end if;

    return jsonb_build_object(
        'users', (select count(*) from auth.users),
        'employers', (select count(*) from public.employers),
        'jobs', (select count(*) from public.jobs),
        'announcements', (select count(*) from public.announcements),
        'reports', v_reports_count
    );
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;

alter table public.job_seekers enable row level security;
alter table public.employers enable row level security;
alter table public.admins enable row level security;
alter table public.users enable row level security;
alter table public.jobs enable row level security;
alter table public.saved_jobs enable row level security;
alter table public.applications enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.announcements enable row level security;
alter table public.notification_read_state enable row level security;
alter table public.app_policies enable row level security;
alter table public.reports enable row level security;

drop policy if exists users_select_self_or_admin on public.users;
create policy users_select_self_or_admin
    on public.users
    for select
    to authenticated
    using (
        auth_user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists users_insert_self on public.users;
create policy users_insert_self
    on public.users
    for insert
    to authenticated
    with check (
        auth_user_id = (select auth.uid())
        and lower(email) = lower((select auth.jwt() ->> 'email'))
        and account_status = 'active'
        and (
            role in ('job_seeker', 'employer')
            or (
                role = 'admin'
                and (select public.is_admin_user())
            )
        )
    );

drop policy if exists users_update_self_or_admin on public.users;
create policy users_update_self_or_admin
    on public.users
    for update
    to authenticated
    using (
        auth_user_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        auth_user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

create or replace function public.guard_user_account_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.account_status is distinct from old.account_status
       and not public.is_admin_user() then
        raise insufficient_privilege
            using message = 'Only an administrator may change account status.';
    end if;
    return new;
end;
$$;

revoke all on function public.guard_user_account_status() from public;

drop trigger if exists users_guard_account_status on public.users;
create trigger users_guard_account_status
before update of account_status on public.users
for each row
execute function public.guard_user_account_status();

do $$
declare
    policy_name text;
begin
    for policy_name in
        select polname
        from pg_policy
        where polrelid = 'public.jobs'::regclass
    loop
        execute format('drop policy %I on public.jobs', policy_name);
    end loop;
end;
$$;

drop policy if exists jobs_select_authenticated on public.jobs;
create policy jobs_select_authenticated
    on public.jobs
    for select
    to authenticated
    using (true);

drop policy if exists jobs_insert_employer on public.jobs;
drop policy if exists jobs_insert_owner on public.jobs;
create policy jobs_insert_owner
    on public.jobs
    for insert
    to authenticated
    with check (
        (
            jobs.employer_id is not null
            and jobs.admin_id is null
            and exists (
                select 1
                from public.employers e
                where e.id = jobs.employer_id
                  and e.user_id = (select auth.uid())
                  and (select public.is_active_employer())
            )
        )
        or (
            jobs.employer_id is null
            and jobs.admin_id is not null
            and exists (
                select 1
                from public.admins a
                where a.id = jobs.admin_id
                  and a.user_id = (select auth.uid())
            )
            and exists (
                select 1
                from public.users u
                where u.auth_user_id = (select auth.uid())
                  and u.account_status = 'active'
            )
        )
    );

drop policy if exists jobs_update_owner_admin on public.jobs;
create policy jobs_update_owner_admin
    on public.jobs
    for update
    to authenticated
    using (
        (
            exists (
                select 1 from public.employers e
                where e.id = jobs.employer_id
                  and e.user_id = (select auth.uid())
            )
            and (select public.is_active_employer())
        )
        or (select public.is_admin_user())
    )
    with check (
        (
            exists (
                select 1 from public.employers e
                where e.id = jobs.employer_id
                  and e.user_id = (select auth.uid())
            )
            and (select public.is_active_employer())
        )
        or (select public.is_admin_user())
    );

drop policy if exists jobs_delete_owner_admin on public.jobs;
create policy jobs_delete_owner_admin
    on public.jobs
    for delete
    to authenticated
    using (
        (
            exists (
                select 1 from public.employers e
                where e.id = jobs.employer_id
                  and e.user_id = (select auth.uid())
            )
            and (select public.is_active_employer())
        )
        or (select public.is_admin_user())
    );

drop policy if exists saved_jobs_select_owner_admin on public.saved_jobs;
create policy saved_jobs_select_owner_admin
    on public.saved_jobs
    for select
    to authenticated
    using (
        exists (
            select 1 from public.job_seekers seeker
            where seeker.id = saved_jobs.job_seeker_id
              and seeker.user_id = (select auth.uid())
        )
        or (select public.is_admin_user())
    );

drop policy if exists saved_jobs_insert_owner on public.saved_jobs;
create policy saved_jobs_insert_owner
    on public.saved_jobs
    for insert
    to authenticated
    with check (
        exists (
            select 1 from public.job_seekers seeker
            where seeker.id = saved_jobs.job_seeker_id
              and seeker.user_id = (select auth.uid())
        )
        and (select public.is_active_job_seeker())
    );

drop policy if exists saved_jobs_delete_owner_admin on public.saved_jobs;
create policy saved_jobs_delete_owner_admin
    on public.saved_jobs
    for delete
    to authenticated
    using (
        exists (
            select 1 from public.job_seekers seeker
            where seeker.id = saved_jobs.job_seeker_id
              and seeker.user_id = (select auth.uid())
        )
        or (select public.is_admin_user())
    );

drop policy if exists applications_select_participants_admin on public.applications;
create policy applications_select_participants_admin
    on public.applications
    for select
    to authenticated
    using (
        exists (
            select 1 from public.job_seekers seeker
            where seeker.id = applications.job_seeker_id
              and seeker.user_id = (select auth.uid())
        )
        or (select public.is_admin_user())
        or exists (
            select 1
            from public.jobs j
            join public.employers e on e.id = j.employer_id
            where j.id = applications.job_id
              and e.user_id = (select auth.uid())
        )
    );

drop policy if exists applications_insert_job_seeker on public.applications;
create policy applications_insert_job_seeker
    on public.applications
    for insert
    to authenticated
    with check (
        exists (
            select 1 from public.job_seekers seeker
            where seeker.id = applications.job_seeker_id
              and seeker.user_id = (select auth.uid())
        )
        and (select public.is_active_job_seeker())
        and status = 'new'
        and reviewed_date is null
        and interview_date is null
    );

drop policy if exists applications_update_employer_admin on public.applications;
create policy applications_update_employer_admin
    on public.applications
    for update
    to authenticated
    using (
        (select public.is_admin_user())
        or exists (
            select 1
            from public.jobs j
            join public.employers e on e.id = j.employer_id
            where j.id = applications.job_id
              and e.user_id = (select auth.uid())
              and (select public.is_active_employer())
        )
    )
    with check (
        (select public.is_admin_user())
        or exists (
            select 1
            from public.jobs j
            join public.employers e on e.id = j.employer_id
            where j.id = applications.job_id
              and e.user_id = (select auth.uid())
              and (select public.is_active_employer())
        )
    );

drop policy if exists conversations_select_participant_admin on public.conversations;
create policy conversations_select_participant_admin
    on public.conversations
    for select
    to authenticated
    using (
        participant1_id = (select auth.uid())
        or participant2_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists conversations_insert_starter on public.conversations;
create policy conversations_insert_starter
    on public.conversations
    for insert
    to authenticated
    with check (
        participant1_id = (select auth.uid())
        and participant1_id <> participant2_id
        and (
            (select public.is_active_job_seeker())
            or (select public.is_active_employer())
            or (select public.is_admin_user())
        )
    );

drop policy if exists conversations_update_participant_admin on public.conversations;
create policy conversations_update_participant_admin
    on public.conversations
    for update
    to authenticated
    using (
        participant1_id = (select auth.uid())
        or participant2_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        participant1_id = (select auth.uid())
        or participant2_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists messages_select_participant_admin on public.messages;
create policy messages_select_participant_admin
    on public.messages
    for select
    to authenticated
    using (
        (select public.is_admin_user())
        or exists (
            select 1
            from public.conversations c
            where c.id = messages.conversation_id
              and (
                  c.participant1_id = (select auth.uid())
                  or c.participant2_id = (select auth.uid())
              )
        )
    );

drop policy if exists messages_insert_sender_participant on public.messages;
create policy messages_insert_sender_participant
    on public.messages
    for insert
    to authenticated
    with check (
        sender_id = (select auth.uid())
        and is_read = false
        and (
            (select public.is_active_job_seeker())
            or (select public.is_active_employer())
            or (select public.is_admin_user())
        )
        and exists (
            select 1
            from public.conversations c
            where c.id = messages.conversation_id
              and (
                  (
                      c.participant1_id = sender_id
                      and c.participant2_id = receiver_id
                  )
                  or (
                      c.participant2_id = sender_id
                      and c.participant1_id = receiver_id
                  )
              )
        )
    );

drop policy if exists messages_update_participant_admin on public.messages;
create policy messages_update_participant_admin
    on public.messages
    for update
    to authenticated
    using (
        (select public.is_admin_user())
        or exists (
            select 1
            from public.conversations c
            where c.id = messages.conversation_id
              and (
                  c.participant1_id = (select auth.uid())
                  or c.participant2_id = (select auth.uid())
              )
        )
    )
    with check (
        (select public.is_admin_user())
        or exists (
            select 1
            from public.conversations c
            where c.id = messages.conversation_id
              and (
                  c.participant1_id = (select auth.uid())
                  or c.participant2_id = (select auth.uid())
              )
        )
    );

drop policy if exists announcements_select_targeted on public.announcements;
create policy announcements_select_targeted
    on public.announcements
    for select
    to authenticated
    using (
        coalesce(cardinality(target_roles), 0) = 0
        or 'all' = any(target_roles)
        or (select public.current_user_role()) = any(target_roles)
        or (select public.is_admin_user())
    );

drop policy if exists announcements_insert_admin on public.announcements;
create policy announcements_insert_admin
    on public.announcements
    for insert
    to authenticated
    with check ((select public.is_admin_user()));

drop policy if exists announcements_delete_admin on public.announcements;
create policy announcements_delete_admin
    on public.announcements
    for delete
    to authenticated
    using ((select public.is_admin_user()));

drop policy if exists notification_read_state_owner_admin on public.notification_read_state;
create policy notification_read_state_owner_admin
    on public.notification_read_state
    for all
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists app_policies_select_authenticated on public.app_policies;
create policy app_policies_select_authenticated
    on public.app_policies
    for select
    to authenticated
    using (true);

drop policy if exists app_policies_write_admin on public.app_policies;
create policy app_policies_write_admin
    on public.app_policies
    for all
    to authenticated
    using ((select public.is_admin_user()))
    with check ((select public.is_admin_user()));

drop policy if exists reports_select_reporter_or_admin on public.reports;
create policy reports_select_reporter_or_admin
    on public.reports
    for select
    to authenticated
    using (
        reporter_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists reports_insert_reporter on public.reports;
create policy reports_insert_reporter
    on public.reports
    for insert
    to authenticated
    with check (
        reporter_id = (select auth.uid())
        and status = 'pending'
        and (subject_job_id is not null or subject_user_id is not null)
        and admin_notes is null
        and reviewed_at is null
        and reviewed_by_admin_id is null
    );

drop policy if exists reports_update_admin on public.reports;
create policy reports_update_admin
    on public.reports
    for update
    to authenticated
    using ((select public.is_admin_user()))
    with check ((select public.is_admin_user()));

drop policy if exists job_seekers_select_owner_admin_applying_employer
    on public.job_seekers;
create policy job_seekers_select_owner_admin_applying_employer
    on public.job_seekers
    for select
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
        or (select public.can_employer_view_job_seeker(job_seekers.id))
    );

drop policy if exists job_seekers_insert_owner_admin on public.job_seekers;
create policy job_seekers_insert_owner_admin
    on public.job_seekers
    for insert
    to authenticated
    with check (
        (
            user_id = (select auth.uid())
            and exists (
                select 1 from public.users u
                where u.auth_user_id = (select auth.uid())
                  and u.account_status = 'active'
            )
        )
        or (select public.is_admin_user())
    );

drop policy if exists job_seekers_update_owner_admin on public.job_seekers;
create policy job_seekers_update_owner_admin
    on public.job_seekers
    for update
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists job_seekers_delete_owner_admin on public.job_seekers;
create policy job_seekers_delete_owner_admin
    on public.job_seekers
    for delete
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists employers_select_owner_admin on public.employers;
create policy employers_select_owner_admin
    on public.employers
    for select
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists employers_insert_owner_admin on public.employers;
create policy employers_insert_owner_admin
    on public.employers
    for insert
    to authenticated
    with check (
        (
            user_id = (select auth.uid())
            and exists (
                select 1 from public.users u
                where u.auth_user_id = (select auth.uid())
                  and u.account_status = 'active'
            )
        )
        or (select public.is_admin_user())
    );

drop policy if exists employers_update_owner_admin on public.employers;
create policy employers_update_owner_admin
    on public.employers
    for update
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists employers_delete_owner_admin on public.employers;
create policy employers_delete_owner_admin
    on public.employers
    for delete
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists admins_select_owner_admin on public.admins;
create policy admins_select_owner_admin
    on public.admins
    for select
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

drop policy if exists admins_insert_admin on public.admins;
create policy admins_insert_admin
    on public.admins
    for insert
    to authenticated
    with check ((select public.is_admin_user()));

drop policy if exists admins_update_owner_admin on public.admins;
create policy admins_update_owner_admin
    on public.admins
    for update
    to authenticated
    using (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    )
    with check (
        user_id = (select auth.uid())
        or (select public.is_admin_user())
    );

-- Authenticated admins may update their own contact details, but cannot
-- grant themselves permissions or alter another admin's permission list.
revoke all on public.users, public.job_seekers, public.employers, public.admins,
    public.jobs, public.saved_jobs, public.applications, public.conversations,
    public.messages, public.announcements, public.notification_read_state,
    public.app_policies, public.reports
from anon, authenticated;

grant select on public.users to authenticated;
grant select on public.job_seekers, public.employers, public.admins,
    public.jobs, public.saved_jobs, public.applications, public.conversations,
    public.messages, public.announcements, public.notification_read_state,
    public.app_policies, public.reports to authenticated;
grant select on public.user_roles to authenticated;

grant insert (
    auth_user_id,
    name,
    email,
    role,
    account_status,
    profile_image,
    bio,
    created_at,
    updated_at
) on public.users to authenticated;
grant update (
    name,
    profile_image,
    bio,
    updated_at,
    account_status
) on public.users to authenticated;

grant insert (
    user_id,
    phone,
    location,
    resume_file_name,
    resume_url,
    resume_image_file_name,
    resume_image_url,
    skills,
    work_experience,
    education
) on public.job_seekers to authenticated;
grant update (
    phone,
    location,
    resume_file_name,
    resume_url,
    resume_image_file_name,
    resume_image_url,
    skills,
    work_experience,
    education,
    updated_at
) on public.job_seekers to authenticated;

grant insert (
    user_id,
    phone,
    location,
    company_name,
    company_address,
    company_description,
    industry,
    company_logo,
    website
) on public.employers to authenticated;
grant update (
    phone,
    location,
    company_name,
    company_address,
    company_description,
    industry,
    company_logo,
    website,
    updated_at
) on public.employers to authenticated;

grant insert (user_id) on public.admins to authenticated;
grant update (phone, location) on public.admins to authenticated;

grant insert (
    id,
    employer_id,
    admin_id,
    title,
    category,
    description,
    location,
    salary,
    is_full_time,
    requirements,
    number_of_vacancies,
    status,
    posted_date,
    deadline
) on public.jobs to authenticated;
grant update (
    title,
    category,
    description,
    location,
    salary,
    is_full_time,
    requirements,
    number_of_vacancies,
    status,
    deadline,
    updated_at
) on public.jobs to authenticated;
grant delete on public.jobs to authenticated;

grant insert (job_seeker_id, job_id) on public.saved_jobs to authenticated;
grant delete on public.saved_jobs to authenticated;

grant insert (
    id,
    job_id,
    job_title_snapshot,
    job_seeker_id,
    job_seeker_name_snapshot,
    status,
    cover_letter,
    applied_date,
    reviewed_date,
    interview_date
) on public.applications to authenticated;
grant update (
    status,
    reviewed_date,
    interview_date,
    updated_at
) on public.applications to authenticated;

grant insert (
    id,
    participant1_id,
    participant2_id,
    created_at,
    updated_at
) on public.conversations to authenticated;
grant update (
    last_message,
    last_message_timestamp,
    updated_at
) on public.conversations to authenticated;

grant insert (
    id,
    conversation_id,
    sender_id,
    receiver_id,
    sender_name_snapshot,
    content,
    timestamp,
    is_read
) on public.messages to authenticated;
grant update (is_read) on public.messages to authenticated;

-- Provision public account/profile rows at Auth-user creation. Confirmation
-- signups usually have no client session, so client-side inserts cannot work.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_role text;
    v_name text;
begin
    if new.raw_app_meta_data ->> 'role' = 'admin' then
        v_role := 'admin';
    else
        v_role := lower(
            replace(trim(coalesce(new.raw_user_meta_data ->> 'role', '')), '-', '_')
        );
    end if;

    if v_role = 'admin'
       and new.raw_app_meta_data ->> 'role' is distinct from 'admin' then
        raise insufficient_privilege
            using message = 'Admin accounts must be provisioned by an authorized administrator.';
    end if;

    if v_role is null
       or v_role not in ('admin', 'job_seeker', 'employer') then
        raise check_violation
            using message = 'Account role must be job_seeker, employer, or an administrator-provisioned admin.';
    end if;

    v_name := coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
        nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
        'User'
    );

    insert into public.users (auth_user_id, email, name, role)
    values (new.id, new.email, v_name, v_role)
    on conflict (auth_user_id) do nothing;

    if v_role = 'admin' then
        insert into public.admins (user_id)
        values (new.id)
        on conflict (user_id) do nothing;
    elsif v_role = 'job_seeker' then
        insert into public.job_seekers (user_id)
        values (new.id)
        on conflict (user_id) do nothing;
    else
        insert into public.employers (user_id, company_name)
        values (
            new.id,
            coalesce(
                nullif(trim(new.raw_user_meta_data ->> 'company_name'), ''),
                v_name
            )
        )
        on conflict (user_id) do nothing;
    end if;

    return new;
end;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_auth_user();

-- Backfill previously registered email-confirmation accounts that were left
-- in auth.users without a corresponding public account/profile.
insert into public.users (auth_user_id, email, name, role)
select au.id,
       au.email,
       coalesce(
           nullif(trim(au.raw_user_meta_data ->> 'name'), ''),
           nullif(split_part(coalesce(au.email, ''), '@', 1), ''),
           'User'
       ),
       case
           when au.raw_app_meta_data ->> 'role' = 'admin' then 'admin'
           else lower(
               replace(
                   trim(coalesce(au.raw_user_meta_data ->> 'role', '')),
                   '-',
                   '_'
               )
           )
       end
from auth.users au
where au.email is not null
  and (
      au.raw_app_meta_data ->> 'role' = 'admin'
      or lower(
          replace(
              trim(coalesce(au.raw_user_meta_data ->> 'role', '')),
              '-',
              '_'
          )
      ) in ('job_seeker', 'employer')
  )
  and not exists (
      select 1 from public.users u where u.auth_user_id = au.id
  )
on conflict (auth_user_id) do nothing;

insert into public.admins (user_id)
select u.auth_user_id
from public.users u
where u.role = 'admin'
  and exists (
      select 1 from auth.users au
      where au.id = u.auth_user_id
        and au.raw_app_meta_data ->> 'role' = 'admin'
  )
  and not exists (
      select 1 from public.admins a where a.user_id = u.auth_user_id
  )
on conflict (user_id) do nothing;

insert into public.job_seekers (user_id)
select u.auth_user_id
from public.users u
where u.role = 'job_seeker'
  and not exists (
      select 1 from public.job_seekers js where js.user_id = u.auth_user_id
  )
on conflict (user_id) do nothing;

insert into public.employers (user_id, company_name)
select u.auth_user_id,
       coalesce(
           nullif(trim(u.name), ''),
           nullif(split_part(u.email, '@', 1), ''),
           'Employer'
       )
from public.users u
where u.role = 'employer'
  and not exists (
      select 1 from public.employers e where e.user_id = u.auth_user_id
  )
on conflict (user_id) do nothing;

grant insert (
    id,
    created_by,
    title,
    category,
    description,
    image_path,
    publish_date,
    target_roles
) on public.announcements to authenticated;
grant delete on public.announcements to authenticated;

grant insert (user_id, read_keys, last_read_at, updated_at)
    on public.notification_read_state to authenticated;
grant update (user_id, read_keys, last_read_at, updated_at)
    on public.notification_read_state to authenticated;
grant delete on public.notification_read_state to authenticated;

grant insert (policy_key, title, body, created_by, updated_at)
    on public.app_policies to authenticated;
grant update (policy_key, title, body, created_by, updated_at)
    on public.app_policies to authenticated;

grant insert (
    reporter_id,
    report_type,
    subject_job_id,
    subject_user_id,
    category,
    title,
    description,
    status,
    created_at
) on public.reports to authenticated;
grant update (
    status,
    admin_notes,
    reviewed_at,
    reviewed_by_admin_id
) on public.reports to authenticated;

-- Avatar images remain public; resumes are private and are exposed only
-- through signed URLs after the object policies authorize the requester.
update public.job_seekers
set resume_url = split_part(
    split_part(resume_url, '/storage/v1/object/public/resumes/', 2),
    '?',
    1
)
where resume_url like '%/storage/v1/object/public/resumes/%';

update public.job_seekers
set resume_url = split_part(
    split_part(resume_url, '/storage/v1/object/sign/resumes/', 2),
    '?',
    1
)
where resume_url like '%/storage/v1/object/sign/resumes/%';

update public.job_seekers
set resume_image_url = split_part(
    split_part(resume_image_url, '/storage/v1/object/public/resumes/', 2),
    '?',
    1
)
where resume_image_url like '%/storage/v1/object/public/resumes/%';

update public.job_seekers
set resume_image_url = split_part(
    split_part(resume_image_url, '/storage/v1/object/sign/resumes/', 2),
    '?',
    1
)
where resume_image_url like '%/storage/v1/object/sign/resumes/%';

insert into storage.buckets (id, name, public)
values
    ('avatars', 'avatars', true),
    ('resumes', 'resumes', false)
on conflict (id) do update
set public = excluded.public;

drop policy if exists app_avatars_insert_owner on storage.objects;
create policy app_avatars_insert_owner
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'avatars'
        and split_part(name, '/', 2) = (select auth.uid())::text
        and exists (
            select 1
            from public.users u
            where u.auth_user_id = (select auth.uid())
              and u.account_status = 'active'
        )
    );

drop policy if exists app_avatars_update_owner on storage.objects;
create policy app_avatars_update_owner
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'avatars'
        and split_part(name, '/', 2) = (select auth.uid())::text
    )
    with check (
        bucket_id = 'avatars'
        and split_part(name, '/', 2) = (select auth.uid())::text
        and exists (
            select 1
            from public.users u
            where u.auth_user_id = (select auth.uid())
              and u.account_status = 'active'
        )
    );

drop policy if exists app_avatars_delete_owner on storage.objects;
create policy app_avatars_delete_owner
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'avatars'
        and split_part(name, '/', 2) = (select auth.uid())::text
    );

create or replace function public.can_read_job_seeker_resume(
    p_owner_user_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_owner_user_id = (select auth.uid())::text
        or (select public.is_admin_user())
        or (
            (select public.is_active_employer())
            and exists (
                select 1
                from public.applications app
                join public.job_seekers seeker
                  on seeker.id = app.job_seeker_id
                join public.jobs job on job.id = app.job_id
                join public.employers employer
                  on employer.id = job.employer_id
                where seeker.user_id::text = p_owner_user_id
                  and employer.user_id = (select auth.uid())
            )
        );
$$;

revoke all on function public.can_read_job_seeker_resume(text) from public;
grant execute on function public.can_read_job_seeker_resume(text)
    to authenticated;

drop policy if exists app_resumes_select_authorized on storage.objects;
create policy app_resumes_select_authorized
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'resumes'
        and public.can_read_job_seeker_resume(
            split_part(name, '/', 2)
        )
    );

drop policy if exists app_resumes_insert_owner on storage.objects;
create policy app_resumes_insert_owner
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'resumes'
        and split_part(name, '/', 2) = (select auth.uid())::text
        and (select public.is_active_job_seeker())
    );

drop policy if exists app_resumes_update_owner on storage.objects;
create policy app_resumes_update_owner
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'resumes'
        and split_part(name, '/', 2) = (select auth.uid())::text
        and (select public.is_active_job_seeker())
    )
    with check (
        bucket_id = 'resumes'
        and split_part(name, '/', 2) = (select auth.uid())::text
        and (select public.is_active_job_seeker())
    );

drop policy if exists app_resumes_delete_owner on storage.objects;
create policy app_resumes_delete_owner
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'resumes'
        and split_part(name, '/', 2) = (select auth.uid())::text
    );

-- Restrictive guards ensure older permissive policies cannot make this
-- bucket publicly readable or writable.
drop policy if exists app_resumes_anon_select_guard on storage.objects;
create policy app_resumes_anon_select_guard
    on storage.objects
    as restrictive
    for select
    to anon
    using (bucket_id <> 'resumes');

drop policy if exists app_resumes_anon_insert_guard on storage.objects;
create policy app_resumes_anon_insert_guard
    on storage.objects
    as restrictive
    for insert
    to anon
    with check (bucket_id <> 'resumes');

drop policy if exists app_resumes_anon_update_guard on storage.objects;
create policy app_resumes_anon_update_guard
    on storage.objects
    as restrictive
    for update
    to anon
    using (bucket_id <> 'resumes')
    with check (bucket_id <> 'resumes');

drop policy if exists app_resumes_anon_delete_guard on storage.objects;
create policy app_resumes_anon_delete_guard
    on storage.objects
    as restrictive
    for delete
    to anon
    using (bucket_id <> 'resumes');

drop policy if exists app_resumes_authenticated_select_guard
    on storage.objects;
create policy app_resumes_authenticated_select_guard
    on storage.objects
    as restrictive
    for select
    to authenticated
    using (
        bucket_id <> 'resumes'
        or public.can_read_job_seeker_resume(split_part(name, '/', 2))
    );

drop policy if exists app_resumes_authenticated_insert_guard
    on storage.objects;
create policy app_resumes_authenticated_insert_guard
    on storage.objects
    as restrictive
    for insert
    to authenticated
    with check (
        bucket_id <> 'resumes'
        or (
            split_part(name, '/', 2) = (select auth.uid())::text
            and (select public.is_active_job_seeker())
        )
    );

drop policy if exists app_resumes_authenticated_update_guard
    on storage.objects;
create policy app_resumes_authenticated_update_guard
    on storage.objects
    as restrictive
    for update
    to authenticated
    using (
        bucket_id <> 'resumes'
        or (
            split_part(name, '/', 2) = (select auth.uid())::text
            and (select public.is_active_job_seeker())
        )
    )
    with check (
        bucket_id <> 'resumes'
        or (
            split_part(name, '/', 2) = (select auth.uid())::text
            and (select public.is_active_job_seeker())
        )
    );

drop policy if exists app_resumes_authenticated_delete_guard
    on storage.objects;
create policy app_resumes_authenticated_delete_guard
    on storage.objects
    as restrictive
    for delete
    to authenticated
    using (
        bucket_id <> 'resumes'
        or split_part(name, '/', 2) = (select auth.uid())::text
    );
