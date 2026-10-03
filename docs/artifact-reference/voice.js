/* VOICE — a provider-independent voice agent.
   The app only talks to this interface; which provider sits behind it is a
   configuration choice. Voice is an INPUT MODALITY for the whole app (body
   selection, assessment, movement check, treatment, reassessment), not a chat
   screen. The voice agent never controls hardware: transcripts go to the app,
   which turns them into structured intents for the care engine + safety layer.

     VoiceAgent (interface)
       ├── MockVoiceAgent        ← now: typed / sample text stands in for speech
       ├── ElevenLabsVoiceAgent  ← later: streaming STT/TTS via OUR backend
       └── OtherVoiceAgent

   States: IDLE → LISTENING → THINKING → SPEAKING → IDLE (+ INTERRUPTED, ERROR) */
(function (root) {
  const STATES = Object.freeze({ IDLE: 'IDLE', LISTENING: 'LISTENING', THINKING: 'THINKING', SPEAKING: 'SPEAKING', INTERRUPTED: 'INTERRUPTED', ERROR: 'ERROR' });

  // The contract every provider implements.
  class VoiceAgent {
    constructor() { this.state = STATES.IDLE; this.handlers = {}; }
    on(evt, fn) { (this.handlers[evt] ||= []).push(fn); return this; }
    emit(evt, data) { (this.handlers[evt] || []).forEach(fn => fn(data)); }
    setState(s, detail) { if (this.state === s) return; this.state = s; this.emit('state', { state: s, detail }); }
    getState() { return this.state; }
    startListening() { throw new Error('not implemented'); }
    stopListening() { throw new Error('not implemented'); }
    transcribe(_audio) { throw new Error('not implemented'); }   // audio → text (provider-specific)
    speak(_text) { throw new Error('not implemented'); }
    interrupt() { throw new Error('not implemented'); }
  }

  // Prototype provider: no microphone, no audio. While LISTENING the app shows a
  // text field; whatever is submitted is treated as the transcript. speak()
  // animates the SPEAKING state for about as long as the line would take to say.
  class MockVoiceAgent extends VoiceAgent {
    constructor() { super(); this.speakTimer = 0; this.name = 'mock'; }
    startListening() {
      if (this.state === STATES.SPEAKING) this.interrupt();
      this.setState(STATES.LISTENING);
    }
    stopListening() { if (this.state === STATES.LISTENING) this.setState(STATES.IDLE); }
    // In the mock, "audio" is already text.
    transcribe(text) {
      const t = String(text || '').trim();
      if (!t) { this.setState(STATES.IDLE); return null; }
      this.emit('transcript', { text: t, final: true });
      this.setState(STATES.THINKING);
      return t;
    }
    // Simulate speech arriving word by word (used by "Try saying" samples).
    simulate(text, { wordMs = 170 } = {}) {
      this.startListening();
      const words = text.split(' '); let i = 0, acc = '';
      const iv = setInterval(() => {
        if (this.state !== STATES.LISTENING) return clearInterval(iv);
        acc += (i ? ' ' : '') + words[i++];
        this.emit('transcript', { text: acc, final: false });
        if (i >= words.length) { clearInterval(iv); setTimeout(() => this.transcribe(text), 400); }
      }, wordMs);
    }
    speak(text) {
      clearTimeout(this.speakTimer);
      this.emit('speak', { text });
      this.setState(STATES.SPEAKING);
      this.speakTimer = setTimeout(() => { if (this.state === STATES.SPEAKING) this.setState(STATES.IDLE); }, Math.min(2600, 500 + String(text).length * 30));
    }
    interrupt() {
      clearTimeout(this.speakTimer);
      this.setState(STATES.INTERRUPTED);
      setTimeout(() => { if (this.state === STATES.INTERRUPTED) this.setState(STATES.IDLE); }, 300);
    }
    fail(message) { this.setState(STATES.ERROR, message); setTimeout(() => this.setState(STATES.IDLE), 1500); }
  }

  // Placeholder only. A real provider must get a short-lived session token from
  // Lofer's backend; API keys never ship in the app or the web page.
  class ElevenLabsVoiceAgent extends VoiceAgent {
    constructor({ tokenEndpoint } = {}) { super(); this.tokenEndpoint = tokenEndpoint; this.name = 'elevenlabs'; }
    startListening() { this.setState(STATES.ERROR, 'ElevenLabs is not configured. Use a server-issued session token.'); }
  }

  const PROVIDERS = { mock: MockVoiceAgent, elevenlabs: ElevenLabsVoiceAgent };
  function create({ provider = 'mock', ...opts } = {}) { return new (PROVIDERS[provider] || MockVoiceAgent)(opts); }

  root.Lofer = root.Lofer || {};
  root.Lofer.Voice = { STATES, VoiceAgent, MockVoiceAgent, ElevenLabsVoiceAgent, create };
})(typeof window !== 'undefined' ? window : globalThis);
