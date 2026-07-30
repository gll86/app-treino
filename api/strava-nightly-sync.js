const admin = require('firebase-admin');

function getAdmin() {
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY)),
      databaseURL: process.env.FIREBASE_DATABASE_URL,
    });
  }
  return admin;
}

// Brasil não usa mais horário de verão desde 2019 — offset fixo UTC-3.
const BR_OFFSET_MS = -3 * 3600 * 1000;

function getYesterdayRangeBR() {
  const nowBR = new Date(Date.now() + BR_OFFSET_MS);
  const y = nowBR.getUTCFullYear(), m = nowBR.getUTCMonth(), d = nowBR.getUTCDate() - 1;
  return getRangeForDateBR(new Date(Date.UTC(y, m, d)).toISOString().slice(0, 10));
}

function getRangeForDateBR(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const startUTC = Date.UTC(y, m - 1, d) - BR_OFFSET_MS;
  const endUTC = startUTC + 24 * 3600 * 1000;
  return { after: Math.floor(startUTC / 1000), before: Math.floor(endUTC / 1000), dateStr };
}

async function refreshAccessToken(refreshToken) {
  const r = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.STRAVA_CLIENT_ID,
      client_secret: process.env.STRAVA_CLIENT_SECRET,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }),
  });
  return r.json();
}

module.exports = async (req, res) => {
  const authHeader = req.headers['authorization'] || '';
  if (process.env.CRON_SECRET && authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    res.status(401).json({ ok: false, error: 'unauthorized' });
    return;
  }

  const db = getAdmin().database();
  const { after, before, dateStr } = (req.query && req.query.date)
    ? getRangeForDateBR(req.query.date)
    : getYesterdayRangeBR();
  const results = [];

  try {
    const usersSnap = await db.ref('users').once('value');
    const users = usersSnap.val() || {};

    for (const uid of Object.keys(users)) {
      const auth = users[uid].strava_auth;
      if (!auth || !auth.refresh_token) continue;

      let tokenInfo = auth;
      const now = Math.floor(Date.now() / 1000);
      if (!auth.expires_at || auth.expires_at <= now + 60) {
        const refreshed = await refreshAccessToken(auth.refresh_token);
        if (!refreshed.access_token) { results.push({ uid, error: 'refresh failed', detail: refreshed }); continue; }
        tokenInfo = refreshed;
        await db.ref(`users/${uid}/strava_auth`).set(refreshed);
      }

      const actRes = await fetch(`https://www.strava.com/api/v3/athlete/activities?after=${after}&before=${before}&per_page=30`, {
        headers: { Authorization: `Bearer ${tokenInfo.access_token}` },
      });
      const activities = await actRes.json();
      if (!Array.isArray(activities)) { results.push({ uid, error: 'activities fetch failed', detail: activities }); continue; }

      const match = activities.find(a => a.type === 'WeightTraining' || a.sport_type === 'WeightTraining');
      if (!match) { results.push({ uid, found: false }); continue; }

      let calorias = null;
      try {
        const detailRes = await fetch(`https://www.strava.com/api/v3/activities/${match.id}`, {
          headers: { Authorization: `Bearer ${tokenInfo.access_token}` },
        });
        const detail = await detailRes.json();
        if (typeof detail.calories === 'number') calorias = Math.round(detail.calories);
      } catch {}

      await db.ref(`users/${uid}/sessoes/${dateStr}`).set({
        duracaoMin: Math.round((match.moving_time || match.elapsed_time || 0) / 60),
        fcMedia: match.average_heartrate ? Math.round(match.average_heartrate) : null,
        fcMax: match.max_heartrate ? Math.round(match.max_heartrate) : null,
        calorias,
        stravaId: match.id,
      });
      results.push({ uid, found: true, dateStr });
    }

    res.status(200).json({ ok: true, results });
  } catch (err) {
    res.status(500).json({ ok: false, error: String(err) });
  }
};
