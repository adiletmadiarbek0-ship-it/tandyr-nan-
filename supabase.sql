-- Tandyr Nan: Supabase SQL Editor-ге толық қойып, Run басыңыз
create table public.emp(id text primary key, data jsonb not null);
create table public.att(id text primary key, emp text not null, day date not null, data jsonb not null, unique(emp, day));
create table public.prod(id text primary key, data jsonb not null);
create table public.pay(id text primary key, data jsonb not null);
create table public.log(id text primary key, data jsonb not null);

do $$ declare t text; begin
  foreach t in array array['emp','att','prod','pay','log'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy admin_all on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- Жұмысшыға тек белсенді қызметкерлердің аты көрінеді (жалақы көрінбейді)
create function public.workers() returns table(id text, name text)
language sql security definer set search_path = public as $$
  select id, data->>'name' from emp where (data->>'on')::boolean order by 2 $$;

create function public.today_done() returns table(emp text, t text)
language sql security definer set search_path = public as $$
  select emp, data->>'time' from att where day = (now() at time zone 'Asia/Almaty')::date $$;

-- Тіркеу: күн мен уақыт серверде (Asia/Almaty), бір күнге бір рет (unique emp+day)
create function public.check_in(p_emp text) returns json
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Asia/Almaty')::date;
        t text := to_char(now() at time zone 'Asia/Almaty', 'HH24:MI:SS');
        r numeric; ex text;
begin
  select (data->>'rate')::numeric into r from emp where id = p_emp and (data->>'on')::boolean;
  if r is null then return json_build_object('ok', false, 'time', null); end if;
  select data->>'time' into ex from att where emp = p_emp and day = d;
  if ex is not null then return json_build_object('ok', false, 'time', ex); end if;
  insert into att(id, emp, day, data)
  values (d || '_' || p_emp, p_emp, d,
          jsonb_build_object('id', d || '_' || p_emp, 'emp', p_emp, 'date', d, 'time', t, 'rate', r))
  on conflict do nothing;
  return json_build_object('ok', true, 'time', t);
end $$;

grant execute on function public.workers(), public.today_done(), public.check_in(text) to anon, authenticated;
