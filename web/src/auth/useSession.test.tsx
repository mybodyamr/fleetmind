import { act, render, screen } from '@testing-library/react';
import { SessionProvider, useSession } from './useSession';

type AuthCallback = (event: string, session: { user: { id: string; email: string } } | null) => void;

const harness = vi.hoisted(() => ({
  authCallback: null as unknown as (event: string, session: unknown) => void,
  rpc: vi.fn(),
}));

vi.mock('../lib/supabase', () => ({
  getSupabase: () => ({
    auth: {
      onAuthStateChange: (cb: AuthCallback) => {
        harness.authCallback = cb as typeof harness.authCallback;
        return { data: { subscription: { unsubscribe: () => {} } } };
      },
    },
    rpc: harness.rpc,
  }),
}));

function Probe() {
  const s = useSession();
  return (
    <output>
      {JSON.stringify({ user: s.user?.id ?? null, permissions: [...s.permissions], loading: s.loading, error: s.error })}
    </output>
  );
}

const state = () => JSON.parse(screen.getByRole('status').textContent ?? '{}');
const tick = () => new Promise((resolve) => setTimeout(resolve, 0));

async function signIn(id: string) {
  await act(async () => {
    harness.authCallback('SIGNED_IN', { user: { id, email: `${id}@example.com` } });
    await tick();
  });
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((r) => (resolve = r));
  return { promise, resolve };
}

beforeEach(() => {
  harness.rpc.mockReset();
  render(
    <SessionProvider>
      <Probe />
    </SessionProvider>,
  );
});

it('loads the permission codes of the signed-in user', async () => {
  harness.rpc.mockResolvedValue({ data: ['tasks.read_own'], error: null });
  await signIn('a');
  expect(state()).toMatchObject({ user: 'a', permissions: ['tasks.read_own'], loading: false, error: false });
});

it('does not bring a signed-out user back when a slow permissions call finishes late', async () => {
  const slow = deferred<{ data: string[]; error: null }>();
  harness.rpc.mockReturnValue(slow.promise);
  await signIn('a');
  await act(async () => {
    harness.authCallback('SIGNED_OUT', null);
    await tick();
  });
  expect(state()).toMatchObject({ user: null, loading: false });
  await act(async () => {
    slow.resolve({ data: ['settings.write'], error: null });
    await tick();
  });
  expect(state()).toMatchObject({ user: null, permissions: [] });
});

it('keeps the newest user when an older permissions call finishes last', async () => {
  const first = deferred<{ data: string[]; error: null }>();
  harness.rpc.mockReturnValueOnce(first.promise).mockResolvedValueOnce({ data: ['tasks.read_own'], error: null });
  await signIn('a');
  await signIn('b');
  await act(async () => {
    first.resolve({ data: ['settings.write'], error: null });
    await tick();
  });
  expect(state()).toMatchObject({ user: 'b', permissions: ['tasks.read_own'] });
});

it('reports an error, not an empty permission set, when the permissions call fails', async () => {
  harness.rpc.mockResolvedValue({ data: null, error: { message: 'network down' } });
  await signIn('a');
  expect(state()).toMatchObject({ user: 'a', permissions: [], loading: false, error: true });
});
