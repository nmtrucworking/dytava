import { loadConfig } from '../server/config.js';
import { openDatabase } from '../server/db.js';
import { createUser } from '../server/auth.js';
import { registrationSchema } from '../server/validation.js';
import { createInterface } from 'node:readline/promises';

const prompt = createInterface({ input: process.stdin, output: process.stdout });
try {
  const email = process.env.ADMIN_EMAIL || await prompt.question('Email admin: ');
  const name = process.env.ADMIN_NAME || await prompt.question('Tên admin: ');
  let password = process.env.ADMIN_PASSWORD;
  if (!password) {
    if (!process.stdin.isTTY) throw new Error('Cần ADMIN_PASSWORD khi chạy không có terminal tương tác.');
    process.stdout.write('Mật khẩu (ít nhất 12 ký tự, ẩn khi nhập): ');
    prompt.close();
    password = await new Promise(resolve => {
      let value = '';
      process.stdin.setRawMode(true);
      process.stdin.resume();
      const onData = data => {
        for (const ch of data.toString()) {
          if (ch === '\u0003') process.exit(130);
          if (ch === '\r' || ch === '\n') {
            process.stdin.removeListener('data', onData);
            process.stdin.setRawMode(false);
            process.stdin.pause();
            process.stdout.write('\n');
            resolve(value);
            return;
          }
          if (ch === '\u007f') value = value.slice(0, -1); else value += ch;
        }
      };
      process.stdin.on('data', onData);
    });
  }
  const values = registrationSchema.parse({ email, name, password });
  const db = openDatabase(loadConfig().databasePath);
  try {
    await createUser(db, { ...values, role: 'admin' });
    console.log(`Đã tạo admin ${values.email}.`);
  } finally { db.close(); }
} catch (error) {
  console.error(error.code === 'ERR_SQLITE_ERROR' ? 'Email đã tồn tại hoặc database không khả dụng.' : error.message);
  process.exitCode = 1;
} finally { prompt.close(); }
