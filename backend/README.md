# Lofer backend

Care Intelligence for the Lofer app, behind one endpoint: `POST /api/care`.

Two providers, chosen with `CARE_PROVIDER` in `backend/.env`:

- **openai**: an OpenAI model (default `gpt-5.4-mini`, reasoning effort `low`) through the Responses
  API with a strict JSON schema. Needs `OPENAI_API_KEY` in `backend/.env` (never in the app, never
  in Git). Requests are sent with `store: false`.
- **mock**: deterministic rules with the same structured output. No key, no cost; the tests use it.

## Run it

Needs Node 24 or newer (it runs the TypeScript files directly, with no build step).

```bash
cd backend
npm install        # first time only
npm start          # http://127.0.0.1:8787   (npm run dev restarts on file changes)
npm test           # backend tests (offline: the OpenAI provider is tested with a fake client)
npm run typecheck  # TypeScript check
npm run smoke      # one live call to the configured provider (a few cents with OpenAI)
```

The iOS app (Debug build) talks to `http://127.0.0.1:8787` by default and falls back to its
on-device understanding if the backend isn't running. To change that, open Xcode › Product ›
Scheme › Edit Scheme › Arguments: `-LoferIntelligence local` (on-device only) or
`-LoferBackendURL http://…`.

## Where things live

```
backend/
├── src/
│   ├── server.ts                      ← starts the server
│   ├── app.ts                         ← routes → handlers (the provider is passed in)
│   ├── routes/                        ← POST /api/care, GET /api/health, tiny HTTP helpers
│   ├── services/careService.ts        ← validate request → provider → validate response (+ timeout)
│   ├── schemas/care.ts                ← THE contract (zod); mirrors the Swift CareSchema.swift
│   ├── providers/
│   │   ├── CareIntelligenceProvider.ts ← the interface a real LLM provider will implement
│   │   ├── index.ts                   ← picks the provider (CARE_PROVIDER, only "mock" today)
│   │   ├── mock/                      ← MockCareIntelligenceProvider + its keyword extraction
│   │   ├── openai/                    ← OpenAICareIntelligenceProvider (Responses API, strict JSON schema)
│   │   └── llm/                       ← provider-neutral: the LLM output schema + prompt builder
│   └── prompts/care-intelligence.md   ← the LLM's core instructions (prompt.ts adds vocabulary + policy)
└── tests/                             ← provider scenarios + HTTP/validation/failure tests
```

## Rules the backend enforces

- Requests and responses are validated against `schemas/care.ts`. A response that doesn't match
  (missing fields, unknown fields, an unknown action) is **never** forwarded: the app gets a 502
  and uses its on-device fallback.
- The response schema has no fields for device commands, intensities, durations or diagnoses.
  A provider can only describe what it understood and **propose** a next step.
- The iOS app's deterministic `InvestigationEngine` and `SafetyValidator` decide what happens.
