(function () {
  'use strict';

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) {
        reg.unregister();
      });
    });
  }

  var params = new URLSearchParams(window.location.search);
  var lang = params.get('lang') === 'ar' ? 'ar' : 'en';

  document.documentElement.lang = lang;
  document.body.dir = lang === 'ar' ? 'rtl' : 'ltr';

  document.querySelectorAll('.lang-panel').forEach(function (panel) {
    panel.hidden = panel.getAttribute('data-lang') !== lang;
  });

  document.querySelectorAll('[data-lang-btn]').forEach(function (btn) {
    btn.classList.toggle('active', btn.getAttribute('data-lang-btn') === lang);
  });

  var subtitleEn = document.getElementById('header-subtitle-en');
  var subtitleAr = document.getElementById('header-subtitle-ar');
  if (subtitleEn && subtitleAr) {
    subtitleEn.hidden = lang === 'ar';
    subtitleAr.hidden = lang !== 'ar';
  }
})();
