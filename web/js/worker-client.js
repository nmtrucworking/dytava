export class ComparisonWorker {
  constructor() { this.pending = new Map(); }
  call(data) {
    if (!this.worker) {
      this.worker = new Worker(new URL('./compare-worker.js', import.meta.url), { type: 'module' });
      this.worker.onmessage = ({ data }) => {
        const pending = this.pending.get(data.id);
        if (!pending) return;
        clearTimeout(pending.timer);
        this.pending.delete(data.id);
        data.error ? pending.reject(new Error(data.error)) : pending.resolve(data.result);
      };
      this.worker.onerror = () => this.reset('Bộ xử lý gặp lỗi. Vui lòng thử lại.');
    }
    const id = crypto.randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => this.reset('Tệp xử lý quá 30 giây. Vui lòng chọn tệp nhỏ hơn.'), 30000);
      this.pending.set(id, { resolve, reject, timer });
      this.worker.postMessage({ ...data, id });
    });
  }
  reset(reason) {
    this.worker?.terminate(); this.worker = null;
    for (const pending of this.pending.values()) { clearTimeout(pending.timer); pending.reject(new Error(reason)); }
    this.pending.clear();
  }
}
