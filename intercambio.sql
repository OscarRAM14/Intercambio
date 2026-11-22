-- =====================================================================
--  INTERCAMBIO NAVIDEÑO  ·  v2.0  ·  Esquema para Supabase
--  Pega TODO este archivo en Supabase > SQL Editor > New query > Run
--  Sirve para instalar desde cero Y para actualizar desde la v1
--  (no borra tus datos; puedes correrlo varias veces).
--
--  Seguridad: nadie lee las tablas directamente. Todo pasa por funciones
--  que piden el código del organizador o el link + PIN de cada persona.
-- =====================================================================

-- ---------- TABLAS ----------
create table if not exists ix_grupos (
  id           uuid primary key default gen_random_uuid(),
  admin_code   text not null unique,
  nombre       text not null,
  monto        numeric(10,2),
  moneda       text not null default 'MXN',
  fecha        timestamptz,
  lugar        text,
  notas        text,
  sorteado     boolean not null default false,
  sorteado_at  timestamptz,
  revelado     boolean not null default false,
  created_at   timestamptz not null default now()
);
alter table ix_grupos add column if not exists coadmin_code text unique;
alter table ix_grupos add column if not exists tema text not null default 'familia';
alter table ix_grupos add column if not exists prev_grupo uuid references ix_grupos(id) on delete set null;

create table if not exists ix_participantes (
  id          uuid primary key default gen_random_uuid(),
  grupo_id    uuid not null references ix_grupos(id) on delete cascade,
  nombre      text not null,
  telefono    text,
  token       text not null unique,
  pin         text not null,
  asignado_a  uuid references ix_participantes(id) on delete set null,
  perfil      jsonb not null default '{}'::jsonb,
  abrio_at    timestamptz,
  vio_at      timestamptz,
  lista_at    timestamptz,
  created_at  timestamptz not null default now()
);
alter table ix_participantes add column if not exists prev_id uuid references ix_participantes(id) on delete set null;
create index if not exists ix_part_grupo on ix_participantes(grupo_id);

create table if not exists ix_exclusiones (
  grupo_id uuid not null references ix_grupos(id) on delete cascade,
  a        uuid not null references ix_participantes(id) on delete cascade,
  b        uuid not null references ix_participantes(id) on delete cascade,
  primary key (grupo_id, a, b)
);

create table if not exists ix_deseos (
  id              uuid primary key default gen_random_uuid(),
  participante_id uuid not null references ix_participantes(id) on delete cascade,
  texto           text not null,
  link            text,
  precio          numeric(10,2),
  comprado        boolean not null default false,
  created_at      timestamptz not null default now()
);
alter table ix_deseos add column if not exists foto text;
alter table ix_deseos add column if not exists prioridad smallint not null default 2;
create index if not exists ix_deseos_part on ix_deseos(participante_id);

create table if not exists ix_mensajes (
  id          uuid primary key default gen_random_uuid(),
  giver_id    uuid not null references ix_participantes(id) on delete cascade,
  receiver_id uuid not null references ix_participantes(id) on delete cascade,
  autor       text not null check (autor in ('santa','amigo')),
  texto       text not null,
  created_at  timestamptz not null default now()
);
create index if not exists ix_msg_pair on ix_mensajes(giver_id, receiver_id);

create table if not exists ix_pistas (
  giver_id   uuid not null references ix_participantes(id) on delete cascade,
  n          smallint not null check (n between 1 and 3),
  texto      text not null,
  updated_at timestamptz not null default now(),
  primary key (giver_id, n)
);

create table if not exists ix_cena (
  id              uuid primary key default gen_random_uuid(),
  grupo_id        uuid not null references ix_grupos(id) on delete cascade,
  texto           text not null,
  participante_id uuid references ix_participantes(id) on delete set null,
  created_at      timestamptz not null default now()
);
create index if not exists ix_cena_grupo on ix_cena(grupo_id);

