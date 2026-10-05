// POST /api/care: one Care Intelligence turn.
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { CareIntelligenceProvider } from '../providers/CareIntelligenceProvider.ts';
import { handleCareRequest } from '../services/careService.ts';
import { readJson, sendJson } from './http.ts';

export async function careRoute(req: IncomingMessage, res: ServerResponse, provider: CareIntelligenceProvider) {
  const body = await readJson(req);
  if (!body.ok) return sendJson(res, body.status, { error: body.error });
  const result = await handleCareRequest(body.value, provider);
  // One line per turn (no personal details: just the shape of the conversation).
  if (process.env.NODE_ENV !== 'test') {
    const input = (body.value as { latestUserInput?: { kind?: string }; turn?: number })?.latestUserInput?.kind ?? '?';
    const outcome = result.status === 200 ? result.body.recommendedNextAction.type : `error ${result.status}`;
    console.log(`[care] turn ${(body.value as { turn?: number })?.turn ?? '?'} ${input} → ${outcome}`);
  }
  sendJson(res, result.status, result.body);
}
