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
