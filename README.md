# FleetMind

نظام إدارة أسطول السيارات والسائقين والمهام مع تتبع GPS. الخطة والمتطلبات في `docs/superpowers/`.

## التشغيل المحلي

```bash
npm install
cp .env.example .env.local   # ضع VITE_SUPABASE_URL و VITE_SUPABASE_ANON_KEY
npm run dev
```

## الأوامر

| الأمر | الوظيفة |
|---|---|
| `npm test` | اختبارات الواجهة (Vitest) |
| `npm run typecheck` | فحص TypeScript |
| `npm run lint` | ESLint |
| `npm run check:migrations` | يمنع الهجرات المدمرة بلا ملف مراجعة |
| `npm run db:test` | اختبارات قاعدة البيانات (pgTAP) |
| `npm run e2e` | اختبارات Playwright |

لا يوضع `service_role` أو أي سر في كود الواجهة (يفحصه `web/src/no-secrets.test.ts`).

## الحسابات

التسجيل الذاتي مغلق (`enable_signup = false`). الحسابات تُنشأ من لوحة Supabase أو بمفتاح `service_role` من الخادم فقط، ثم يُضاف لها صف في `profiles` ودور عبر `assign_role`. تعطيل الحساب يتم عبر `set_profile_active` (يُسجَّل في سجل التدقيق، ولا يمكن تعطيل آخر `system_admin` نشط).
