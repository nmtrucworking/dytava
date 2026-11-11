export class ApiError extends Error {
  constructor(message, status) { super(message); this.status = status; }
}
export async function api(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    ...options, credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', 'X-Dytava-Request': '1', ...options.headers },
    body: options.body === undefined ? undefined : JSON.stringify(options.body)
  });
  if (response.status === 204) return null;
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const fields = data.fields?.map(f => `${f.path}: ${f.message}`).join('; ');
    throw new ApiError(fields || data.error || 'Không kết nối được máy chủ.', response.status);
  }
  return data;
}
export const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
export function download(data, filename, type = 'application/json') {
  const url = URL.createObjectURL(new Blob([typeof data === 'string' ? data : JSON.stringify(data, null, 2)], { type }));
  const a = document.createElement('a');
  a.href = url; a.download = filename; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export const dateTime = value => new Date(value).toLocaleString('vi-VN');
export function message(element, text, isError = false) {
  element.textContent = text;
  element.className = isError ? 'form-message error' : 'form-message';
}
