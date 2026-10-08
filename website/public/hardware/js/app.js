/* Lofer hardware prototype · interaction logic */
(function(){
const D = window.LOFER_BOARD_DATA;
const LEGEND = [["#E24B4A","Switched battery"],["#B42318","Unswitched battery"],["#EF9F27","3.3 V"],["#5F5E5A","Ground"],["#2C2C2A","Star-ground returns"],["#378ADD","I²C SCL"],["#1D9E75","I²C SDA"],["#5DCAA5","Battery sense"],["#993C1D","Thermistor"],["#D85A30","Raw EMG"],["#7F77DD","Status lines"],["#D4537E","PWM"],["#8E1F55","Driver sleep"],["#BA7517","Heater current"],["#73726c","Motor"]];

const svg = document.getElementById('board');
const pb = document.getElementById('pb'), tabname = document.getElementById('tabname'), clearBtn = document.getElementById('clear');
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const el = (kind,id) => svg.querySelector(`.${kind}[data-id="${id}"]`);
const stripOf = h => h.replace(/[a-j]$/,'');
const holeDesc = h => { const s=stripOf(h), c=s.slice(1); return `col ${c} ${s[0]==='T'?'top':'bottom'}, hole ${h.slice(-1)}`; };

// strip groups (bridges merge strips)
const parent = {}; Object.keys(D.strips).forEach(s=>parent[s]=s);
const find = s => parent[s]===s ? s : (parent[s]=find(parent[s]));
Object.values(D.wires).forEach(w=>{ if(w.kind==='bridge') parent[find(stripOf(w.a[1]))]=find(stripOf(w.b[1])); });
const groupOf = s => Object.keys(D.strips).filter(x=>find(x)===find(s));
// members of every strip: {comp,pin,wire}
const members = {}; Object.keys(D.strips).forEach(s=>members[s]=[]);
Object.entries(D.wires).forEach(([id,w])=>{ if(w.kind==='bridge') return;
  [[w.a,w.b],[w.b,w.a]].forEach(([e,o])=>{ if(e[0]==='BB' && o[0]!=='BB') members[stripOf(e[1])].push({comp:o[0],pin:o[1],wire:id}); }); });
Object.entries(D.comps).forEach(([cid,c])=>Object.entries(c.holes).forEach(([p,h])=>members[stripOf(h)].push({comp:cid,pin:p,wire:null})));
const groupMembers = s => groupOf(s).flatMap(x=>members[x]);
const pinLabel = (cid,p) => (D.comps[cid] && D.comps[cid].pins[p]) || p;
const netName = s => D.strips[s].net;

function reset(){ svg.classList.remove('sel'); svg.querySelectorAll('.primary,.soft').forEach(n=>n.classList.remove('primary','soft')); }
function mark(kind,id,cls){ const n=el(kind,id); if(n && !n.classList.contains('primary')) { n.classList.remove('soft'); n.classList.add(cls); } }
function softStrip(s, spread){
  groupOf(s).forEach(x=>mark('strip',x,'soft'));
  if(spread || !D.strips[s].power) groupMembers(s).forEach(m=>{ mark('comp',m.comp,'soft'); if(m.wire) mark('wire',m.wire,'soft'); });
}
function endHTML(e, selfComp){
  if(e[0]==='BB'){
    const s=stripOf(e[1]); const others=groupMembers(s).filter(m=>m.comp!==selfComp);
    const list = others.length ? others.map(m=>`${esc(D.comps[m.comp].name)} <span class="pin">${esc(pinLabel(m.comp,m.pin))}</span>`).join(', ') : 'nothing else';
    return `<button type="button" data-go="strip:${s}">Breadboard, ${esc(holeDesc(e[1]))}</button><div>${esc(netName(s))}</div><small>Also on this net: ${list}</small>`;
  }
  return `<button type="button" data-go="comp:${e[0]}">${esc(D.comps[e[0]].name)}</button><div>Pin <span class="pin">${esc(pinLabel(e[0],e[1]))}</span></div>`;
}
function show(tab, body){ tabname.textContent=tab; pb.innerHTML=body; clearBtn.hidden = tab==='Overview'; }

function selectComp(id){
  reset(); svg.classList.add('sel'); el('comp',id).classList.add('primary');
  const c=D.comps[id]; const rows=[];
  Object.entries(D.wires).forEach(([wid,w])=>{
    let me=null, other=null;
    if(w.a[0]===id){me=w.a;other=w.b;} else if(w.b[0]===id){me=w.b;other=w.a;} else return;
    el('wire',wid).classList.add('primary');
    if(other[0]==='BB') softStrip(stripOf(other[1])); else mark('comp',other[0],'soft');
    const to = other[0]==='BB' ? `breadboard ${holeDesc(other[1])} · ${netName(stripOf(other[1]))}` : `${D.comps[other[0]].name} · ${pinLabel(other[0],other[1])}`;
    rows.push({pin:me[1], html:`<button class="row" type="button" data-go="wire:${wid}"><span class="sw" style="background:${w.color}"></span><span><span class="pin">${esc(pinLabel(id,me[1]))}</span> → <b>${esc(to)}</b><small>${esc(w.label)}</small></span></button>`});
  });
  Object.entries(c.holes).forEach(([p,h])=>{ const s=stripOf(h); softStrip(s);
    rows.push({pin:p, html:`<button class="row" type="button" data-go="strip:${s}"><span class="sw" style="background:var(--line)"></span><span><span class="pin">${esc(pinLabel(id,p))}</span> → <b>plugged into breadboard ${esc(holeDesc(h))}</b><small>${esc(netName(s))}</small></span></button>`}); });
  const order=Object.keys(c.pins); rows.sort((a,b)=>order.indexOf(a.pin)-order.indexOf(b.pin));
  const free=Object.keys(c.pins).filter(p=>!rows.some(r=>r.pin===p));
  show('Component', `<div class="kind">${esc(c.kind)}</div><h2>${esc(c.name)}</h2><p>${esc(c.purpose)}</p>
    <h3>Connections (${rows.length})</h3><div class="rows">${rows.map(r=>r.html).join('')}</div>
    ${free.length?`<p style="font-size:.84rem;color:var(--muted)">Unconnected: ${free.map(p=>`<span class="pin">${esc(pinLabel(id,p))}</span>`).join(' ')}</p>`:''}
    ${c.notes.length?`<h3>Build notes</h3><ul>${c.notes.map(n=>`<li>${esc(n)}</li>`).join('')}</ul>`:''}`);
}
function selectWire(id){
  reset(); svg.classList.add('sel'); el('wire',id).classList.add('primary'); const w=D.wires[id];
  [w.a,w.b].forEach(e=>{ if(e[0]==='BB') softStrip(stripOf(e[1]), false); else mark('comp',e[0],'soft'); });
  const kind = {wire:'Wire',lead:'Soldered lead',bridge:'Breadboard bridge'}[w.kind];
  show(kind, `<div class="kind">${kind}</div><h2>${esc(w.label)}</h2>
    <div class="ends"><div class="end"><div class="lab">End A</div>${endHTML(w.a,w.b[0])}</div><div class="end"><div class="lab">End B</div>${endHTML(w.b,w.a[0])}</div></div>
    ${w.note?`<p>${esc(w.note)}</p>`:''}`);
}
function selectStrip(s){
  reset(); svg.classList.add('sel'); groupOf(s).forEach(x=>el('strip',x).classList.add('primary')); softStrip(s,true);
  const g=groupOf(s), m=groupMembers(s);
  const cols=g.map(x=>`col ${x.slice(1)} ${x[0]==='T'?'top':'bottom'}`).join(', ');
  show('Breadboard net', `<div class="kind">Breadboard strip${g.length>1?'s':''} · ${esc(cols)}</div><h2>${esc(netName(s))}</h2>
    <p>${g.length>1?'These strips are joined by short bridge wires, so they form one net.':'One five-hole strip.'} ${m.length} connection${m.length===1?'':'s'} land here.</p>
    <div class="rows">${m.map(x=>`<button class="row" type="button" data-go="${x.wire?'wire:'+x.wire:'comp:'+x.comp}"><span class="sw" style="background:${x.wire?D.wires[x.wire].color:'var(--line)'}"></span><span><b>${esc(D.comps[x.comp].name)}</b> <span class="pin">${esc(pinLabel(x.comp,x.pin))}</span><small>${x.wire?'by wire':'plugged in directly'}</small></span></button>`).join('')}</div>`);
}
function overview(){
  reset();
  const item=(go,title,text)=>`<button class="fix ov" type="button" data-go="${go}"><span class="num">›</span><span><b>${esc(title)}</b><br>${esc(text)}</span></button>`;
  show('Overview', `<div class="kind">System overview</div><h2>Senses your muscles, soothes them with heat and deep-vibration massage</h2>
   <p>This bench rig is the hardware prototype of a Lofer tile. It senses muscle activity through skin electrodes, delivers heat and deep-vibration massage with built-in safety controls, and is built to connect to the Lofer app over Bluetooth.</p>
   <h3>How it fits together</h3><div class="fixes">
   ${item('comp:REG','Power','A protected LiPo with USB-C charging. A buck-boost regulator holds a clean 3.3 V from full charge to empty.')}
   ${item('comp:ESP','Brain','An ESP32-S3 runs the sensing, the heat and massage control, and the Bluetooth link. Fixed safety rules in its firmware decide what runs.')}
   ${item('comp:AD','Sensing','Muscle activity sampled at 1–2 kHz, skin temperature under the heater, battery level and room climate.')}
   ${item('comp:DRV','Heat and massage','A motor driver powers a 20 × 30 mm heater film and a coin vibration motor, switched silently at 20 kHz.')}
   </div>
   <h3>Built-in safety controls</h3><p style="margin-top:0">The heater has three independent safety controls, so no single failure can overheat your skin.</p><div class="fixes">
   ${item('comp:NTC','42 °C · firmware','A thermistor under the heater stops heating at 42 °C. A broken or shorted sensor also stops it.')}
   ${item('wire:w_slp','Driver sleep · second control path','The ESP32 can switch the whole driver off, even if a control pin is stuck.')}
   ${item('comp:TCO','45 °C · hardware','A thermostat in the heater circuit cuts power on its own, with no software involved.')}
   ${item('wire:w_lop','Skin contact','If the electrodes lose contact with your skin, heat and massage stop.')}
   </div>
   <h3>At a glance</h3><dl class="spec">
   <dt>Battery</dt><dd>3.7 V · 850 mAh LiPo, protected</dd>
   <dt>Heat</dt><dd>1–1.5 W, cut off at 42 °C and 45 °C</dd>
   <dt>Muscle sensing</dt><dd>1–2 kHz, 20–450 Hz band</dd>
   <dt>Wireless</dt><dd>Bluetooth LE 5</dd>
   <dt>Status</dt><dd>Prototype. Muscle-signal sensing is designed, not yet validated.</dd></dl>`);
}
function go(spec){ const [k,id]=spec.split(':'); if(k==='comp')selectComp(id); else if(k==='wire')selectWire(id); else if(k==='strip')selectStrip(id); }

svg.addEventListener('click', e=>{
  const n=e.target.closest('.comp,.wire,.strip');
  if(!n){ overview(); return; }
  if(n.classList.contains('comp')) selectComp(n.dataset.id);
  else if(n.classList.contains('wire')) selectWire(n.dataset.id);
  else selectStrip(n.dataset.id);
});
svg.addEventListener('keydown', e=>{ if(e.key==='Enter'||e.key===' '){ const n=e.target.closest('.comp,.wire,.strip'); if(n){ e.preventDefault(); n.dispatchEvent(new MouseEvent('click',{bubbles:true})); } } });
document.addEventListener('keydown', e=>{ if(e.key==='Escape') overview(); });
pb.addEventListener('click', e=>{ const b=e.target.closest('[data-go]'); if(b) go(b.dataset.go); });
clearBtn.addEventListener('click', overview);
document.getElementById('legend').innerHTML = LEGEND.map(([c,l])=>`<span><i style="background:${c}"></i>${esc(l)}</span>`).join('');
overview();
})();
