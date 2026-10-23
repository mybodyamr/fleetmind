import { useState, type FormEvent, type JSX } from 'react';
import { getSupabase } from '../lib/supabase';

export function LoginPage(): JSX.Element {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [failed, setFailed] = useState(false);
  const [pending, setPending] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setPending(true);
    setFailed(false);
    const { error } = await getSupabase().auth.signInWithPassword({ email, password });
    setPending(false);
    if (error) setFailed(true);
  }

  return (
    <main className="login">
      <section className="login__sign">
        <h1 className="wordmark">FleetMind</h1>
        <p>إدارة السيارات والسائقين ومهام التوصيل من المخزن إلى الفروع.</p>
      </section>
      <section className="login__form">
        <h2>تسجيل الدخول</h2>
        <form onSubmit={onSubmit} noValidate>
          <label htmlFor="email">البريد الإلكتروني</label>
          <input
            id="email"
            type="email"
            dir="ltr"
            inputMode="email"
            autoComplete="username"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <label htmlFor="password">كلمة المرور</label>
          <input
            id="password"
            type="password"
            dir="ltr"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          {failed && (
            <p role="alert" className="login__error">
              تعذّر تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور ثم أعد المحاولة.
            </p>
          )}
          <button type="submit" disabled={pending}>
            {pending ? 'جارٍ تسجيل الدخول…' : 'تسجيل الدخول'}
          </button>
        </form>
      </section>
    </main>
  );
}
