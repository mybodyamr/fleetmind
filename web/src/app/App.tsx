import { useEffect, type JSX } from 'react';
import { LoginPage } from '../auth/LoginPage';
import { RequirePermission } from '../auth/RequirePermission';
import { useSession } from '../auth/useSession';
import { getSupabase } from '../lib/supabase';

export function App(): JSX.Element {
  const { user, loading } = useSession();

  useEffect(() => {
    document.documentElement.dir = 'rtl';
    document.documentElement.lang = 'ar';
  }, []);

  if (loading) {
    return (
      <main>
        <h1 className="wordmark">FleetMind</h1>
        <p role="status">جارٍ التحميل…</p>
      </main>
    );
  }

  if (!user) return <LoginPage />;

  return (
    <>
      <header className="shell__bar">
        <h1 className="wordmark">FleetMind</h1>
        <span className="shell__user" dir="ltr">{user.email}</span>
        <button type="button" className="shell__out" onClick={() => void getSupabase().auth.signOut()}>
          تسجيل الخروج
        </button>
      </header>
      <main className="shell__main">
        <RequirePermission code="settings.write">
          <section aria-labelledby="settings-title" className="panel">
            <h2 id="settings-title">إعدادات النظام</h2>
            <p>تظهر هنا إعدادات التتبع والتنبيهات عند إضافتها.</p>
          </section>
        </RequirePermission>
      </main>
    </>
  );
}
