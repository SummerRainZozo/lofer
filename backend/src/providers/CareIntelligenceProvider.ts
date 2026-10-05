// The seam for Care Intelligence. Everything else (routes, validation, the iOS app)
// talks to this interface, so a real LLM provider can replace the mock without changing
// the investigation engine or the care flow.
//
//   CareIntelligenceProvider
//   ├── MockCareIntelligenceProvider   ← now: deterministic rules, realistic structured output
//   └── (next phase) an LLM provider   ← same input, same validated output
//
// A provider may: understand the user's words in context, extract structured facts, notice
// what's uncertain, suggest possible contributing patterns, PROPOSE a next step and phrase it.
// It may NOT: diagnose, claim a root cause, choose device settings, or override safety. The
// response schema has no fields for those, and the iOS app's deterministic engine and
// SafetyValidator decide what actually happens.
import type { CareRequest, CareIntelligenceResponse } from '../schemas/care.ts';

export interface CareIntelligenceProvider {
  /** Short id reported in responses ("mock", later e.g. "anthropic"). */
  readonly name: string;
  respond(request: CareRequest): Promise<CareIntelligenceResponse>;
}
