import { expect, test, type Page } from '@playwright/test';
import { createUser, patch, rpc, signIn, type TestUser } from './support';

let admin: TestUser;
let driver: TestUser;

test.beforeAll(async () => {
  admin = await createUser('system_admin');
  driver = await createUser('driver');
});

async function login(page: Page, user: TestUser) {
  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(user.email);
  await page.getByLabel('كلمة المرور').fill(user.password);
  await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
}

test('the login page and the signed-in shell are Arabic and right-to-left', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
  await login(page, admin);
  await expect(page.getByRole('heading', { name: 'FleetMind' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'إعدادات النظام' })).toBeVisible();
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
});

test('a driver is told غير مصرح on the settings panel', async ({ page }) => {
  await login(page, driver);
  await expect(page.getByRole('heading', { name: 'غير مصرح' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'إعدادات النظام' })).toHaveCount(0);
});

test('the server refuses a driver who calls an admin API directly, without the UI', async () => {
  const driverToken = await signIn(driver);
  const call = await rpc(driverToken, 'set_setting', {
    p_key: 'gps.update_interval_seconds',
    p_value: 5,
    p_reason: 'direct call',
  });
  expect(call.status).toBe(403);
  expect(call.body?.code).toBe('42501');

  const write = await patch(driverToken, 'settings?key=eq.gps.update_interval_seconds', { value: 1 });
  expect([401, 403]).toContain(write.status);

  // Control: the same call succeeds for an administrator, so the refusal above is the permission check.
  const adminToken = await signIn(admin);
  const ok = await rpc(adminToken, 'set_setting', {
    p_key: 'gps.update_interval_seconds',
    p_value: 5,
    p_reason: 'control call',
  });
  expect([200, 204]).toContain(ok.status);
});
