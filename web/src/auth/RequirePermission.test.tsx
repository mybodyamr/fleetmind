import { render, screen } from '@testing-library/react';
import { RequirePermission } from './RequirePermission';
import { useSession } from './useSession';

vi.mock('./useSession');

const mockedUseSession = vi.mocked(useSession);

function sessionWith(permissions: string[], loading = false) {
  mockedUseSession.mockReturnValue({
    user: { id: 'u1', email: 'a@example.com' },
    permissions: new Set(permissions),
    loading,
  } as ReturnType<typeof useSession>);
}

it('renders the children when the permission is held', () => {
  sessionWith(['settings.write']);
  render(
    <RequirePermission code="settings.write">
      <p>محتوى الإعدادات</p>
    </RequirePermission>,
  );
  expect(screen.getByText('محتوى الإعدادات')).toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: 'غير مصرح' })).not.toBeInTheDocument();
});

it('hides the children and shows غير مصرح when the permission is missing', () => {
  sessionWith(['tasks.read_own']);
  render(
    <RequirePermission code="settings.write">
      <p>محتوى الإعدادات</p>
    </RequirePermission>,
  );
  expect(screen.queryByText('محتوى الإعدادات')).not.toBeInTheDocument();
  expect(screen.getByRole('heading', { name: 'غير مصرح' })).toBeInTheDocument();
});

it('shows neither the children nor غير مصرح while the session is loading', () => {
  sessionWith(['settings.write'], true);
  render(
    <RequirePermission code="settings.write">
      <p>محتوى الإعدادات</p>
    </RequirePermission>,
  );
  expect(screen.queryByText('محتوى الإعدادات')).not.toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: 'غير مصرح' })).not.toBeInTheDocument();
});
