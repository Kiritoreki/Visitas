-- ============================================================
-- Registro de Visitas · Base de datos para Supabase
-- Pegar TODO este archivo en Supabase → SQL Editor → Run.
-- Se puede volver a ejecutar sin perder datos.
-- ============================================================

-- ---------- Dispositivos autorizados (sin usuario ni clave) ----------
create table if not exists public.dispositivos (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  nombre  text not null default 'Dispositivo',
  codigo  text not null,
  rol     text not null default 'pendiente' check (rol in ('pendiente','admin','lector','bloqueado')),
  creado  timestamptz not null default now()
);

create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from public.dispositivos where user_id = auth.uid()
$$;
create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.mi_rol() = 'admin', false)
$$;
create or replace function public.puede_leer() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.mi_rol() in ('admin','lector'), false)
$$;
create or replace function public.hay_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.dispositivos where rol = 'admin')
$$;
-- El primer dispositivo que lo pida queda como administrador (solo si aún no hay ninguno).
create or replace function public.reclamar_admin() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.dispositivos where rol = 'admin') then return false; end if;
  update public.dispositivos set rol = 'admin' where user_id = auth.uid();
  return found;
end $$;

-- ---------- Lugares: Parroquia → Sector → Barrio ----------
create table if not exists public.lugares (
  id       uuid primary key default gen_random_uuid(),
  nombre   text not null,
  padre    uuid references public.lugares(id) on delete cascade,
  palabras text[] not null default '{}',
  creado   timestamptz not null default now()
);

-- ---------- Clientes ----------
create table if not exists public.clientes (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  telefono    text,
  telefono2   text,
  ip          text,
  direccion   text,
  lugar_id    uuid references public.lugares(id) on delete set null,
  lat         double precision,
  lng         double precision,
  precision_m double precision,
  nap         text,
  hilo        text,
  notas       text,
  creado      timestamptz not null default now(),
  editado     timestamptz not null default now()
);

-- ---------- Visitas ----------
create table if not exists public.visitas (
  id              uuid primary key default gen_random_uuid(),
  cliente_id      uuid not null references public.clientes(id) on delete cascade,
  fecha           timestamptz not null default now(),
  tipo            text not null,
  companero       text,
  previa_otra     boolean not null default false,
  sintomas        text[] not null default '{}',
  hallazgos       text[] not null default '{}',
  soluciones      text[] not null default '{}',
  causa           text,
  sin_senal       boolean not null default false,
  onu_antes       numeric,
  olt_antes       numeric,
  onu_despues     numeric,
  olt_despues     numeric,
  nap             text,
  hilo            text,
  etiqueta_estado text,
  estado          text,
  nota            text,
  fotos           jsonb not null default '[]',
  creado          timestamptz not null default now()
);
create index if not exists visitas_cliente_idx on public.visitas (cliente_id, fecha desc);

-- ---------- Permisos (RLS): administrador edita, lector solo ve ----------
alter table public.dispositivos enable row level security;
alter table public.lugares      enable row level security;
alter table public.clientes     enable row level security;
alter table public.visitas      enable row level security;

drop policy if exists disp_ver      on public.dispositivos;
drop policy if exists disp_pedir    on public.dispositivos;
drop policy if exists disp_admin_up on public.dispositivos;
drop policy if exists disp_admin_de on public.dispositivos;
create policy disp_ver      on public.dispositivos for select using (user_id = auth.uid() or public.es_admin());
create policy disp_pedir    on public.dispositivos for insert with check (user_id = auth.uid() and rol = 'pendiente');
create policy disp_admin_up on public.dispositivos for update using (public.es_admin()) with check (public.es_admin());
create policy disp_admin_de on public.dispositivos for delete using (public.es_admin());

do $$
declare t text;
begin
  foreach t in array array['lugares','clientes','visitas'] loop
    execute format('drop policy if exists %1$s_leer on public.%1$s', t);
    execute format('drop policy if exists %1$s_editar on public.%1$s', t);
    execute format('create policy %1$s_leer on public.%1$s for select using (public.puede_leer())', t);
    execute format('create policy %1$s_editar on public.%1$s for all using (public.es_admin()) with check (public.es_admin())', t);
  end loop;
end $$;

-- ---------- Acceso a la API (funciona aunque "Automatically expose new tables" esté desactivado) ----------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.dispositivos, public.lugares, public.clientes, public.visitas to authenticated;
grant execute on function public.mi_rol(), public.es_admin(), public.puede_leer(), public.hay_admin(), public.reclamar_admin() to authenticated;
revoke all on public.dispositivos, public.lugares, public.clientes, public.visitas from anon;

-- ---------- Fotos (almacenamiento privado) ----------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', false)
on conflict (id) do nothing;

drop policy if exists fotos_leer   on storage.objects;
drop policy if exists fotos_subir  on storage.objects;
drop policy if exists fotos_cambiar on storage.objects;
drop policy if exists fotos_borrar on storage.objects;
create policy fotos_leer    on storage.objects for select using (bucket_id = 'fotos' and public.puede_leer());
create policy fotos_subir   on storage.objects for insert with check (bucket_id = 'fotos' and public.es_admin());
create policy fotos_cambiar on storage.objects for update using (bucket_id = 'fotos' and public.es_admin());
create policy fotos_borrar  on storage.objects for delete using (bucket_id = 'fotos' and public.es_admin());

-- ---------- Lugares iniciales (se pueden editar desde la app) ----------
insert into public.lugares (nombre)
select n from unnest(array['Palanda','Valladolid','La Canela','San Francisco','Santa Ana','El Porvenir','Tapala']) as n
where not exists (select 1 from public.lugares);
