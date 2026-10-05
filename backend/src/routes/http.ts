// Small HTTP helpers (no framework needed for two routes).
import type { IncomingMessage, ServerResponse } from 'node:http';

const MAX_BODY_BYTES = 256 * 1024;

export function sendJson(res: ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

export async function readJson(req: IncomingMessage): Promise<{ ok: true; value: unknown } | { ok: false; status: number; error: string }> {
  let size = 0;
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    size += (chunk as Buffer).length;
    if (size > MAX_BODY_BYTES) return { ok: false, status: 413, error: 'Request too large' };
    chunks.push(chunk as Buffer);
  }
  try {
    return { ok: true, value: JSON.parse(Buffer.concat(chunks).toString('utf8')) };
  } catch {
    return { ok: false, status: 400, error: 'Body is not valid JSON' };
  }
}
