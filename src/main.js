// Small UI behaviors: focus heading and mobile nav toggle
document.addEventListener('DOMContentLoaded', () => {
  const h1 = document.querySelector('h1');
  if (h1) h1.tabIndex = -1;

  const toggle = document.getElementById('nav-toggle');
  const nav = document.getElementById('site-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded));
      if (!expanded) {
        nav.style.display = 'block';
      } else {
        nav.style.display = '';
      }
    });
  }

  // Read more toggles for projects
  document.body.addEventListener('click', (e) => {
    const more = e.target.closest('.proj-more');
    if (!more) return;
    e.preventDefault();
    const card = more.closest('.proj-card');
    if (!card) return;
    const full = card.querySelector('.proj-full');
    if (!full) return;
    if (full.style.display === 'none' || !full.style.display) {
      full.style.display = 'block';
      more.textContent = 'Show less';
    } else {
      full.style.display = 'none';
      more.textContent = 'Read more';
    }
  });

  // Tag link clicks: expand associated hidden detail and scroll to anchor
  document.body.addEventListener('click', (e) => {
    const tagLink = e.target.closest('a.tag');
    if (!tagLink) return;
    const href = tagLink.getAttribute('href');
    if (!href || !href.startsWith('#')) return;
    e.preventDefault();
    const id = href.slice(1);

    // Try to open the proj-full within the same card first
    const card = tagLink.closest('.proj-card');
    if (card) {
      const full = card.querySelector('.proj-full');
      if (full && (full.style.display === 'none' || !full.style.display)) {
        full.style.display = 'block';
      }
    }

    // If the target anchor is inside a hidden section elsewhere, ensure it's visible
    const target = document.getElementById(id);
    if (target) {
      const parentFull = target.closest('.proj-full');
      if (parentFull && (parentFull.style.display === 'none' || !parentFull.style.display)) {
        parentFull.style.display = 'block';
      }
      // Allow the layout to update then scroll
      setTimeout(() => {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        try { history.replaceState(null, '', href); } catch (err) { /* ignore */ }
      }, 60);
    }
  });
});
