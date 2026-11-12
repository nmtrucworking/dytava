import { renderReport } from './report/renderer.js';

const feedback = document.getElementById('report-feedback');
const print = document.getElementById('report-print');
const token = location.hash.slice(1);
let accepted = false;
print.onclick = () => window.print();
window.addEventListener('message', async event => {
  if (accepted || event.origin !== location.origin || event.source !== window.opener || event.data?.type !== 'dytava-report-payload' || event.data.token !== token) return;
  accepted = true;
  try {
    const { html } = renderReport(event.data.report, { allowLegacy: true, timezone: 'Asia/Ho_Chi_Minh' });
    document.getElementById('report-root').innerHTML = html;
    await document.fonts.ready;
    await Promise.all([...document.images].map(img => img.decode()));
    print.disabled = false;
    feedback.hidden = true;
    document.title = 'Báo cáo đối chiếu dữ liệu · Dytava';
  } catch {
    feedback.textContent = 'Không thể tạo báo cáo: dữ liệu hoặc phạm vi không hợp lệ. Quay lại cửa sổ so sánh và chạy lại.';
  }
});
if (window.opener && token) window.opener.postMessage({ type: 'dytava-report-ready', token }, location.origin);
else feedback.textContent = 'Mở báo cáo bằng nút “PDF Dytava” trong công cụ so sánh. Dữ liệu không được lưu trên máy chủ.';
