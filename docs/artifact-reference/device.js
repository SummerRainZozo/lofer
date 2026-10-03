/* DEVICE LAYER — a simulated Lofer wearable.
   Accepts only commands sealed by the Safety layer. Later this file is replaced
   by a Bluetooth driver for the real patches; nothing above it changes. */
(function (root) {
  const { isSealed } = root.Lofer.Safety;
  const PATCHES = ['P1', 'P2', 'P3', 'P4'];

  const dev = {
    name: 'Lofer wearable', mode: 'simulated', connected: true, patches: PATCHES,
    run: null,                       // the active run, or null
    execute(cmd) {
      if (!isSealed(cmd)) throw new Error('Device refused a command that the safety layer did not validate.');
      const total = cmd.steps.reduce((a, s) => a + s.minutes * 60, 0);
      this.run = { cmd, t: 0, total, paused: false, level: null, region: cmd.region, active: patchSet(cmd.focus), log: [], lastLog: -10, skin: 32.4 };
      return this.run;
    },
    setIntensity(cmd) { if (!isSealed(cmd) || !this.run) return false; this.run.level = cmd.setIntensity; return true; },
    retarget(cmd) { if (!isSealed(cmd) || !this.run) return false; this.run.region = cmd.retarget; this.run.active = patchSet('shift'); return true; },
    pause() { if (this.run) this.run.paused = true; },
    resume() { if (this.run) this.run.paused = false; },
    stop() { const r = this.run; this.run = null; return r; },
    // Advance simulated time by dtSec and return the current readings.
    tick(dtSec, rnd = Math.random) {
      const r = this.run; if (!r) return null;
      if (!r.paused) r.t = Math.min(r.total, r.t + dtSec);
      let acc = 0, i = 0;
      for (; i < r.cmd.steps.length; i++) { acc += r.cmd.steps[i].minutes * 60; if (r.t < acc) break; }
      i = Math.min(i, r.cmd.steps.length - 1);
      const step = r.cmd.steps[i], level = r.level ?? step.intensity;
      const wave = Math.sin(2 * Math.PI * r.t / (step.modality === 'vibration' ? 4 : 12));
      const kpa = step.modality === 'heat' ? 4 + level : step.modality === 'ems' ? 6 : (8 + level * 8) * (1 + .2 * wave) + (rnd() - .5) * 2;
      r.skin += ((step.modality === 'heat' ? 34 + level * 1.2 : 32.6) - r.skin) * Math.min(1, dtSec / 60);
      const reading = { t: r.t, step: i, modality: step.modality, level, pressure: Math.max(1, kpa), skinTemp: r.skin, emsmA: step.modality === 'ems' ? 4 + level * 3 : 0, paused: r.paused, done: r.t >= r.total };
      if (r.t - r.lastLog >= 10) { r.log.push({ t: Math.round(r.t), modality: step.modality, level, pressure: +reading.pressure.toFixed(1), skinTemp: +r.skin.toFixed(1) }); r.lastLog = r.t; }
      return reading;
    }
  };
  // Which patches sit over the target (the interaction layer places them on the 3D body).
  function patchSet(focus) { return focus === 'shift' ? ['P2', 'P3', 'P4'] : ['P1', 'P2', 'P3']; }

  root.Lofer = root.Lofer || {};
  root.Lofer.Device = dev;
})(typeof window !== 'undefined' ? window : globalThis);
