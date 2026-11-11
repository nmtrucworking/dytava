import Papa from 'papaparse';
import { SAMPLE_DATASETS } from './sample-data.js';
import { AdminPortal } from './admin-portal.js';
import { AccountUI } from './account.js';
import { AdminUI } from './admin-ui.js';
import { ComparisonWorker } from './worker-client.js';
import { api, escapeHtml as e, download } from './api.js';

class App {
  constructor() {
    this.adminPortal = new AdminPortal();
    this.account = new AccountUI(this);
    this.admin = new AdminUI(this);
    this.worker = new ComparisonWorker();
    this.activeFilter = 'ALL'; this.gridPage = 0; this.busy = 0; this.runRevision = 0;
    this.user = null; this.allowRegistration = true; this.retentionDays = 30;
    this.fileA = structuredClone(SAMPLE_DATASETS.academic.fileA);
    this.fileB = structuredClone(SAMPLE_DATASETS.academic.fileB);
    this.localFiles = {}; this.parseRevisions = { A: 0, B: 0 };
    this.init();
  }
  async init() {
    this.setupTheme(); this.setupNavigation(); this.setupModals();
    this.setupFileUploads(); this.setupComparisonControls();
    this.account.setup(); this.admin.setup();
    this.populateKeyColumnOptions(); this.updateFileBadges();
    try {
      const [auth] = await Promise.all([api('/auth/me'), this.refreshConfig()]);
      this.user = auth.user; this.allowRegistration = auth.allowRegistration;
      document.getElementById('connection-status').hidden = true;
    } catch {
      document.getElementById('connection-status').hidden = false;
    }
    this.ready = true; this.updateAccount(); this.route();
    await this.runComparison();
    this.renderPublicReleases();
  }
  setupTheme() {
    let theme;
    try { theme = localStorage.getItem('dytava_theme'); } catch { /* Storage may be disabled. */ }
    document.body.classList.toggle('dark', theme === 'dark');
    const btn = document.getElementById('btn-theme-toggle');
    const update = () => { btn.textContent = document.body.classList.contains('dark') ? '☀️' : '🌙'; };
    update(); btn.onclick = () => {
      document.body.classList.toggle('dark'); update();
      try { localStorage.setItem('dytava_theme', document.body.classList.contains('dark') ? 'dark' : 'light'); } catch { /* Theme still works. */ }
    };
  }
  setupNavigation() {
    document.getElementById('nav-view-showcase').onclick = () => { location.hash = '#/'; };
    document.getElementById('nav-view-admin').onclick = () => { location.hash = '#/admin/overview'; };
    window.addEventListener('hashchange', () => { if (this.ready) this.route(); });
    document.getElementById('access-login').onclick = () => this.account.openAuth();
    document.getElementById('btn-retry-connection').onclick = () => location.reload();
  }
  route() {
    const hash = location.hash;
    let view = hash.startsWith('#/admin') ? 'admin' : hash.startsWith('#/history') ? 'history' : 'showcase';
    if (view === 'admin' && this.user?.role !== 'admin') {
      view = 'access';
      document.getElementById('access-title').textContent = this.user ? 'Tài khoản chưa có quyền quản trị' : 'Đăng nhập để quản trị';
      document.getElementById('access-description').textContent = this.user ? 'Chỉ tài khoản admin mới được xem dữ liệu vận hành và thay đổi cấu hình.' : 'Trang quản trị được bảo vệ bằng tài khoản admin.';
      document.getElementById('access-login').hidden = Boolean(this.user);
    }
    this.currentView = view;
    for (const name of ['showcase', 'admin', 'history', 'access']) document.getElementById(`view-${name}`).style.display = name === view ? 'block' : 'none';
    document.getElementById('nav-view-showcase').classList.toggle('active', view === 'showcase');
    document.getElementById('nav-view-admin').classList.toggle('active', view === 'admin');
    if (view === 'admin') { this.currentAdminTab = hash.split('/')[2] || 'overview'; this.admin.render(this.currentAdminTab); }
    if (view === 'history') this.account.renderHistory();
    if (view === 'showcase' && hash && !hash.startsWith('#/')) document.getElementById(hash.slice(1))?.scrollIntoView();
  }
  updateAccount() {
    document.getElementById('btn-account').textContent = this.user ? this.user.name : 'Đăng nhập';
    document.getElementById('btn-account').title = this.user ? 'Đổi mật khẩu' : 'Đăng nhập hoặc tạo tài khoản';
    document.getElementById('btn-logout').hidden = !this.user;
    this.updateSaveButton();
  }
  isEnabled(id) {
    return this.config ? this.config.flags.find(f => f.id === id)?.enabled === true : id !== 'FLAG_HISTORY';
  }
  async refreshConfig() {
    this.config = await api('/config'); this.retentionDays = this.config.retentionDays;
    const select = document.getElementById('opt-policy'); const previous = select.value;
    select.innerHTML = '<option value="">Cấu hình tùy chỉnh</option>' + this.config.policies.map(policy => `<option value="${e(policy.id)}">${e(policy.name)} · r${policy.revision}</option>`).join('');
    if (this.config.policies.some(p => p.id === previous)) select.value = previous;
    const uploads = this.isEnabled('FLAG_OFFLINE_XLSX_CSV');
    document.querySelectorAll('.upload-box').forEach(el => { el.classList.toggle('disabled', !uploads); el.setAttribute('aria-disabled', String(!uploads)); });
    document.querySelectorAll('input[type=file]').forEach(el => { el.disabled = !uploads; });
    const key = document.getElementById('opt-key-column'); key.disabled = !this.isEnabled('FLAG_KEY_ALIGNMENT');
    if (key.disabled) key.value = '';
    for (const id of ['btn-export-csv', 'btn-export-json']) document.getElementById(id).disabled = !this.isEnabled('FLAG_REPORT_EXPORT');
    this.updateSaveButton();
  }
  setupModals() {
    document.querySelectorAll('.modal-overlay').forEach(modal => {
      modal.setAttribute('role', 'dialog'); modal.setAttribute('aria-modal', 'true'); modal.setAttribute('tabindex', '-1');
      modal.addEventListener('click', event => { if (event.target === modal || event.target.closest('.btn-close-modal')) this.closeModals(); });
    });
    document.addEventListener('keydown', event => {
      const modal = document.querySelector('.modal-overlay.open'); if (!modal) return;
      if (event.key === 'Escape') this.closeModals();
      if (event.key !== 'Tab') return;
      const elements = [...modal.querySelectorAll('button, input, select, textarea, a[href]')].filter(el => !el.disabled && el.getClientRects().length);
      const first = elements[0], last = elements.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    });
  }
  openModal(id) {
    const already = document.querySelector('.modal-overlay.open');
    if (!already) this.modalOpener = document.activeElement;
    document.querySelectorAll('.modal-overlay.open').forEach(el => el.classList.remove('open'));
    const modal = document.getElementById(id); modal.classList.add('open'); document.body.classList.add('modal-open');
    setTimeout(() => ([...modal.querySelectorAll('input:not([disabled]), textarea, button')].find(el => el.getClientRects().length) || modal).focus(), 0);
  }
  closeModals() {
    document.querySelectorAll('.modal-overlay.open').forEach(el => el.classList.remove('open'));
    document.body.classList.remove('modal-open'); this.modalOpener?.focus();
  }
  setupFileUploads() {
    for (const side of ['a', 'b']) {
      const zone = document.getElementById(`dropzone-${side}`), input = document.getElementById(`file-input-${side}`);
      zone.tabIndex = 0; zone.setAttribute('role', 'button'); zone.setAttribute('aria-label', `Chọn tệp nguồn ${side.toUpperCase()}`);
      zone.onclick = event => { if (event.target !== input && this.isEnabled('FLAG_OFFLINE_XLSX_CSV')) input.click(); };
      zone.onkeydown = event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); if (!input.disabled) input.click(); } };
      zone.ondragover = event => { event.preventDefault(); zone.classList.add('drag-over'); };
      zone.ondragleave = () => zone.classList.remove('drag-over');
      zone.ondrop = event => { event.preventDefault(); zone.classList.remove('drag-over'); if (event.dataTransfer.files[0]) this.loadFile(event.dataTransfer.files[0], side.toUpperCase()); };
      input.onchange = () => { if (input.files[0]) this.loadFile(input.files[0], side.toUpperCase()); input.value = ''; };
      document.getElementById(`sheet-${side}`).onchange = event => this.loadFile(this.localFiles[side.toUpperCase()], side.toUpperCase(), event.target.value);
    }
    document.getElementById('sample-dataset-select').onchange = event => {
      const sample = SAMPLE_DATASETS[event.target.value]; if (!sample) return;
      this.parseRevisions.A++; this.parseRevisions.B++;
      this.fileA = structuredClone(sample.fileA); this.fileB = structuredClone(sample.fileB); this.localFiles = {};
      this.updateFileBadges(); this.populateKeyColumnOptions(); this.runComparison();
    };
  }
  async loadFile(file, side, sheetName) {
    if (!file || !this.isEnabled('FLAG_OFFLINE_XLSX_CSV')) return this.showToast('Nhập tệp đang tạm tắt.', 'error');
    const revision = ++this.parseRevisions[side]; this.setBusy(1);
    try {
      const result = await this.worker.call({ type: 'parse', file, sheetName });
      if (revision !== this.parseRevisions[side]) return;
      this[`file${side}`] = result; this.localFiles[side] = file;
      this.updateFileBadges(); this.populateKeyColumnOptions(); await this.runComparison();
      this.showToast(`Đã đọc ${file.name}: ${result.rows.length} dòng.`);
    } catch (error) { if (revision === this.parseRevisions[side]) this.showToast(error.message, 'error'); }
    finally { this.setBusy(-1); }
  }
  updateFileBadges() {
    for (const side of ['A', 'B']) {
      const file = this[`file${side}`];
      document.getElementById(`file-badge-${side.toLowerCase()}`).textContent = `${file.name} (${file.rows.length} hàng)`;
      document.getElementById(`label-table-${side.toLowerCase()}`).textContent = file.sheetName || file.name;
      const sheet = document.getElementById(`sheet-${side.toLowerCase()}`); sheet.hidden = !file.sheets || file.sheets.length < 2;
      sheet.innerHTML = (file.sheets || []).map(name => `<option value="${e(name)}">${e(name)}</option>`).join(''); sheet.value = file.sheetName || '';
    }
  }
  populateKeyColumnOptions() {
    const select = document.getElementById('opt-key-column'); const previous = select.value;
    const headers = this.fileA.headers.filter(h => this.fileB.headers.includes(h));
    select.innerHTML = '<option value="">Căn chỉnh theo thứ tự dòng</option>' + headers.map(h => `<option value="${e(h)}">Cột khóa: ${e(h)}</option>`).join('');
    const guess = headers.find(h => /mã|^id$|code|sku/i.test(h));
    select.value = headers.includes(previous) ? previous : guess || '';
    if (!this.isEnabled('FLAG_KEY_ALIGNMENT')) select.value = '';
  }
  setupComparisonControls() {
    document.getElementById('btn-run-compare').onclick = () => this.runComparison();
    document.getElementById('btn-export-json').onclick = () => this.exportJsonReport();
    document.getElementById('btn-export-csv').onclick = () => this.exportCsvDiff();
    for (const id of ['opt-key-column', 'opt-tolerance', 'opt-leading-zeros', 'opt-case-sensitive', 'opt-trim', 'opt-identifier-case', 'opt-null-zero']) document.getElementById(id).onchange = () => { document.getElementById('opt-policy').value = ''; this.runComparison(); };
    document.getElementById('opt-policy').onchange = event => {
      const policy = this.config?.policies.find(p => p.id === event.target.value);
      if (policy) {
        document.getElementById('opt-tolerance').value = policy.config.tolerance_abs;
        for (const [id, key] of [['opt-leading-zeros', 'preserve_leading_zeros'], ['opt-case-sensitive', 'case_sensitive_text'], ['opt-trim', 'trim_text'], ['opt-identifier-case', 'case_sensitive_identifier'], ['opt-null-zero', 'distinct_null_zero']]) document.getElementById(id).checked = policy.config[key];
      }
      this.runComparison();
    };
    document.querySelectorAll('.stat-cell').forEach(cell => cell.onclick = () => {
      document.querySelectorAll('.stat-cell').forEach(el => el.classList.remove('active-filter')); cell.classList.add('active-filter');
      this.activeFilter = cell.dataset.filter || 'ALL'; this.gridPage = 0; this.renderDualGrid();
    });
    document.getElementById('grid-prev').onclick = () => { this.gridPage = Math.max(0, this.gridPage - 1); this.renderDualGrid(); };
    document.getElementById('grid-next').onclick = () => { this.gridPage++; this.renderDualGrid(); };
  }
  setBusy(delta) {
    this.busy = Math.max(0, this.busy + delta);
    const button = document.getElementById('btn-run-compare'); button.disabled = Boolean(this.busy); button.textContent = this.busy ? 'Đang xử lý…' : '⚡ Chạy so sánh';
    document.getElementById('compare-status').textContent = this.busy ? 'Đang xử lý cục bộ trong trình duyệt…' : '';
    this.updateSaveButton();
  }
  updateSaveButton() {
    const button = document.getElementById('btn-save-session');
    const saved = this.currentComparisonResult?.metadata.clientId === this.savedClientId && Boolean(this.savedClientId);
    button.disabled = Boolean(this.busy) || !this.currentComparisonResult || saved || !this.isEnabled('FLAG_HISTORY');
    button.textContent = saved ? '✓ Đã lưu thống kê' : 'Lưu thống kê phiên';
  }
  async runComparison() {
    const revision = ++this.runRevision;
    const tolerance = Number(document.getElementById('opt-tolerance').value);
    if (!Number.isFinite(tolerance) || tolerance < 0 || tolerance > 1e9) return this.showToast('Dung sai phải từ 0 đến 1.000.000.000.', 'error');
    const policyConfig = {
      tolerance_abs: tolerance, preserve_leading_zeros: document.getElementById('opt-leading-zeros').checked,
      case_sensitive_identifier: document.getElementById('opt-identifier-case').checked,
      case_sensitive_text: document.getElementById('opt-case-sensitive').checked,
      trim_text: document.getElementById('opt-trim').checked, distinct_null_zero: document.getElementById('opt-null-zero').checked
    };
    const policyId = document.getElementById('opt-policy').value || 'web-custom-policy';
    const fileA = this.fileA, fileB = this.fileB;
    const keyColumn = this.isEnabled('FLAG_KEY_ALIGNMENT') ? document.getElementById('opt-key-column').value || null : null;
    this.currentComparisonResult = null; this.updateSaveButton();
    this.setBusy(1); const start = performance.now();
    try {
      const result = await this.worker.call({ type: 'compare', fileA, fileB, policy: { ...policyConfig, policy_id: policyId }, keyColumn });
      if (revision !== this.runRevision) return;
      result.metadata = { clientId: crypto.randomUUID(), formatA: fileA.format, formatB: fileB.format, rowsA: fileA.rows.length, rowsB: fileB.rows.length, durationMs: Math.round((performance.now() - start) * 100) / 100, policyId, policyConfig, summary: result.summary };
      this.currentComparisonResult = result; this.gridPage = 0; this.updateSummaryCounters(); this.renderDualGrid();
      document.getElementById('comparison-error').textContent = '';
    } catch (error) {
      if (revision === this.runRevision) {
        this.currentComparisonResult = null;
        document.getElementById('comparison-error').textContent = error.message;
        for (const side of ['a', 'b']) document.getElementById(`table-container-${side}`).textContent = 'Không thể so sánh với cấu hình hiện tại.';
        for (const id of ['cnt-total', 'cnt-exact', 'cnt-equiv', 'cnt-diff', 'cnt-unres', 'cnt-added-removed']) document.getElementById(id).textContent = '—';
        this.showToast(error.message, 'error');
      }
    } finally { this.setBusy(-1); }
  }
  updateSummaryCounters() {
    const summary = this.currentComparisonResult.summary;
    for (const [id, key] of [['cnt-total', 'total_cells_checked'], ['cnt-exact', 'exact'], ['cnt-equiv', 'equivalent'], ['cnt-diff', 'different'], ['cnt-unres', 'unresolved']]) document.getElementById(id).textContent = summary[key];
    document.getElementById('cnt-added-removed').textContent = `+${summary.added_rows} / -${summary.removed_rows}`;
  }
  renderDualGrid() {
    if (!this.currentComparisonResult) return;
    const { headers, alignedRows } = this.currentComparisonResult;
    const filtered = alignedRows.filter(row => this.activeFilter === 'ALL' || (this.activeFilter === 'ROWS' ? ['ADDED', 'REMOVED'].includes(row.rowStatus) : row.rowStatus === this.activeFilter));
    this.gridPage = Math.min(this.gridPage, Math.max(0, Math.ceil(filtered.length / 100) - 1));
    const rows = filtered.slice(this.gridPage * 100, (this.gridPage + 1) * 100);
    for (const side of ['A', 'B']) {
      const pane = document.getElementById(`table-container-${side.toLowerCase()}`);
      pane.innerHTML = `<table class="diff-table"><thead><tr><th>#</th>${headers.map(h => `<th>${e(h)}</th>`).join('')}</tr></thead><tbody>${rows.map((row, i) => `<tr class="${row.rowStatus === 'ADDED' ? 'row-added' : row.rowStatus === 'REMOVED' ? 'row-removed' : ''}"><td>${this.gridPage * 100 + i + 1}</td>${headers.map((h, field) => {
        const value = row[`row${side}`]?.[this[`file${side}`].headers.indexOf(h)] ?? '';
        const status = row.cellComparisons[h]?.status;
        const classes = { EXACT: 'cell-exact', EQUIVALENT: 'cell-equiv', DIFFERENT: 'cell-diff', UNRESOLVED: 'cell-unres' };
        return `<td class="${classes[status] || ''}" tabindex="0" data-row="${i}" data-field="${field}">${value === '' ? '<i class="empty-cell">—</i>' : e(value)}</td>`;
      }).join('')}</tr>`).join('') || `<tr><td colspan="${headers.length + 1}" class="empty-state">Không có dòng phù hợp.</td></tr>`}</tbody></table>`;
      pane.querySelectorAll('[data-row]').forEach(td => {
        const inspect = () => { const row = rows[Number(td.dataset.row)]; const field = headers[Number(td.dataset.field)]; if (row.cellComparisons[field]) this.openInspectorModal(field, row.key, row.cellComparisons[field]); };
        td.onclick = inspect; td.onkeydown = event => { if (event.key === 'Enter') inspect(); };
      });
    }
    document.getElementById('grid-page-label').textContent = `${filtered.length ? this.gridPage * 100 + 1 : 0}–${Math.min((this.gridPage + 1) * 100, filtered.length)} / ${filtered.length} dòng`;
    document.getElementById('grid-prev').disabled = this.gridPage === 0;
    document.getElementById('grid-next').disabled = (this.gridPage + 1) * 100 >= filtered.length;
    const a = document.getElementById('table-container-a'), b = document.getElementById('table-container-b');
    let lock = false;
    const sync = (from, to) => { if (lock) return; lock = true; to.scrollTop = from.scrollTop; to.scrollLeft = from.scrollLeft; requestAnimationFrame(() => { lock = false; }); };
    a.onscroll = () => sync(a, b); b.onscroll = () => sync(b, a);
  }
  openInspectorModal(field, key, comparison) {
    const values = { 'insp-field-name': field, 'insp-row-key': `Khóa: ${key}`, 'insp-status-badge': comparison.status, 'insp-raw-a': comparison.rawA, 'insp-raw-b': comparison.rawB, 'insp-norm-a': comparison.normA, 'insp-norm-b': comparison.normB, 'insp-type': comparison.type, 'insp-rule-id': comparison.ruleId, 'insp-reason': comparison.reason };
    for (const [id, value] of Object.entries(values)) document.getElementById(id).textContent = value ?? '(Trống)';
    this.openModal('cell-inspector-modal');
  }
  exportJsonReport() {
    if (!this.currentComparisonResult || !this.isEnabled('FLAG_REPORT_EXPORT')) return;
    download(this.currentComparisonResult.report, `dytava-${Date.now()}.json`); this.showToast('Đã xuất báo cáo JSON.');
  }
  exportCsvDiff() {
    if (!this.currentComparisonResult || !this.isEnabled('FLAG_REPORT_EXPORT')) return;
    const { headers, alignedRows } = this.currentComparisonResult;
    const rows = alignedRows.filter(row => !['EXACT', 'EQUIVALENT'].includes(row.rowStatus)).map(row => [row.key, row.rowStatus, ...headers.map(h => String(row.rowA?.[this.fileA.headers.indexOf(h)] ?? '')), ...headers.map(h => String(row.rowB?.[this.fileB.headers.indexOf(h)] ?? ''))]);
    const csv = Papa.unparse({ fields: ['Key', 'Status', ...headers.map(h => `${h} (A)`), ...headers.map(h => `${h} (B)`)], data: rows }, { escapeFormulae: /^[\s]*[=+\-@\t\r\n]/, quotes: true });
    download(`\uFEFF${csv}`, `differences-${Date.now()}.csv`, 'text/csv;charset=utf-8'); this.showToast('Đã xuất CSV khác biệt.');
  }
  async renderPublicReleases() {
    const container = document.getElementById('public-releases');
    try {
      const { items } = await api('/releases');
      container.innerHTML = items.map(row => `<article class="metric-card"><h3>${e(row.product)} <small>v${e(row.version)}</small></h3><p>${e(row.platform)} · ${e(row.stage)} · ${e(row.size)}</p><p class="release-changelog">${e(row.changelog)}</p><a class="btn btn-outline btn-sm" href="${e(row.downloadUrl)}" target="_blank" rel="noopener noreferrer">Tải bản phát hành</a><details><summary>SHA256</summary><code class="checksum">${e(row.sha256)}</code></details></article>`).join('') || '<p class="empty-state">Chưa có bản phát hành được công bố. Bạn có thể dùng công cụ so sánh web ngay phía trên.</p>';
    } catch { container.textContent = 'Chưa tải được danh sách phát hành. Vui lòng thử lại sau.'; }
  }
  showToast(text, type = 'info') {
    let container = document.getElementById('toast-container');
    if (!container) { container = document.createElement('div'); container.id = 'toast-container'; container.className = 'toast-container'; container.setAttribute('role', 'status'); document.body.appendChild(container); }
    const toast = document.createElement('div'); toast.className = `toast ${type === 'error' ? 'toast-error' : ''}`; toast.textContent = text; container.appendChild(toast);
    setTimeout(() => toast.remove(), 5000);
  }
}

document.addEventListener('DOMContentLoaded', () => { window.dytavaApp = new App(); });
