const $ = (selector) => document.querySelector(selector);
const marks = { overstated: '⌜', 'needs-premise': '?', supported: '✓' };
const verdictNames = { overstated: 'Overstated', 'needs-premise': 'Needs a stated assumption', supported: 'Supported' };
const statusNames = { proved: '✓ Proved', checked: '✓ Checked', assumed: '? Declared assumption', tested: '○ Tested, not verified', open: '○ Not verified', violated: '× Evidence against' };
const routes = {
  lean: 'Prove the stated contract in Lean. The proof covers the contract, not its biological meaning.',
  'runtime-checker': 'Use a verified checker on the actual analysis object. Check its input and where it is called.',
  refinement: 'Prove that the numerical implementation matches its specification. Example tests alone are not a proof.',
  'human-ruling': 'Obtain a documented ruling from the person responsible for the study or restriction. State the ruling as a premise when it is not a proof.',
  empirical: 'Collect and assess the relevant study evidence. Empirical support is not a formal proof; state the remaining assumptions.'
};
let trace;
let overrides = {};
const accepted = new Set();
let busy = false;
const escape = (value) => String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function obligationHTML(o) {
  const hypothetical = Object.hasOwn(overrides, o.id);
  const verified = ['proved', 'checked'].includes(o.status);
  return `<li class="obligation"><span class="obligation-status ${hypothetical ? 'hypothetical' : ''}">${escape(statusNames[o.status])}${hypothetical ? ' / supposed, not established' : ''} <span class="ref">${escape(o.id)}</span></span>
    <h3>${escape(o.text)}</h3><p><strong>Evidence:</strong> ${escape(o.evidence)}</p>
    <p><strong>Verification route:</strong> ${escape(routes[o.route] || o.route)}</p>
    ${o.trusts?.length ? `<p><strong>Still trusts:</strong> ${escape(o.trusts.join('; '))}.</p>` : ''}
    ${hypothetical ? `<button data-undo="${escape(o.id)}">Restore the study fact</button>` : !verified ? `<button data-suppose="${escape(o.id)}">What if this were verified?</button>` : ''}</li>`;
}

function render() {
  const focusSentence = document.activeElement?.closest('.sentence')?.id;
  const expanded = new Set([...document.querySelectorAll('details[open]')].map((d) => d.id));
  const firstRender = !$('#sentences').children.length;
  const claims = Object.fromEntries(trace.claims.map((c) => [c.id, c]));
  const obligations = Object.fromEntries(trace.obligations.map((o) => [o.id, o]));
  const sentences = trace.draft.sentences;
  const counts = Object.fromEntries(Object.keys(verdictNames).map((v) => [v, sentences.filter((s) => s.verdict === v).length]));
  $('#counts').innerHTML = Object.keys(verdictNames).map((v) => `<span class="count ${v}"><span aria-hidden="true">${marks[v]}</span><b>${counts[v]}</b> ${v === 'needs-premise' ? 'need a premise' : v}</span>`).join('');
  const active = Object.keys(overrides);
  $('#hypothesis').hidden = active.length === 0;
  $('#hypothesis-text').textContent = `${active.length} fact status${active.length === 1 ? '' : 'es'} supposed. No new evidence has been added.`;
  $('#reset-edits').disabled = !accepted.size;
  $('#sentences').innerHTML = sentences.map((s, index) => {
    const cs = s.claims.map((id) => claims[id]);
    const needs = [...new Set(cs.flatMap((c) => c.needs))];
    const gaps = [...new Set(cs.flatMap((c) => c.gaps))];
    const premises = [...new Set(cs.flatMap((c) => c.premises))];
    const blockers = [...new Set(cs.flatMap((c) => c.blockers))];
    const edited = accepted.has(s.id);
    let reason = blockers.length ? 'Evidence contradicts a fact this sentence needs.' : gaps.length ? 'Unverified facts remain. Tests and partial proofs do not establish this sentence.' : premises.length ? 'This sentence is supported only if its declared assumptions hold. State them in the text.' : 'All facts needed by this sentence are marked verified in the study trace.';
    return `<article class="sentence ${s.verdict}" id="${escape(s.id)}"><div class="prose"><span class="sentence-ref">Sentence ${index + 1} <span class="ref">${escape(s.id)}</span></span><span class="proof-mark" aria-hidden="true">${marks[s.verdict]}</span>
      <p class="sentence-text ${edited ? 'edited-text' : ''} ${edited && s.rewrite === null ? 'removed' : ''}">${escape(edited && s.rewrite !== null ? s.rewrite : s.text)}</p>
      ${edited ? `<p class="edit-label">${s.rewrite === null ? 'Deleted locally.' : 'Stub rewrite accepted locally.'} The verdict at right still refers to the original sentence. This edit has not been verified.</p><button data-revert="${escape(s.id)}">Undo this edit</button>` : ''}</div>
      <aside class="note" aria-label="Referee note for sentence ${index + 1}"><p class="verdict"><span aria-hidden="true">${marks[s.verdict]}</span>${verdictNames[s.verdict]}${edited ? ' (original)' : ''}</p>
      ${cs.map((c) => `<p class="claim"><strong>Asserts:</strong> ${escape(c.text)} <span class="ref">${escape(c.id)}</span></p>`).join('')}
      <p class="reason">${reason}</p>
      ${blockers.length ? `<p class="reason"><strong>Contradicted:</strong> ${blockers.map((id) => escape(obligations[id].text)).join(' ')}</p>` : ''}
      ${premises.length ? `<p class="reason"><strong>Assumptions:</strong> ${premises.map((id) => escape(obligations[id].text)).join(' ')}</p>` : ''}
      ${!edited && s.verdict !== 'supported' ? `<div class="rewrite"><p class="rewrite-label">Suggested edit / stub text</p><p>${s.rewrite === null ? 'Delete this sentence. The causal claim is not established.' : escape(s.rewrite)}</p><button data-accept="${escape(s.id)}">${s.rewrite === null ? 'Accept deletion' : 'Accept rewrite'}</button></div>` : ''}
      <details id="proof-${escape(s.id)}" ${expanded.has(`proof-${s.id}`) || (firstRender && index === 0) ? 'open' : ''}><summary>${s.verdict === 'supported' ? 'Why this sentence is supported' : 'What would make this sentence true'} (${needs.length})</summary><ul class="obligations">${needs.map((id) => obligationHTML(obligations[id])).join('')}</ul></details></aside></article>`;
  }).join('');
  if (focusSentence) document.querySelector(`#${focusSentence} button, #${focusSentence} summary`)?.focus({ preventScroll: true });
}

