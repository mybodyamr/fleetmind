import type { JSX, ReactNode } from 'react';
import { useSession } from './useSession';

/**
 * Shows `children` only to users holding `code`. This is a user-experience guard, not a
 * security boundary: the database refuses the underlying requests regardless of the UI.
 */
export function RequirePermission({ code, children }: { code: string; children: ReactNode }): JSX.Element {
  const { permissions, loading } = useSession();

  if (loading) return <p role="status">جارٍ التحميل…</p>;

  if (!permissions.has(code)) {
    return (
      <section className="denied">
        <h2>غير مصرح</h2>
        <p>ليس لديك صلاحية لعرض هذا القسم. اطلب الصلاحية من مدير النظام.</p>
      </section>
    );
  }
  return <>{children}</>;
}
