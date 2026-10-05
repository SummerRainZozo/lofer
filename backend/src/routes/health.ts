// GET /api/health: is the backend up, and which provider is answering?
import type { ServerResponse } from 'node:http';
import type { CareIntelligenceProvider } from '../providers/CareIntelligenceProvider.ts';
import { SCHEMA_VERSION } from '../schemas/care.ts';
import { sendJson } from './http.ts';

export function healthRoute(res: ServerResponse, provider: CareIntelligenceProvider) {
  sendJson(res, 200, { ok: true, provider: provider.name, schemaVersion: SCHEMA_VERSION });
}
