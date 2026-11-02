/* transpectUI – Interaktionen (Vanilla JS, keine Abhängigkeiten) */

/* ---------- WebSocket (Server-Push, /ws/data) ---------- */
const wsDataHref = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws/data';
let wsData = null;
let wsRetry = 0;
let username;

function wsConnect() {
  try { wsData = new WebSocket(wsDataHref); } catch (e) { return; }
  wsData.addEventListener('message', () => { /* Datenkanal – derzeit nur Heartbeat */ });
  wsData.addEventListener('close', () => {
    wsRetry += 1;
    if (wsRetry < 5) setTimeout(wsConnect, 5000 * wsRetry);
  });
  wsData.addEventListener('open', () => {
    wsRetry = 0;
    setInterval(() => {
      if (wsData && wsData.readyState === 1 && username) wsData.send('HEARTBEAT:' + username);
    }, 15000);
  });
}

/* ---------- Hilfen ---------- */
function formatSize(bytes) {
  if (bytes >= 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1).replace('.', ',') + ' MB';
  if (bytes >= 1024) return Math.round(bytes / 1024) + ' KB';
  return bytes + ' B';
}

/* ---------- Datei-Dropzone ---------- */
function renderSelectedFile(zone, input, file) {
  zone.classList.add('is-selected');
  const view = document.createElement('div');
  view.className = 'tx-file-selected';
  view.innerHTML =
    '<span class="tx-file-icon" aria-hidden="true">' + zone.dataset.fileIcon + '</span>' +
    '<div><strong></strong><span></span></div>' +
    '<span class="tx-file-actions"></span>';
  view.querySelector('strong').textContent = file.name;
  view.querySelector('div > span').textContent = formatSize(file.size);

  const actions = view.querySelector('.tx-file-actions');

  const replaceBtn = document.createElement('button');
  replaceBtn.type = 'button';
  replaceBtn.className = 'tx-btn tx-btn--secondary';
  replaceBtn.textContent = 'Ersetzen';
  replaceBtn.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); input.click(); });

  const removeBtn = document.createElement('button');
  removeBtn.type = 'button';
  removeBtn.className = 'tx-icon-btn tx-icon-btn--danger';
  removeBtn.setAttribute('aria-label', 'Datei entfernen');
  removeBtn.innerHTML = zone.dataset.iconX;
  removeBtn.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    input.value = '';
    resetZone(zone, input);
  });

  actions.append(replaceBtn, removeBtn);
  zone.querySelectorAll(':scope > *:not(input)').forEach((n) => n.remove());
  zone.appendChild(view);
}

function resetZone(zone, input) {
  zone.classList.remove('is-selected');
  zone.querySelectorAll(':scope > *:not(input)').forEach((n) => n.remove());
  zone.insertAdjacentHTML('beforeend', zone.dataset.idleHtml);
  updateSubmit(zone, input);
}

function updateSubmit(zone, input) {
  const form = input.closest('form');
  if (!form) return;
  const submit = form.querySelector('button[type="submit"]');
  if (!submit) return;
  const hasFile = input.files && input.files.length > 0;
  if (hasFile) { submit.removeAttribute('disabled'); submit.classList.remove('is-disabled'); }
  else { submit.setAttribute('disabled', ''); submit.classList.add('is-disabled'); }
}

function initDropzone() {
  const zone = document.getElementById('dropZone');
  if (!zone) return;
  const input = zone.querySelector('input[type="file"]');
  if (!input) return;

  zone.dataset.idleHtml = '';
  Array.from(zone.children).forEach((n) => {
    if (n !== input) { zone.dataset.idleHtml += n.outerHTML; }
  });
  zone.dataset.fileIcon = zone.dataset.fileIcon ||
    '<svg viewBox="0 0 24 24" width="25" height="25" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>';
  zone.dataset.iconX = zone.dataset.iconX ||
    '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';

  input.addEventListener('change', () => {
    if (input.files && input.files.length > 0) renderSelectedFile(zone, input, input.files[0]);
    else resetZone(zone, input);
    updateSubmit(zone, input);
  });

  zone.addEventListener('dragover', (e) => { e.preventDefault(); zone.classList.add('is-dragging'); });
  zone.addEventListener('dragleave', () => zone.classList.remove('is-dragging'));
  zone.addEventListener('drop', (e) => {
    e.preventDefault();
    zone.classList.remove('is-dragging');
    const file = e.dataTransfer.files[0];
    if (!file) return;
    const dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
    renderSelectedFile(zone, input, file);
    updateSubmit(zone, input);
  });

  updateSubmit(zone, input);
}

/* ---------- Benutzer-Menü (Popover) ---------- */
function initUserMenu() {
  const menu = document.querySelector('.tx-user-menu');
  if (!menu) return;
  const trigger = menu.querySelector('.tx-user-trigger');
  trigger.addEventListener('click', (e) => {
    e.stopPropagation();
    menu.classList.toggle('is-open');
    trigger.setAttribute('aria-expanded', menu.classList.contains('is-open'));
  });
  document.addEventListener('click', (e) => {
    if (!menu.contains(e.target)) menu.classList.remove('is-open');
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') menu.classList.remove('is-open');
  });
}

/* ---------- Mobile-Navigation ---------- */
function initMobileNav() {
  const header = document.querySelector('.tx-header');
  const btn = document.querySelector('.tx-mobile-menu');
  if (!header || !btn) return;
  btn.addEventListener('click', () => header.classList.toggle('is-nav-open'));
}

/* ---------- Protokoll: automatisch nach unten scrollen ---------- */
function initLogScroll() {
  const log = document.querySelector('.tx-log');
  if (log) log.scrollTop = log.scrollHeight;
}

/* ---------- Start ---------- */
window.addEventListener('load', () => {
  username = document.querySelector('.tx-user-name') ? document.querySelector('.tx-user-name').textContent : null;
  initDropzone();
  initUserMenu();
  initMobileNav();
  initLogScroll();
  wsConnect();
}, false);
