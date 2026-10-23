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
