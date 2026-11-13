/* Optional dashboard adapter: immutable failed-case bindings, no browser commands. */
(function (root) {
  'use strict';
  function binding(catalog, href, base) {
    const url = new URL(href, base);
    if (!url.pathname.endsWith('/chk_test_errors.cgi')) return null;
    if (url.searchParams.getAll('log').length !== 1 || url.searchParams.getAll('arg').length !== 1) return null;
    return catalog.failures.find(function (entry) {
      const deployment = new URL(entry.dashboard_url);
      return /^[0-9a-f]{64}$/.test(entry.id) && url.origin === deployment.origin &&
        url.pathname === deployment.pathname + 'cgi-bin/chk_test_errors.cgi' &&
        // The legacy CGI restores '+' after query decoding (its links predate encoding).
        url.searchParams.get('log').replace(/ /g, '+') === entry.log && url.searchParams.get('arg') === entry.test;
    }) || null;
  }
  function decorate(document, catalog, identities) {
    if (catalog.schema !== 'cti-dashboard-links/v1' || !Array.isArray(catalog.failures)) throw new Error('Invalid CTI link catalog');
    if (!identities || identities.schema !== 'cti-dashboard-identities/v1' || !identities.matches) throw new Error('Run identities unavailable');
    const bindings = new Set();
    catalog.failures.forEach(function (entry) {
      const deployment = new URL(entry.dashboard_url);
      const identity = JSON.stringify([entry.dashboard_url, entry.log, entry.test]);
      if (!/^[0-9a-f]{64}$/.test(entry.id) || !['http:', 'https:'].includes(deployment.protocol) ||
          !/^[0-9a-f]{64}$/.test(entry.log_sha256) || typeof entry.log !== 'string' || typeof entry.test !== 'string' || bindings.has(identity)) {
        throw new Error('Invalid or ambiguous CTI failure binding');
      }
      bindings.add(identity);
    });
    document.querySelectorAll('a[href]').forEach(function (anchor) {
      if (anchor.dataset.ctiSession) return;
      const entry = binding(catalog, anchor.href, document.baseURI);
      if (!entry) return;
      if (identities.matches[entry.id] !== entry.log_sha256) return;
      const details = document.createElement('a');
      details.href = anchor.href;
      details.textContent = ' [details]';
      details.dataset.ctiSession = 'details';
      anchor.insertAdjacentElement('afterend', details);
      anchor.href = 'opencti-session://failure/' + entry.id;
      anchor.title = 'Open preserved failure in Terminal (private Docker session)';
      anchor.dataset.ctiSession = entry.id;
    });
    // The case-details page itself has no self-link; add an explicit Terminal action.
    const current = binding(catalog, document.location.href, document.baseURI);
    if (current && identities.matches[current.id] === current.log_sha256 && !document.getElementById('cti-open-terminal')) {
      const action = document.createElement('a');
      action.id = 'cti-open-terminal';
      action.href = 'opencti-session://failure/' + current.id;
      action.textContent = 'Open preserved failure in Terminal';
      const paragraph = document.createElement('p');
      paragraph.appendChild(action);
      document.body.prepend(paragraph);
    }
  }
  if (typeof module !== 'undefined') module.exports = {binding: binding, decorate: decorate};
  if (!root.document) return;
  const script = root.document.currentScript;
  const source = new URL(script.dataset.catalog, root.document.baseURI);
  if (source.origin !== root.location.origin) return;
  const identitySource = new URL('./cti-session-identity.cgi', root.document.baseURI);
  function read(url) {
    return root.fetch(url, {credentials: 'same-origin', cache: 'no-store'})
      .then(function (response) {if (!response.ok) throw new Error('CTI catalog/identity unavailable'); return response.json();});
  }
  Promise.all([read(source.href), read(identitySource.href)])
    .then(function (results) {decorate(root.document, results[0], results[1]);})
    .catch(function (error) {root.console.warn('CTI Terminal links unavailable; existing details links retained.', error);});
}(typeof window === 'undefined' ? globalThis : window));
