;(function () {
  try {
    var root = document.documentElement
    var theme = localStorage.getItem('cs-console.theme') || 'light'
    var dark =
      theme === 'dark' || (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    root.classList.toggle('dark', dark)
    if (localStorage.getItem('cs-console.density') === 'compact') root.dataset.density = 'compact'
  } catch (_) {}
})()
