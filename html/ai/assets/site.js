/*
 * HAVE: ${a}/ai/assets/site.js
 *
 * Designed by Claude Code ☕
 */
//
// Progressive enhancement only: the pages work fine without this.
for (const card of document.querySelectorAll('.card')) {
  card.addEventListener('pointermove', (e) => {
    const r = card.getBoundingClientRect();
    card.style.setProperty('--mx', `${e.clientX - r.left}px`);
    card.style.setProperty('--my', `${e.clientY - r.top}px`);
  });
}

for (const btn of document.querySelectorAll('button[data-copy]')) {
  btn.hidden = false;
  btn.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(btn.dataset.copy);
      btn.dataset.done = '';
      btn.textContent = 'copied';
      setTimeout(() => { delete btn.dataset.done; btn.textContent = 'copy'; }, 1400);
    } catch { /* clipboard unavailable; leave the button alone */ }
  });
}
