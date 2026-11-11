import { api, escapeHtml as e, dateTime, download, message } from './api.js';

export class AccountUI {
  constructor(app) { this.app = app; this.mode = 'login'; this.offset = 0; }
  setup() {
    document.getElementById('btn-account').addEventListener('click', () => this.app.user ? this.openPassword() : this.openAuth());
    document.getElementById('btn-logout').addEventListener('click', async () => {
      try {
        await api('/auth/logout', { method: 'POST', body: {} });
        this.app.user = null; this.app.updateAccount(); this.app.route();
        this.app.showToast('Đã đăng xuất.');
      } catch (error) { this.app.showToast(error.message, 'error'); }
    });
    document.getElementById('btn-save-session').addEventListener('click', () => this.saveSession());
    document.getElementById('form-auth').addEventListener('submit', event => this.submitAuth(event));
    document.getElementById('auth-mode-toggle').addEventListener('click', () => this.openAuth(this.mode === 'login' ? 'register' : 'login'));
    document.getElementById('form-password').addEventListener('submit', event => this.changePassword(event));
  }
  openAuth(mode = 'login') {
    this.mode = mode === 'register' && this.app.allowRegistration ? 'register' : 'login';
    const register = this.mode === 'register';
    document.getElementById('auth-title').textContent = register ? 'Tạo tài khoản Dytava' : 'Đăng nhập Dytava';
    document.getElementById('auth-name-group').hidden = !register;
    document.getElementById('auth-name').required = register;
    document.getElementById('auth-password').autocomplete = register ? 'new-password' : 'current-password';
    document.getElementById('auth-submit').textContent = register ? 'Tạo tài khoản' : 'Đăng nhập';
    document.getElementById('auth-mode-toggle').textContent = register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký';
    document.getElementById('auth-mode-toggle').hidden = !this.app.allowRegistration;
    message(document.getElementById('auth-message'), '');
    this.app.openModal('modal-auth');
  }
  async submitAuth(event) {
    event.preventDefault();
    const button = document.getElementById('auth-submit'); button.disabled = true;
    const body = { email: document.getElementById('auth-email').value.trim(), password: document.getElementById('auth-password').value };
    if (this.mode === 'register') body.name = document.getElementById('auth-name').value.trim();
    try {
      const { user } = await api(`/auth/${this.mode}`, { method: 'POST', body });
      this.app.user = user;
      document.getElementById('form-auth').reset();
      this.app.closeModals(); this.app.updateAccount(); this.app.route();
      this.app.showToast(`Xin chào ${user.name}.`);
    } catch (error) { message(document.getElementById('auth-message'), error.message, true); }
    finally { button.disabled = false; }
  }
  openPassword() { this.app.openModal('modal-password'); }
  async changePassword(event) {
    event.preventDefault();
    const form = event.target; const button = form.querySelector('[type=submit]'); button.disabled = true;
    try {
      await api('/auth/password', { method: 'POST', body: { currentPassword: form.elements.currentPassword.value, newPassword: form.elements.newPassword.value } });
      form.reset(); this.app.closeModals(); this.app.showToast('Đã đổi mật khẩu và đăng xuất các phiên khác.');
    } catch (error) { message(document.getElementById('password-message'), error.message, true); }
    finally { button.disabled = false; }
  }
  async saveSession() {
    if (!this.app.user) return this.openAuth();
    if (!this.app.isEnabled('FLAG_HISTORY')) return this.app.showToast('Lưu thống kê đang tắt.', 'error');
    const result = this.app.currentComparisonResult;
    if (!result || this.app.busy) return;
    const button = document.getElementById('btn-save-session'); button.disabled = true;
    try {
      await api('/comparisons', { method: 'POST', body: result.metadata });
      this.app.savedClientId = result.metadata.clientId;
      button.textContent = '✓ Đã lưu thống kê';
      this.app.showToast('Đã lưu thống kê. Nội dung và tên tệp không được gửi lên máy chủ.');
    } catch (error) { this.app.showToast(error.message, 'error'); }
    finally { this.app.updateSaveButton(); }
  }
  async renderHistory() {
    const container = document.getElementById('history-content');
    if (!this.app.user) {
      container.innerHTML = '<div class="empty-state"><h3>Đăng nhập để xem lịch sử</h3><p>Thống kê được lưu riêng theo tài khoản.</p><button class="btn btn-primary" id="history-login">Đăng nhập</button></div>';
      document.getElementById('history-login').onclick = () => this.openAuth(); return;
    }
    container.textContent = 'Đang tải lịch sử…';
    try {
      const data = await api(`/comparisons?limit=20&offset=${this.offset}`);
      container.innerHTML = `<div class="section-toolbar"><p>${data.total} phiên đã lưu · Tự xóa sau ${this.app.retentionDays} ngày</p><button id="history-delete-all" class="btn btn-outline btn-sm" ${!data.total ? 'disabled' : ''}>Xóa toàn bộ lịch sử</button></div>
      <p class="privacy-note">Chỉ lưu định dạng, số dòng, cấu hình và thống kê. Để xem lại nội dung chi tiết, chọn lại hai tệp gốc.</p>
      <div class="admin-table-container"><table class="admin-table"><thead><tr><th>Thời gian</th><th>Định dạng</th><th>Số dòng A / B</th><th>Exact / Equiv / Diff / Chờ duyệt</th><th>Thao tác</th></tr></thead><tbody>${data.items.map(row => `<tr><td>${e(dateTime(row.createdAt))}</td><td>${e(row.formatA.toUpperCase())} ↔ ${e(row.formatB.toUpperCase())}</td><td>${row.rowsA} / ${row.rowsB}</td><td>${row.summary.exact} / ${row.summary.equivalent} / ${row.summary.different} / ${row.summary.unresolved}</td><td><button class="btn btn-outline btn-sm" data-export="${row.id}">JSON thống kê</button> <button class="btn btn-ghost btn-sm" data-delete="${row.id}">Xóa</button></td></tr>`).join('') || '<tr><td colspan="5" class="empty-state">Chưa lưu phiên nào. Bấm “Lưu thống kê phiên” sau khi so sánh.</td></tr>'}</tbody></table></div>
      <div class="pagination"><button id="history-prev" class="btn btn-outline btn-sm" ${!this.offset ? 'disabled' : ''}>Trang trước</button><span>${data.total ? this.offset + 1 : 0}–${Math.min(this.offset + 20, data.total)} / ${data.total}</span><button id="history-next" class="btn btn-outline btn-sm" ${this.offset + 20 >= data.total ? 'disabled' : ''}>Trang sau</button></div>`;
      container.querySelectorAll('[data-export]').forEach(btn => btn.onclick = () => download(data.items.find(row => row.id === btn.dataset.export), `statistics-${btn.dataset.export}.json`));
      container.querySelectorAll('[data-delete]').forEach(btn => btn.onclick = async () => {
        try { await api(`/comparisons/${btn.dataset.delete}`, { method: 'DELETE', body: {} }); await this.renderHistory(); }
        catch (error) { this.app.showToast(error.message, 'error'); }
      });
      document.getElementById('history-delete-all').onclick = async () => {
        if (!confirm('Xóa toàn bộ thống kê đã lưu của bạn?')) return;
        try { await api('/comparisons', { method: 'DELETE', body: {} }); this.offset = 0; await this.renderHistory(); }
        catch (error) { this.app.showToast(error.message, 'error'); }
      };
      document.getElementById('history-prev').onclick = () => { this.offset = Math.max(0, this.offset - 20); this.renderHistory(); };
      document.getElementById('history-next').onclick = () => { this.offset += 20; this.renderHistory(); };
    } catch (error) { container.textContent = error.message; }
  }
}