async function evaluate(next) {
  if (busy) return;
  busy = true;
  $('#message').textContent = 'Checking the supposed facts…';
  try {
    const response = await fetch('/api/evaluate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ overrides: next }) });
    if (!response.ok) throw new Error('The manuscript could not be checked. Try again.');
    trace = await response.json();
    overrides = trace.overrides;
    const hash = Object.entries(overrides).map(([id, status]) => `${id}:${status}`).join(',');
    history.replaceState(null, '', `${location.pathname}${hash ? '#whatif=' + hash : ''}`);
    render();
    $('#message').textContent = Object.keys(overrides).length ? 'Verdicts updated under the supposed facts. Nothing has been proved by this action.' : 'Study facts restored.';
  } catch (error) { $('#message').textContent = error.message; }
  finally { busy = false; }
}

document.addEventListener('click', (event) => {
  const button = event.target.closest('button');
  if (!button) return;
  if (button.dataset.accept) { accepted.add(button.dataset.accept); render(); $('#message').textContent = 'Stub edit accepted. The original claim verdict is unchanged.'; }
  if (button.dataset.revert) { accepted.delete(button.dataset.revert); render(); $('#message').textContent = 'Original sentence restored.'; }
  if (button.dataset.suppose) evaluate({ ...overrides, [button.dataset.suppose]: 'proved' });
  if (button.dataset.undo) { const next = { ...overrides }; delete next[button.dataset.undo]; evaluate(next); }
  if (button.id === 'reset-edits') { accepted.clear(); render(); $('#message').textContent = 'All original sentences restored.'; }
  if (button.id === 'reset-whatif') evaluate({});
});

async function start() {
  try {
    const response = await fetch('/api/trace');
    if (!response.ok) throw new Error('The manuscript could not be loaded. Reload this page to try again.');
    trace = await response.json();
    render();
    $('#message').textContent = '';
    const parameters = new URLSearchParams(location.hash.slice(1));
    const initial = Object.fromEntries((parameters.get('whatif') || '').split(',').filter(Boolean).map((pair) => pair.split(':')).filter(([id, status]) => trace.obligations.some((o) => o.id === id) && ['proved', 'checked', 'assumed', 'tested', 'open', 'violated'].includes(status)));
    if (Object.keys(initial).length) await evaluate(initial);
  } catch (error) { $('#message').textContent = error.message; }
}
start();
