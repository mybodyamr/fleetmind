import { createContext, useContext, useEffect, useState, type JSX, type ReactNode } from 'react';
import { getSupabase } from '../lib/supabase';

export interface SessionState {
  user: { id: string; email?: string } | null;
  permissions: Set<string>;
  loading: boolean;
}

const signedOut: SessionState = { user: null, permissions: new Set(), loading: false };
const SessionContext = createContext<SessionState | null>(null);

/** Loads the signed-in user and their permission codes once for the whole app. */
export function SessionProvider({ children }: { children: ReactNode }): JSX.Element {
  const [state, setState] = useState<SessionState>({ ...signedOut, loading: true });

  useEffect(() => {
    const supabase = getSupabase();
    let cancelled = false;

    const load = async (user: { id: string; email?: string } | null) => {
      if (!user) {
        if (!cancelled) setState(signedOut);
        return;
      }
      const { data, error } = await supabase.rpc('my_permissions');
      if (cancelled) return;
      setState({
        user: { id: user.id, email: user.email },
        permissions: new Set(error ? [] : (data as string[])),
        loading: false,
      });
    };

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      // Calling supabase inside this callback can deadlock the auth client, so defer it.
      setTimeout(() => void load(session?.user ?? null), 0);
    });
    return () => {
      cancelled = true;
      data.subscription.unsubscribe();
    };
  }, []);

  return <SessionContext.Provider value={state}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionState {
  const state = useContext(SessionContext);
  if (!state) throw new Error('useSession must be used inside <SessionProvider>');
  return state;
}
