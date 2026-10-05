// Chooses the Care Intelligence provider from the environment (CARE_PROVIDER).
import type { CareIntelligenceProvider } from './CareIntelligenceProvider.ts';
import { MockCareIntelligenceProvider } from './mock/MockCareIntelligenceProvider.ts';

export function createProvider(name = process.env.CARE_PROVIDER ?? 'mock'): CareIntelligenceProvider {
  switch (name) {
    case 'mock':
      return new MockCareIntelligenceProvider();
    default:
      // Real providers come in the next phase, after explicit approval.
      throw new Error(`Care provider "${name}" isn't implemented yet. Use CARE_PROVIDER=mock.`);
  }
}
