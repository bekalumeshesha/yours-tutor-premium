// OPTIONAL: lets the admin "Post via bot" button send announcements to a Telegram channel.
// Deploy: supabase functions deploy telegram-notify
// Secrets: supabase secrets set TELEGRAM_BOT_TOKEN=xxxx TELEGRAM_CHAT_ID=@your_channel
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
function role(req: Request) {
  try { return JSON.parse(atob((req.headers.get('Authorization') || '').split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).role; } catch { return null; }
}
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (role(req) !== 'authenticated') return new Response('Forbidden', { status: 403, headers: cors });
  const { text } = await req.json();
  const r = await fetch(`https://api.telegram.org/bot${Deno.env.get('TELEGRAM_BOT_TOKEN')}/sendMessage`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: Deno.env.get('TELEGRAM_CHAT_ID'), text: String(text).slice(0, 4000) }) });
  return new Response(JSON.stringify({ ok: r.ok }), { status: r.ok ? 200 : 502, headers: { ...cors, 'Content-Type': 'application/json' } });
});
