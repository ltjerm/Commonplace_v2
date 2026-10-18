/* Commonplace — a tiny personal commonplace journal.
 *
 * Data model (mirrors a simple Swift Codable struct):
 *   Entry {
 *     id: String (UUID)
 *     type: "quote" | "thought" | "idea"
 *     text: String
 *     author: String?        // author for quotes, source for others (optional)
 *     tags: [String]         // lowercase, no '#'
 *     favorite: Bool
 *     createdAt: String      // ISO 8601, UTC, no fractional seconds: 2026-10-16T23:18:00Z
 *     updatedAt: String      // (decodes with JSONDecoder.dateDecodingStrategy = .iso8601)
 *   }
 * Storage: localStorage["commonplace.v1"] = JSON of { version: 1, entries: [Entry] }
 * Export file: { app: "Commonplace", version: 1, exportedAt, entries: [Entry] }
 */
(() => {
  'use strict';

  const STORAGE_KEY = 'commonplace.v1';
  const TYPES = ['quote', 'thought', 'idea'];
  const TYPE_LABEL = { quote: 'Quote', thought: 'Thought', idea: 'Idea' };
  const $ = (s, el = document) => el.querySelector(s);

  // ---------- Store ----------
  const nowISO = () => new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() :
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
      const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16);
    })).toUpperCase();

  function normTags(input) {
    const arr = Array.isArray(input) ? input : String(input || '').split(/[\s,]+/);
    const out = [];
    for (let t of arr) {
      t = String(t).trim().replace(/^#+/, '').trim().toLowerCase().replace(/\s+/g, '-');
      if (t && !out.includes(t)) out.push(t);
    }
    return out;
  }

  function sanitize(e) {
    if (!e || typeof e !== 'object' || typeof e.text !== 'string') return null;
    const created = isNaN(Date.parse(e.createdAt)) ? nowISO() : new Date(e.createdAt).toISOString().replace(/\.\d{3}Z$/, 'Z');
    const updated = isNaN(Date.parse(e.updatedAt)) ? created : new Date(e.updatedAt).toISOString().replace(/\.\d{3}Z$/, 'Z');
    const author = typeof e.author === 'string' && e.author.trim() ? e.author.trim() : null;
    return {
      id: typeof e.id === 'string' && e.id ? e.id : uuid(),
      type: TYPES.includes(e.type) ? e.type : 'thought',
      text: e.text,
      author,
      tags: normTags(e.tags || []),
      favorite: !!e.favorite,
      createdAt: created,
      updatedAt: updated,
    };
  }

  const store = {
    entries: [],
    load() {
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        const data = raw ? JSON.parse(raw) : null;
        this.entries = (data && Array.isArray(data.entries) ? data.entries : []).map(sanitize).filter(Boolean);
      } catch (err) { console.error(err); this.entries = []; }
    },
    save() {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ version: 1, entries: this.entries }));
    },
    sorted() { // newest first; ties (same second) broken by insertion order
      return this.entries.map((e, i) => [e, i]).sort((a, b) => b[0].createdAt.localeCompare(a[0].createdAt) || b[1] - a[1]).map(x => x[0]);
    },
    get(id) { return this.entries.find(e => e.id === id); },
    upsert(partial) {
      const t = nowISO();
      const existing = partial.id && this.get(partial.id);
      if (existing) {
        Object.assign(existing, sanitize({ ...existing, ...partial, updatedAt: t }));
      } else {
        this.entries.push(sanitize({ ...partial, id: uuid(), createdAt: t, updatedAt: t }));
      }
      this.save();
    },
    remove(id) { this.entries = this.entries.filter(e => e.id !== id); this.save(); },
    allTags() {
      const counts = new Map();
      for (const e of this.entries) for (const t of e.tags) counts.set(t, (counts.get(t) || 0) + 1);
      return [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(x => x[0]);
    },
    merge(incoming) {
      let added = 0, updated = 0;
      for (const raw of incoming) {
        const e = sanitize(raw); if (!e) continue;
        const cur = this.get(e.id);
        if (!cur) { this.entries.push(e); added++; }
        else if (e.updatedAt > cur.updatedAt) { Object.assign(cur, e); updated++; }
      }
      this.save();
      return { added, updated };
    },
  };

  // ---------- UI prefs (separate key; never touches entries) ----------
  const PREFS_KEY = 'commonplace.prefs';
  let prefs = {};
  try { prefs = JSON.parse(localStorage.getItem(PREFS_KEY)) || {}; } catch (_) { prefs = {}; }
  const savePrefs = () => { try { localStorage.setItem(PREFS_KEY, JSON.stringify(prefs)); } catch (_) {} };
  const applyPrefs = () => document.documentElement.classList.toggle('solid', !!prefs.reduceTransparency);
  applyPrefs();
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  // ---------- Helpers ----------
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const icons = {
    star: '<svg viewBox="0 0 24 24"><path d="M12 3.6l2.5 5.2 5.7.8-4.1 4 1 5.7L12 16.6l-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/></svg>',
    search: '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
    share: '<svg viewBox="0 0 24 24"><path d="M12 15V4M8 8l4-4 4 4M6 12v7h12v-7"/></svg>',
    close: '<svg viewBox="0 0 24 24"><path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/></svg>',
    shuffle: '<svg viewBox="0 0 24 24"><path d="M4 7h3.5c4.5 0 4.5 10 9 10H20M4 17h3.5c1.6 0 2.6-1.3 3.4-3M13.1 10c.8-1.7 1.8-3 3.4-3H20M17.5 4.5L20 7l-2.5 2.5M17.5 14.5L20 17l-2.5 2.5"/></svg>',
  };
  function fmtDate(iso, withTime) {
    const d = new Date(iso);
    const opts = { month: 'short', day: 'numeric' };
    if (d.getFullYear() !== new Date().getFullYear()) opts.year = 'numeric';
    let s = d.toLocaleDateString(undefined, opts);
    if (withTime) s += ' · ' + d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    return s;
  }
  function dayLabel(iso) {
    const d = new Date(iso), today = new Date();
    const start = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
    const diff = Math.round((start(today) - start(d)) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Yesterday';
    return d.toLocaleDateString(undefined, { weekday: diff < 7 ? 'long' : undefined, month: 'long', day: 'numeric', year: d.getFullYear() !== today.getFullYear() ? 'numeric' : undefined });
  }
  function highlight(text, q) {
    const safe = esc(text);
    if (!q) return safe;
    const terms = q.split(/\s+/).filter(Boolean).map(t => t.replace(/^#/, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).filter(Boolean);
    if (!terms.length) return safe;
    return safe.replace(new RegExp('(' + terms.map(esc).join('|') + ')', 'gi'), '<mark>$1</mark>');
  }
  let toastTimer;
  function toast(msg) {
    const t = $('#toast'); t.textContent = msg; t.classList.add('show');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('show'), 2000);
  }
  const typePill = t => `<span class="type-pill type-${t}"><i></i>${TYPE_LABEL[t]}</span>`;

  function cardHTML(e, q) {
    const author = e.author ? `<div class="author">${highlight(e.author, q)}</div>` : '';
    const tags = e.tags.length ? `<div class="tags">${e.tags.map(t => `<button data-tag="${esc(t)}">#${highlight(t, q)}</button>`).join('')}</div>` : '';
    return `<article class="card glass ${e.type}" data-id="${esc(e.id)}">
      <div class="meta">${typePill(e.type)}<span>${fmtDate(e.createdAt, true)}</span></div>
      <p class="text clamped">${highlight(e.text, q)}</p>${author}${tags}
      <button class="star-btn" data-star="${esc(e.id)}" aria-label="Favorite" aria-pressed="${e.favorite}">${icons.star}</button>
    </article>`;
  }

  function bindCards(root, rerender) {
    root.addEventListener('click', ev => {
      const star = ev.target.closest('[data-star]');
      if (star) {
        ev.stopPropagation();
        const e = store.get(star.dataset.star);
        if (e) {
          store.upsert({ id: e.id, favorite: !e.favorite });
          star.setAttribute('aria-pressed', String(!e.favorite));
          star.classList.remove('pop'); void star.offsetWidth; star.classList.add('pop');
        }
        return;
      }
      const tag = ev.target.closest('[data-tag]');
      if (tag && tag.closest('.card')) {
        ev.stopPropagation();
        state.filter = { kind: 'all', tag: tag.dataset.tag };
        if (location.hash === '#/' || location.hash === '') { rerender && rerender(); } else location.hash = '#/';
        return;
      }
      const card = ev.target.closest('.card');
      if (card) location.hash = '#/edit/' + encodeURIComponent(card.dataset.id);
    });
  }

  // ---------- State ----------
  const state = {
    filter: { kind: 'all', tag: null }, // kind: all | quote | thought | idea | fav
    query: '',
    pullMode: 'smart', // smart | quotes | favorites | all
    lastPulled: null,
    underlay: '#/',     // the page shown behind the Add/Edit sheet
    sheetClose: null,
  };
  const view = () => $('#view');
  const setTitle = (t, actions = '') => { $('#title').textContent = t; $('#topActions').innerHTML = actions; };

  // ---------- Home ----------
  function renderHome() {
    setTitle('Commonplace', `<a class="icon-btn round glass" href="#/search" aria-label="Search">${icons.search}</a>`);
    const f = state.filter;
    const kinds = [['all', 'All'], ['quote', 'Quotes'], ['thought', 'Thoughts'], ['idea', 'Ideas'], ['fav', '★ Favorites']];
    const tags = store.allTags();
    let list = store.sorted();
    if (f.kind === 'fav') list = list.filter(e => e.favorite);
    else if (f.kind !== 'all') list = list.filter(e => e.type === f.kind);
    if (f.tag) list = list.filter(e => e.tags.includes(f.tag));

    let feed = '', lastDay = '';
    for (const e of list) {
      const dl = dayLabel(e.createdAt);
      if (dl !== lastDay) { feed += `<div class="day">${esc(dl)}</div>`; lastDay = dl; }
      feed += cardHTML(e);
    }
    const empty = store.entries.length === 0
      ? `<div class="empty glass"><div class="glyph">“</div><div class="big">Your commonplace book is empty.</div>Tap <b>+</b> to capture a quote, a thought, or an idea.</div>`
      : `<div class="empty glass"><div class="big">Nothing here yet.</div>No entries match this filter.</div>`;

    view().innerHTML = `
      <div class="chips" role="toolbar" aria-label="Filter by type">
        ${kinds.map(([k, l]) => `<button class="chip glass" data-kind="${k}" aria-pressed="${f.kind === k}">${l}</button>`).join('')}
      </div>
      ${tags.length ? `<div class="chips" role="toolbar" aria-label="Filter by tag">
        ${tags.map(t => `<button class="chip glass tag" data-filter-tag="${esc(t)}" aria-pressed="${f.tag === t}">#${esc(t)}${f.tag === t ? ' ✕' : ''}</button>`).join('')}
      </div>` : ''}
      <div class="feed">${list.length ? feed : empty}</div>`;

    view().querySelectorAll('[data-kind]').forEach(b => b.onclick = () => { state.filter.kind = b.dataset.kind; renderHome(); });
    view().querySelectorAll('[data-filter-tag]').forEach(b => b.onclick = () => {
      state.filter.tag = state.filter.tag === b.dataset.filterTag ? null : b.dataset.filterTag; renderHome();
    });
    bindCards($('.feed', view()), renderHome);
  }

  // ---------- Add / Edit (bottom sheet) ----------
  function renderEdit(id) {
    const existing = id ? store.get(id) : null;
    if (id && !existing) { state.sheetClose = null; location.hash = state.underlay; return; }
    const draft = existing ? { ...existing, tags: [...existing.tags] } :
      { type: TYPES.includes(state.filter.kind) ? state.filter.kind : 'quote', text: '', author: '', tags: state.filter.tag ? [state.filter.tag] : [], favorite: false };

    $('#sheetBody').innerHTML = `
      <form id="editForm" autocomplete="off">
        <div class="sheet-head">
          <button type="button" class="icon-btn round glass left" id="fCancel" aria-label="Cancel">${icons.close}</button>
          <h2 id="sheetTitle">${existing ? 'Edit' : 'New entry'}</h2>
          <button type="submit" class="btn-save right">Save</button>
        </div>
        <div class="sheet-scroll">
          <div class="segmented" role="radiogroup" aria-label="Type">
            <span class="thumb" aria-hidden="true"></span>
            ${TYPES.map(t => `<button type="button" data-type="${t}" aria-pressed="${draft.type === t}">${TYPE_LABEL[t]}</button>`).join('')}
          </div>
          <textarea class="big" id="fText" aria-label="Text">${esc(draft.text)}</textarea>
          <div class="field">
            <label for="fAuthor" id="authorLabel"></label>
            <input id="fAuthor" type="text" value="${esc(draft.author || '')}" autocapitalize="words" enterkeyhint="next">
          </div>
          <div class="field">
            <label for="fTags">Tags</label>
            <input id="fTags" type="text" value="${esc(draft.tags.join(', '))}" placeholder="discipline stoic work" autocapitalize="none" autocorrect="off" spellcheck="false" enterkeyhint="done">
            <div class="suggest" id="tagSuggest"></div>
          </div>
          <div class="row">
            <button type="button" class="btn glass fav-toggle" id="fFav" aria-pressed="${draft.favorite}" aria-label="Favorite"><span class="s">${draft.favorite ? '★' : '☆'}</span><span>Favorite</span></button>
          </div>
          ${existing ? `<div class="row"><button type="button" class="btn glass danger block" id="fDelete">Delete entry</button></div>
            <p class="fine">Created ${fmtDate(existing.createdAt, true)}${existing.updatedAt !== existing.createdAt ? ` · edited ${fmtDate(existing.updatedAt, true)}` : ''}</p>` : ''}
        </div>
      </form>`;

    const body = $('#sheetBody');
    const text = $('#fText'), author = $('#fAuthor'), tagsIn = $('#fTags');
    const snapshot = () => JSON.stringify([draft.type, text.value, author.value, normTags(tagsIn.value), draft.favorite]);
    const initial = snapshot();
    const placeholders = { quote: 'Type or paste the quote…', thought: 'What’s on your mind?', idea: 'Capture the idea before it slips away…' };
    const syncType = () => {
      body.querySelectorAll('[data-type]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.type === draft.type)));
      $('.segmented', body).style.setProperty('--i', TYPES.indexOf(draft.type));
      text.placeholder = placeholders[draft.type];
      $('#authorLabel').textContent = draft.type === 'quote' ? 'Author' : 'Source (optional)';
      author.placeholder = draft.type === 'quote' ? 'Marcus Aurelius' : 'Book, podcast, conversation…';
    };
    body.querySelectorAll('[data-type]').forEach(b => b.onclick = () => { draft.type = b.dataset.type; syncType(); });
    syncType();

    const renderSuggest = () => {
      const current = normTags(tagsIn.value);
      const sugg = store.allTags().filter(t => !current.includes(t)).slice(0, 12);
      $('#tagSuggest').innerHTML = sugg.map(t => `<button type="button" class="chip glass tag" data-add="${esc(t)}">#${esc(t)}</button>`).join('');
    };
    $('#tagSuggest').addEventListener('click', ev => {
      const b = ev.target.closest('[data-add]'); if (!b) return;
      const cur = normTags(tagsIn.value); cur.push(b.dataset.add);
      tagsIn.value = cur.join(', ') + ', '; renderSuggest();
    });
    tagsIn.addEventListener('input', renderSuggest);
    renderSuggest();

    $('#fFav').onclick = () => {
      draft.favorite = !draft.favorite;
      $('#fFav').setAttribute('aria-pressed', String(draft.favorite)); $('#fFav .s').textContent = draft.favorite ? '★' : '☆';
    };
    const autosize = () => { text.style.height = 'auto'; text.style.height = Math.max(text.scrollHeight + 2, window.innerHeight * 0.3) + 'px'; };
    text.addEventListener('input', autosize);
    text.addEventListener('keydown', ev => { if (ev.key === 'Enter' && (ev.metaKey || ev.ctrlKey)) $('#editForm').requestSubmit(); });
    author.addEventListener('keydown', ev => { if (ev.key === 'Enter') { ev.preventDefault(); tagsIn.focus(); } });

    const leave = () => { state.sheetClose = null; location.hash = state.underlay; };
    state.sheetClose = () => {
      if (snapshot() !== initial && !confirm('Discard your changes?')) { $('.sheet').style.transform = ''; return; }
      leave();
    };
    $('#fCancel').onclick = () => state.sheetClose();

    $('#editForm').onsubmit = ev => {
      ev.preventDefault();
      const value = text.value.replace(/\s+$/, '');
      if (!value.trim()) { toast('Write something first'); text.focus(); return; }
      store.upsert({ id: existing?.id, type: draft.type, text: value, author: author.value, tags: normTags(tagsIn.value), favorite: draft.favorite });
      toast(existing ? 'Saved' : 'Captured');
      leave();
    };
    if (existing) $('#fDelete').onclick = () => {
      if (confirm('Delete this entry? This can’t be undone.')) { store.remove(existing.id); toast('Deleted'); leave(); }
    };
    if (!existing) setTimeout(() => text.focus({ preventScroll: true }), reduceMotion.matches ? 0 : 320);
    autosize();
  }

  // ---------- Search ----------
  function renderSearch(autofocus = true) {
    setTitle('Search');
    view().innerHTML = `
      <div class="searchbox glass">${icons.search}
        <input id="q" type="search" placeholder="Words, authors, #tags" value="${esc(state.query)}" autocapitalize="none" autocorrect="off" enterkeyhint="search">
      </div>
      <div class="feed" id="results"></div>`;
    const q = $('#q'), results = $('#results');
    const run = () => {
      state.query = q.value;
      const terms = q.value.toLowerCase().split(/\s+/).filter(Boolean);
      if (!terms.length) {
        const tags = store.allTags();
        results.innerHTML = tags.length
          ? `<div class="day small">Browse tags</div><div class="suggest">${tags.map(t => `<button class="chip glass tag" data-q="#${esc(t)}">#${esc(t)}</button>`).join('')}</div>`
          : `<div class="empty glass">Search across text, authors, and tags.</div>`;
        return;
      }
      const hits = store.sorted().filter(e => {
        const hay = [e.text, e.author || '', e.tags.map(t => '#' + t).join(' ')].join(' ').toLowerCase();
        return terms.every(t => t.startsWith('#') ? e.tags.some(tag => tag.startsWith(t.slice(1))) : hay.includes(t));
      });
      results.innerHTML = hits.length
        ? `<div class="day small">${hits.length} ${hits.length === 1 ? 'entry' : 'entries'}</div>` + hits.map(e => cardHTML(e, q.value)).join('')
        : `<div class="empty glass">No matches for “${esc(q.value)}”.</div>`;
    };
    q.addEventListener('input', run);
    results.addEventListener('click', ev => {
      const b = ev.target.closest('[data-q]'); if (b) { q.value = b.dataset.q; run(); }
    });
    bindCards(results, null);
    run();
    if (autofocus) setTimeout(() => q.focus(), 60);
  }

  // ---------- Pull one ----------
  function pickRandom(mode) {
    let pool = store.entries;
    if (mode === 'quotes') pool = pool.filter(e => e.type === 'quote');
    if (mode === 'favorites') pool = pool.filter(e => e.favorite);
    if (!pool.length) return null;
    // Smart mode: weight quotes and favorites higher; avoid immediate repeats.
    const weight = e => mode === 'smart' ? (e.type === 'quote' ? 3 : 1) * (e.favorite ? 3 : 1) : 1;
    let candidates = pool.length > 1 ? pool.filter(e => e.id !== state.lastPulled) : pool;
    const total = candidates.reduce((s, e) => s + weight(e), 0);
    let r = Math.random() * total;
    for (const e of candidates) { r -= weight(e); if (r <= 0) return e; }
    return candidates[candidates.length - 1];
  }

  function renderRandom(keep) {
    setTitle('Pull one');
    const modes = [['smart', 'Best of'], ['quotes', 'Quotes'], ['favorites', '★ Favorites'], ['all', 'Anything']];
    const e = keep && state.lastPulled && store.get(state.lastPulled) || pickRandom(state.pullMode);
    if (e) state.lastPulled = e.id;
    view().innerHTML = `
      <div class="chips" role="toolbar" aria-label="Pull from">
        ${modes.map(([k, l]) => `<button class="chip glass" data-mode="${k}" aria-pressed="${state.pullMode === k}">${l}</button>`).join('')}
      </div>
      ${e ? `<div class="pull-stage">
          <div class="layer l2 glass" aria-hidden="true"></div>
          <div class="layer l1 glass" aria-hidden="true"></div>
          <div class="pull-float">
            <article class="pull-card glass ${e.type} ${keep ? '' : 'pop'}" id="pulled">
              <span class="shine" aria-hidden="true"></span>
              ${e.type === 'quote' ? '<div class="mark">“</div>' : ''}
              <p class="text">${esc(e.text)}</p>
              ${e.author ? `<div class="author">${esc(e.author)}</div>` : ''}
              <div class="meta">${typePill(e.type)}${e.favorite ? '<span style="color:var(--star)">★</span>' : ''}<span>${fmtDate(e.createdAt)}</span>${e.tags.map(t => `<span>#${esc(t)}</span>`).join('')}</div>
            </article>
          </div>
        </div>
        <div class="row pull-actions">
          <button class="btn glass round" id="share" aria-label="Share">${icons.share}</button>
          <button class="btn primary" id="again">${icons.shuffle}<span>Pull another</span></button>
        </div>`
        : `<div class="empty glass"><div class="glyph">“</div><div class="big">Nothing to pull yet.</div>${state.pullMode === 'favorites' ? 'Star a few entries first.' : state.pullMode === 'quotes' ? 'Add a quote first.' : 'Add a few entries first.'}</div>`}`;
    view().querySelectorAll('[data-mode]').forEach(b => b.onclick = () => { state.pullMode = b.dataset.mode; renderRandom(); });
    if (!e) return;
    const card = $('#pulled');
    $('#again').onclick = () => renderRandom();
    let moved = 0, downAt = null;
    card.addEventListener('pointerdown', ev => { downAt = [ev.clientX, ev.clientY]; moved = 0; });
    card.addEventListener('click', () => { if (moved < 8) location.hash = '#/edit/' + encodeURIComponent(e.id); });
    if (!reduceMotion.matches) {
      const tilt = ev => {
        const r = card.getBoundingClientRect();
        const x = Math.min(Math.max((ev.clientX - r.left) / r.width, 0), 1) - .5;
        const y = Math.min(Math.max((ev.clientY - r.top) / r.height, 0), 1) - .5;
        if (downAt) moved = Math.max(moved, Math.hypot(ev.clientX - downAt[0], ev.clientY - downAt[1]));
        card.classList.add('tilting');
        card.style.setProperty('--rx', (-y * 12).toFixed(2) + 'deg');
        card.style.setProperty('--ry', (x * 14).toFixed(2) + 'deg');
        card.style.setProperty('--mx', ((x + .5) * 100).toFixed(1) + '%');
        card.style.setProperty('--my', ((y + .5) * 100).toFixed(1) + '%');
      };
      const reset = () => {
        downAt = null; card.classList.remove('tilting');
        ['--rx', '--ry', '--mx', '--my'].forEach(p => card.style.removeProperty(p));
      };
      card.addEventListener('pointermove', tilt);
      card.addEventListener('pointerup', reset);
      card.addEventListener('pointerleave', reset);
      card.addEventListener('pointercancel', reset);
    }
    $('#share').onclick = async () => {
      const s = e.text + (e.author ? `\n— ${e.author}` : '');
      try {
        if (navigator.share) await navigator.share({ text: s });
        else { await navigator.clipboard.writeText(s); toast('Copied'); }
      } catch (_) { /* cancelled */ }
    };
  }

  // ---------- Settings ----------
  function renderSettings() {
    setTitle('Settings');
    const n = store.entries.length;
    const counts = TYPES.map(t => store.entries.filter(e => e.type === t).length);
    const favs = store.entries.filter(e => e.favorite).length;
    view().innerHTML = `
      <div class="group-title">Library</div>
      <div class="section glass">
        <div class="setting"><div class="label">Entries</div><div class="stat">${n}</div></div>
        <div class="setting"><div class="sub">${counts[0]} quotes · ${counts[1]} thoughts · ${counts[2]} ideas · ${favs} favorites</div></div>
      </div>
      <div class="group-title">Data</div>
      <div class="section glass">
        <div class="setting"><div><div class="label">Export JSON</div><div class="sub">Back up, or move to the native app</div></div><button id="exportBtn">Export</button></div>
        <div class="setting"><div><div class="label">Import JSON</div><div class="sub">Merges by id; newer edits win</div></div>
          <label class="btnlike" for="importFile">Import</label><input id="importFile" type="file" accept="application/json,.json" hidden></div>
      </div>
      <div class="group-title">Appearance</div>
      <div class="section glass">
        <div class="setting"><div><div class="label">Reduce transparency</div><div class="sub">Solid surfaces instead of glass</div></div>
          <label class="switch"><input type="checkbox" id="solidToggle" ${prefs.reduceTransparency ? 'checked' : ''} aria-label="Reduce transparency"><span></span></label></div>
      </div>
      <div class="group-title">Danger zone</div>
      <div class="section glass">
        <div class="setting"><div><div class="label">Erase everything</div><div class="sub">Export first. Can’t be undone.</div></div><button class="danger" id="eraseBtn">Erase</button></div>
      </div>
      <p class="fine">Commonplace stores everything on this device only. No accounts, no servers.<br>Add to Home Screen from Safari’s Share menu for the full-screen app.</p>`;

    $('#solidToggle').onchange = ev => { prefs.reduceTransparency = ev.target.checked; savePrefs(); applyPrefs(); };
    $('#exportBtn').onclick = async () => {
      const payload = { app: 'Commonplace', version: 1, exportedAt: nowISO(), entries: store.sorted() };
      const json = JSON.stringify(payload, null, 2);
      const name = `commonplace-${new Date().toISOString().slice(0, 10)}.json`;
      const file = new File([json], name, { type: 'application/json' });
      try {
        if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], title: name }); return; }
      } catch (err) { if (err && err.name === 'AbortError') return; }
      const url = URL.createObjectURL(file);
      const a = Object.assign(document.createElement('a'), { href: url, download: name });
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 4000);
      toast(`Exported ${n} entries`);
    };
    $('#importFile').onchange = async ev => {
      const f = ev.target.files[0]; if (!f) return;
      try {
        const data = JSON.parse(await f.text());
        const list = Array.isArray(data) ? data : data.entries;
        if (!Array.isArray(list)) throw new Error('No entries array found');
        const { added, updated } = store.merge(list);
        toast(`Imported: ${added} new, ${updated} updated`);
        renderSettings();
      } catch (err) { alert('Couldn’t import that file: ' + err.message); }
      ev.target.value = '';
    };
    $('#eraseBtn').onclick = () => {
      if (!n) return toast('Already empty');
      if (confirm(`Erase all ${n} entries from this device?`) && confirm('Really erase? Export first if you want a backup.')) {
        store.entries = []; store.save(); toast('Erased'); renderSettings();
      }
    };
  }

  // ---------- Sheet mechanics ----------
  const sheetRoot = $('#sheetRoot'), sheet = $('.sheet');
  let sheetOpen = false, closeTimer = null;
  function openSheet(id) {
    clearTimeout(closeTimer);
    renderEdit(id);
    if (sheetOpen || !state.sheetClose) return;
    sheetOpen = true;
    $('#app').style.transformOrigin = `50% ${Math.round(window.scrollY + window.innerHeight * 0.3)}px`;
    sheet.style.transform = '';
    sheetRoot.hidden = false;
    document.documentElement.classList.add('sheet-lock');
    void sheet.offsetWidth; // commit start position so the slide-up animates
    requestAnimationFrame(() => document.body.classList.add('sheet-open'));
  }
  function closeSheet() {
    if (!sheetOpen) return;
    sheetOpen = false;
    if (document.activeElement && sheetRoot.contains(document.activeElement)) document.activeElement.blur();
    document.body.classList.remove('sheet-open');
    sheet.style.transform = '';
    closeTimer = setTimeout(() => {
      sheetRoot.hidden = true; $('#sheetBody').innerHTML = '';
      document.documentElement.classList.remove('sheet-lock');
    }, reduceMotion.matches ? 0 : 450);
  }
  $('.scrim').addEventListener('click', () => state.sheetClose && state.sheetClose());
  // Drag the grabber/header down to dismiss.
  (() => {
    let startY = null, dy = 0, t0 = 0;
    sheet.addEventListener('pointerdown', ev => {
      if (!ev.target.closest('.grabber, .sheet-head') || ev.target.closest('button')) return;
      startY = ev.clientY; dy = 0; t0 = performance.now();
      sheet.classList.add('dragging');
      try { sheet.setPointerCapture(ev.pointerId); } catch (_) {}
    });
    sheet.addEventListener('pointermove', ev => {
      if (startY === null) return;
      dy = Math.max(0, ev.clientY - startY);
      sheet.style.transform = `translateY(${dy}px)`;
    });
    const end = () => {
      if (startY === null) return;
      startY = null; sheet.classList.remove('dragging');
      const v = dy / Math.max(1, performance.now() - t0);
      if (dy > 120 || (v > 0.6 && dy > 30)) { state.sheetClose ? state.sheetClose() : (sheet.style.transform = ''); }
      else sheet.style.transform = '';
    };
    sheet.addEventListener('pointerup', end);
    sheet.addEventListener('pointercancel', end);
  })();

  // ---------- Tab bar ----------
  const tabbar = $('.tabbar'), indicator = $('.tab-indicator');
  let activeTab = 'home';
  function setActiveTab(tab) {
    activeTab = tab;
    tabbar.querySelectorAll('a').forEach(a => a.dataset.tab === tab ? a.setAttribute('aria-current', 'page') : a.removeAttribute('aria-current'));
    const a = tabbar.querySelector(`a[data-tab="${tab}"]`);
    if (!a) { indicator.style.opacity = '0'; return; }
    indicator.style.opacity = '1';
    indicator.style.width = a.offsetWidth + 'px';
    indicator.style.transform = `translateX(${a.offsetLeft}px)`;
  }
  window.addEventListener('resize', () => setActiveTab(activeTab));

  // ---------- Router ----------
  let rendered = false;
  function renderPage(key, returning) {
    const parts = key.replace(/^#/, '').split('/').filter(Boolean);
    let tab = 'home';
    if (parts[0] === 'search') { tab = 'search'; renderSearch(!returning); }
    else if (parts[0] === 'random') { tab = 'random'; renderRandom(returning); }
    else if (parts[0] === 'settings') { tab = 'settings'; renderSettings(); }
    else { key = '#/'; renderHome(); }
    state.underlay = key; rendered = true;
    setActiveTab(tab);
  }
  function route() {
    const h = location.hash.replace(/^#/, '') || '/';
    const parts = h.split('/').filter(Boolean);
    if (parts[0] === 'new' || parts[0] === 'edit') {
      if (!rendered) renderPage(state.underlay);
      openSheet(parts[0] === 'edit' ? decodeURIComponent(parts[1] || '') : null);
      return;
    }
    const key = '#/' + parts.join('/');
    const returning = sheetOpen && key === state.underlay;
    const y = window.scrollY;
    closeSheet();
    renderPage(key, returning);
    window.scrollTo(0, returning ? y : 0);
    onScroll();
  }

  // Large title shrinks on scroll.
  let ticking = false;
  function onScroll() { document.body.classList.toggle('scrolled', window.scrollY > 6); ticking = false; }
  window.addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });

  // iOS only applies :active styles when a touch listener exists.
  document.addEventListener('touchstart', () => {}, { passive: true });

  // Keep tabs in sync across windows/tabs.
  window.addEventListener('storage', ev => { if (ev.key === STORAGE_KEY) { store.load(); route(); } });
  window.addEventListener('hashchange', route);

  store.load();
  route();

  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
    window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(err => console.warn('SW failed', err)));
  }
})();
