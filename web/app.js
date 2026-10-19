// The GUI displays what the fvTrace engine computed; it derives no verdict itself.

/**
 * @param {string} id
 * @returns {HTMLElement}
 */
function byId(id) {
  const el = document.getElementById(id);
  if (!el) throw new Error(`missing #${id}`);
  return el;
}

byId("status").textContent = "No trace loaded yet.";
