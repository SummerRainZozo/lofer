// The Lofer backend as an http.Server, with the provider passed in (so tests can swap it).
import { createServer, type Server } from 'node:http';
import type { CareIntelligenceProvider } from './providers/CareIntelligenceProvider.ts';
import { careRoute } from './routes/care.ts';
import { healthRoute } from './routes/health.ts';
import { sendJson } from './routes/http.ts';

export function createApp(provider: CareIntelligenceProvider): Server {
  return createServer(async (req, res) => {
    try {
      const path = (req.url ?? '/').split('?')[0];
      if (req.method === 'GET' && path === '/api/health') return healthRoute(res, provider);
      if (req.method === 'POST' && path === '/api/care') return await careRoute(req, res, provider);
      sendJson(res, 404, { error: 'Not found' });
    } catch {
      sendJson(res, 500, { error: 'Internal error' });
    }
  });
}
