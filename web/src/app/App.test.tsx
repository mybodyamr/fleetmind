import { render, screen } from '@testing-library/react';
import { App } from './App';

it('renders Arabic RTL shell', () => {
  render(<App />);
  expect(document.documentElement.dir).toBe('rtl');
  expect(document.documentElement.lang).toBe('ar');
  expect(screen.getByRole('main')).toBeInTheDocument();
  expect(screen.getByRole('heading', { name: 'FleetMind' })).toBeInTheDocument();
});
