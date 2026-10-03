(function () {
  var root = document.documentElement;
  var toggle = document.getElementById('theme-toggle');
  if (!toggle) return;

  toggle.addEventListener('click', function () {
    var current = root.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
    var next = current === 'light' ? 'dark' : 'light';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem('theme', next); } catch (e) {}
  });
})();

/* ---- Home page: category + keyword post filter ---- */
(function () {
  var root = document.getElementById('post-filter');
  if (!root) return;

  var cards   = Array.prototype.slice.call(document.querySelectorAll('#posts-list .post-card'));
  var chips   = Array.prototype.slice.call(root.querySelectorAll('.chip'));
  var input   = document.getElementById('filter-q');
  var clear   = document.getElementById('filter-clear');
  var count   = document.getElementById('filter-count');
  var empty   = document.getElementById('filter-empty');
  var yearSel = document.getElementById('filter-year');
  var cat = 'all', q = '', yr = 'all';

  function tokens(card) {
    return (card.getAttribute('data-tags') || '').split(/\s+/);
  }

  function apply() {
    var shown = 0;
    cards.forEach(function (card) {
      var matchCat  = cat === 'all' || tokens(card).indexOf(cat) !== -1;
      var matchQ    = q === '' || (card.getAttribute('data-text') || '').indexOf(q) !== -1;
      var matchYear = yr === 'all' || card.getAttribute('data-year') === yr;
      var show = matchCat && matchQ && matchYear;
      card.hidden = !show;
      if (show) shown++;
    });
    if (empty) empty.hidden = shown !== 0;
    if (count) {
      count.textContent = (cat === 'all' && q === '' && yr === 'all')
        ? cards.length + ' posts'
        : 'Showing ' + shown + ' of ' + cards.length;
    }
    if (clear) clear.hidden = q === '';
    sync();
  }

  function sync() {
    var p = new URLSearchParams();
    if (cat !== 'all') p.set('cat', cat);
    if (q !== '') p.set('q', q);
    if (yr !== 'all') p.set('year', yr);
    var qs = p.toString();
    history.replaceState(null, '', qs ? '?' + qs : location.pathname);
  }

  function setCat(next) {
    cat = next;
    chips.forEach(function (c) {
      var on = c.getAttribute('data-cat') === cat;
      c.classList.toggle('is-active', on);
      c.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    apply();
  }

  chips.forEach(function (c) {
    c.setAttribute('aria-pressed', c.classList.contains('is-active') ? 'true' : 'false');
    c.addEventListener('click', function () { setCat(c.getAttribute('data-cat')); });
  });

  if (input) {
    input.addEventListener('input', function () {
      q = input.value.trim().toLowerCase();
      apply();
    });
  }
  if (clear) {
    clear.addEventListener('click', function () {
      input.value = ''; q = ''; apply(); input.focus();
    });
  }
  if (yearSel) {
    yearSel.addEventListener('change', function () {
      yr = yearSel.value || 'all';
      apply();
    });
  }

  // Restore state from the URL (so a filtered view is shareable / survives reload)
  var params = new URLSearchParams(location.search);
  var urlCat = params.get('cat');
  var urlQ = params.get('q');
  var urlYear = params.get('year');
  if (urlQ) { q = urlQ.toLowerCase(); if (input) input.value = urlQ; }
  if (urlYear && yearSel && Array.prototype.some.call(yearSel.options, function (o) { return o.value === urlYear; })) {
    yr = urlYear; yearSel.value = urlYear;
  }
  if (urlCat && chips.some(function (c) { return c.getAttribute('data-cat') === urlCat; })) {
    setCat(urlCat);
  } else {
    apply();
  }
})();
