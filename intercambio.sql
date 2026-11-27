-- =====================================================================
--  INTERCAMBIO NAVIDEÑO  ·  v3.0  ·  Esquema para Supabase
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
alter table ix_grupos add column if not exists categorias jsonb not null default '[]'::jsonb;
alter table ix_grupos drop constraint if exists ix_grupos_tema_check;

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
alter table ix_participantes add column if not exists responsable_id uuid references ix_participantes(id) on delete set null;
alter table ix_participantes add column if not exists asistencia text check (asistencia in ('si','no','talvez'));
alter table ix_participantes add column if not exists asistencia_at timestamptz;
alter table ix_participantes add column if not exists pin_propio boolean not null default false;
alter table ix_participantes add column if not exists adivina uuid references ix_participantes(id) on delete set null;
alter table ix_participantes add column if not exists regalo_foto text;
alter table ix_participantes add column if not exists idioma text not null default 'es';
alter table ix_participantes add column if not exists categoria text;
alter table ix_participantes add column if not exists telefono2 text;
alter table ix_participantes add column if not exists es_pareja boolean not null default false;
alter table ix_participantes add column if not exists avatar text;
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
alter table ix_deseos add column if not exists grupal boolean not null default false;
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
alter table ix_mensajes add column if not exists audio text;
alter table ix_mensajes add column if not exists efecto text;

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

create table if not exists ix_adviento (
  participante_id uuid not null references ix_participantes(id) on delete cascade,
  dia        smallint not null check (dia between 1 and 24),
  correcta   boolean not null,
  created_at timestamptz not null default now(),
  primary key (participante_id, dia)
);

create table if not exists ix_fotos (
  id              uuid primary key default gen_random_uuid(),
  grupo_id        uuid not null references ix_grupos(id) on delete cascade,
  participante_id uuid references ix_participantes(id) on delete set null,
  foto            text not null,
  texto           text,
  created_at      timestamptz not null default now()
);
create index if not exists ix_fotos_grupo on ix_fotos(grupo_id, created_at);

create table if not exists ix_trivia (
  id         uuid primary key default gen_random_uuid(),
  grupo_id   uuid not null references ix_grupos(id) on delete cascade,
  pregunta   text not null,
  opciones   jsonb not null,
  correcta   smallint not null,
  created_at timestamptz not null default now()
);

create table if not exists ix_coop (
  id         uuid primary key default gen_random_uuid(),
  grupo_id   uuid not null references ix_grupos(id) on delete cascade,
  concepto   text not null,
  monto      numeric(10,2) not null,
  created_at timestamptz not null default now()
);
create table if not exists ix_coop_pagos (
  coop_id         uuid not null references ix_coop(id) on delete cascade,
  participante_id uuid not null references ix_participantes(id) on delete cascade,
  pagado          numeric(10,2) not null,
  updated_at      timestamptz not null default now(),
  primary key (coop_id, participante_id)
);
create table if not exists ix_aportes (
  deseo_id        uuid not null references ix_deseos(id) on delete cascade,
  participante_id uuid not null references ix_participantes(id) on delete cascade,
  monto           numeric(10,2) not null,
  created_at      timestamptz not null default now(),
  primary key (deseo_id, participante_id)
);
create table if not exists ix_push (
  id              uuid primary key default gen_random_uuid(),
  grupo_id        uuid not null references ix_grupos(id) on delete cascade,
  participante_id uuid references ix_participantes(id) on delete cascade,
  es_admin        boolean not null default false,
  endpoint        text not null unique,
  sub             jsonb not null,
  url             text,
  idioma          text not null default 'es',
  created_at      timestamptz not null default now()
);
create table if not exists ix_avisos (
  grupo_id   uuid not null references ix_grupos(id) on delete cascade,
  clave      text not null,
  created_at timestamptz not null default now(),
  primary key (grupo_id, clave)
);

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
alter table ix_adviento      enable row level security;
alter table ix_fotos         enable row level security;
alter table ix_trivia        enable row level security;
alter table ix_coop          enable row level security;
alter table ix_coop_pagos    enable row level security;
alter table ix_aportes       enable row level security;
alter table ix_push          enable row level security;
alter table ix_avisos        enable row level security;
revoke all on ix_grupos, ix_participantes, ix_exclusiones, ix_deseos, ix_mensajes,
              ix_pistas, ix_cena, ix_mejoras, ix_adviento, ix_fotos, ix_trivia,
              ix_coop, ix_coop_pagos, ix_aportes, ix_push, ix_avisos from anon, authenticated;

-- Funciones de la v1 que cambiaron de parámetros
drop function if exists ix_crear_grupo(text,numeric,timestamptz,text,text);
drop function if exists ix_admin_editar(text,text,numeric,timestamptz,text,text);
drop function if exists ix_sortear(text,boolean);
drop function if exists ix_deseo_agregar(text,text,text,text,numeric);
drop function if exists ix_admin_agregar(text,text,text);
drop function if exists ix_admin_editar_participante(text,uuid,text,text);
drop function if exists ix_admin_agregar(text,text,text,uuid);
drop function if exists ix_admin_editar_participante(text,uuid,text,text,uuid);
drop function if exists ix_admin_alta(text,text,text,uuid);
drop function if exists ix_mensaje(text,text,text,text);
drop function if exists ix_deseo_agregar(text,text,text,text,numeric,text,int);

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
language sql immutable as $$ select case when t in ('trabajo','posada') then t else 'familia' end $$;

-- Cuándo se desbloquea cada pista: 1 ya, 2 una semana antes, 3 un día antes
create or replace function ix__desbloqueo(p_fecha timestamptz, p_n int) returns timestamptz
language sql immutable as $$
  select case when p_fecha is null or p_n = 1 then null
              when p_n = 2 then p_fecha - interval '7 days'
              else p_fecha - interval '1 day' end $$;

create or replace function ix__idioma(t text) returns text
language sql immutable as $$ select case when t = 'en' then 'en' else 'es' end $$;

-- Monto que le toca a una persona (por categoría o el general)
create or replace function ix__monto(p_grupo uuid, p_cat text) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select (c->>'monto')::numeric from ix_grupos g, jsonb_array_elements(g.categorias) c
                   where g.id = p_grupo and c->>'id' = p_cat limit 1),
                  (select monto from ix_grupos where id = p_grupo)) $$;

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
             'sorteado_at', g.sorteado_at, 'revelado', g.revelado, 'tema', g.tema, 'categorias', g.categorias,
             'tiene_anterior', exists(select 1 from ix_participantes where grupo_id = g.id and prev_id is not null)),
    'participantes', coalesce((
      select json_agg(json_build_object(
        'id', p.id, 'nombre', p.nombre, 'telefono', p.telefono, 'token', p.token,
        'telefono2', p.telefono2, 'es_pareja', p.es_pareja, 'categoria', p.categoria, 'idioma', p.idioma,
        'avatar', p.avatar, 'push', exists(select 1 from ix_push x where x.participante_id = p.id or x.participante_id in (select c.id from ix_participantes c where c.responsable_id = p.id)),
        'pin', case when p.pin_propio then null else p.pin end, 'pin_propio', p.pin_propio,
        'asistencia', p.asistencia, 'asistencia_at', p.asistencia_at, 'voto', p.adivina is not null,
        'abrio', p.abrio_at is not null, 'vio', p.vio_at is not null,
        'deseos', (select count(*) from ix_deseos d where d.participante_id = p.id),
        'perfil', p.perfil <> '{}'::jsonb, 'responsable_id', p.responsable_id)
        order by p.created_at)
      from ix_participantes p where p.grupo_id = g.id), '[]'::json),
    'exclusiones', coalesce((
      select json_agg(json_build_object('a', e.a, 'b', e.b))
      from ix_exclusiones e where e.grupo_id = g.id), '[]'::json),
    'cena', ix__cena(g.id),
    'trivia', coalesce((select json_agg(json_build_object('id', t.id, 'pregunta', t.pregunta, 'opciones', t.opciones, 'correcta', t.correcta) order by t.created_at)
              from ix_trivia t where t.grupo_id = g.id), '[]'::json),
    'fotos', (select count(*) from ix_fotos f where f.grupo_id = g.id),
    'coop', coalesce((select json_agg(json_build_object('id', c.id, 'concepto', c.concepto, 'monto', c.monto,
              'pagos', coalesce((select json_object_agg(pg.participante_id, pg.pagado) from ix_coop_pagos pg where pg.coop_id = c.id), '{}'::json))
              order by c.created_at) from ix_coop c where c.grupo_id = g.id), '[]'::json),
    'push_admin', exists(select 1 from ix_push x where x.grupo_id = g.id and x.es_admin),
    'avisos', coalesce((select json_agg(a.clave) from ix_avisos a where a.grupo_id = g.id), '[]'::json),
    'historial', exists(select 1 from ix_grupos h where h.id = g.prev_grupo),
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

