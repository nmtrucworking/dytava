import { api, escapeHtml as e, dateTime, download, message } from './api.js';

const policyLabels = { preserve_leading_zeros: 'Giữ số 0 đầu mã', case_sensitive_identifier: 'Phân biệt hoa/thường ở mã', case_sensitive_text: 'Phân biệt hoa/thường ở văn bản', trim_text: 'Loại khoảng trắng thừa', distinct_null_zero: 'Phân biệt ô trống và số 0' };
export class AdminUI {
  constructor(app) { this.app = app; this.auditOffset = 0; this.releaseEditId = null; }
  setup() {
    document.querySelectorAll('.admin-nav-item').forEach(item => item.addEventListener('click', () => { location.hash = `#/admin/${item.dataset.tab}`; }));
    document.getElementById('btn-open-add-release').onclick = () => this.openRelease();
    document.getElementById('form-add-release').onsubmit = event => this.saveRelease(event);
    document.getElementById('btn-run-acceptance-tests').onclick = () => this.renderAcceptance(true);
    document.getElementById('btn-test-policy-single').onclick = () => this.testPolicy();
    document.getElementById('form-policy').onsubmit = event => this.savePolicy(event);
  }
  async render(tab) {
    if (this.app.user?.role !== 'admin') return;
    const allowed = ['overview', 'releases', 'policies', 'acceptance', 'audit', 'flags'];
    if (!allowed.includes(tab)) { location.hash = '#/admin/overview'; return; }
    document.querySelectorAll('.admin-nav-item').forEach(item => item.classList.toggle('active', item.dataset.tab === tab));
    document.querySelectorAll('.admin-tab-panel').forEach(panel => { panel.style.display = panel.id === `tab-panel-${tab}` ? 'block' : 'none'; });
    const errorBox = document.getElementById('admin-error'); message(errorBox, '');
    try {
      if (tab === 'overview') await this.renderOverview();
      if (tab === 'releases') await this.renderReleases();
      if (tab === 'policies') { await this.app.refreshConfig(); this.renderPolicies(); }
      if (tab === 'acceptance') this.renderAcceptance(false);
      if (tab === 'audit') await this.renderAudit();
      if (tab === 'flags') { await this.app.refreshConfig(); this.renderFlags(); }
    } catch (error) {
      message(errorBox, error.message, true);
      if (error.status === 401) { this.app.user = null; this.app.updateAccount(); this.app.route(); }
    }
  }
  async renderOverview() {
    const panel = document.getElementById('tab-panel-overview');
    panel.innerHTML = '<p>Đang tải số liệu…</p>';
    const data = await api('/admin/overview');
    const ratio = value => data.cells ? `${(value / data.cells * 100).toFixed(1)}%` : '—';
    const totalFormats = data.formats.reduce((n, f) => n + f.count, 0);
    panel.innerHTML = `<div class="admin-title-row"><div><h2>Trung tâm quản trị</h2><p class="privacy-note">Thống kê do người dùng chủ động lưu trong ${data.retentionDays} ngày gần nhất. Không bao gồm mọi lượt sử dụng; không xác minh nội dung tệp.</p></div><button id="refresh-overview" class="btn btn-primary btn-sm">Làm mới dữ liệu</button></div>
      <div class="metrics-row">${[['Phiên đã lưu', data.comparisons, `${data.users} tài khoản · ${data.releases} bản phát hành`], ['Tỷ lệ tương đương', ratio(data.equivalent), `${data.equivalent} / ${data.cells} ô đã đối chiếu`], ['Tỷ lệ chờ duyệt', ratio(data.unresolved), `${data.unresolved} ô mơ hồ`], ['Thời gian trung bình', `${data.averageDurationMs.toFixed(1)} ms`, 'Thời gian engine do trình duyệt ghi nhận']].map(([label, value, note]) => `<div class="metric-card"><div class="metric-label">${e(label)}</div><div class="metric-val">${e(value)}</div><p class="privacy-note">${e(note)}</p></div>`).join('')}</div>
      <div class="dashboard-grid"><div class="metric-card"><h3>Định dạng đầu vào</h3>${data.formats.map(f => `<div class="format-row"><span>${e(f.format.toUpperCase())}</span><div class="format-track"><div style="width:${f.count / totalFormats * 100}%"></div></div><strong>${f.count}</strong></div>`).join('') || '<p class="empty-state">Chưa có thống kê được lưu.</p>'}</div>
      <div class="metric-card"><h3>Phiên được lưu gần đây</h3>${data.recent.map(row => `<div class="recent-row"><span>${e(row.formatA.toUpperCase())} ↔ ${e(row.formatB.toUpperCase())} · ${row.rowsA} / ${row.rowsB} dòng</span><small>${e(dateTime(row.createdAt))}</small></div>`).join('') || '<p class="empty-state">Chưa có phiên được lưu.</p>'}</div></div>`;
    document.getElementById('refresh-overview').onclick = () => this.render('overview');
  }
  async renderReleases() {
    const body = document.getElementById('tbody-releases'); body.innerHTML = '<tr><td colspan="8">Đang tải…</td></tr>';
    const { items } = await api('/releases'); this.releases = items;
    body.innerHTML = items.map(row => `<tr><td><strong>${e(row.product)}</strong></td><td>${e(row.platform)}</td><td><code>${e(row.version)}</code></td><td>${e(row.stage)}</td><td>${e(row.size)}</td><td><code title="${row.sha256}">${row.sha256.slice(0, 12)}…</code></td><td>${e(row.releaseDate)}</td><td><button class="btn btn-outline btn-sm" data-edit-release="${row.id}">Sửa</button> <button class="btn btn-ghost btn-sm" data-delete-release="${row.id}">Xóa</button></td></tr>`).join('') || '<tr><td colspan="8" class="empty-state">Chưa có bản phát hành. Tạo bản mới với URL và checksum của tệp thực tế.</td></tr>';
    body.querySelectorAll('[data-edit-release]').forEach(btn => btn.onclick = () => this.openRelease(items.find(row => row.id === btn.dataset.editRelease)));
    body.querySelectorAll('[data-delete-release]').forEach(btn => btn.onclick = async () => {
      if (!confirm('Xóa bản phát hành này khỏi danh sách công khai?')) return;
      try { await api(`/admin/releases/${btn.dataset.deleteRelease}`, { method: 'DELETE', body: {} }); await this.renderReleases(); await this.app.renderPublicReleases(); }
      catch (error) { this.app.showToast(error.message, 'error'); }
    });
  }
  openRelease(row) {
    this.releaseEditId = row?.id || null;
    document.getElementById('form-add-release').reset();
    document.getElementById('release-modal-title').textContent = row ? 'Sửa bản phát hành' : 'Tạo bản phát hành';
    for (const key of ['product', 'platform', 'version', 'stage', 'size', 'sha256', 'downloadUrl', 'changelog']) if (row) document.getElementById(`rel-${key}`).value = row[key];
    message(document.getElementById('release-message'), '');
    this.app.openModal('modal-add-release');
  }
  async saveRelease(event) {
    event.preventDefault(); const button = event.target.querySelector('[type=submit]'); button.disabled = true;
    const body = Object.fromEntries(['product', 'platform', 'version', 'stage', 'size', 'sha256', 'downloadUrl', 'changelog'].map(key => [key, document.getElementById(`rel-${key}`).value]));
    try {
      await api(`/admin/releases${this.releaseEditId ? `/${this.releaseEditId}` : ''}`, { method: this.releaseEditId ? 'PUT' : 'POST', body });
      this.app.closeModals(); await this.renderReleases(); await this.app.renderPublicReleases(); this.app.showToast('Đã lưu bản phát hành vào database.');
    } catch (error) { message(document.getElementById('release-message'), error.message, true); }
    finally { button.disabled = false; }
  }
  renderPolicies() {
    const container = document.getElementById('policies-list');
    container.innerHTML = `<div class="section-toolbar"><p>Policy được lưu và sử dụng trong công cụ so sánh.</p><button id="new-policy" class="btn btn-primary btn-sm">+ Tạo policy</button></div><div class="policy-grid">${this.app.config.policies.map(row => `<article class="metric-card"><h3>${e(row.name)}</h3><code>${e(row.id)} · r${row.revision}</code><p class="privacy-note">${e(row.description)}</p><p>Dung sai: ${row.config.tolerance_abs}</p><button class="btn btn-outline btn-sm" data-edit-policy="${e(row.id)}">Chỉnh sửa</button> <button class="btn btn-ghost btn-sm" data-delete-policy="${e(row.id)}">Xóa</button></article>`).join('') || '<p>Chưa có policy.</p>'}</div>`;
    document.getElementById('new-policy').onclick = () => this.openPolicy();
    container.querySelectorAll('[data-edit-policy]').forEach(btn => btn.onclick = () => this.openPolicy(this.app.config.policies.find(row => row.id === btn.dataset.editPolicy)));
    container.querySelectorAll('[data-delete-policy]').forEach(btn => btn.onclick = async () => {
      if (!confirm('Xóa policy này? Các phiên cũ vẫn giữ cấu hình tại thời điểm lưu.')) return;
      try { await api(`/admin/policies/${btn.dataset.deletePolicy}`, { method: 'DELETE', body: {} }); await this.app.refreshConfig(); this.renderPolicies(); }
      catch (error) { this.app.showToast(error.message, 'error'); }
    });
  }
  openPolicy(row) {
    this.policyEditing = row || null;
    const form = document.getElementById('form-policy'); form.reset();
    form.elements.policyId.value = row?.id || ''; form.elements.policyId.disabled = Boolean(row);
    form.elements.policyName.value = row?.name || ''; form.elements.description.value = row?.description || '';
    form.elements.tolerance_abs.value = row?.config.tolerance_abs || 0;
    for (const key of Object.keys(policyLabels)) form.elements[key].checked = row ? row.config[key] : key !== 'case_sensitive_text';
    message(document.getElementById('policy-message'), ''); this.app.openModal('modal-policy');
  }
  async savePolicy(event) {
    event.preventDefault(); const form = event.target; const button = form.querySelector('[type=submit]'); button.disabled = true;
    const config = { tolerance_abs: Number(form.elements.tolerance_abs.value), ...Object.fromEntries(Object.keys(policyLabels).map(key => [key, form.elements[key].checked])) };
    const body = { id: form.elements.policyId.value, name: form.elements.policyName.value, description: form.elements.description.value, config };
    if (this.policyEditing) body.revision = this.policyEditing.revision;
    try {
      await api(`/admin/policies${this.policyEditing ? `/${this.policyEditing.id}` : ''}`, { method: this.policyEditing ? 'PUT' : 'POST', body });
      await this.app.refreshConfig(); this.renderPolicies(); this.app.closeModals(); this.app.showToast('Đã lưu policy.');
    } catch (error) { message(document.getElementById('policy-message'), error.message, true); }
    finally { button.disabled = false; }
  }
  renderFlags() {
    const container = document.getElementById('feature-flags-list');
    container.innerHTML = this.app.config.flags.map(flag => `<div class="flag-row"><div><strong>${e(flag.name)}</strong><p class="privacy-note">${e(flag.desc)}</p><code>${e(flag.id)} · r${flag.revision}</code></div><label class="switch-label"><input type="checkbox" aria-label="${e(flag.name)}" ${flag.enabled ? 'checked' : ''} data-flag="${flag.id}"><span class="switch-slider"></span></label></div>`).join('');
    container.querySelectorAll('[data-flag]').forEach(input => input.onchange = async () => {
      input.disabled = true;
      const flag = this.app.config.flags.find(f => f.id === input.dataset.flag);
      try {
        await api(`/admin/flags/${flag.id}`, { method: 'PATCH', body: { enabled: input.checked, revision: flag.revision } });
        await this.app.refreshConfig(); this.app.showToast('Đã cập nhật cờ tính năng.');
      } catch (error) { this.app.showToast(error.message, 'error'); await this.app.refreshConfig().catch(() => {}); }
      finally { this.renderFlags(); }
    });
  }
  renderAcceptance(run) {
    const results = run ? this.app.adminPortal.runAllAcceptanceTests() : this.app.adminPortal.acceptanceCases;
    document.getElementById('tbody-acceptance').innerHTML = results.map(row => `<tr><td>${e(row.id)}</td><td>${e(row.type)}</td><td><code>${e(row.left)}</code></td><td><code>${e(row.right)}</code></td><td>${e(row.policy)}</td><td>${e(row.expected)}</td><td>${e(row.actual || '—')}</td><td>${row.passed === undefined ? 'Chưa chạy' : row.passed ? '✓ PASS' : '✗ FAIL'}</td></tr>`).join('');
    const bar = document.getElementById('acceptance-progress'); bar.style.width = run ? '100%' : '0%';
    if (run) { const passed = results.filter(row => row.passed).length; bar.textContent = `${passed}/${results.length} đạt (${Math.round(passed / results.length * 100)}%)`; bar.style.background = passed === results.length ? 'var(--status-exact)' : 'var(--status-diff)'; }
  }
  testPolicy() {
    const row = this.app.adminPortal.testSinglePolicy(document.getElementById('test-val-a').value, document.getElementById('test-val-b').value, document.getElementById('test-val-type').value);
    const container = document.getElementById('policy-test-result'); container.style.display = 'block';
    container.innerHTML = `<strong>${e(row.status)}</strong><p>Quy tắc: <code>${e(row.ruleId)}</code></p><p>${e(row.reason)}</p><p>A: <code>${e(row.normA)}</code> · B: <code>${e(row.normB)}</code></p>`;
  }
  async renderAudit() {
    const container = document.getElementById('admin-audit-content'); container.textContent = 'Đang tải nhật ký…';
    const [logs, comparisons] = await Promise.all([api(`/admin/audit?limit=25&offset=${this.auditOffset}`), api('/admin/comparisons?limit=25')]);
    container.innerHTML = `<div class="section-toolbar"><p>Nhật ký thao tác quản trị và thống kê phiên · lưu ${this.app.retentionDays} ngày</p><button id="audit-export" class="btn btn-outline btn-sm">Tải nhật ký JSON</button></div><h3>Nhật ký hệ thống</h3><div class="admin-table-container"><table class="admin-table"><thead><tr><th>Thời gian</th><th>Hành động</th><th>Tài nguyên</th><th>Chi tiết</th></tr></thead><tbody>${logs.items.map(row => `<tr><td>${e(dateTime(row.createdAt))}</td><td>${e(row.action)}</td><td><code>${e(row.resourceId)}</code></td><td><code>${e(JSON.stringify(row.details))}</code></td></tr>`).join('') || '<tr><td colspan="4" class="empty-state">Chưa có nhật ký.</td></tr>'}</tbody></table></div>
      <div class="pagination"><button id="audit-prev" class="btn btn-outline btn-sm" ${!this.auditOffset ? 'disabled' : ''}>Trang trước</button><span>${logs.total} sự kiện</span><button id="audit-next" class="btn btn-outline btn-sm" ${this.auditOffset + 25 >= logs.total ? 'disabled' : ''}>Trang sau</button></div>
      <h3>25 phiên được lưu gần nhất</h3><div class="admin-table-container"><table class="admin-table"><thead><tr><th>Mã phiên</th><th>Thời gian</th><th>Định dạng</th><th>Số dòng A / B</th><th>Hash thống kê</th></tr></thead><tbody>${comparisons.items.map(row => `<tr><td><code>${e(row.id)}</code></td><td>${e(dateTime(row.createdAt))}</td><td>${e(row.formatA)} / ${e(row.formatB)}</td><td>${row.rowsA} / ${row.rowsB}</td><td><code title="${row.metadataSha256}">${row.metadataSha256.slice(0, 16)}…</code></td></tr>`).join('') || '<tr><td colspan="5" class="empty-state">Chưa có thống kê phiên.</td></tr>'}</tbody></table></div>`;
    document.getElementById('audit-export').onclick = async () => {
      try { download(await api('/admin/audit/export'), 'dytava-audit.json'); }
      catch (error) { this.app.showToast(error.message, 'error'); }
    };
    document.getElementById('audit-prev').onclick = () => { this.auditOffset = Math.max(0, this.auditOffset - 25); this.render('audit'); };
    document.getElementById('audit-next').onclick = () => { this.auditOffset += 25; this.render('audit'); };
  }
}
