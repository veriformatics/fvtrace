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
  $('circuits').innerHTML = trace.claims.filter(c => c.question === question).map(c => `<article class="circuit ${c.latent ? 'latent' : ''}"><button class="claim-head" data-inspect="${c.id}" aria-label="Inspect claim ${c.id}: ${escape(c.text)}">${lamp(c.state)}<span><span class="claim-meta">${c.id} / ${escape(c.level)}${c.latent ? ' / Overlooked direction' : ''}</span><h3>${escape(c.text)}</h3><span class="claim-state ${c.state}">${labels[c.state]}${c.premises.length ? `; ${c.premises.length} ${c.premises.length === 1 ? 'assumption' : 'assumptions'}` : ''}</span></span></button><div class="contacts" aria-label="Facts needed by ${c.id}">${c.needs.map(id => {
    const o = trace.obligations.find(o => o.id === id);
    return `<div class="contact"><button class="switch ${o.status}" data-toggle="${id}" aria-pressed="${Object.hasOwn(overrides,id)}" aria-label="${Object.hasOwn(overrides,id) ? 'Restore recorded status for' : 'Suppose verified:'} ${id}. ${escape(o.text)}" title="${escape(o.text)} — ${factLabels[o.status]}" ${busy ? 'disabled' : ''}>${switchSVG(o.status)}</button><button class="contact-label" data-inspect="${id}"><strong>${id}</strong><span>${escape(kindLabels[o.kind] || o.kind)}</span><span>${factLabels[o.status]}</span></button>${Object.hasOwn(overrides,id) ? '<span class="hyp-tag">What-if</span>' : ''}</div>`;
  }).join('')}<span class="terminal" aria-label="${c.id}: ${labels[c.state]}">${lamp(c.state)}<small>${c.id}</small></span></div></article>`).join('');
  renderInspector();
  $('work-list').innerHTML = trace.work.slice(0,6).map(w => {
    const o = trace.obligations.find(o => o.id === w.id);
    return `<button class="work-item" data-inspect="${w.id}"><span class="work-count">${w.unlocks.length}</span><span>${escape(o.text)}<small>${w.id} / ${w.unlocks.length} claims made available / ${w.gates.length} depend on this</small></span></button>`;
  }).join('') + '<small>First six facts in the current ranking.</small>';
}
function renderInspector() {
  const o = trace.obligations.find(o => o.id === selection);
  const c = trace.claims.find(c => c.id === selection);
  $('inspector').className = 'inspector';
  if (o) {
    const route = routes[o.route] || ['Review needed','Define a verification route for this fact.'];
    const changed = Object.hasOwn(overrides,o.id);
    $('inspector').innerHTML = `<span class="reference">Selected fact ${o.id}</span><h2>What closes this switch?</h2><span class="status-label">${changed ? 'What-if: ' : ''}${factLabels[o.status]}</span><p class="fact">${escape(o.text)}</p><h3>Recorded evidence</h3><p>${escape(o.evidence)}</p>${changed ? `<p class="note">Recorded status: ${factLabels[o.base_status]}. The evidence has not changed.</p>` : ''}<h3>Verification route: ${route[0]}</h3><p>${route[1]}</p>${o.trusts ? `<h3>Trusted base</h3><ul>${o.trusts.map(t => `<li>${escape(t)}</li>`).join('')}</ul>` : ''}<button class="action" data-toggle="${o.id}" ${busy ? 'disabled' : ''}>${changed ? 'Restore recorded fact' : 'Suppose this fact verified'}</button><p class="note">This explores a proof's consequence. It does not prove the fact.</p><h3>Claims that need this fact</h3>${trace.claims.filter(c => c.needs.includes(o.id)).map(c => `<button class="fact-link" data-inspect="${c.id}">${c.id}: ${escape(c.text)}</button>`).join('')}`;
  } else if(c) {
    $('inspector').innerHTML = `<span class="reference">Selected claim ${c.id}</span><h2>${labels[c.state]}</h2><p class="fact">${escape(c.text)}</p><h3>Why this lamp is ${c.state === 'can' ? 'lit' : c.state === 'conditional' ? 'conditional' : c.state === 'cannot' ? 'broken' : 'dark'}</h3><p>${c.blockers.length ? `A needed fact is violated: ${c.blockers.join(', ')}.` : c.gaps.length ? `Facts still need verification: ${c.gaps.join(', ')}.` : c.premises.length ? `The claim depends on declared assumptions: ${c.premises.join(', ')}.` : 'All needed facts have a proof or a verified-checker result in this example.'}</p>${c.premises.length && c.gaps.length ? `<p class="note">Also depends on assumptions: ${c.premises.join(', ')}.</p>` : ''}<h3>Inspect the supporting facts</h3>${c.needs.map(id => `<button class="fact-link" data-inspect="${id}">${id}: ${escape(trace.obligations.find(o => o.id === id).text)}</button>`).join('')}${c.latent ? '<h3>Overlooked direction</h3><p>This is a possible direction, not an established finding. Its dashed outline stays visible even if the hypothetical circuit lights.</p>' : ''}`;
  }
}
async function evaluate(next) {
  if(busy) return;
  busy = true;
  document.body.setAttribute('aria-busy','true');
  const focus = document.activeElement?.dataset.toggle;
  const fromInspector = document.activeElement?.classList.contains('action');
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
    if(focus) document.querySelector(`${fromInspector ? ".action" : ".switch"}[data-toggle="${focus}"]`)?.focus({preventScroll:true});
  }
}
document.addEventListener('click', event => {
  const button = event.target.closest('button');
  if(!button) return;
  if(button.dataset.question) { changeQuestion(button.dataset.question); document.querySelector(`[data-question="${question}"]`)?.focus({preventScroll:true}); }
  if(button.dataset.inspect) { selection = button.dataset.inspect; renderInspector(); $('inspector').focus({preventScroll:true}); if(innerWidth <= 760) $('inspector').scrollIntoView({block:'start'}); }
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
