import { useEffect, type JSX } from 'react';

export function App(): JSX.Element {
  useEffect(() => {
    document.documentElement.dir = 'rtl';
    document.documentElement.lang = 'ar';
  }, []);

  return (
    <main>
      <h1>FleetMind</h1>
    </main>
  );
}
