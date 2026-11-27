// =====================================================================
//  Intercambio Navideño · Edge Function "push" · v3.0
//  Envía notificaciones al celular (Web Push estándar, sin librerías externas).
//  Pégala en Supabase > Edge Functions > Deploy a new function > Via Editor
//  con el nombre: push   — y DESACTIVA "Verify JWT" en sus ajustes.
//  Secretos necesarios (Edge Functions > Secrets): VAPID_PRIVATE_KEY, VAPID_SUBJECT, CRON_SECRET
// =====================================================================
// ===== Web Push estándar (RFC 8291 aes128gcm + VAPID RFC 8292) solo con Web Crypto =====
const enc = new TextEncoder();
const b64u = (buf) => { let s = ''; const b = new Uint8Array(buf); for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
const unb64u = (str) => { const s = atob(str.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((str.length + 3) % 4)); const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i); return b; };
const cat = (...arr) => { const n = arr.reduce((a, x) => a + x.length, 0); const o = new Uint8Array(n); let k = 0; for (const x of arr){ o.set(x, k); k += x.length; } return o; };
async function hmac(key, data){ const k = await crypto.subtle.importKey('raw', key, {name: 'HMAC', hash: 'SHA-256'}, false, ['sign']); return new Uint8Array(await crypto.subtle.sign('HMAC', k, data)); }
async function cifrar(sub, texto){
  const uaPub = unb64u(sub.keys.p256dh), auth = unb64u(sub.keys.auth);
  const as = await crypto.subtle.generateKey({name: 'ECDH', namedCurve: 'P-256'}, true, ['deriveBits']);
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', as.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPub, {name: 'ECDH', namedCurve: 'P-256'}, false, []);
  const secreto = new Uint8Array(await crypto.subtle.deriveBits({name: 'ECDH', public: uaKey}, as.privateKey, 256));
  const prkKey = await hmac(auth, secreto);
  const ikm = await hmac(prkKey, cat(enc.encode('WebPush: info\0'), uaPub, asPub, new Uint8Array([1])));
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, cat(enc.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, cat(enc.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
  const k = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv: nonce}, k, cat(enc.encode(texto), new Uint8Array([2]))));
  const rs = new Uint8Array([0, 0, 16, 0]);
  return cat(salt, rs, new Uint8Array([asPub.length]), asPub, ct);
}
async function vapid(endpoint, jwk, sujeto){
  const aud = new URL(endpoint).origin;
  const h = b64u(enc.encode(JSON.stringify({typ: 'JWT', alg: 'ES256'})));
  const c = b64u(enc.encode(JSON.stringify({aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: sujeto})));
  const key = await crypto.subtle.importKey('jwk', {kty: 'EC', crv: 'P-256', x: jwk.x, y: jwk.y, d: jwk.d, ext: true}, {name: 'ECDSA', namedCurve: 'P-256'}, false, ['sign']);
  const firma = await crypto.subtle.sign({name: 'ECDSA', hash: 'SHA-256'}, key, enc.encode(h + '.' + c));
  const pub = b64u(cat(new Uint8Array([4]), unb64u(jwk.x), unb64u(jwk.y)));
  return `vapid t=${h}.${c}.${b64u(firma)}, k=${pub}`;
}
async function enviar(sub, datos, jwk, sujeto){
  const body = await cifrar(sub, JSON.stringify(datos));
  return fetch(sub.endpoint, {method: 'POST', body, headers: {
    'Content-Encoding': 'aes128gcm', 'Content-Type': 'application/octet-stream', TTL: '86400', Urgency: 'high',
    Authorization: await vapid(sub.endpoint, jwk, sujeto)}});
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
const json = (d, status = 200) => new Response(JSON.stringify(d), {status, headers: {...CORS, 'Content-Type': 'application/json'}});
const URL_BASE = Deno.env.get('SUPABASE_URL');
const LLAVE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SECRET_KEY');
const cab = () => { const h = {apikey: LLAVE, 'Content-Type': 'application/json'}; if (LLAVE && LLAVE.startsWith('eyJ')) h.Authorization = 'Bearer ' + LLAVE; return h; };
async function rpc(fn, args){
  const r = await fetch(URL_BASE + '/rest/v1/rpc/' + fn, {method: 'POST', headers: cab(), body: JSON.stringify(args || {})});
  const t = await r.text(); let d = null; try{ d = t ? JSON.parse(t) : null; }catch(_){}
  if (!r.ok) throw new Error((d && d.message) || ('Error ' + r.status));
  return d;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  try{
    const jwk = JSON.parse(Deno.env.get('VAPID_PRIVATE_KEY') || 'null');
    if (!jwk || !jwk.d) return json({error: 'Falta el secreto VAPID_PRIVATE_KEY'}, 500);
    const sujeto = Deno.env.get('VAPID_SUBJECT') || 'https://github.com';
    const body = await req.json();
    let lista;
    if (body.tipo === 'cron'){
      if (!body.secreto || body.secreto !== Deno.env.get('CRON_SECRET')) return json({error: 'No autorizado'}, 401);
      lista = await rpc('ix_push_cron');
    } else {
      lista = await rpc('ix_push_destinos', {p: body});
    }
    lista = lista || [];
    const vistos = new Set();
    lista = lista.filter(d => { const k = d.id + '|' + d.titulo + '|' + d.cuerpo; if (vistos.has(k)) return false; vistos.add(k); return true; });
    let enviados = 0; const muertos = [];
    await Promise.all(lista.map(async (d) => {
      try{
        const r = await enviar(d.sub, {title: d.titulo, body: d.cuerpo, url: d.url}, jwk, sujeto);
        if (r.status === 404 || r.status === 410) muertos.push(d.id);
        else if (r.ok) enviados++;
      }catch(_){}
    }));
    if (muertos.length) await fetch(URL_BASE + '/rest/v1/ix_push?id=in.(' + muertos.join(',') + ')', {method: 'DELETE', headers: cab()});
    return json({enviados, total: lista.length, borrados: muertos.length});
  }catch(e){
    return json({error: (e && e.message) || String(e)}, 400);
  }
});