create table if not exists ix_mejoras (
  id         uuid primary key default gen_random_uuid(),
  grupo_id   uuid not null references ix_grupos(id) on delete cascade,
  texto      text not null,
  hecho      boolean not null default false,
  created_at timestamptz not null default now()
);

-- RLS activada sin políticas = nadie lee/escribe directo con la llave pública
alter table ix_grupos        enable row level security;
alter table ix_participantes enable row level security;
alter table ix_exclusiones   enable row level security;
alter table ix_deseos        enable row level security;
alter table ix_mensajes      enable row level security;
alter table ix_pistas        enable row level security;
alter table ix_cena          enable row level security;
alter table ix_mejoras       enable row level security;
revoke all on ix_grupos, ix_participantes, ix_exclusiones, ix_deseos, ix_mensajes,
              ix_pistas, ix_cena, ix_mejoras from anon, authenticated;

-- Funciones de la v1 que cambiaron de parámetros
drop function if exists ix_crear_grupo(text,numeric,timestamptz,text,text);
drop function if exists ix_admin_editar(text,text,numeric,timestamptz,text,text);
drop function if exists ix_sortear(text,boolean);
drop function if exists ix_deseo_agregar(text,text,text,text,numeric);

-- ---------- AYUDANTES INTERNOS ----------
create or replace function ix__secreto() returns text
language sql volatile as $$ select replace(gen_random_uuid()::text,'-','') $$;

create or replace function ix__pin() returns text
language sql volatile as $$ select lpad((floor(random()*10000))::int::text, 4, '0') $$;

-- Acepta el código del organizador o del coorganizador
create or replace function ix__grupo(p_admin text) returns ix_grupos
language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  select * into g from ix_grupos where admin_code = p_admin or coadmin_code = p_admin;
  if not found or coalesce(p_admin,'') = '' then raise exception 'Código de organizador inválido'; end if;
  return g;
end $$;

-- Solo el organizador principal
create or replace function ix__principal(p_admin text) returns ix_grupos
language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if g.admin_code <> p_admin then raise exception 'Solo el organizador principal puede hacer esto'; end if;
  return g;
end $$;

create or replace function ix__yo(p_token text, p_pin text) returns ix_participantes
language plpgsql security definer set search_path = public as $$
declare p ix_participantes;
begin
  select * into p from ix_participantes where token = p_token;
  if not found then raise exception 'Link inválido. Pide al organizador que te lo reenvíe.'; end if;
  if p.pin <> p_pin then raise exception 'Código incorrecto'; end if;
  return p;
end $$;

create or replace function ix__tema(t text) returns text
language sql immutable as $$ select case when t = 'trabajo' then 'trabajo' else 'familia' end $$;

-- Cuándo se desbloquea cada pista: 1 ya, 2 una semana antes, 3 un día antes
create or replace function ix__desbloqueo(p_fecha timestamptz, p_n int) returns timestamptz
language sql immutable as $$
  select case when p_fecha is null or p_n = 1 then null
              when p_n = 2 then p_fecha - interval '7 days'
              else p_fecha - interval '1 day' end $$;

create or replace function ix__cena(p_grupo uuid) returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('id', c.id, 'texto', c.texto, 'quien_id', c.participante_id,
         'quien', p.nombre) order by c.created_at), '[]'::json)
  from ix_cena c left join ix_participantes p on p.id = c.participante_id
  where c.grupo_id = p_grupo $$;

-- =====================================================================
--  FUNCIONES DEL ORGANIZADOR
-- =====================================================================
create or replace function ix_crear_grupo(p_nombre text, p_monto numeric, p_fecha timestamptz,
                                          p_lugar text, p_notas text, p_tema text default 'familia')
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  if coalesce(trim(p_nombre),'') = '' then raise exception 'Ponle nombre al intercambio'; end if;
  insert into ix_grupos(admin_code, nombre, monto, fecha, lugar, notas, tema)
  values (ix__secreto(), left(trim(p_nombre),80), p_monto, p_fecha, left(p_lugar,120), left(p_notas,500), ix__tema(p_tema))
  returning * into g;
  return json_build_object('id', g.id, 'admin_code', g.admin_code);
