import { render, screen } from '@testing-library/react';
import { useSession } from '../auth/useSession';
import { App } from './App';

vi.mock('../auth/useSession');

const mockedUseSession = vi.mocked(useSession);

function signedOut() {
  mockedUseSession.mockReturnValue({ user: null, permissions: new Set(), loading: false, error: false });
}

it('renders Arabic RTL shell', () => {
  signedOut();
  render(<App />);
  expect(document.documentElement.dir).toBe('rtl');
  expect(document.documentElement.lang).toBe('ar');
  expect(screen.getByRole('main')).toBeInTheDocument();
  expect(screen.getByRole('heading', { name: 'FleetMind' })).toBeInTheDocument();
});

it('asks for credentials when nobody is signed in', () => {
  signedOut();
  render(<App />);
  expect(screen.getByLabelText('البريد الإلكتروني')).toBeInTheDocument();
  expect(screen.getByLabelText('كلمة المرور')).toBeInTheDocument();
  expect(screen.getByRole('button', { name: 'تسجيل الدخول' })).toBeInTheDocument();
});

it('shows the settings panel to a user who holds settings.write', () => {
  mockedUseSession.mockReturnValue({
    user: { id: 'u1', email: 'admin@example.com' },
    permissions: new Set(['settings.write']),
    loading: false,
    error: false,
  });
  render(<App />);
  expect(screen.getByRole('region', { name: 'إعدادات النظام' })).toBeInTheDocument();
});

it('tells the user the permissions could not be loaded, instead of saying غير مصرح', () => {
  mockedUseSession.mockReturnValue({
    user: { id: 'u1', email: 'driver@example.com' },
    permissions: new Set(),
    loading: false,
    error: true,
  });
  render(<App />);
  expect(screen.getByRole('alert')).toHaveTextContent('تعذّر تحميل صلاحياتك');
  expect(screen.getByRole('button', { name: 'إعادة المحاولة' })).toBeInTheDocument();
  expect(screen.getByRole('button', { name: 'تسجيل الخروج' })).toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: 'غير مصرح' })).not.toBeInTheDocument();
});
