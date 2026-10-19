const $ = id => document.getElementById(id);
const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels = {can:'Can claim', conditional:'On assumption', open:'Not yet', cannot:'Cannot claim'};
const symbols = {can:'✓',conditional:'≈',open:'○',cannot:'×'};
const factLabels = {proved:'Verified by proof',checked:'Verified by checker',assumed:'Assumption',tested:'Tested, not verified',open:'Open',violated:'Violated'};
const kindLabels = {'spec-review':'Question review',implementation:'Implementation',estimand:'Contrast',numerical:'Numerics',provenance:'Study design',statistical:'Statistics',interpretation:'Interpretation',release:'Publication',dataflow:'Data flow'};
const routes = {
  lean:['Formal proof','State the fact precisely and prove it in Lean. The proof still depends on the stated specification and trusted base.'],
  'runtime-checker':['Verified checker','Use a proved checker on the actual analysis object. Its acceptance must be connected to the claim.'],
  refinement:['Implementation verification','Connect the numerical implementation to a precise contract. Test results alone do not close this gap.'],
  'human-ruling':['Human review','Ask the responsible scientist or data owner to review this fact. Record the ruling and its scope. A declaration is not itself a formal proof.'],
  empirical:['Scientific assessment','Gather evidence and assess the scientific assumption. Empirical support is not a formal proof of the assumption.']
};
const effortLabels = {hours:'Hours',days:'Days',weeks:'Weeks',months:'Months'};
const kindIcons = {
  dry:'<svg viewBox="0 0 20 20" aria-hidden="true"><rect x="2.5" y="3.5" width="15" height="10" rx="1"/><path d="M7 17.5h6M10 13.5v4M6 7l2 1.5L6 10M10 10h3"/></svg>',
  wet:'<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M7.5 2.5h5M8.5 2.5v5L4 16a1.2 1.2 0 0 0 1 1.5h10a1.2 1.2 0 0 0 1-1.5L11.5 7.5v-5M6 12.5h8"/></svg>'
};
const kindNames = {dry:'Dry experiment',wet:'Wet experiment'};
let filter = 'all', view = new URLSearchParams(location.search).get('view') === 'text' ? 'text' : 'circuits';
const groupTitles = {can:'Can claim',conditional:'On assumption',open:'Not yet',cannot:'Cannot claim'};
function groups() {
  const qs = trace.claims.filter(c => c.question === question);
  return [...Object.keys(groupTitles).map(st => [groupTitles[st], qs.filter(c => !c.latent && c.state === st)]), ['Overlooked directions', qs.filter(c => c.latent)]].filter(([,list]) => list.length);
}
function phrased(c) {
  if (c.state !== 'conditional') return c.text;
  return `Assuming ${c.premises.map(id => `“${obligation(id).text.replace(/[.]$/,'')}”`).join(' and ')}, ${c.text.charAt(0).toLowerCase() + c.text.slice(1)}`;
}
function textGroup(list) {
  return `<ul class="text-claims">${list.map(c => `<li>${lamp(c.state)}<div><button class="text-claim" data-inspect="${c.id}">${escape(phrased(c))}</button><small>${c.id} / ${escape(c.level)}${c.blockers.length ? ` / violated: ${c.blockers.join(', ')}` : ''}${c.gaps.length ? ` / gaps: ${c.gaps.join(', ')}` : ''}${c.premises.length ? ` / assumes: ${c.premises.join(', ')}` : ''}</small></div></li>`).join('')}</ul>`;
}
function factList() {
  const ids = [...new Set(trace.claims.filter(c => c.question === question).flatMap(c => c.needs))].filter(id => !['proved','checked'].includes(obligation(id).status));
  return `<h3 class="group-title">Facts to settle <span>${ids.length}</span></h3><ul class="text-facts">${ids.map(id => { const o = obligation(id), n = trace.experiments.filter(e => fills(e,o)).length; return `<li><button class="text-claim" data-inspect="${id}"><strong>${id}</strong> ${escape(o.text)}</button><small>${factLabels[o.status]} / ${routes[o.route][0]}${n ? ` / ${n} ${n === 1 ? 'experiment' : 'experiments'}` : ''}</small></li>`; }).join('')}</ul>`;
}
let trace, question = new URLSearchParams(location.search).get('question') || 'Q1', selection = 'O3', overrides = {}, busy = false;
if(!/^Q[1-4]$/.test(question)) question = 'Q1';
function selectQuestionFact() {
  const needs = trace.claims.find(c => c.question === question).needs;
  selection = needs.find(id => !['proved','checked'].includes(trace.obligations.find(o => o.id === id).status)) || needs[0];
}
function changeQuestion(id) {
  question = id;
  selectQuestionFact();
  const url = new URL(location.href);
  url.searchParams.set('question',id);
  history.replaceState(null,'',url);
  render();
}
function lamp(state) { return `<span class="lamp ${state}" aria-hidden="true">${symbols[state]}</span>`; }
function kindTag(e) { return `<span class="kind ${e.kind}">${kindIcons[e.kind]}${kindNames[e.kind]}</span>`; }
function obligation(id) { return trace.obligations.find(o => o.id === id); }
const strength = {violated:0,open:1,tested:1,assumed:2,checked:3,proved:3};
function fills(e, o) { return Object.hasOwn(e.success,o.id) && strength[e.success[o.id]] > strength[o.status]; }
function outcomeApplied(map) { const keys = Object.keys(map); return keys.length > 0 && keys.every(id => overrides[id] === map[id]); }
function applyOutcome(map) {
  const next = {...overrides};
  if (outcomeApplied(map)) Object.keys(map).forEach(id => delete next[id]);
  else Object.assign(next, map);
  evaluate(next);
}
function moveList(moves, empty) {
  return moves.length ? `<ul class="moves">${moves.map(m => `<li>${lamp(m.to)}<span><button class="fact-link inline" data-inspect="${m.claim}">${m.claim}</button>: ${labels[m.from]} to ${labels[m.to]}.${m.to === 'conditional' ? ` Rests on ${m.remaining.join(', ')}.` : m.to === 'open' ? ` Still needs ${m.remaining.join(', ')}.` : ''}</span></li>`).join('')}</ul>` : `<p>${empty}</p>`;
}
function factChanges(map, applied) {
  return `<ul>${Object.entries(map).map(([id,st]) => `<li>${id}: ${factLabels[obligation(id)[applied ? 'base_status' : 'status']]} to ${factLabels[st]}</li>`).join('')}</ul>`;
}
function experimentRow(e) {
  const impact = e.lights ? `Lights ${e.lights} ${e.lights === 1 ? 'lamp' : 'lamps'}` : e.clears ? `Clears ${e.clears} broken ${e.clears === 1 ? 'contact' : 'contacts'}` : 'No lamp on its own';
  return `<button class="experiment-row" data-inspect="${e.id}" aria-pressed="${selection === e.id}">${kindTag(e)}<span class="experiment-title">${escape(e.title)}</span><small>${e.id} / ${effortLabels[e.effort]} / fills ${Object.keys(e.success).join(', ')}${e.scope === 'new' ? ' / creates new data' : ''}</small><span class="impact${e.lights ? ' lit' : ''}">${e.applied ? 'Supposed successful' : impact}</span></button>`;
}
function hashOverrides() {
  const query = new URLSearchParams(location.hash.slice(1));
  return Object.fromEntries((query.get('whatif') || '').split(',').filter(Boolean).map(x => x.split(':')).filter(([id,status]) => /^O\d+$/.test(id) && ['proved','checked','assumed','tested','open','violated'].includes(status)));
}
function switchSVG(status) {
  const contacts = '<path d="M0 21H15M45 21H60"/><circle cx="16" cy="21" r="3"/><circle cx="44" cy="21" r="3"/>';
  const arm = status === 'violated' ? '<path d="M19 21L27 17M33 25L41 21M27 12L34 29M34 12L27 29"/>' : ['proved','checked'].includes(status) ? '<path d="M19 21H41"/>' : status === 'assumed' ? '<path stroke-dasharray="3 3" d="M19 21H41"/>' : '<path d="M19 19L40 7"/>';
  return `<svg viewBox="0 0 60 42" aria-hidden="true">${contacts}${arm}</svg>`;
}
function render() {
  $('study-summary').textContent = trace.analysis.summary;
  const count = Object.keys(overrides).length;
  $('scenario-text').innerHTML = count ? `<strong>What-if: ${count} ${count === 1 ? 'fact changed' : 'facts changed'}.</strong> Hypothetical only. No new evidence.` : 'Recorded evidence. No hypothetical changes.';
  document.querySelector('.scenario').classList.toggle('hypothetical', !!count);
  $('reset').disabled = !count || busy;
  $('overview').innerHTML = Object.entries(labels).map(([state,label]) => `<div class="stat">${lamp(state)}<b>${trace.counts[state]}</b><span>${label}</span></div>`).join('');
  const names = ['Tau and amyloid','Agreement across assays','Publication restrictions','Microglia identity'];
  $('questions').innerHTML = trace.questions.map((q,i) => `<button data-question="${q.id}" aria-current="${q.id === question}">${names[i]}<small>${trace.claims.filter(c => c.question === q.id).length} claims</small></button>`).join('');
  $('question-select').innerHTML = trace.questions.map((q,i) => `<option value="${q.id}" ${q.id === question ? 'selected' : ''}>${names[i]}</option>`).join('');
  const q = trace.questions.find(q => q.id === question);
  $('question-reference').textContent = `Scientific question ${q.id.slice(1)}`;
  $('question-title').textContent = q.text;
  const card = c => `<article class="circuit ${c.latent ? 'latent' : ''}"><button class="claim-head" data-inspect="${c.id}" aria-label="Inspect claim ${c.id}: ${escape(c.text)}">${lamp(c.state)}<span><span class="claim-meta">${c.id} / ${escape(c.level)}${c.latent ? ' / Overlooked direction' : ''}</span><h3>${escape(c.text)}</h3><span class="claim-state ${c.state}">${labels[c.state]}${c.premises.length ? `; ${c.premises.length} ${c.premises.length === 1 ? 'assumption' : 'assumptions'}` : ''}</span></span></button><div class="contacts" aria-label="Facts needed by ${c.id}">${c.needs.map(id => {
    const o = trace.obligations.find(o => o.id === id);
    return `<div class="contact"><button class="switch ${o.status}" data-toggle="${id}" aria-pressed="${Object.hasOwn(overrides,id)}" aria-label="${Object.hasOwn(overrides,id) ? 'Restore recorded status for' : 'Suppose verified:'} ${id}. ${escape(o.text)}" title="${escape(o.text)} — ${factLabels[o.status]}" ${busy ? 'disabled' : ''}>${switchSVG(o.status)}</button><button class="contact-label" data-inspect="${id}"><strong>${id}</strong><span>${escape(kindLabels[o.kind] || o.kind)}</span><span>${factLabels[o.status]}</span>${(n => n ? `<span class="exp-hint">${n} ${n === 1 ? 'experiment' : 'experiments'}</span>` : '')(trace.experiments.filter(e => fills(e,o)).length)}</button>${Object.hasOwn(overrides,id) ? '<span class="hyp-tag">What-if</span>' : ''}</div>`;
  }).join('')}<span class="terminal" aria-label="${c.id}: ${labels[c.state]}">${lamp(c.state)}<small>${c.id}</small></span></div></article>`;
  $('board-hint').textContent = view === 'text' ? 'Click a claim or fact to inspect it.' : 'Click a switch to suppose the fact verified. Click its reference to inspect the evidence.';
  document.querySelectorAll('[data-view]').forEach(b => b.setAttribute('aria-pressed', b.dataset.view === view));
  $('circuits').innerHTML = groups().map(([title,list]) => `<h3 class="group-title">${title} <span>${list.length}</span></h3>${view === 'text' ? textGroup(list) : list.map(card).join('')}`).join('') + (view === 'text' ? factList() : '');
  renderInspector();
  const shown = trace.experiments.filter(e => filter === 'all' || e.kind === filter);
  document.querySelectorAll('[data-filter]').forEach(b => b.setAttribute('aria-pressed', b.dataset.filter === filter));
  $('experiment-list').innerHTML = shown.map(experimentRow).join('');
  $('work-list').innerHTML = trace.work.slice(0,6).map(w => {
    const o = trace.obligations.find(o => o.id === w.id);
    return `<button class="work-item" data-inspect="${w.id}"><span class="work-count">${w.unlocks.length}</span><span>${escape(o.text)}<small>${w.id} / ${w.unlocks.length} claims made available / ${w.gates.length} depend on this</small></span></button>`;
  }).join('') + '<small>First six facts in the current ranking.</small>';
}
function renderInspector() {
  const o = trace.obligations.find(o => o.id === selection);
  const c = trace.claims.find(c => c.id === selection);
  const e = trace.experiments.find(e => e.id === selection);
  $('inspector').className = 'inspector';
  if (e) {
    const won = outcomeApplied(e.success), lost = outcomeApplied(e.failure);
    const gated = trace.claims.filter(c => Object.keys(e.success).some(id => c.needs.includes(id)) && !e.wins.some(m => m.claim === c.id));
    $('inspector').innerHTML = `<span class="reference">Suggested experiment ${e.id}</span>${kindTag(e)}<h2>${escape(e.title)}</h2><p class="effort">${effortLabels[e.effort]} of work. Needs: ${escape(e.needs)}.</p>${e.scope === 'new' ? '<p class="new-data">Creates new data. This prototype reuses the existing facts as stand-ins for the new data, so its what-if can appear to close gaps in the existing analysis. It cannot: the existing analysis keeps its gaps.</p>' : ''}<h3>Method</h3><p>${escape(e.method)}</p><h3>If it succeeds</h3>${factChanges(e.success, won)}${won ? '<p class="note">Supposed in the current what-if. The circuits show this outcome.</p>' : moveList(e.wins, 'No lamp changes on its own.')}${gated.length && !won ? `<p class="note">${gated.map(c => `${c.id} still needs ${c.needs.filter(id => !Object.hasOwn(e.success,id) && strength[obligation(id).status] < 3).join(', ') || 'its premises'}`).join('. ')}.</p>` : ''}<h3>If it fails</h3>${Object.keys(e.failure).length ? factChanges(e.failure, lost) + (lost ? '<p class="note">Supposed in the current what-if. The circuits show this outcome.</p>' : moveList(e.losses, 'No lamp changes.')) : '<p>No fact changes. The gap stays open.</p>'}<h3>Limits</h3><p>${escape(e.caveat)}</p><button class="action" data-outcome="success" data-experiment="${e.id}" ${busy || lost ? 'disabled' : ''}>${won ? 'Restore recorded facts' : 'Suppose it succeeds'}</button>${Object.keys(e.failure).length ? `<button class="action secondary" data-outcome="failure" data-experiment="${e.id}" ${busy || won ? 'disabled' : ''}>${lost ? 'Restore recorded facts' : 'Suppose it fails'}</button>` : ''}<p class="note">Success = the stated criteria are met. A fact becomes verified only through a proof or a proved checker on the actual data. An inconclusive result leaves the fact unchanged; failure = an established counterexample.</p><p class="note">This explores an outcome. It does not run the experiment. Suggestions in this prototype are hand-written examples.</p>`;
  } else if (o) {
    const route = routes[o.route] || ['Review needed','Define a verification route for this fact.'];
    const changed = Object.hasOwn(overrides,o.id);
    $('inspector').innerHTML = `<span class="reference">Selected fact ${o.id}</span><h2>What closes this switch?</h2><span class="status-label">${changed ? 'What-if: ' : ''}${factLabels[o.status]}</span><p class="fact">${escape(o.text)}</p><h3>Recorded evidence</h3><p>${escape(o.evidence)}</p>${changed ? `<p class="note">Recorded status: ${factLabels[o.base_status]}. The evidence has not changed.</p>` : ''}<h3>Verification route: ${route[0]}</h3><p>${route[1]}</p>${o.trusts ? `<h3>Trusted base</h3><ul>${o.trusts.map(t => `<li>${escape(t)}</li>`).join('')}</ul>` : ''}${['proved','checked'].includes(o.status) ? '' : (ex => `<h3>Experiments that fill this gap</h3>${ex.length ? ex.map(e => `<button class="fact-link exp-link" data-inspect="${e.id}">${kindTag(e)}${escape(e.title)} <small>(${effortLabels[e.effort]})</small></button>`).join('') : `<p>${o.route === 'human-ruling' ? 'No experiment fills this gap. It needs a ruling from the responsible scientist or data owner.' : 'No experiment is suggested for this gap.'}</p>`}`)(trace.experiments.filter(e => fills(e,o)))}<button class="action" data-toggle="${o.id}" ${busy ? 'disabled' : ''}>${changed ? 'Restore recorded fact' : 'Suppose this fact verified'}</button><p class="note">This explores a proof's consequence. It does not prove the fact.</p><h3>Claims that need this fact</h3>${trace.claims.filter(c => c.needs.includes(o.id)).map(c => `<button class="fact-link" data-inspect="${c.id}">${c.id}: ${escape(c.text)}</button>`).join('')}`;
  } else if(c) {
    $('inspector').innerHTML = `<span class="reference">Selected claim ${c.id}</span><h2>${labels[c.state]}</h2><p class="fact">${escape(c.text)}</p><h3>Why this lamp is ${c.state === 'can' ? 'lit' : c.state === 'conditional' ? 'conditional' : c.state === 'cannot' ? 'broken' : 'dark'}</h3><p>${c.blockers.length ? `A needed fact is violated: ${c.blockers.join(', ')}.` : c.gaps.length ? `Facts still need verification: ${c.gaps.join(', ')}.` : c.premises.length ? `The claim depends on declared assumptions: ${c.premises.join(', ')}.` : 'All needed facts have a proof or a verified-checker result in this example.'}</p>${c.premises.length && c.gaps.length ? `<p class="note">Also depends on assumptions: ${c.premises.join(', ')}.</p>` : ''}<h3>Inspect the supporting facts</h3>${c.needs.map(id => `<button class="fact-link" data-inspect="${id}">${id}: ${escape(trace.obligations.find(o => o.id === id).text)}</button>`).join('')}${c.plan ? (p => `<h3>Plan to light this lamp</h3>${p.experiments.length ? p.experiments.map(id => trace.experiments.find(e => e.id === id)).map(e => `<button class="fact-link exp-link" data-inspect="${e.id}">${kindTag(e)}${escape(e.title)} <small>(${effortLabels[e.effort]})</small></button>`).join('') : '<p>No suggested experiment raises these facts.</p>'}${p.uncovered.length ? `<p class="note">No experiment covers ${p.uncovered.join(', ')}. ${p.uncovered.map(id => obligation(id).route === 'human-ruling' ? `${id} needs a ruling` : `${id} needs a new approach`).join('. ')}.</p>` : ''}${p.experiments.length ? `<p>If every experiment in the plan succeeds: <strong class="${p.state}">${labels[p.state]}</strong>.</p><button class="action" data-plan="${c.id}" ${busy ? 'disabled' : ''}>Suppose the plan succeeds</button><p class="note">Each experiment is the cheapest suggestion for one fact.</p>` : ''}`)(c.plan) : ''}${c.latent ? '<h3>Overlooked direction</h3><p>This is a possible direction, not an established finding. Its dashed outline stays visible even if the hypothetical circuit lights.</p>' : ''}`;
  }
}
async function evaluate(next) {
  if(busy) return;
  busy = true;
  document.body.setAttribute('aria-busy','true');
  const focus = document.activeElement?.dataset.toggle;
  const fromInspector = document.activeElement?.classList.contains('action');
  const outcome = document.activeElement?.dataset.experiment || document.activeElement?.dataset.plan;
  try {
    const response = await fetch('/api/evaluate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({overrides:next})});
    if(!response.ok) throw new Error(`Evaluation failed (${response.status})`);
    trace = await response.json();
    overrides = trace.overrides;
    const hash = Object.entries(overrides).map(([id,status]) => `${id}:${status}`).join(',');
    history.replaceState(null,'',location.pathname + location.search + (hash ? `#whatif=${hash}` : ''));
    $('error').hidden = true;
  } catch(error) {
    $('error').textContent = 'The what-if could not be evaluated. Your previous view is unchanged. Try again.';
    $('error').hidden = false;
    console.error(error);
  } finally {
    busy = false;
    document.body.removeAttribute('aria-busy');
    render();
    if(!focus && outcome) $('inspector').focus({preventScroll:true});
    if(focus) document.querySelector(`${fromInspector ? ".action" : ".switch"}[data-toggle="${focus}"]`)?.focus({preventScroll:true});
  }
}
document.addEventListener('click', event => {
  const button = event.target.closest('button');
  if(!button) return;
  if(button.dataset.question) { changeQuestion(button.dataset.question); document.querySelector(`[data-question="${question}"]`)?.focus({preventScroll:true}); }
  if(button.dataset.inspect) { selection = button.dataset.inspect; renderInspector(); $('inspector').focus({preventScroll:true}); if(innerWidth <= 760) $('inspector').scrollIntoView({block:'start'}); }
  if(button.dataset.view) { view = button.dataset.view; const url = new URL(location.href); url.searchParams.set('view',view); history.replaceState(null,'',url); render(); }
  if(button.dataset.filter) { filter = button.dataset.filter; render(); }
  if(button.dataset.experiment) { const e = trace.experiments.find(e => e.id === button.dataset.experiment); selection = e.id; applyOutcome(button.dataset.outcome === 'success' ? e.success : e.failure); }
  if(button.dataset.plan) { const p = trace.claims.find(c => c.id === button.dataset.plan).plan; selection = button.dataset.plan; evaluate({...overrides, ...Object.assign({}, ...p.experiments.map(id => trace.experiments.find(e => e.id === id).success))}); }
  if(button.dataset.toggle) {
    const id = button.dataset.toggle, next = {...overrides};
    if(Object.hasOwn(next,id)) delete next[id]; else next[id] = 'proved';
    selection = id;
    evaluate(next);
  }
});
$('question-select').addEventListener('change', event => {changeQuestion(event.target.value); $('question-select').focus({preventScroll:true});});
$('reset').addEventListener('click', () => evaluate({}));
window.addEventListener('hashchange', () => evaluate(hashOverrides()));
(async () => {
  try {
    const response = await fetch('/api/trace');
    if(!response.ok) throw new Error(`Analysis failed (${response.status})`);
    trace = await response.json(); selectQuestionFact(); render();
    const initial = hashOverrides();
    if(Object.keys(initial).length) await evaluate(initial);
  } catch(error) {
    $('error').hidden = false;
    $('error').textContent = 'The study could not be loaded. Reload this page after the local server is running.';
    console.error(error);
  }
})();
