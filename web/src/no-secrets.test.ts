import { readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Returns "file:line" for every line in `dir` (recursively) matching `pattern`.
export function grepSource(dir: string, pattern: RegExp): string[] {
  const hits: string[] = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      hits.push(...grepSource(path, pattern));
      continue;
    }
    if (path.endsWith('no-secrets.test.ts')) continue;
    readFileSync(path, 'utf8')
      .split('\n')
      .forEach((line, i) => {
        if (pattern.test(line)) hits.push(`${path}:${i + 1}`);
      });
  }
  return hits;
}

it('has no service_role reference in web source', () => {
  expect(grepSource('web/src', /service_role/i)).toEqual([]);
});

it('grepSource really detects a planted service_role reference', () => {
  const planted = join('web/src', '__planted__.ts');
  writeFileSync(planted, "const k = 'SERVICE_ROLE';\n");
  try {
    expect(grepSource('web/src', /service_role/i)).toEqual([`${planted}:1`]);
  } finally {
    rmSync(planted);
  }
});