-- Valida que el responsable sea alguien del mismo grupo que no tenga a su vez responsable
create or replace function ix__validar_resp(p_grupo uuid, p_id uuid, p_resp uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_resp is null then return; end if;
  if p_resp = p_id then raise exception 'Una persona no puede ser su propio responsable'; end if;
  if not exists (select 1 from ix_participantes where id = p_resp and grupo_id = p_grupo and responsable_id is null) then
    raise exception 'El responsable debe ser alguien del intercambio que use su propio celular'; end if;
  if p_id is not null and exists (select 1 from ix_participantes where responsable_id = p_id) then
    raise exception 'Esta persona ya administra a alguien más; no puede estar a cargo de otro'; end if;
end $$;

-- p_datos: {nombre, telefono, responsable, categoria, es_pareja, telefono2, idioma}
create or replace function ix__datos_ok(p_grupo uuid, p_datos jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_datos->>'nombre'),'') = '' then raise exception 'Escribe el nombre'; end if;
  if coalesce(p_datos->>'categoria','') <> '' and not exists (
       select 1 from ix_grupos g, jsonb_array_elements(g.categorias) c where g.id = p_grupo and c->>'id' = p_datos->>'categoria') then
    raise exception 'Categoría inválida'; end if;
end $$;

create or replace function ix_admin_agregar(p_admin text, p_datos jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare g ix_grupos; nid uuid; resp uuid := nullif(p_datos->>'responsable','')::uuid;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo. Usa «Cambios de último momento».'; end if;
  if (select count(*) from ix_participantes where grupo_id = g.id) >= 60 then raise exception 'Máximo 60 participantes'; end if;
  perform ix__datos_ok(g.id, p_datos);
  perform ix__validar_resp(g.id, null, resp);
  insert into ix_participantes(grupo_id, nombre, telefono, token, pin, responsable_id, categoria, es_pareja, telefono2, idioma)
  values (g.id, left(trim(p_datos->>'nombre'),60), nullif(regexp_replace(coalesce(p_datos->>'telefono',''),'\D','','g'),''),
          ix__secreto(), ix__pin(), resp, nullif(p_datos->>'categoria',''), coalesce((p_datos->>'es_pareja')::boolean,false),
          nullif(regexp_replace(coalesce(p_datos->>'telefono2',''),'\D','','g'),''), ix__idioma(p_datos->>'idioma'))
  returning id into nid;
  return nid;
end $$;

create or replace function ix_admin_editar_participante(p_admin text, p_id uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos; p ix_participantes; resp uuid := nullif(p_datos->>'responsable','')::uuid; cat text := nullif(p_datos->>'categoria','');
begin
  g := ix__grupo(p_admin);
  select * into p from ix_participantes where id = p_id and grupo_id = g.id;
  if not found then raise exception 'Participante no encontrado'; end if;
  perform ix__datos_ok(g.id, p_datos);
  if resp is distinct from p.responsable_id then
    perform ix__validar_resp(g.id, p_id, resp);
    if g.sorteado and resp is not null and exists (
         select 1 from ix_participantes x where x.grupo_id = g.id and
         ((x.id = p_id and x.asignado_a = resp) or (x.id = resp and x.asignado_a = p_id))) then
      raise exception 'En el sorteo ya les tocó regalarse entre ellos. Reinicia el sorteo para asignar ese responsable.';
    end if;
  end if;
  if g.sorteado and cat is distinct from p.categoria then
    raise exception 'El sorteo ya se hizo: reinícialo para cambiar de categoría'; end if;
  update ix_participantes set nombre = left(trim(p_datos->>'nombre'),60),
         telefono = nullif(regexp_replace(coalesce(p_datos->>'telefono',''),'\D','','g'),''),
         telefono2 = nullif(regexp_replace(coalesce(p_datos->>'telefono2',''),'\D','','g'),''),
         es_pareja = coalesce((p_datos->>'es_pareja')::boolean, false),
         idioma = ix__idioma(p_datos->>'idioma'),
         responsable_id = resp, categoria = cat
  where id = p_id;
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
  rep_g uuid[]; rep_r uuid[]; cat record; listo boolean;
  n int; i int; k int; intento int; pick uuid; ok boolean; modo int;
  usar_rec boolean; usar_rep boolean; peor_rec boolean := false; peor_rep boolean := false;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo'; end if;
  if (select count(*) from ix_participantes where grupo_id = g.id) < 3 then raise exception 'Se necesitan al menos 3 participantes'; end if;
  for cat in select coalesce(categoria,'') as c, count(*) as total from ix_participantes where grupo_id = g.id group by 1 loop
    if cat.total < 2 then raise exception 'La categoría «%» necesita al menos 2 personas', coalesce(nullif(cat.c,''),'general'); end if;
  end loop;
 for cat in select coalesce(categoria,'') as c from ix_participantes where grupo_id = g.id group by 1 loop
  listo := false;
  select array_agg(id) into ids from ix_participantes where grupo_id = g.id and coalesce(categoria,'') = cat.c;
  n := coalesce(array_length(ids,1),0);

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
          and not exists (select 1 from ix_participantes rp
                          where (rp.id = givers[i] and rp.responsable_id = r) or (rp.id = r and rp.responsable_id = givers[i]))
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
        if p_evitar_parejas and n >= 4 and not usar_rec then peor_rec := true; end if;
        if p_evitar_repetir and array_length(rep_g,1) > 0 and not usar_rep then peor_rep := true; end if;
        listo := true; exit;
      end if;
    end loop;
    exit when listo;
  end loop;
  if not listo then
    raise exception 'No se pudo hacer el sorteo con esas exclusiones%. Quita alguna e intenta de nuevo.',
      case when cat.c <> '' then ' (categoría «' || cat.c || '»)' else '' end;
  end if;
 end loop;
  update ix_grupos set sorteado = true, sorteado_at = now(), revelado = false where id = g.id;
  return json_build_object('ok', true, 'sin_parejas', not peor_rec, 'sin_repetir', not peor_rep);
end $$;

create or replace function ix_admin_reiniciar(p_admin text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_mensajes m using ix_participantes p where m.giver_id = p.id and p.grupo_id = g.id;
  delete from ix_pistas s using ix_participantes p where s.giver_id = p.id and p.grupo_id = g.id;
  update ix_deseos d set comprado = false from ix_participantes p where d.participante_id = p.id and p.grupo_id = g.id;
  update ix_participantes set asignado_a = null, vio_at = null, adivina = null, regalo_foto = null where grupo_id = g.id;
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
    select json_agg(json_build_object('id', a.id, 'foto', a.regalo_foto is not null, 'de', a.nombre, 'para', b.nombre,
                    'av_de', a.avatar, 'av_para', b.avatar, 'voto', b.adivina is not null,
                    'atino', b.adivina = a.id, 'creia', (select c.nombre from ix_participantes c where c.id = b.adivina)) order by random())
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
  insert into ix_grupos(admin_code, nombre, monto, moneda, lugar, notas, tema, prev_grupo, categorias)
  values (ix__secreto(), left(coalesce(nullif(trim(p_nombre),''), g.nombre || ' (nuevo)'),80),
          g.monto, g.moneda, g.lugar, g.notas, g.tema, g.id, g.categorias)
  returning * into ng;
  insert into ix_participantes(grupo_id, nombre, telefono, token, pin, perfil, prev_id, categoria, idioma, telefono2, es_pareja, avatar)
  select ng.id, p.nombre, p.telefono, ix__secreto(), ix__pin(), p.perfil, p.id, p.categoria, p.idioma, p.telefono2, p.es_pareja, p.avatar
  from ix_participantes p where p.grupo_id = g.id order by p.created_at;
  update ix_participantes np set responsable_id = nr.id
  from ix_participantes op, ix_participantes nr
  where np.grupo_id = ng.id and op.id = np.prev_id and op.responsable_id is not null
    and nr.grupo_id = ng.id and nr.prev_id = op.responsable_id;
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
    'yo', json_build_object('id', me.id, 'nombre', me.nombre, 'perfil', me.perfil, 'asistencia', me.asistencia, 'pin_propio', me.pin_propio,
          'adivina', me.adivina, 'idioma', me.idioma, 'categoria', me.categoria, 'avatar', me.avatar, 'es_pareja', me.es_pareja,
          'monto', ix__monto(g.id, me.categoria)),
    'personas', coalesce((select json_agg(json_build_object('id', o.id, 'nombre', o.nombre) order by o.nombre)
          from ix_participantes o where o.grupo_id = me.grupo_id and o.id <> me.id), '[]'::json),
    'adivino', case when g.revelado and santa.id is not null and me.adivina is not null then me.adivina = santa.id else null end,
    'adviento', json_build_object(
          'mios', coalesce((select json_agg(json_build_object('dia', a.dia, 'correcta', a.correcta)) from ix_adviento a where a.participante_id = me.id), '[]'::json),
          'ranking', coalesce((select json_agg(x order by x.puntos desc, x.nombre) from (
               select p.nombre, count(*) filter (where a.correcta) as puntos
               from ix_adviento a join ix_participantes p on p.id = a.participante_id
               where p.grupo_id = me.grupo_id group by p.id, p.nombre having count(*) filter (where a.correcta) > 0
               order by 2 desc limit 10) x), '[]'::json)),
    'grupo', json_build_object('nombre', g.nombre, 'monto', ix__monto(g.id, me.categoria), 'moneda', g.moneda, 'fecha', g.fecha,
             'lugar', g.lugar, 'notas', g.notas, 'sorteado', g.sorteado, 'revelado', g.revelado, 'tema', g.tema,
             'total', (select count(*) from ix_participantes where grupo_id = g.id)),
    'mis_deseos', coalesce((select json_agg(json_build_object('id', d.id, 'texto', d.texto, 'link', d.link,
                  'precio', d.precio, 'foto', d.foto, 'prioridad', d.prioridad, 'grupal', d.grupal) order by d.prioridad, d.created_at)
                  from ix_deseos d where d.participante_id = me.id), '[]'::json),
    'amigo', case when amigo.id is null then null else json_build_object(
              'nombre', amigo.nombre, 'perfil', amigo.perfil, 'avatar', amigo.avatar, 'es_pareja', amigo.es_pareja,
              'deseos', coalesce((select json_agg(json_build_object('id', d.id, 'texto', d.texto, 'link', d.link,
                        'precio', d.precio, 'foto', d.foto, 'prioridad', d.prioridad, 'comprado', d.comprado, 'grupal', d.grupal)
                        order by d.prioridad, d.created_at)
                        from ix_deseos d where d.participante_id = amigo.id), '[]'::json)) end,
    'chat_amigo', case when amigo.id is null then '[]'::json else coalesce((
              select json_agg(json_build_object('id', m.id, 'autor', m.autor, 'texto', m.texto, 'fecha', m.created_at, 'audio', m.audio is not null) order by m.created_at)
              from ix_mensajes m where m.giver_id = me.id and m.receiver_id = amigo.id), '[]'::json) end,
    'chat_santa', case when santa.id is null then '[]'::json else coalesce((
              select json_agg(json_build_object('id', m.id, 'autor', m.autor, 'texto', m.texto, 'fecha', m.created_at, 'audio', m.audio is not null) order by m.created_at)
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
    'santa_nombre', case when g.revelado and santa.id is not null then santa.nombre else null end,
    'mi_regalo_foto', me.regalo_foto,
    'santa_avatar', case when g.revelado and santa.id is not null then santa.avatar else null end,
    'categorias', g.categorias,
    'coop', coalesce((select json_agg(json_build_object('id', c.id, 'concepto', c.concepto, 'monto', c.monto,
              'pagado', coalesce((select pg.pagado from ix_coop_pagos pg where pg.coop_id = c.id and pg.participante_id = me.id), 0),
              'total', (select coalesce(sum(pg.pagado),0) from ix_coop_pagos pg where pg.coop_id = c.id),
              'personas', (select count(*) from ix_participantes x where x.grupo_id = g.id)) order by c.created_at)
              from ix_coop c where c.grupo_id = g.id), '[]'::json),
    'grupales', coalesce((select json_agg(json_build_object('id', d.id, 'texto', d.texto, 'precio', d.precio, 'foto', d.foto, 'link', d.link,
              'para', o.nombre, 'mio', (select a.monto from ix_aportes a where a.deseo_id = d.id and a.participante_id = me.id),
              'aportes', coalesce((select json_agg(json_build_object('nombre', ap.nombre, 'monto', a.monto) order by a.created_at)
                         from ix_aportes a join ix_participantes ap on ap.id = a.participante_id where a.deseo_id = d.id), '[]'::json))
              order by d.created_at)
              from ix_deseos d join ix_participantes o on o.id = d.participante_id
              where d.grupal and o.grupo_id = g.id and o.id <> me.id), '[]'::json),
    'regalo_foto', case when g.revelado and santa.id is not null then santa.regalo_foto else null end,
    'fotos', (select count(*) from ix_fotos f where f.grupo_id = me.grupo_id),
    'a_cargo', coalesce((select json_agg(json_build_object('nombre', c.nombre, 'token', c.token, 'pin', c.pin) order by c.created_at)
              from ix_participantes c where c.responsable_id = me.id), '[]'::json),
    'responsable', (select r.nombre from ix_participantes r where r.id = me.responsable_id)
  );
end $$;

create or replace function ix_perfil(p_token text, p_pin text, p_perfil jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; clean jsonb := '{}'::jsonb; k text;
begin
  me := ix__yo(p_token, p_pin);
  foreach k in array array['talla','calzado','colores','gustos','evitar','yatengo'] loop
    if coalesce(p_perfil->>k,'') <> '' then clean := clean || jsonb_build_object(k, left(p_perfil->>k, 200)); end if;
  end loop;
  update ix_participantes set perfil = clean, lista_at = now() where id = me.id;
end $$;

create or replace function ix_deseo_agregar(p_token text, p_pin text, p_texto text, p_link text, p_precio numeric,
                                            p_foto text default null, p_prioridad int default 2, p_grupal boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(trim(p_texto),'') = '' then raise exception 'Escribe qué te gustaría'; end if;
  if (select count(*) from ix_deseos where participante_id = me.id) >= 15 then
    raise exception 'Máximo 15 deseos'; end if;
  if p_foto is not null and (p_foto !~ '^data:image/(jpeg|png|webp);base64,' or length(p_foto) > 250000) then
    raise exception 'La foto no es válida o es muy pesada'; end if;
  insert into ix_deseos(participante_id, texto, link, precio, foto, prioridad, grupal)
  values (me.id, left(trim(p_texto),200),
          case when p_link ~* '^https?://' then left(p_link,500) else null end, p_precio,
          p_foto, case when p_prioridad = 1 then 1 else 2 end, coalesce(p_grupal,false));
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
-- p_hacia = 'amigo' (a quien le regalo, anónimo) o 'santa' (a quien me regala). Puede llevar audio ya distorsionado.
create or replace function ix_mensaje(p_token text, p_pin text, p_hacia text, p_texto text,
                                      p_audio text default null, p_efecto text default null)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; santa_id uuid; t text := left(trim(coalesce(p_texto,'')),400);
begin
  me := ix__yo(p_token, p_pin);
  if t = '' and p_audio is null then raise exception 'Escribe un mensaje'; end if;
  if p_audio is not null and (p_audio !~ '^data:audio/(wav|x-wav|webm|mp4|mpeg|ogg)' or length(p_audio) > 400000) then
    raise exception 'El audio no es válido o es muy largo'; end if;
  if p_hacia = 'amigo' then
    if me.asignado_a is null then raise exception 'Aún no hay sorteo'; end if;
    insert into ix_mensajes(giver_id, receiver_id, autor, texto, audio, efecto) values (me.id, me.asignado_a, 'santa', t, p_audio, left(p_efecto,20));
  elsif p_hacia = 'santa' then
    select id into santa_id from ix_participantes where asignado_a = me.id limit 1;
    if santa_id is null then raise exception 'Aún no hay sorteo'; end if;
    insert into ix_mensajes(giver_id, receiver_id, autor, texto, audio, efecto) values (santa_id, me.id, 'amigo', t, p_audio, left(p_efecto,20));
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


-- =====================================================================
--  TANDA 1 (v2.2): asistencia, código propio y cambios de último momento
-- =====================================================================
create or replace function ix_asistencia(p_token text, p_pin text, p_valor text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if p_valor is not null and p_valor not in ('si','no','talvez') then raise exception 'Respuesta inválida'; end if;
  update ix_participantes set asistencia = p_valor, asistencia_at = now() where id = me.id;
end $$;

create or replace function ix_cambiar_pin(p_token text, p_pin text, p_nuevo text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(p_nuevo,'') !~ '^[0-9]{4}$' then raise exception 'El código debe ser de 4 números'; end if;
  if p_nuevo in ('0000','1111','1234','2222','3333','4444','5555','6666','7777','8888','9999','4321') then
    raise exception 'Ese código es muy fácil de adivinar, elige otro'; end if;
  update ix_participantes set pin = p_nuevo, pin_propio = true where id = me.id;
end $$;

create or replace function ix_admin_reset_pin(p_admin text, p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare g ix_grupos; nuevo text := ix__pin();
begin
  g := ix__grupo(p_admin);
  update ix_participantes set pin = nuevo, pin_propio = false where id = p_id and grupo_id = g.id;
  if not found then raise exception 'Participante no encontrado'; end if;
  return nuevo;
end $$;

-- ¿Puede "a" regalarle a "b"? (no a sí mismo, sin exclusión, sin relación responsable/a cargo)
drop function if exists ix__valido(uuid,uuid,uuid);
create or replace function ix__valido(p_grupo uuid, p_x uuid, p_y uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_x <> p_y
    and (select coalesce(categoria,'') from ix_participantes where id = p_x) = (select coalesce(categoria,'') from ix_participantes where id = p_y)
    and not exists (select 1 from ix_exclusiones e where e.grupo_id = p_grupo and e.a = least(p_x,p_y) and e.b = greatest(p_x,p_y))
    and not exists (select 1 from ix_participantes rp where (rp.id = p_x and rp.responsable_id = p_y) or (rp.id = p_y and rp.responsable_id = p_x)) $$;

-- Limpia lo que dependía de la asignación anterior de estas personas
create or replace function ix__reacomodo(p_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from ix_pistas where giver_id = any(p_ids);
  delete from ix_mensajes where giver_id = any(p_ids);
  update ix_deseos set comprado = false
   where participante_id in (select asignado_a from ix_participantes where id = any(p_ids));
  update ix_participantes set vio_at = null, regalo_foto = null where id = any(p_ids);
end $$;

-- Quitar a alguien DESPUÉS del sorteo sin rehacerlo todo
create or replace function ix_admin_baja(p_admin text, p_id uuid)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos; x ix_participantes; s uuid; r uuid; pa record; afect uuid[];
begin
  g := ix__grupo(p_admin);
  if not g.sorteado then raise exception 'Aún no hay sorteo: usa «Quitar» normal'; end if;
  select * into x from ix_participantes where id = p_id and grupo_id = g.id;
  if not found then raise exception 'Participante no encontrado'; end if;
  if exists (select 1 from ix_participantes where responsable_id = x.id) then
    raise exception '% maneja la cuenta de otra persona. Primero asígnale otro responsable (botón Editar).', x.nombre; end if;
  if (select count(*) from ix_participantes where grupo_id = g.id) <= 3 then
    raise exception 'Deben quedar al menos 3 personas'; end if;
  select id into s from ix_participantes where asignado_a = x.id and grupo_id = g.id;
  r := x.asignado_a;
  if s is null or r is null then
    delete from ix_participantes where id = x.id;
    return json_build_object('afectados', 0);
  end if;
  update ix_participantes set asignado_a = null where id = x.id;
  if ix__valido(g.id, s, r) then
    afect := array[s];
    perform ix__reacomodo(afect);
    update ix_participantes set asignado_a = r where id = s;
  else
    for pa in select id, asignado_a as t from ix_participantes
              where grupo_id = g.id and id not in (x.id, s) and asignado_a is not null and asignado_a <> x.id
              order by random() loop
      if ix__valido(g.id, s, pa.t) and ix__valido(g.id, pa.id, r) then
        afect := array[s, pa.id];
        perform ix__reacomodo(afect);
        update ix_participantes set asignado_a = pa.t where id = s;
        update ix_participantes set asignado_a = r where id = pa.id;
        exit;
      end if;
    end loop;
    if afect is null then raise exception 'No se pudo reacomodar con las exclusiones actuales. Quita alguna o reinicia el sorteo.'; end if;
  end if;
  delete from ix_participantes where id = x.id;
  return json_build_object('afectados', array_length(afect,1));
end $$;

-- Agregar a alguien DESPUÉS del sorteo: se mete en una cadena existente (A→T se vuelve A→nuevo→T)
create or replace function ix_admin_alta(p_admin text, p_datos jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos; n ix_participantes; pa record; ok boolean := false; resp uuid := nullif(p_datos->>'responsable','')::uuid;
begin
  g := ix__grupo(p_admin);
  if not g.sorteado then raise exception 'Aún no hay sorteo: usa «Agregar» normal'; end if;
  if (select count(*) from ix_participantes where grupo_id = g.id) >= 60 then raise exception 'Máximo 60 participantes'; end if;
  perform ix__datos_ok(g.id, p_datos);
  perform ix__validar_resp(g.id, null, resp);
  insert into ix_participantes(grupo_id, nombre, telefono, token, pin, responsable_id, categoria, es_pareja, telefono2, idioma)
  values (g.id, left(trim(p_datos->>'nombre'),60), nullif(regexp_replace(coalesce(p_datos->>'telefono',''),'\D','','g'),''),
          ix__secreto(), ix__pin(), resp, nullif(p_datos->>'categoria',''), coalesce((p_datos->>'es_pareja')::boolean,false),
          nullif(regexp_replace(coalesce(p_datos->>'telefono2',''),'\D','','g'),''), ix__idioma(p_datos->>'idioma'))
  returning * into n;
  for pa in select id, asignado_a as t from ix_participantes
            where grupo_id = g.id and id <> n.id and asignado_a is not null order by random() loop
    if ix__valido(g.id, pa.id, n.id) and ix__valido(g.id, n.id, pa.t) then
      perform ix__reacomodo(array[pa.id]);
      update ix_participantes set asignado_a = n.id where id = pa.id;
      update ix_participantes set asignado_a = pa.t where id = n.id;
      ok := true; exit;
    end if;
  end loop;
  if not ok then raise exception 'No se pudo acomodar a % con las exclusiones o categorías actuales', n.nombre; end if;
  return json_build_object('afectados', 1, 'id', n.id);
end $$;

-- =====================================================================
--  TANDA 2 (v2.3): adivina quién es tu Santa y calendario de adviento
-- =====================================================================
create or replace function ix_adivinar(p_token text, p_pin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes; g ix_grupos;
begin
  me := ix__yo(p_token, p_pin);
  select * into g from ix_grupos where id = me.grupo_id;
  if g.revelado then raise exception 'Los Santas ya se revelaron'; end if;
  if p_id is not null and (p_id = me.id or not exists (select 1 from ix_participantes where id = p_id and grupo_id = me.grupo_id)) then
    raise exception 'Elige a otra persona del intercambio'; end if;
  update ix_participantes set adivina = p_id where id = me.id;
end $$;

-- Guarda la respuesta de la trivia del día (cuenta solo el primer intento)
create or replace function ix_adviento(p_token text, p_pin text, p_dia int, p_correcta boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if p_dia not between 1 and 24 then raise exception 'Día inválido'; end if;
  insert into ix_adviento(participante_id, dia, correcta) values (me.id, p_dia, coalesce(p_correcta,false))
  on conflict do nothing;
end $$;


-- =====================================================================
--  TANDA 3 (v2.4): noche del intercambio — TV, trivia, álbum y foto del regalo
-- =====================================================================
create or replace function ix__foto_ok(p_foto text) returns void
language plpgsql immutable as $$
begin
  if p_foto is null or p_foto !~ '^data:image/(jpeg|png|webp);base64,' or length(p_foto) > 250000 then
    raise exception 'La foto no es válida o es muy pesada'; end if;
end $$;

-- Datos para el centro de la fiesta (no requiere revelar)
create or replace function ix_tv_info(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  return json_build_object('nombre', g.nombre, 'tema', g.tema, 'sorteado', g.sorteado, 'revelado', g.revelado,
    'personas', coalesce((select json_agg(json_build_object('nombre', p.nombre, 'asistencia', p.asistencia, 'avatar', p.avatar) order by p.created_at)
                from ix_participantes p where p.grupo_id = g.id), '[]'::json),
    'trivia', coalesce((select json_agg(json_build_object('pregunta', t.pregunta, 'opciones', t.opciones, 'correcta', t.correcta) order by t.created_at)
                from ix_trivia t where t.grupo_id = g.id), '[]'::json),
    'fotos', (select count(*) from ix_fotos f where f.grupo_id = g.id));
end $$;

create or replace function ix_tv_foto(p_admin text, p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if not g.revelado then raise exception 'Primero revela los Santas'; end if;
  return (select regalo_foto from ix_participantes where id = p_id and grupo_id = g.id);
end $$;

-- Trivia familiar (la escribe el organizador)
create or replace function ix_admin_trivia_agregar(p_admin text, p_pregunta text, p_opciones jsonb, p_correcta int)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos; n int;
begin
  g := ix__grupo(p_admin);
  if coalesce(trim(p_pregunta),'') = '' then raise exception 'Escribe la pregunta'; end if;
  if jsonb_typeof(p_opciones) <> 'array' then raise exception 'Opciones inválidas'; end if;
  n := jsonb_array_length(p_opciones);
  if n < 2 or n > 4 then raise exception 'Pon de 2 a 4 opciones'; end if;
  if p_correcta < 0 or p_correcta >= n then raise exception 'Marca la respuesta correcta'; end if;
  if (select count(*) from ix_trivia where grupo_id = g.id) >= 50 then raise exception 'Máximo 50 preguntas'; end if;
  insert into ix_trivia(grupo_id, pregunta, opciones, correcta)
  values (g.id, left(trim(p_pregunta),200), (select jsonb_agg(left(trim(x),80)) from jsonb_array_elements_text(p_opciones) x), p_correcta);
end $$;

create or replace function ix_admin_trivia_borrar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_trivia where id = p_id and grupo_id = g.id;
end $$;

-- Foto del regalo que compró el Santa (se ve hasta la revelación)
create or replace function ix_regalo_foto(p_token text, p_pin text, p_foto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if me.asignado_a is null then raise exception 'Aún no hay sorteo'; end if;
  if p_foto is not null then perform ix__foto_ok(p_foto); end if;
  update ix_participantes set regalo_foto = p_foto where id = me.id;
end $$;

-- Álbum del intercambio
create or replace function ix_album(p_token text, p_pin text)
returns json language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  return coalesce((select json_agg(x order by x.fecha desc) from (
    select f.id, f.foto, f.texto, f.created_at as fecha, p.nombre as autor, f.participante_id = me.id as mia
    from ix_fotos f left join ix_participantes p on p.id = f.participante_id
    where f.grupo_id = me.grupo_id order by f.created_at desc limit 120) x), '[]'::json);
end $$;

create or replace function ix_foto_subir(p_token text, p_pin text, p_foto text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  perform ix__foto_ok(p_foto);
  if (select count(*) from ix_fotos where participante_id = me.id) >= 15 then raise exception 'Máximo 15 fotos por persona'; end if;
  if (select count(*) from ix_fotos where grupo_id = me.grupo_id) >= 300 then raise exception 'El álbum está lleno (300 fotos)'; end if;
  insert into ix_fotos(grupo_id, participante_id, foto, texto) values (me.grupo_id, me.id, p_foto, nullif(left(trim(coalesce(p_texto,'')),120),''));
end $$;

create or replace function ix_foto_borrar(p_token text, p_pin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  delete from ix_fotos where id = p_id and participante_id = me.id;
end $$;

create or replace function ix_admin_album(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  return coalesce((select json_agg(x order by x.fecha) from (
    select f.id, f.foto, f.texto, f.created_at as fecha, p.nombre as autor
    from ix_fotos f left join ix_participantes p on p.id = f.participante_id
    where f.grupo_id = g.id order by f.created_at desc limit 120) x), '[]'::json);
end $$;

create or replace function ix_admin_foto_borrar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_fotos where id = p_id and grupo_id = g.id;
end $$;


-- =====================================================================
--  v3.0: idioma, foto de perfil, categorías, parejas, cooperación, regalo grupal,
--        audios, historial, respaldo y notificaciones
-- =====================================================================
create or replace function ix_idioma(p_token text, p_pin text, p_idioma text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  update ix_participantes set idioma = ix__idioma(p_idioma) where id = me.id;
  update ix_push set idioma = ix__idioma(p_idioma) where participante_id = me.id;
end $$;

create or replace function ix_avatar(p_token text, p_pin text, p_foto text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if p_foto is not null then
    perform ix__foto_ok(p_foto);
    if length(p_foto) > 80000 then raise exception 'La foto de perfil es muy pesada'; end if;
  end if;
  update ix_participantes set avatar = p_foto where id = me.id;
end $$;

-- Categorías con su propio monto (ej. Adultos $500, Niños $300). Cada categoría se sortea por separado.
create or replace function ix_admin_categorias(p_admin text, p_categorias jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos; c jsonb; limpio jsonb := '[]'::jsonb; ids text[] := '{}';
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo: reinícialo para cambiar las categorías'; end if;
  if jsonb_typeof(p_categorias) <> 'array' or jsonb_array_length(p_categorias) > 6 then raise exception 'Máximo 6 categorías'; end if;
  for c in select * from jsonb_array_elements(p_categorias) loop
    if coalesce(trim(c->>'nombre'),'') = '' or coalesce(c->>'id','') = '' then raise exception 'Cada categoría necesita nombre'; end if;
    limpio := limpio || jsonb_build_array(jsonb_build_object('id', left(c->>'id',20), 'nombre', left(trim(c->>'nombre'),30),
                                                             'monto', nullif(c->>'monto','')::numeric));
    ids := ids || left(c->>'id',20);
  end loop;
  update ix_grupos set categorias = limpio where id = g.id;
  update ix_participantes set categoria = null where grupo_id = g.id and categoria is not null and not (categoria = any(ids));
end $$;

-- Unir a dos personas en una pareja (comparten link, dan y reciben un solo regalo)
create or replace function ix_admin_unir_pareja(p_admin text, p_a uuid, p_b uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos; pa ix_participantes; pb ix_participantes;
begin
  g := ix__grupo(p_admin);
  if g.sorteado then raise exception 'El sorteo ya se hizo: reinícialo para unir parejas'; end if;
  select * into pa from ix_participantes where id = p_a and grupo_id = g.id;
  select * into pb from ix_participantes where id = p_b and grupo_id = g.id;
  if pa.id is null or pb.id is null or pa.id = pb.id then raise exception 'Elige a dos personas distintas'; end if;
  if pa.es_pareja or pb.es_pareja then raise exception 'Alguno de los dos ya es pareja'; end if;
  if pa.responsable_id is not null or pb.responsable_id is not null then raise exception 'Una persona sin celular no puede unirse en pareja'; end if;
  update ix_participantes set nombre = left(pa.nombre || ' y ' || pb.nombre, 60), es_pareja = true,
         telefono2 = coalesce(pb.telefono, pb.telefono2), categoria = coalesce(pa.categoria, pb.categoria) where id = pa.id;
  update ix_deseos set participante_id = pa.id where participante_id = pb.id;
  update ix_participantes set responsable_id = pa.id where responsable_id = pb.id;
  delete from ix_exclusiones e where e.a = pb.id or e.b = pb.id;
  delete from ix_participantes where id = pb.id;
end $$;

-- Cooperación (cena, regalo grupal, renta del salón...)
create or replace function ix_admin_coop_crear(p_admin text, p_concepto text, p_monto numeric)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if coalesce(trim(p_concepto),'') = '' then raise exception 'Escribe el concepto'; end if;
  if coalesce(p_monto,0) <= 0 then raise exception 'Pon cuánto le toca a cada quien'; end if;
  if (select count(*) from ix_coop where grupo_id = g.id) >= 10 then raise exception 'Máximo 10 cooperaciones'; end if;
  insert into ix_coop(grupo_id, concepto, monto) values (g.id, left(trim(p_concepto),60), p_monto);
end $$;

create or replace function ix_admin_coop_borrar(p_admin text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  delete from ix_coop where id = p_id and grupo_id = g.id;
end $$;

create or replace function ix_admin_coop_pago(p_admin text, p_coop uuid, p_participante uuid, p_pagado numeric)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if not exists (select 1 from ix_coop where id = p_coop and grupo_id = g.id) or
     not exists (select 1 from ix_participantes where id = p_participante and grupo_id = g.id) then raise exception 'Datos inválidos'; end if;
  if coalesce(p_pagado,0) <= 0 then
    delete from ix_coop_pagos where coop_id = p_coop and participante_id = p_participante;
  else
    insert into ix_coop_pagos(coop_id, participante_id, pagado) values (p_coop, p_participante, p_pagado)
    on conflict (coop_id, participante_id) do update set pagado = excluded.pagado, updated_at = now();
  end if;
end $$;

-- Regalo grupal: el dueño lo marca; los demás se apuntan con una cantidad (el dueño no ve quién)
create or replace function ix_deseo_grupal(p_token text, p_pin text, p_id uuid, p_grupal boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  update ix_deseos set grupal = coalesce(p_grupal,false) where id = p_id and participante_id = me.id;
end $$;

create or replace function ix_aporte(p_token text, p_pin text, p_deseo uuid, p_monto numeric)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if not exists (select 1 from ix_deseos d join ix_participantes o on o.id = d.participante_id
                 where d.id = p_deseo and d.grupal and o.grupo_id = me.grupo_id and o.id <> me.id) then
    raise exception 'Ese regalo ya no está disponible para cooperar'; end if;
  if coalesce(p_monto,0) <= 0 then
    delete from ix_aportes where deseo_id = p_deseo and participante_id = me.id;
  else
    insert into ix_aportes(deseo_id, participante_id, monto) values (p_deseo, me.id, least(p_monto, 100000))
    on conflict (deseo_id, participante_id) do update set monto = excluded.monto;
  end if;
end $$;

-- Audio de un mensaje (solo para quien lo mandó o lo recibió)
create or replace function ix_audio(p_token text, p_pin text, p_id uuid)
returns json language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  return (select json_build_object('audio', m.audio, 'efecto', m.efecto) from ix_mensajes m
          where m.id = p_id and (m.giver_id = me.id or m.receiver_id = me.id
             or m.giver_id in (select id from ix_participantes where responsable_id = me.id)
             or m.receiver_id in (select id from ix_participantes where responsable_id = me.id)));
end $$;

-- Historial: intercambios anteriores (de donde se duplicó este) ya revelados
create or replace function ix_admin_historial(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  return coalesce((
    with recursive cadena as (
      select h.*, 1 as nivel from ix_grupos h where h.id = g.prev_grupo
      union all
      select h.*, c.nivel + 1 from ix_grupos h join cadena c on h.id = c.prev_grupo where c.nivel < 10
    )
    select json_agg(json_build_object('nombre', c.nombre, 'fecha', c.fecha, 'revelado', c.revelado,
      'pares', case when c.revelado then coalesce((select json_agg(json_build_object('de', a.nombre, 'para', b.nombre) order by a.nombre)
               from ix_participantes a join ix_participantes b on b.id = a.asignado_a where a.grupo_id = c.id), '[]'::json) else '[]'::json end)
      order by c.nivel)
    from cadena c), '[]'::json);
end $$;

-- Respaldo completo del intercambio (para guardar o restaurar en otra base de datos)
create or replace function ix_admin_respaldo(p_admin text)
returns json language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__principal(p_admin);
  return json_build_object('app', 'intercambio-navideno', 'version', 3, 'fecha_respaldo', now(),
    'grupo', (select to_jsonb(x) - 'id' - 'prev_grupo' - 'coadmin_code' from ix_grupos x where x.id = g.id),
    'participantes', coalesce((select json_agg((to_jsonb(p) - 'grupo_id') order by p.created_at) from ix_participantes p where p.grupo_id = g.id), '[]'::json),
    'exclusiones', coalesce((select json_agg(json_build_object('a', e.a, 'b', e.b)) from ix_exclusiones e where e.grupo_id = g.id), '[]'::json),
    'deseos', coalesce((select json_agg(to_jsonb(d)) from ix_deseos d join ix_participantes p on p.id = d.participante_id where p.grupo_id = g.id), '[]'::json),
    'cena', coalesce((select json_agg(to_jsonb(c) - 'grupo_id') from ix_cena c where c.grupo_id = g.id), '[]'::json),
    'trivia', coalesce((select json_agg(to_jsonb(t) - 'grupo_id' - 'id') from ix_trivia t where t.grupo_id = g.id), '[]'::json),
    'pistas', coalesce((select json_agg(to_jsonb(s)) from ix_pistas s join ix_participantes p on p.id = s.giver_id where p.grupo_id = g.id), '[]'::json),
    'coop', coalesce((select json_agg(json_build_object('concepto', c.concepto, 'monto', c.monto,
              'pagos', coalesce((select json_agg(json_build_object('p', pg.participante_id, 'pagado', pg.pagado)) from ix_coop_pagos pg where pg.coop_id = c.id), '[]'::json)))
              from ix_coop c where c.grupo_id = g.id), '[]'::json));
end $$;

-- Restaurar un respaldo (conserva links y códigos de todos)
create or replace function ix_restaurar(p_datos jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare g jsonb := p_datos->'grupo'; nid uuid; x jsonb; m jsonb := '{}'::jsonb; nuevo uuid; c jsonb; cid uuid; pg jsonb;
begin
  if coalesce(p_datos->>'app','') <> 'intercambio-navideno' or g is null then raise exception 'Ese archivo no es un respaldo de Intercambio Navideño'; end if;
  if exists (select 1 from ix_grupos where admin_code = g->>'admin_code') then
    raise exception 'Este intercambio ya existe en esta base de datos'; end if;
  if exists (select 1 from ix_participantes p, jsonb_array_elements(p_datos->'participantes') q where p.token = q->>'token') then
    raise exception 'Algunos participantes ya existen en esta base de datos'; end if;
  insert into ix_grupos(admin_code, nombre, monto, moneda, fecha, lugar, notas, sorteado, sorteado_at, revelado, tema, categorias)
  values (g->>'admin_code', g->>'nombre', nullif(g->>'monto','')::numeric, coalesce(g->>'moneda','MXN'), nullif(g->>'fecha','')::timestamptz,
          g->>'lugar', g->>'notas', coalesce((g->>'sorteado')::boolean,false), nullif(g->>'sorteado_at','')::timestamptz,
          coalesce((g->>'revelado')::boolean,false), ix__tema(g->>'tema'), coalesce(g->'categorias','[]'::jsonb))
  returning id into nid;
  for x in select * from jsonb_array_elements(p_datos->'participantes') loop
    insert into ix_participantes(grupo_id, nombre, telefono, token, pin, perfil, abrio_at, vio_at, lista_at, asistencia, asistencia_at,
                                 pin_propio, regalo_foto, idioma, categoria, telefono2, es_pareja, avatar, created_at)
    values (nid, x->>'nombre', x->>'telefono', x->>'token', x->>'pin', coalesce(x->'perfil','{}'::jsonb),
            nullif(x->>'abrio_at','')::timestamptz, nullif(x->>'vio_at','')::timestamptz, nullif(x->>'lista_at','')::timestamptz,
            x->>'asistencia', nullif(x->>'asistencia_at','')::timestamptz, coalesce((x->>'pin_propio')::boolean,false),
            x->>'regalo_foto', ix__idioma(x->>'idioma'), x->>'categoria', x->>'telefono2', coalesce((x->>'es_pareja')::boolean,false),
            x->>'avatar', coalesce(nullif(x->>'created_at','')::timestamptz, now()))
    returning id into nuevo;
    m := m || jsonb_build_object(x->>'id', nuevo);
  end loop;
  for x in select * from jsonb_array_elements(p_datos->'participantes') loop
    update ix_participantes set asignado_a = nullif(m->>(x->>'asignado_a'),'')::uuid,
           responsable_id = nullif(m->>(x->>'responsable_id'),'')::uuid, adivina = nullif(m->>(x->>'adivina'),'')::uuid
    where id = (m->>(x->>'id'))::uuid;
  end loop;
  insert into ix_exclusiones(grupo_id, a, b)
  select nid, least((m->>(e->>'a'))::uuid, (m->>(e->>'b'))::uuid), greatest((m->>(e->>'a'))::uuid, (m->>(e->>'b'))::uuid)
  from jsonb_array_elements(coalesce(p_datos->'exclusiones','[]')) e where m ? (e->>'a') and m ? (e->>'b') on conflict do nothing;
  insert into ix_deseos(participante_id, texto, link, precio, comprado, foto, prioridad, grupal, created_at)
  select (m->>(d->>'participante_id'))::uuid, d->>'texto', d->>'link', nullif(d->>'precio','')::numeric, coalesce((d->>'comprado')::boolean,false),
         d->>'foto', coalesce((d->>'prioridad')::smallint,2), coalesce((d->>'grupal')::boolean,false), coalesce(nullif(d->>'created_at','')::timestamptz, now())
  from jsonb_array_elements(coalesce(p_datos->'deseos','[]')) d where m ? (d->>'participante_id');
  insert into ix_cena(grupo_id, texto, participante_id)
  select nid, c2->>'texto', nullif(m->>(c2->>'participante_id'),'')::uuid from jsonb_array_elements(coalesce(p_datos->'cena','[]')) c2;
  insert into ix_trivia(grupo_id, pregunta, opciones, correcta)
  select nid, t->>'pregunta', t->'opciones', (t->>'correcta')::smallint from jsonb_array_elements(coalesce(p_datos->'trivia','[]')) t;
  insert into ix_pistas(giver_id, n, texto)
  select (m->>(s->>'giver_id'))::uuid, (s->>'n')::smallint, s->>'texto' from jsonb_array_elements(coalesce(p_datos->'pistas','[]')) s where m ? (s->>'giver_id');
  for c in select * from jsonb_array_elements(coalesce(p_datos->'coop','[]')) loop
    insert into ix_coop(grupo_id, concepto, monto) values (nid, c->>'concepto', (c->>'monto')::numeric) returning id into cid;
    for pg in select * from jsonb_array_elements(coalesce(c->'pagos','[]')) loop
      if m ? (pg->>'p') then insert into ix_coop_pagos(coop_id, participante_id, pagado) values (cid, (m->>(pg->>'p'))::uuid, (pg->>'pagado')::numeric); end if;
    end loop;
  end loop;
  return json_build_object('admin_code', g->>'admin_code', 'nombre', g->>'nombre');
end $$;

-- ---------- NOTIFICACIONES (Web Push) ----------
create or replace function ix_push_guardar(p_token text, p_pin text, p_sub jsonb, p_url text)
returns void language plpgsql security definer set search_path = public as $$
declare me ix_participantes;
begin
  me := ix__yo(p_token, p_pin);
  if coalesce(p_sub->>'endpoint','') !~ '^https://' then raise exception 'Suscripción inválida'; end if;
  insert into ix_push(grupo_id, participante_id, endpoint, sub, url, idioma)
  values (me.grupo_id, me.id, p_sub->>'endpoint', p_sub, left(p_url,500), me.idioma)
  on conflict (endpoint) do update set participante_id = excluded.participante_id, grupo_id = excluded.grupo_id, es_admin = false,
     sub = excluded.sub, url = excluded.url, idioma = excluded.idioma;
end $$;

create or replace function ix_push_guardar_admin(p_admin text, p_sub jsonb, p_url text, p_idioma text)
returns void language plpgsql security definer set search_path = public as $$
declare g ix_grupos;
begin
  g := ix__grupo(p_admin);
  if coalesce(p_sub->>'endpoint','') !~ '^https://' then raise exception 'Suscripción inválida'; end if;
  insert into ix_push(grupo_id, participante_id, es_admin, endpoint, sub, url, idioma)
  values (g.id, null, true, p_sub->>'endpoint', p_sub, left(p_url,500), ix__idioma(p_idioma))
  on conflict (endpoint) do update set participante_id = null, grupo_id = excluded.grupo_id, es_admin = true,
     sub = excluded.sub, url = excluded.url, idioma = excluded.idioma;
end $$;

create or replace function ix_push_quitar(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from ix_push where endpoint = p_endpoint $$;

-- Destinatarios de una notificación (solo la Edge Function con la llave de servicio puede llamarla)
create or replace function ix_push_destinos(p jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare me ix_participantes; g ix_grupos; tipo text := p->>'tipo'; dest uuid[]; t_es text; t_en text; c_es text; c_en text; santa uuid;
begin
  if tipo = 'mensaje' then
    me := ix__yo(p->>'token', p->>'pin');
    if p->>'hacia' = 'amigo' then dest := array[me.asignado_a];
      t_es := '💬 Mensaje de tu Santa'; t_en := '💬 Message from your Santa';
      c_es := 'Tu Santa secreto te escribió. ¡Ábrelo!'; c_en := 'Your Secret Santa wrote to you. Open it!';
    else select id into santa from ix_participantes where asignado_a = me.id limit 1; dest := array[santa];
      t_es := '💬 Te respondió tu amigo secreto'; t_en := '💬 Your Secret Santa match replied';
      c_es := me.nombre || ' te contestó en el chat anónimo.'; c_en := me.nombre || ' replied in the anonymous chat.';
    end if;
    select * into g from ix_grupos where id = me.grupo_id;
  else
    g := ix__grupo(p->>'admin');
    if tipo = 'prueba' then
      return coalesce((select json_agg(json_build_object('id', x.id, 'sub', x.sub, 'url', x.url,
        'titulo', case when x.idioma = 'en' then '🔔 It works!' else '🔔 ¡Funciona!' end,
        'cuerpo', case when x.idioma = 'en' then 'Notifications are ready for ' else 'Las notificaciones ya están listas para ' end || g.nombre))
        from ix_push x where x.grupo_id = g.id and x.es_admin), '[]'::json);
    end if;
    select array_agg(id) into dest from ix_participantes where grupo_id = g.id
      and (tipo <> 'cambio' or (vio_at is null and asignado_a is not null));
    if tipo = 'sorteo' then t_es := '🎲 ¡Ya se hizo el sorteo!'; t_en := '🎲 The draw is done!';
      c_es := 'Entra a ver a quién te tocó en ' || g.nombre; c_en := 'See who you got in ' || g.nombre;
    elsif tipo = 'revelado' then t_es := '🎅 ¡Se revelaron los Santas!'; t_en := '🎅 Santas revealed!';
      c_es := 'Entra a ver quién fue tu Santa'; c_en := 'Find out who your Santa was';
    elsif tipo = 'cambio' then t_es := '🔄 Hubo un cambio'; t_en := '🔄 There was a change';
      c_es := 'Revisa a quién le regalas en ' || g.nombre; c_en := 'Check who you are giving to in ' || g.nombre;
    elsif tipo = 'aviso' then t_es := left(coalesce(p->>'titulo', g.nombre),80); t_en := left(coalesce(p->>'titulo_en', p->>'titulo', g.nombre),80);
      c_es := left(coalesce(p->>'texto',''),200); c_en := left(coalesce(p->>'texto_en', p->>'texto',''),200);
    else raise exception 'Tipo inválido'; end if;
  end if;
  return coalesce((select json_agg(json_build_object('id', x.id, 'sub', x.sub, 'url', x.url,
      'titulo', case when x.idioma = 'en' then t_en else t_es end,
      'cuerpo', case when pp.responsable_id is not null and x.participante_id = pp.responsable_id
                     then (case when x.idioma = 'en' then 'For ' else 'Para ' end) || pp.nombre || ': ' else '' end
                || case when x.idioma = 'en' then c_en else c_es end))
    from ix_participantes pp join ix_push x on (x.participante_id = pp.id or x.participante_id = pp.responsable_id)
    where pp.id = any(dest)), '[]'::json);
end $$;

-- Recordatorios automáticos por fecha (los llama la tarea programada una vez al día)
create or replace function ix_push_cron()
returns json language plpgsql security definer set search_path = public as $$
declare g record; dias int; hoy date := (now() at time zone 'America/Mexico_City')::date; salida jsonb := '[]'::jsonb;
        clave text; t_es text; t_en text; c_es text; c_en text; filtro text; r record; n int;
begin
  for g in select * from ix_grupos where fecha is not null and (fecha at time zone 'America/Mexico_City')::date >= hoy loop
    dias := (g.fecha at time zone 'America/Mexico_City')::date - hoy;
    clave := null; filtro := 'todos';
    if dias = 14 then clave := 'auto-lista'; filtro := 'sinlista'; t_es := '📝 ¿Ya llenaste tu lista?'; t_en := '📝 Did you fill in your wish list?';
      c_es := 'Faltan 2 semanas para ' || g.nombre || '. Tu Santa necesita ideas.'; c_en := '2 weeks to go for ' || g.nombre || '. Your Santa needs ideas.';
    elsif dias = 10 and g.sorteado then clave := 'auto-compra'; t_es := '🛍️ ¡Hora de comprar tu regalo!'; t_en := '🛍️ Time to buy your gift!';
      c_es := 'Faltan 10 días. Revisa la lista de tu amigo secreto.'; c_en := '10 days left. Check your match''s wish list.';
    elsif dias = 7 then clave := 'auto-asis'; filtro := 'sinasis'; t_es := '🙋 ¿Vas a ir?'; t_en := '🙋 Are you coming?';
      c_es := 'Confirma tu asistencia a ' || g.nombre; c_en := 'Please confirm you are coming to ' || g.nombre;
    elsif dias = 3 and exists (select 1 from ix_cena where grupo_id = g.id) then clave := 'auto-cena'; t_es := '🍽️ ¿Ya apartaste tu platillo?'; t_en := '🍽️ What dish are you bringing?';
      c_es := 'Faltan 3 días. Revisa quién lleva qué.'; c_en := '3 days left. Check who is bringing what.';
    elsif dias = 1 then clave := 'auto-manana'; t_es := '🎄 ¡Mañana es el intercambio!'; t_en := '🎄 The gift exchange is tomorrow!';
      c_es := 'No olvides tu regalo 🎁'; c_en := 'Don''t forget your gift 🎁';
    elsif dias = 0 then clave := 'auto-hoy'; t_es := '🎉 ¡Hoy es el intercambio!'; t_en := '🎉 Today is the gift exchange!';
      c_es := g.nombre || coalesce(' · ' || g.lugar, ''); c_en := g.nombre || coalesce(' · ' || g.lugar, '');
    end if;
    if clave is not null then
      insert into ix_avisos(grupo_id, clave) values (g.id, clave) on conflict do nothing;
      get diagnostics n = row_count;
      if n > 0 then
        salida := salida || coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'sub', x.sub, 'url', x.url,
            'titulo', case when x.idioma = 'en' then t_en else t_es end, 'cuerpo', case when x.idioma = 'en' then c_en else c_es end))
          from ix_participantes pp join ix_push x on (x.participante_id = pp.id or x.participante_id = pp.responsable_id)
          where pp.grupo_id = g.id
            and (filtro <> 'sinlista' or not exists (select 1 from ix_deseos d where d.participante_id = pp.id))
            and (filtro <> 'sinasis' or pp.asistencia is null)), '[]'::jsonb);
      end if;
    end if;
    -- pistas que se desbloquean hoy
    if g.sorteado and dias in (7, 1) then
      insert into ix_avisos(grupo_id, clave) values (g.id, 'auto-pista-' || dias) on conflict do nothing;
      get diagnostics n = row_count;
      if n > 0 then
        salida := salida || coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'sub', x.sub, 'url', x.url,
            'titulo', case when x.idioma = 'en' then '🔍 New clue unlocked' else '🔍 Se desbloqueó una pista' end,
            'cuerpo', case when x.idioma = 'en' then 'Your Santa left you a new clue.' else 'Tu Santa te dejó una pista nueva.' end))
          from ix_participantes rec join ix_participantes santa on santa.asignado_a = rec.id
          join ix_pistas ps on ps.giver_id = santa.id and ps.n = case when dias = 7 then 2 else 3 end
          join ix_push x on (x.participante_id = rec.id or x.participante_id = rec.responsable_id)
          where rec.grupo_id = g.id), '[]'::jsonb);
      end if;
    end if;
  end loop;
  return salida;
end $$;

-- ---------- PERMISOS: solo las funciones públicas se pueden llamar ----------
revoke execute on function ix__validar_resp(uuid,uuid,uuid), ix__valido(uuid,uuid,uuid), ix__reacomodo(uuid[]), ix__foto_ok(text),
  ix__idioma(text), ix__monto(uuid,text), ix__datos_ok(uuid,jsonb), ix_push_destinos(jsonb), ix_push_cron() from public, anon, authenticated;
grant execute on function ix_push_destinos(jsonb), ix_push_cron() to service_role;
grant select, delete on ix_push to service_role;
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
    'ix_admin_agregar(text,jsonb)',
    'ix_admin_editar_participante(text,uuid,jsonb)',
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
    'ix_deseo_agregar(text,text,text,text,numeric,text,int,boolean)',
    'ix_deseo_prioridad(text,text,uuid,int)',
    'ix_deseo_quitar(text,text,uuid)',
    'ix_deseo_comprado(text,text,uuid,boolean)',
    'ix_mensaje(text,text,text,text,text,text)',
    'ix_pista_guardar(text,text,int,text)',
    'ix_cena_agregar(text,text,text)',
    'ix_cena_tomar(text,text,uuid,boolean)',
    'ix_asistencia(text,text,text)',
    'ix_cambiar_pin(text,text,text)',
    'ix_admin_reset_pin(text,uuid)',
    'ix_admin_baja(text,uuid)',
    'ix_admin_alta(text,jsonb)',
    'ix_adivinar(text,text,uuid)',
    'ix_adviento(text,text,int,boolean)',
    'ix_tv_info(text)',
    'ix_tv_foto(text,uuid)',
    'ix_admin_trivia_agregar(text,text,jsonb,int)',
    'ix_admin_trivia_borrar(text,uuid)',
    'ix_regalo_foto(text,text,text)',
    'ix_album(text,text)',
    'ix_foto_subir(text,text,text,text)',
    'ix_foto_borrar(text,text,uuid)',
    'ix_admin_album(text)',
    'ix_admin_foto_borrar(text,uuid)',
    'ix_idioma(text,text,text)',
    'ix_avatar(text,text,text)',
    'ix_admin_categorias(text,jsonb)',
    'ix_admin_unir_pareja(text,uuid,uuid)',
    'ix_admin_coop_crear(text,text,numeric)',
    'ix_admin_coop_borrar(text,uuid)',
    'ix_admin_coop_pago(text,uuid,uuid,numeric)',
    'ix_deseo_grupal(text,text,uuid,boolean)',
    'ix_aporte(text,text,uuid,numeric)',
    'ix_audio(text,text,uuid)',
    'ix_admin_historial(text)',
    'ix_admin_respaldo(text)',
    'ix_restaurar(jsonb)',
    'ix_push_guardar(text,text,jsonb,text)',
    'ix_push_guardar_admin(text,jsonb,text,text)',
    'ix_push_quitar(text)'
  ] loop
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