end $$;

create or replace function ix_admin_get(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos; principal boolean;
begin
  g := ix__grupo(p_admin);
  principal := g.admin_code = p_admin;
  return json_build_object(
    'es_principal', principal,
    'coadmin_code', case when principal then g.coadmin_code else null end,
    'grupo', json_build_object('id', g.id, 'nombre', g.nombre, 'monto', g.monto, 'moneda', g.moneda,
             'fecha', g.fecha, 'lugar', g.lugar, 'notas', g.notas, 'sorteado', g.sorteado,
             'sorteado_at', g.sorteado_at, 'revelado', g.revelado, 'tema', g.tema,
             'tiene_anterior', exists(select 1 from ix_participantes where grupo_id = g.id and prev_id is not null)),
    'participantes', coalesce((
      select json_agg(json_build_object(
        'id', p.id, 'nombre', p.nombre, 'telefono', p.telefono, 'token', p.token, 'pin', p.pin,
        'abrio', p.abrio_at is not null, 'vio', p.vio_at is not null,
        'deseos', (select count(*) from ix_deseos d where d.participante_id = p.id),
        'perfil', p.perfil <> '{}'::jsonb)
        order by p.created_at)
      from ix_participantes p where p.grupo_id = g.id), '[]'::json),
    'exclusiones', coalesce((
      select json_agg(json_build_object('a', e.a, 'b', e.b))
      from ix_exclusiones e where e.grupo_id = g.id), '[]'::json),
    'cena', ix__cena(g.id),
    'mejoras', case when principal then coalesce((
      select json_agg(json_build_object('id', m.id, 'texto', m.texto, 'hecho', m.hecho) order by m.hecho, m.created_at)
      from ix_mejoras m where m.grupo_id = g.id), '[]'::json) else '[]'::json end
  );
end $$;

create or replace function ix_admin_editar(p_admin text, p_nombre text, p_monto numeric,
                                           p_fecha timestamptz, p_lugar text, p_notas text, p_tema text default 'familia')
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if coalesce(trim(p_nombre),'') = '' then raise exception 'Ponle nombre al intercambio'; end if;
  update ix_grupos set nombre = left(trim(p_nombre),80), monto = p_monto, fecha = p_fecha,
         lugar = left(p_lugar,120), notas = left(p_notas,500), tema = ix__tema(p_tema)
  where id = g.id;
end $$;

create or replace function ix_admin_agregar(p_admin text, p_nombre text, p_telefono text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo. Reinícialo para agregar personas.'; end if;
  if coalesce(trim(p_nombre),'') = '' then raise exception 'Escribe el nombre'; end if;
  if (select count(*) from ix_participantes where grupo_id = g.id) >= 60 then
    raise exception 'Máximo 60 participantes'; end if;
  insert into ix_participantes(grupo_id, nombre, telefono, token, pin)
  values (g.id, left(trim(p_nombre),40), nullif(regexp_replace(coalesce(p_telefono,''),'\D','','g'),''),
          ix__secreto(), ix__pin());
end $$;

create or replace function ix_admin_editar_participante(p_admin text, p_id uuid, p_nombre text, p_telefono text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if coalesce(trim(p_nombre),'') = '' then raise exception 'Escribe el nombre'; end if;
  update ix_participantes set nombre = left(trim(p_nombre),40),
         telefono = nullif(regexp_replace(coalesce(p_telefono,''),'\D','','g'),'')
  where id = p_id and grupo_id = g.id;
end $$;

create or replace function ix_admin_quitar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo. Reinícialo para quitar personas.'; end if;
  delete from ix_participantes where id = p_id and grupo_id = g.id;
end $$;

create or replace function ix_admin_exclusion(p_admin text, p_a uuid, p_b uuid, p_activa boolean)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos; x uuid; y uuid;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo. Reinícialo para cambiar exclusiones.'; end if;
  if p_a = p_b then raise exception 'Elige dos personas distintas'; end if;
  if (select count(*) from ix_participantes where id in (p_a,p_b) and grupo_id = g.id) <> 2 then
    raise exception 'Participantes inválidos'; end if;
  x := least(p_a, p_b); y := greatest(p_a, p_b);
  if p_activa then
    insert into ix_exclusiones(grupo_id, a, b) values (g.id, x, y) on conflict do nothing;
  else
    delete from ix_exclusiones where grupo_id = g.id and a = x and b = y;
  end if;
end $$;

-- Sorteo en el servidor: nadie (ni el organizador) recibe el resultado.
-- Intenta cumplir todo; si no se puede, primero suelta "no recíprocos" y luego "no repetir".
create or replace function ix_sortear(p_admin text, p_evitar_parejas boolean default true,
                                      p_evitar_repetir boolean default true)
returns json language plpgsql security definer set search_path = public as $$
declare
  g ix_grupos; ids uuid[]; givers uuid[]; avail uuid[]; result uuid[]; cand uuid[];
  rep_g uuid[]; rep_r uuid[];
  n int; i int; k int; intento int; pick uuid; ok boolean; modo int;
  usar_rec boolean; usar_rep boolean;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo'; end if;
  select array_agg(id) into ids from ix_participantes where grupo_id = g.id;
  n := coalesce(array_length(ids,1),0);
  if n < 3 then raise exception 'Se necesitan al menos 3 participantes'; end if;

  -- parejas del intercambio anterior (quién le regaló a quién)
  select array_agg(ng.id), array_agg(nr.id) into rep_g, rep_r
  from ix_participantes ng
  join ix_participantes og on og.id = ng.prev_id
  join ix_participantes nr on nr.prev_id = og.asignado_a and nr.grupo_id = g.id
  where ng.grupo_id = g.id;
  rep_g := coalesce(rep_g, '{}'); rep_r := coalesce(rep_r, '{}');

  for modo in 1..4 loop
    usar_rep := p_evitar_repetir and modo in (1,2) and array_length(rep_g,1) > 0;
    usar_rec := p_evitar_parejas and modo in (1,3) and n >= 4;
    if (modo = 2 and not p_evitar_parejas) or (modo = 3 and not p_evitar_repetir) then continue; end if;
    for intento in 1..300 loop
      ok := true; result := '{}';
      select array_agg(x order by random()) into givers from unnest(ids) x;
      avail := givers;
      for i in 1..n loop
        select array_agg(r) into cand from unnest(avail) r
        where r <> givers[i]
          and not exists (select 1 from ix_exclusiones e
                          where e.grupo_id = g.id and e.a = least(givers[i], r) and e.b = greatest(givers[i], r))
          and (not usar_rec or not exists (
                 select 1 from generate_subscripts(result,1) s
                 where givers[s] = r and result[s] = givers[i]))
          and (not usar_rep or not exists (
                 select 1 from generate_subscripts(rep_g,1) s
                 where rep_g[s] = givers[i] and rep_r[s] = r));
        if cand is null then ok := false; exit; end if;
        pick := cand[1 + floor(random()*array_length(cand,1))::int];
        result := result || pick;
        avail := array_remove(avail, pick);
      end loop;
      if ok then
        for k in 1..n loop
          update ix_participantes set asignado_a = result[k], vio_at = null where id = givers[k];
        end loop;
        update ix_grupos set sorteado = true, sorteado_at = now(), revelado = false where id = g.id;
        return json_build_object('ok', true,
          'sin_parejas', usar_rec or not p_evitar_parejas or n < 4,
          'sin_repetir', usar_rep or not p_evitar_repetir or array_length(rep_g,1) is null);
      end if;
    end loop;
  end loop;
  raise exception 'No se pudo hacer el sorteo con esas exclusiones. Quita alguna e intenta de nuevo.';
end $$;

create or replace function ix_admin_reiniciar(p_admin text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_mensajes m using ix_participantes p where m.giver_id = p.id and p.grupo_id = g.id;
  delete from ix_pistas s using ix_participantes p where s.giver_id = p.id and p.grupo_id = g.id;
  update ix_deseos d set comprado = false from ix_participantes p where d.participante_id = p.id and p.grupo_id = g.id;
  update ix_participantes set asignado_a = null, vio_at = null where grupo_id = g.id;
  update ix_grupos set sorteado = false, sorteado_at = null, revelado = false where id = g.id;
end $$;

create or replace function ix_admin_revelar(p_admin text, p_revelar boolean)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if not g.sorteado then raise exception 'Primero haz el sorteo'; end if;
  update ix_grupos set revelado = p_revelar where id = g.id;
end $$;

-- Pantalla de TV: solo cuando ya se revelaron los Santas
create or replace function ix_tv(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if not g.sorteado then raise exception 'Primero haz el sorteo'; end if;
  if not g.revelado then raise exception 'Activa «Revelar Santas» en el panel para usar la pantalla de TV'; end if;
  return json_build_object('nombre', g.nombre, 'tema', g.tema, 'pares', coalesce((
    select json_agg(json_build_object('de', a.nombre, 'para', b.nombre) order by random())
    from ix_participantes a join ix_participantes b on b.id = a.asignado_a
    where a.grupo_id = g.id), '[]'::json));
end $$;

create or replace function ix_admin_borrar_grupo(p_admin text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__principal(p_admin);
  delete from ix_grupos where id = g.id;
end $$;

-- Coorganizador: genera (o quita) un segundo link de panel
create or replace function ix_admin_coorg(p_admin text, p_activar boolean)
returns text language plpgsql security definer set search_path = public as $$
declare g ix_grupos; c text;
begin
  g := ix__principal(p_admin);
  c := case when p_activar then ix__secreto() else null end;
  update ix_grupos set coadmin_code = c where id = g.id;
  return c;
end $$;

-- Duplicar para otro año: misma gente (con links y códigos nuevos), mismas exclusiones
create or replace function ix_admin_duplicar(p_admin text, p_nombre text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos; ng ix_grupos;
begin
  g := ix__principal(p_admin);
  insert into ix_grupos(admin_code, nombre, monto, moneda, lugar, notas, tema, prev_grupo)
  values (ix__secreto(), left(coalesce(nullif(trim(p_nombre),''), g.nombre || ' (nuevo)'),80),
          g.monto, g.moneda, g.lugar, g.notas, g.tema, g.id)
  returning * into ng;
  insert into ix_participantes(grupo_id, nombre, telefono, token, pin, perfil, prev_id)
  select ng.id, p.nombre, p.telefono, ix__secreto(), ix__pin(), p.perfil, p.id
  from ix_participantes p where p.grupo_id = g.id order by p.created_at;
  insert into ix_exclusiones(grupo_id, a, b)
  select ng.id, least(na.id, nb.id), greatest(na.id, nb.id)
  from ix_exclusiones e
  join ix_participantes na on na.prev_id = e.a and na.grupo_id = ng.id
  join ix_participantes nb on nb.prev_id = e.b and nb.grupo_id = ng.id
  where e.grupo_id = g.id
  on conflict do nothing;
  return json_build_object('id', ng.id, 'admin_code', ng.admin_code);
end $$;

-- Cena: lo que se necesita llevar
create or replace function ix_admin_cena_agregar(p_admin text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe el platillo'; end if;
  if (select count(*) from ix_cena where grupo_id = g.id) >= 60 then raise exception 'Máximo 60 platillos'; end if;
  insert into ix_cena(grupo_id, texto) values (g.id, left(trim(p_texto),80));
end $$;

create or replace function ix_admin_cena_borrar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_cena where id = p_id and grupo_id = g.id;
end $$;

-- Mejoras para la app (solo el organizador principal)
create or replace function ix_mejora_agregar(p_admin text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__principal(p_admin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe la mejora'; end if;
  insert into ix_mejoras(grupo_id, texto) values (g.id, left(trim(p_texto),400));
end $$;

create or replace function ix_mejora_estado(p_admin text, p_id uuid, p_hecho boolean)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__principal(p_admin);
  update ix_mejoras set hecho = p_hecho where id = p_id and grupo_id = g.id;
end $$;

create or replace function ix_mejora_borrar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__principal(p_admin);
  delete from ix_mejoras where id = p_id and grupo_id = g.id;
end $$;

-- =====================================================================
--  FUNCIONES DEL PARTICIPANTE (link + PIN)
-- =====================================================================
create or replace function ix_entrar(p_token text, p_pin text)
returns json language plpgsql security definer set search_path = public as $$
declare me ix_participantes; g ix_grupos; amigo ix_participantes; santa ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  select * into g from ix_grupos where id = me.grupo_id;
  update ix_participantes set abrio_at = coalesce(abrio_at, now()),
         vio_at = case when asignado_a is not null then coalesce(vio_at, now()) else vio_at end
  where id = me.id;
  if me.asignado_a is not null then select * into amigo from ix_participantes where id = me.asignado_a; end if;
  select * into santa from ix_participantes where asignado_a = me.id limit 1;

  return json_build_object(
    'yo', json_build_object('id', me.id, 'nombre', me.nombre, 'perfil', me.perfil),
    'grupo', json_build_object('nombre', g.nombre, 'monto', g.monto, 'moneda', g.moneda, 'fecha', g.fecha,
             'lugar', g.lugar, 'notas', g.notas, 'sorteado', g.sorteado, 'revelado', g.revelado, 'tema', g.tema,
             'total', (select count(*) from ix_participantes where grupo_id = g.id)),
    'mis_deseos', coalesce((select json_agg(json_build_object('id', d.id, 'texto', d.texto, 'link', d.link,
                  'precio', d.precio, 'foto', d.foto, 'prioridad', d.prioridad) order by d.prioridad, d.created_at)
                  from ix_deseos d where d.participante_id = me.id), '[]'::json),
    'amigo', case when amigo.id is null then null else json_build_object(
              'nombre', amigo.nombre, 'perfil', amigo.perfil,
              'deseos', coalesce((select json_agg(json_build_object('id', d.id, 'texto', d.texto, 'link', d.link,
                        'precio', d.precio, 'foto', d.foto, 'prioridad', d.prioridad, 'comprado', d.comprado)
                        order by d.prioridad, d.created_at)
                        from ix_deseos d where d.participante_id = amigo.id), '[]'::json)) end,
    'chat_amigo', case when amigo.id is null then '[]'::json else coalesce((
              select json_agg(json_build_object('autor', m.autor, 'texto', m.texto, 'fecha', m.created_at) order by m.created_at)
              from ix_mensajes m where m.giver_id = me.id and m.receiver_id = amigo.id), '[]'::json) end,
    'chat_santa', case when santa.id is null then '[]'::json else coalesce((
              select json_agg(json_build_object('autor', m.autor, 'texto', m.texto, 'fecha', m.created_at) order by m.created_at)
              from ix_mensajes m where m.giver_id = santa.id and m.receiver_id = me.id), '[]'::json) end,
    'pistas_mias', case when amigo.id is null then '[]'::json else (
              select json_agg(json_build_object('n', s.n, 'texto', ps.texto, 'desbloquea', ix__desbloqueo(g.fecha, s.n)) order by s.n)
              from generate_series(1,3) s(n) left join ix_pistas ps on ps.giver_id = me.id and ps.n = s.n) end,
    'pistas_santa', case when santa.id is null then '[]'::json else coalesce((
              select json_agg(json_build_object('n', ps.n,
                     'texto', case when ix__desbloqueo(g.fecha, ps.n) is null or ix__desbloqueo(g.fecha, ps.n) <= now()
                                   then ps.texto else null end,
                     'desbloquea', ix__desbloqueo(g.fecha, ps.n)) order by ps.n)
              from ix_pistas ps where ps.giver_id = santa.id), '[]'::json) end,
    'cena', ix__cena(g.id),
    'santa_nombre', case when g.revelado and santa.id is not null then santa.nombre else null end
  );
end $$;

create or replace function ix_perfil(p_token text, p_pin text, p_perfil jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; clean jsonb := '{}'::jsonb; k text;
begin
  me := ix__yo(p_token, p_pin);
  foreach k in array array['talla','calzado','colores','gustos','evitar'] loop
    if coalesce(p_perfil->>k,'') <> '' then clean := clean || jsonb_build_object(k, left(p_perfil->>k, 200)); end if;
  end loop;
  update ix_participantes set perfil = clean, lista_at = now() where id = me.id;
end $$;

create or replace function ix_deseo_agregar(p_token text, p_pin text, p_texto text, p_link text, p_precio numeric,
                                            p_foto text default null, p_prioridad int default 2)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe qué te gustaría'; end if;
  if (select count(*) from ix_deseos where participante_id = me.id) >= 15 then
    raise exception 'Máximo 15 deseos'; end if;
  if p_foto is not null and (p_foto !~ '^data:image/(jpeg|png|webp);base64,' or length(p_foto) > 250000) then
    raise exception 'La foto no es válida o es muy pesada'; end if;
  insert into ix_deseos(participante_id, texto, link, precio, foto, prioridad)
  values (me.id, left(trim(p_texto),200),
          case when p_link ~* '^https?://' then left(p_link,500) else null end, p_precio,
          p_foto, case when p_prioridad = 1 then 1 else 2 end);
  update ix_participantes set lista_at = now() where id = me.id;
end $$;

create or replace function ix_deseo_prioridad(p_token text, p_pin text, p_id uuid, p_prioridad int)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  update ix_deseos set prioridad = case when p_prioridad = 1 then 1 else 2 end
  where id = p_id and participante_id = me.id;
end $$;

create or replace function ix_deseo_quitar(p_token text, p_pin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  delete from ix_deseos where id = p_id and participante_id = me.id;
end $$;

-- El que regala marca "ya lo compré" (la persona que lo pidió no lo ve)
create or replace function ix_deseo_comprado(p_token text, p_pin text, p_id uuid, p_comprado boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if me.asignado_a is null then raise exception 'Aún no hay sorteo'; end if;
  update ix_deseos set comprado = p_comprado where id = p_id and participante_id = me.asignado_a;
end $$;

-- p_hacia = 'amigo' (pregunta anónima a quien le regalo) o 'santa' (respuesta a quien me regala)
create or replace function ix_mensaje(p_token text, p_pin text, p_hacia text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; santa_id uuid;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe un mensaje'; end if;
  if p_hacia = 'amigo' then
    if me.asignado_a is null then raise exception 'Aún no hay sorteo'; end if;
    insert into ix_mensajes(giver_id, receiver_id, autor, texto) values (me.id, me.asignado_a, 'santa', left(trim(p_texto),400));
  elsif p_hacia = 'santa' then
    select id into santa_id from ix_participantes where asignado_a = me.id limit 1;
    if santa_id is null then raise exception 'Aún no hay sorteo'; end if;
    insert into ix_mensajes(giver_id, receiver_id, autor, texto) values (santa_id, me.id, 'amigo', left(trim(p_texto),400));
  else
    raise exception 'Destino inválido';
  end if;
end $$;

-- Pistas que el Santa le deja a su amigo secreto (texto vacío = borrar)
create or replace function ix_pista_guardar(p_token text, p_pin text, p_n int, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if me.asignado_a is null then raise exception 'Aún no hay sorteo'; end if;
  if p_n not between 1 and 3 then raise exception 'Pista inválida'; end if;
  if coalesce(trim(p_texto),'') = '' then
    delete from ix_pistas where giver_id = me.id and n = p_n;
  else
    insert into ix_pistas(giver_id, n, texto) values (me.id, p_n, left(trim(p_texto),200))
    on conflict (giver_id, n) do update set texto = excluded.texto, updated_at = now();
  end if;
end $$;

-- Cena: agregar lo que yo llevo / apartar o soltar un platillo
create or replace function ix_cena_agregar(p_token text, p_pin text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe qué vas a llevar'; end if;
  if (select count(*) from ix_cena where grupo_id = me.grupo_id) >= 60 then raise exception 'Máximo 60 platillos'; end if;
  insert into ix_cena(grupo_id, texto, participante_id) values (me.grupo_id, left(trim(p_texto),80), me.id);
end $$;

create or replace function ix_cena_tomar(p_token text, p_pin text, p_id uuid, p_tomar boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; c ix_cena;
begin
  me := ix__yo(p_token, p_pin);
  select * into c from ix_cena where id = p_id and grupo_id = me.grupo_id;
  if not found then raise exception 'Ese platillo ya no existe'; end if;
  if p_tomar then
    if c.participante_id is not null and c.participante_id <> me.id then raise exception 'Alguien más ya lo va a llevar'; end if;
    update ix_cena set participante_id = me.id where id = c.id;
  else
    if c.participante_id = me.id then update ix_cena set participante_id = null where id = c.id; end if;
  end if;
end $$;

-- ---------- PERMISOS: solo las funciones públicas se pueden llamar ----------
revoke execute on function ix__secreto(), ix__pin(), ix__grupo(text), ix__principal(text), ix__yo(text,text),
  ix__tema(text), ix__desbloqueo(timestamptz,int), ix__cena(uuid)
  from public, anon, authenticated;
do $$
declare f text;
begin
  foreach f in array array[
    'ix_crear_grupo(text,numeric,timestamptz,text,text,text)',
    'ix_admin_get(text)',
    'ix_admin_editar(text,text,numeric,timestamptz,text,text,text)',
    'ix_admin_agregar(text,text,text)',
    'ix_admin_editar_participante(text,uuid,text,text)',
    'ix_admin_quitar(text,uuid)',
    'ix_admin_exclusion(text,uuid,uuid,boolean)',
    'ix_sortear(text,boolean,boolean)',
    'ix_admin_reiniciar(text)',
    'ix_admin_revelar(text,boolean)',
    'ix_tv(text)',
    'ix_admin_borrar_grupo(text)',
    'ix_admin_coorg(text,boolean)',
    'ix_admin_duplicar(text,text)',
    'ix_admin_cena_agregar(text,text)',
    'ix_admin_cena_borrar(text,uuid)',
    'ix_mejora_agregar(text,text)',
    'ix_mejora_estado(text,uuid,boolean)',
    'ix_mejora_borrar(text,uuid)',
    'ix_entrar(text,text)',
    'ix_perfil(text,text,jsonb)',
    'ix_deseo_agregar(text,text,text,text,numeric,text,int)',
    'ix_deseo_prioridad(text,text,uuid,int)',
    'ix_deseo_quitar(text,text,uuid)',
    'ix_deseo_comprado(text,text,uuid,boolean)',
    'ix_mensaje(text,text,text,text)',
    'ix_pista_guardar(text,text,int,text)',
    'ix_cena_agregar(text,text,text)',
    'ix_cena_tomar(text,text,uuid,boolean)'
  ] loop
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
