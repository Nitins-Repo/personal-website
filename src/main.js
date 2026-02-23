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

// Build blog TOC dynamically (separate listener to avoid altering existing handlers)
document.addEventListener('DOMContentLoaded', () => {
  try {
    const tocList = document.getElementById('blog-toc-list');
    if (!tocList) return;

    const entries = Array.from(document.querySelectorAll('.blog-entry'));
    console.debug('[main.js] found', entries.length, '.blog-entry elements');

    entries.forEach((e) => e.classList.add('hidden'));

    const clearActive = () => {
      tocList.querySelectorAll('a').forEach(a => a.classList.remove('active'));
      entries.forEach(en => en.classList.add('hidden'));
      const empty = document.getElementById('blog-empty'); if (empty) empty.style.display = '';
    };

    const showPost = (unique, linkEl) => {
      clearActive();
      const post = document.getElementById(unique);
      if (!post) return;
      post.classList.remove('hidden');
      if (linkEl) linkEl.classList.add('active');
      const empty = document.getElementById('blog-empty'); if (empty) empty.style.display = 'none';
      setTimeout(() => {
        post.scrollIntoView({ behavior: 'smooth', block: 'start' });

        // If the mobile TOC is open, close it so the content is on top.
        const mobileToc = document.querySelector('.blog-toc');
        if (mobileToc && mobileToc.classList.contains('visible')) {
          mobileToc.classList.remove('visible');
          const backdrop = document.querySelector('.blog-toc-backdrop');
          if (backdrop && backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
          const toggleBtn = document.getElementById('blog-toc-toggle');
          if (toggleBtn) toggleBtn.setAttribute('aria-expanded', 'false');
        }
      }, 40);
      try { history.replaceState(null, '', '#' + unique); } catch (err) { /* ignore */ }
    };

    entries.forEach((entry, idx) => {
      try {
        const h1 = entry.querySelector('h1');
        if (!h1) return;
        let slug = h1.textContent.trim().toLowerCase().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-');
        const base = slug || ('post-' + (idx+1));
        let unique = base;
        let i = 1;
        while (document.getElementById(unique)) { unique = base + '-' + i; i++; }
        entry.id = unique;

        const li = document.createElement('li');
        const a = document.createElement('a');
        a.href = '#' + unique;
        a.textContent = h1.textContent.trim();
        a.dataset.postId = unique;
        a.addEventListener('click', (ev) => {
          ev.preventDefault();
          showPost(unique, a);
        });
        li.appendChild(a);
        tocList.appendChild(li);
      } catch (errInner) {
        console.error('[main.js] error building TOC item', errInner, entry);
      }
    });

    // When the user clicks on the visible content area on small screens,
    // move focus to the TOC toggle so it's easy to reopen the TOC.
    document.addEventListener('click', (ev) => {
      if (window.innerWidth >= 900) return; // desktop keeps TOC visible
      const clickedInsidePost = !!ev.target.closest('.blog-entry');
      if (!clickedInsidePost) return;
      const toggleBtn = document.getElementById('blog-toc-toggle');
      if (toggleBtn) toggleBtn.focus();
    });

    const initialHash = (location.hash || '').replace('#','');
    if (initialHash) {
      const startLink = tocList.querySelector('a[data-post-id="' + initialHash + '"]');
      if (startLink) showPost(initialHash, startLink);
    }
  } catch (err) {
    console.error('[main.js] error building TOC', err);
  }
});

// Mobile TOC toggle behavior
document.addEventListener('DOMContentLoaded', () => {
  const toggle = document.getElementById('blog-toc-toggle');
  const toc = document.querySelector('.blog-toc');
  if (!toggle || !toc) return;

  const backdrop = document.createElement('div');
  backdrop.className = 'blog-toc-backdrop';

  const openTOC = () => {
    toc.classList.add('visible');
    toggle.setAttribute('aria-expanded', 'true');
    document.body.appendChild(backdrop);
  };

  const closeTOC = () => {
    toc.classList.remove('visible');
    toggle.setAttribute('aria-expanded', 'false');
    if (backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
  };

  toggle.addEventListener('click', (e) => {
    e.preventDefault();
    if (toc.classList.contains('visible')) closeTOC(); else openTOC();
  });

  backdrop.addEventListener('click', closeTOC);

  // Close when clicking outside toc (for devices without backdrop support)
  document.addEventListener('click', (e) => {
    if (!toc.classList.contains('visible')) return;
    if (e.target.closest('.blog-toc') || e.target.closest('#blog-toc-toggle')) return;
    closeTOC();
  });
});
