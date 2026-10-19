const states = {
  can: {symbol: '✓', label: 'Can say now'},
  conditional: {symbol: '◇', label: 'Only with assumptions'},
  open: {symbol: '○', label: 'Not yet supported'},
  cannot: {symbol: '×', label: 'Cannot say as written'}
};
const routes = {
  lean: 'Prove the stated property in Lean.',
  'runtime-checker': 'Use a proved checker on the actual analysis output.',
  refinement: 'Prove that the numerical implementation meets its specification.',
  'human-ruling': 'Get an explicit review from the responsible scientist or owner.',
  empirical: 'Assess this fact with study evidence. Empirical support is not a formal proof.'
};
const labels = ['Tau and amyloid', 'Agreement across assays', 'Publication limits', 'Microglia identity'];
const $ = id => document.getElementById(id);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let trace, baseline, selected, busy = false;

function fact(id, role) {
  const o = trace.obligations.find(o => o.id === id);
  return `<div class="fact"><p class="fact-label">${role} <span class="work-id">${esc(id)}</span></p><p>${esc(o.text)}</p>${role === 'Gap' || role === 'Required fact' ? `<p class="route">${esc(routes[o.route] || 'Review the stated fact.')}</p>` : ''}<details class="evidence"><summary>Evidence and scope</summary><p>${esc(o.evidence)}</p>${o.trusts ? `<p>Relies on: ${o.trusts.map(esc).join('; ')}.</p>` : ''}</details></div>`;
}
function claim(c) {
  const premises = c.premises.map(id => trace.obligations.find(o => o.id === id).text);
  const text = c.state === 'conditional' ? `Assuming ${premises.map(t => `“${t.replace(/[.]$/, '')}”`).join(' and ')}, ${c.text.charAt(0).toLowerCase() + c.text.slice(1)}` : c.text;
  return `<article class="claim" id="claim-${esc(c.id)}"><p class="claim-text">${esc(text)}</p><p class="reference">${esc(c.id)} / ${esc(c.level)}${c.latent ? ` / ${esc(states[c.state].label)}` : ''}</p>${c.blockers.map(id => fact(id, 'Violated fact')).join('')}${c.gaps.map(id => fact(id, 'Gap')).join('')}${c.premises.map(id => fact(id, 'Declared assumption')).join('')}${c.verified.length ? `<details class="evidence"><summary>${c.verified.length} verified ${c.verified.length === 1 ? 'fact' : 'facts'} supporting this claim</summary>${c.verified.map(id => fact(id, 'Verified fact')).join('')}</details>` : ''}</article>`;
}
function renderClaims() {
  const q = trace.questions.find(q => q.id === selected);
  $('question-heading').innerHTML = `<div class="question-heading"><span class="reference">${esc(q.id)}${q.primary ? ' / Primary scientific question' : ''}</span><h2 id="question-title">${esc(q.text)}</h2></div>`;
  const claims = trace.claims.filter(c => c.question === selected && !c.latent);
  $('claims').innerHTML = Object.entries(states).map(([state, s]) => {
    const rows = claims.filter(c => c.state === state);
    return `<section class="state-section state-${state}" aria-label="${s.label}"><h3 class="state-title"><span aria-hidden="true">${s.symbol}</span>${s.label}<span class="state-count">${rows.length}</span></h3>${rows.length ? rows.map(claim).join('') : '<p class="empty">No claims in this account.</p>'}</section>`;
  }).join('');
  const latent = trace.claims.filter(c => c.question === selected && c.latent);
  $('directions').hidden = !latent.length;
  $('directions').innerHTML = `<h2>Directions that open if…</h2><p class="quiet">Possible next questions, not established findings. Review every required fact before pursuing them.</p>${latent.map(c => `<div><p class="reference">${states[c.state].symbol} ${states[c.state].label}</p>${claim(c)}</div>`).join('')}`;
  document.querySelectorAll('.question-tab').forEach(b => b.setAttribute('aria-pressed', b.dataset.question === selected));
}
function render() {
  $('title').textContent = trace.analysis.title;
  $('summary').textContent = trace.analysis.summary;
  $('balances').innerHTML = Object.entries(states).map(([state, s]) => `<div class="balance state-${state}"><span class="balance-number">${trace.counts[state]}</span><span class="balance-label"><span aria-hidden="true">${s.symbol} </span>${s.label}</span></div>`).join('');
  $('questions').innerHTML = trace.questions.map((q, i) => `<button class="question-tab" data-question="${esc(q.id)}" aria-pressed="${q.id === selected}"><span class="question-ref">${esc(q.id)}</span>${labels[i] || esc(q.text)}</button>`).join('');
  renderClaims();
  const overrides = Object.keys(trace.overrides);
  $('scenario').hidden = !overrides.length;
  const changed = trace.claims.filter(c => baseline.claims.find(b => b.id === c.id).state !== c.state);
  $('scenario').innerHTML = `<div class="scenario-top"><h2>What-if account, not verified findings</h2><button id="reset">Reset to study record</button></div><p>Supposed verified: ${overrides.map(id => esc(id)).join(', ')}. These changes are not saved and do not constitute proof.</p><ul>${changed.length ? changed.map(c => `<li>${esc(c.id)}: ${esc(states[baseline.claims.find(b => b.id === c.id).state].label)} becomes <strong>${esc(states[c.state].label)}</strong>.</li>`).join('') : '<li>No claim changes account yet. Other required facts remain unresolved.</li>'}</ul>`;
  const workRows = trace.work.map(w => {
    const o = trace.obligations.find(o => o.id === w.id);
    return `<article class="work-entry"><span class="work-impact">${w.unlocks.length ? `Unlocks ${w.unlocks.length} ${w.unlocks.length === 1 ? 'claim' : 'claims'}` : 'No claim unlocked on its own'}<span class="work-id">${esc(w.id)}</span></span><p>${esc(o.text)}</p><p class="quiet">${esc(routes[w.route] || 'Review this fact.')}</p>${o.status === 'violated' ? '<p class="work-warning">The study record contradicts this fact. This supposition reverses evidence; it does not resolve it.</p>' : ''}<p class="reference">${w.unlocks.length ? `Would move: ${w.unlocks.map(esc).join(', ')}.` : `Needed by: ${w.gates.map(esc).join(', ')}.`}</p><button class="work-button" data-suppose="${esc(w.id)}" aria-label="Suppose ${esc(w.id)} verified">Suppose verified</button></article>`;
  });
  $('work').innerHTML = workRows.length ? workRows.slice(0, 4).join('') + (workRows.length > 4 ? `<details class="evidence"><summary>${workRows.length - 4} more verification tasks</summary>${workRows.slice(4).join('')}</details>` : '') : '<p>All recorded facts have been supposed verified. Reset to inspect the actual study record.</p>';
  $('draft').innerHTML = trace.draft.sentences.map(s => `<article class="sentence"><p class="reference">${esc(s.id)} / ${esc(s.verdict.replaceAll('-', ' '))}</p><p>${esc(s.text)}</p>${s.verdict === 'supported' ? '<p class="quiet">Supported within the recorded claim scope.</p>' : s.rewrite ? `<p class="rewrite">Stub rewrite: ${esc(s.rewrite)}</p>` : '<p class="rewrite">Remove this sentence. No supported rewrite is supplied.</p>'}</article>`).join('');
}
async function evaluate(overrides) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button').forEach(b => b.disabled = true);
  $('error').hidden = true;
  try {
    const response = await fetch('/api/evaluate', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({overrides})});
    if (!response.ok) throw new Error('The study account could not be recalculated. Try again.');
    trace = await response.json();
    history.replaceState(null, '', location.pathname + (Object.keys(trace.overrides).length ? '#whatif=' + Object.entries(trace.overrides).map(([id, status]) => `${id}:${status}`).join(',') : ''));
    render();
    $('announcement').textContent = Object.keys(overrides).length ? 'Hypothetical account updated. Review the changed claims above.' : 'The original study record is restored.';
    if (Object.keys(overrides).length) {
      $('scenario').setAttribute('tabindex', '-1');
      $('scenario').focus({preventScroll: true});
      $('scenario').scrollIntoView({block: 'nearest'});
    }
  } catch (e) {
    $('error').textContent = e.message;
    $('error').hidden = false;
  } finally {
    busy = false;
    document.querySelectorAll('button').forEach(b => b.disabled = false);
  }
}
document.addEventListener('click', e => {
  const q = e.target.closest('[data-question]');
  if (q) { selected = q.dataset.question; renderClaims(); }
  const w = e.target.closest('[data-suppose]');
  if (w) evaluate({...trace.overrides, [w.dataset.suppose]: 'proved'});
  if (e.target.closest('#reset')) evaluate({});
});
(async () => {
  try {
    const response = await fetch('/api/trace');
    if (!response.ok) throw new Error('The study record could not be loaded. Reload this page to try again.');
    baseline = trace = await response.json();
    selected = trace.questions.find(q => q.primary)?.id || trace.questions[0].id;
    render();
    if (location.hash.startsWith('#whatif=')) {
      const overrides = Object.fromEntries(location.hash.slice(8).split(',').map(x => x.split(':')).filter(([id, status]) => /^O\d+$/.test(id) && ['proved','checked','assumed','tested','open','violated'].includes(status)));
      await evaluate(overrides);
    }
  } catch (e) {
    $('title').textContent = 'The claim ledger could not be opened';
    $('error').textContent = e.message;
    $('error').hidden = false;
  }
})();
