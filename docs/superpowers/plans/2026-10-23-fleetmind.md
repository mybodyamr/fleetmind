# FleetMind — خطة التنفيذ (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** نظام لإدارة أسطول السيارات والسائقين والمهام والرحلات، مع إسناد يدوي موثق للمهام، وتتبع GPS حقيقي، وصلاحيات مفروضة على الخادم وقاعدة البيانات.

**Architecture:** قاعدة PostgreSQL على Supabase هي مصدر الحقيقة: القيود وسياسات RLS والدوال الذرية (RPC) تفرض قواعد الإسناد والمهام والصلاحيات، وكل الواجهات عملاء رقيقون فوقها. استقبال بيانات GPS يمر عبر Edge Function واحدة خلف واجهة مصادر قابلة للتوسعة (تطبيق Android الآن، جهاز مستقل لاحقًا بعد تحديده).

**Tech Stack:** React + TypeScript + Vite، TanStack Query، Tailwind (خصائص منطقية RTL)، Leaflet مع OpenStreetMap، Supabase (Postgres + PostGIS + btree_gist + pg_cron + Auth + Storage + Realtime + Edge Functions)، Vercel، Kotlin/Compose لتطبيق التتبع، Supabase Realtime للإشعارات. الاختبارات: pgTAP وVitest وPlaywright.

**Spec:** وثيقة متطلبات FleetMind المرفقة في المحادثة (14 قسمًا). لا يوجد لها ملف في المستودع بعد؛ تُنسخ إلى `docs/superpowers/specs/fleetmind-requirements.md` في أول commit.

## قرارات مبدئية (أحتاج تأكيدك عليها)

| القرار | الافتراض الحالي | الأثر لو تغيّر |
|---|---|---|
| عدد الشركات | شركة واحدة (مؤكد) | لا أثر، ولا حاجة لـ `org_id` |
| الخريطة | Leaflet + OpenStreetMap (بلا مفتاح) | Google Maps يحتاج مفتاحًا وتكلفة |
| تطبيق Android | Kotlin أصلي للتتبع فقط، وشاشات المهام في واجهة السائق (React) | Capacitor أسرع بناءً لكن أقل موثوقية في الخلفية |
| توزيع المهام | يدوي بالكامل من مسؤول الحركة (مؤكد)؛ لا قائمة دور ولا ترشيح تلقائي | لو احتجتم ترشيحًا تلقائيًا لاحقًا يُضاف كوحدة مستقلة فوق جداول الإسناد |
| الإشعارات | Supabase Realtime وجدول `notifications` (مؤكد)، بلا Firebase | لو فاتت إشعارات سائقين والتطبيق مغلق يُضاف FCM لاحقًا دون تغيير الجداول |
| المنطقة الزمنية والعملة والوحدات | تخزين `timestamptz` دائمًا، والعرض بتوقيت الرياض، العملة ريال، وحدات كم/لتر (افتراض، قل لي لو غلط) | لا أثر على البنية |
| تقارير PDF بالعربية | تُقرّر في spike بالمرحلة 8 (Chromium على الخادم أو print CSS) | تشكيل الحروف العربية في مكتبات PDF العادية مشكلة معروفة |

## ما ينفذ مباشرة وما يحتاج جهة خارجية

**مباشرة:** قاعدة البيانات والقيود وRLS، الإسناد وتبديل السائق والسيارة، دورة المهمة، الواجهات، استقبال GPS عبر Android، التنبيهات داخل التطبيق، التقارير والتصدير.

**يحتاج منك:**
- حسابا Supabase وVercel موجودان عندك (مؤكد). يُفضّل أن تكون خطة Supabase فيها نسخ احتياطي PITR.
- لا يوجد جهاز GPS مستقل (مؤكد)، فالتتبع من تطبيق Android وحده. لا يُكتب أي محول لجهاز قبل أن يوجد جهاز فعلي وبروتوكول معروف وتجربة اتصال حقيقية، ولا يُدّعى أن التكامل يعمل.
- مفاتيح توقيع تطبيق Android وطريقة التوزيع (Play أو APK داخلي).

## Global Constraints

- من القسم 14 في الوثيقة: لا تفترض أن ميزة تعمل قبل اختبارها، ولا تعتبر نجاح البناء أو TypeScript دليلًا كافيًا.
- لا مواقع ثابتة أو عشوائية أو بيانات وهمية تُعرض كأنها GPS حقيقي، ولا بيانات تجريبية في الإنتاج (البيانات التجريبية في `supabase/seed.sql` للتطوير فقط، وCI يفشل لو وصلت إلى migration).
- لا تعتمد على PWA وحده للتتبع المستمر في الخلفية على Android.
- الصلاحيات تُطبق على الخادم وقاعدة البيانات (RLS وRPC)، وإخفاء الأزرار لا يُعد حماية.
- لا مفاتيح سرية أو `service_role` داخل كود الواجهة.
- لا تجاوز للصلاحيات، ولا تغيير للسائق أو السيارة أو إعادة إسناد، دون سبب مسجل في `audit_log`.
- لا تغييرات مدمرة في قاعدة البيانات دون ملف مراجعة وخطة ترحيل ونسخة احتياطية.
- لا ادعاء بوصول إشعار قبل تأكيد من نظام التسليم، ولا افتراض أن الوقود يأتي من GPS.
- دعم العربية وRTL، وتصميم متجاوب للموبايل والكمبيوتر.
- لا يُعرض موقع قديم على أنه مباشر: كل موقع يظهر معه مصدره وتوقيته وحالته (متصل/قديم/غير متصل).

## Review Focus

أكثر خمس حالات تقع خارج ما تغطيه المتطلبات صراحة وقد تكسر النظام، مع الاختبار الذي يثبتها في المرحلة المسؤولة:

1. **تزامن:** مسؤولا حركة يسندان المهمة نفسها في اللحظة نفسها، أو يسندان مهمتين متداخلتين للسائق نفسه. المتوقع: ينجح واحد فقط والآخر يحصل على خطأ واضح. (المرحلة 3: `assignment.concurrency.int.test.ts` بجلستين متوازيتين.)
2. **دفعات GPS بعد انقطاع:** نقاط مكررة، أو بترتيب مختلف، أو بتوقيت مستقبلي (ساعة الجهاز متقدمة)، أو بدقة ضعيفة، أو قفزات مستحيلة. المتوقع: لا تكرار، الترتيب حسب `recorded_at`، وتُوسم المشبوهة ولا تُحذف بصمت. (المرحلة 6: `ingest_positions.test.sql`.)
3. **إسناد لسائق لا يصلح:** سائق في إجازة أو بلا تأهيل أو بلا سيارة، أو سيارته في الصيانة. المتوقع: رفض بقائمة موانع واضحة لكل حالة، وليس خطأ 500. (المرحلة 3: `assign_blockers.test.sql`.)
4. **تغير الحالة بعد الإسناد:** السيارة دخلت الصيانة أو السائق ذهب في إجازة أو انتهى تأهيله. المتوقع: يوسم الإسناد `needs_reassignment` مع تنبيه، ولا تبقى صامتة. (المرحلتان 4 و7: `assignment_invalidation.test.sql`.)
5. **حدود الوقت:** مهمتان تتلامسان (نهاية الأولى = بداية الثانية)، مهمة تعبر منتصف الليل، مدة صفرية أو سالبة. المتوقع: التلامس مسموح، والمدة غير الموجبة مرفوضة. (المرحلة 3: `task_window_boundaries.test.sql` والنوافذ بصيغة `[)`.)

---

## البنية

**المكونات:**
- `web/` تطبيق React واحد بواجهتين حسب الدور: لوحة الإدارة والحركة، وواجهة السائق المتجاوبة.
- `supabase/` الهجرات والاختبارات والدوال الطرفية (Edge Functions).
- `android/` تطبيق التتبع (المرحلة 6).

**مبدأ التنفيذ:** كل قاعدة عمل حرجة (الإسناد، انتقالات الحالة، منع التداخل، الصلاحيات) تعيش في قاعدة البيانات كقيد أو دالة ذرية، والواجهة تستدعيها فقط. هذا يجعل الاختبار بـ pgTAP ممكنًا، ويمنع أي عميل (حتى لو كُتب خطأ) من كسر القاعدة.

### قاعدة البيانات

| المجال | الجداول | قيود جوهرية |
|---|---|---|
| الهوية | `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles` | `has_permission(code)` تقرأ `auth.uid()`، والحساب غير النشط بلا صلاحيات |
| السيارات | `vehicles`, `vehicle_driver_history`, `vehicle_status_history`, `odometer_readings`, `vehicle_documents` | رقم اللوحة والرقم الداخلي فريدان، العداد لا ينقص إلا بسبب موثق، ربط نشط واحد فقط لكل سائق ولكل سيارة في أي لحظة (exclusion على الفترة)، وكل تغيير مسجل بسبب |
| السائقون | `drivers`, `qualifications`, `driver_qualifications`, `driver_leaves` | `drivers.user_id` فريد، وللتأهيل تاريخ انتهاء، و`work_status` (`available` | `on_task` | `returning` | `on_leave` | `unavailable`) |
| المهام | `tasks`, `task_assignments`, `task_transitions`, `task_status_history`, `task_stops`, `task_attachments` | رقم مرجعي فريد؛ `kind` (`delivery` | `maintenance_run` | `other`)؛ محطات `task_stops` بترتيب `seq` فريد داخل المهمة؛ إسناد نشط واحد لكل مهمة (فهرس جزئي فريد)؛ لا تداخل نافذة سائق أو سيارة (exclusion بـ `tstzrange` على إسنادات نشطة) |
| الرحلات | `trips`, `trip_stops` | مرتبطة بمهمة وسيارة وسائق |
| GPS | `tracking_sessions`, `vehicle_positions`, `vehicle_last_position`, `geofences` | عمود `source` على كل نقطة؛ فريد على `(tracking_session_id, recorded_at)` للتكرار؛ نقطة `last_position` تتحدث فقط لو أحدث |
| الصيانة | `faults`, `maintenance_orders`, `maintenance_parts`, `maintenance_schedules` | السيارة في صيانة لا تُسند (ما لم يوجد استثناء موثق) |
| المال | `fuel_logs`, `expenses`, `receipts` | مرتبطة بسيارة وقراءة عداد |
| التنبيهات | `alert_rules`, `alerts`, `notifications`, `notification_deliveries` | حالة التسليم: `queued → sent → delivered → failed`، و`delivered` فقط بتأكيد |
| النظام | `settings`, `audit_log` | `audit_log` للإضافة فقط لكل الأدوار |

### آلة حالات المهمة

الانتقالات المسموحة فقط (تُخزَّن في جدول `task_transitions` وتفرضها دالة trigger، وكل انتقال يُسجَّل في `task_status_history`):

| من | إلى | بواسطة |
|---|---|---|
| draft | pending_assignment | مسؤول الحركة |
| pending_assignment | assigned | `assign_task` (تلقائي أو يدوي) |
| assigned | awaiting_acceptance | النظام عند إنشاء الإشعار |
| awaiting_acceptance | accepted | السائق |
| awaiting_acceptance، assigned، accepted | pending_assignment | رفض السائق (بسبب) أو إعادة إسناد من المسؤول (بسبب)؛ عدم القبول لفترة يرفع تنبيهًا ولا يغيّر الحالة |
| accepted | in_progress | السائق (زر «بدء المهمة» عند التحرك، مع عداد البداية) |
| in_progress | completed | النظام عند انتهاء آخر محطة (عداد النهاية + إثبات تسليم إن لزم) |
| accepted، in_progress | delayed | النظام فقط (مهمة مجدولة) |
| delayed | الحالة السابقة | النظام/السائق (تُحفظ `delayed_from_status`) |
| أي حالة غير نهائية | cancelled | مسؤول الحركة أو المدير (بسبب) |
| in_progress | failed | السائق أو المسؤول (بسبب) |

الحالات النهائية: `completed`, `cancelled`, `failed`.

لا توجد حالة «في الطريق إلى نقطة البداية»: مسؤول الحركة يحمّل السيارة من المخزن قبل الإسناد، فيبدأ السائق مباشرة بعد القبول.

### محطات المهمة وتدفق السائق

المهمة تتكون من نقطة تحميل (مثل المخزن) وفرع واحد أو أكثر بترتيب `seq`. لكل محطة حالة `task_stops.status`: `pending → arrived → unloaded`، ويمكن `skipped` أو `failed` بسبب مسجل. لا تصير محطة `arrived` قبل أن تكون السابقة `unloaded` أو `skipped`.

| زر السائق | الأثر |
|---|---|
| قبول | `awaiting_acceptance → accepted` |
| بدء المهمة | `accepted → in_progress`، يسجل عداد البداية |
| تم الوصول | المحطة الحالية `pending → arrived` مع وقت الوصول (وموقع GPS إن توفر، للمعلومية فقط ولا يمنع الضغط) |
| انتهاء التنزيل | المحطة `arrived → unloaded` وتُفتح التالية. عند آخر محطة تكتمل المهمة (مع عداد النهاية وإثبات التسليم إن لزم) |

**بعد آخر محطة:** السائق في حالة عودة (`returning`) إلى نقطة العودة المحددة في المهمة (مثل المخزن). العودة لا تحجز نافذة زمنية، فيستطيع مسؤول الحركة إسناد مهمة جديدة له أثناء العودة، أو توجيهه إلى الصيانة أو مكان آخر (`kind`: `maintenance_run` أو `other`).

### إسناد المهام وربط السائق بالسيارة

التوزيع يدوي بالكامل: مسؤول الحركة يختار السائق، والنظام لا يرشّح ولا يرتّب سائقين. دوره أن يمنع التعارض ويوثق كل تغيير.

لكل سائق سيارة خاصة به (ربط نشط واحد). عند حدوث مشكلة يغيّر المسؤول سيارة السائق مع بقاء السائق، أو يغيّر سائق السيارة مع بقاء السيارة، والسجل يحتفظ بالتاريخ والسبب.

**الدوال** (كلها في Postgres، ذرية، وتكتب `audit_log`):
- `pair_vehicle(p_driver_id uuid, p_vehicle_id uuid, p_reason text) returns uuid`: تنهي الربط الحالي للسائق وللسيارة معًا وتنشئ الربط الجديد في معاملة واحدة، فتخدم الحالتين (تغيير سيارة السائق، أو تغيير سائق السيارة). السبب إلزامي. إن كان للسائق مهام مسندة لم تبدأ تُحدَّث سيارتها ويُشعَر السائق. وإن كانت له مهمة `in_progress` تُرفض الدالة ويُستخدم `reassign_task`.
- `assign_task(p_task_id uuid, p_driver_id uuid, p_reason text default null) returns uuid`: السيارة هي سيارة السائق الحالية. ترفض بقائمة موانع صريحة: `no_vehicle`، `on_leave`، `unavailable`، `unqualified`، `overlap`، `vehicle_unavailable`. استثناء سيارة الصيانة يتطلب صلاحية `vehicles.assign_in_maintenance` وسببًا مسجلًا. تنشئ الإسناد وتنقل المهمة إلى `assigned` وتنشئ إشعار السائق.
- `reassign_task(p_task_id uuid, p_driver_id uuid, p_vehicle_id uuid, p_reason text) returns uuid`: تغيير سائق المهمة أو سيارتها حتى أثناء التنفيذ (مثل عطل في الطريق). يُغلق الإسناد القديم ويُنشأ جديد، والمحطات المنتهية (`unloaded`) تبقى كما هي، وتُسجَّل قراءة عداد الإغلاق للسيارة القديمة وقراءة البداية للجديدة، ويُشعَر السائقان.
- `respond_to_assignment(p_assignment_id uuid, p_accept boolean, p_reason text)`.

### الصلاحيات

الأدوار: `system_admin`, `fleet_manager`, `dispatcher`, `supervisor`, `driver`, `maintenance`, `finance`. التخصيص يتم بصفوف `role_permissions` وليس بكود. رموز الصلاحيات الابتدائية:
`users.manage`, `settings.write`, `audit.read`, `vehicles.read`, `vehicles.write`, `drivers.read`, `drivers.write`, `tasks.read`, `tasks.read_own`, `tasks.create`, `tasks.assign`, `tasks.reassign`, `fleet.pair`, `vehicles.assign_in_maintenance`, `tasks.respond_own`, `tracking.read`, `tracking.write_own`, `maintenance.read`, `maintenance.write`, `finance.read`, `finance.write`, `reports.read`, `reports.export`.

بيانات السائق محصورة بصفوفه عبر RLS (`drivers.user_id = auth.uid()`).

### واجهة مصادر GPS

- نقطة دخول واحدة: Edge Function `ingest-positions` تستقبل دفعة `{tracking_session_id, points:[{recorded_at, lat, lng, speed?, heading?, accuracy?}]}`.
- المصادقة: JWT السائق، وجلسة التتبع تُفتح فقط لسائق عنده مهمة `in_progress` أو في حالة عودة.
- التكرار: `INSERT ... ON CONFLICT DO NOTHING` على المفتاح الفريد، فإعادة الإرسال بعد انقطاع آمنة.
- الحالة: `fresh` أقل من `gps.stale_after_seconds`، `stale` حتى `gps.offline_after_seconds`، بعدها `offline`. تُحسب وقت القراءة ولا تُخزَّن.
- المصدر الآن واحد (تطبيق Android). عمود `source` على كل نقطة يتسع لمصدر ثانٍ لاحقًا بلا تغيير في الجداول، ولا يُبنى منطق تعارض بين المصادر إلا إذا ظهر مصدر ثانٍ فعلًا.
- المسافة والتوقفات: تُحسب من النقاط بدالة SQL (PostGIS)، والنقاط ذات الدقة الأضعف من `gps.min_accuracy_m` تُخزَّن لكن لا تدخل الحساب.
- الانقطاع: `pg_cron` كل دقيقة يفحص آخر نقطة ويفتح تنبيه `gps_offline` واحدًا بلا تكرار.

### الإشعارات

- الإشعار صف في `notifications` يصل للتطبيق عبر Supabase Realtime. تطبيق Android يحتفظ بالاشتراك طوال الوردية (خدمة أمامية مشتركة مع التتبع) ويعرض إشعار Android محليًا عند وصول إسناد أو تعديل أو إلغاء.
- `delivered` لا تُسجَّل إلا حين يؤكد التطبيق الاستلام (ack). بدون ack تبقى `sent`.
- حدّ معروف: لو أغلق النظام التطبيق أو لم تبدأ الوردية فلن يصل الإشعار حتى يُفتح التطبيق. لذلك أي مهمة لم تُقبل خلال `assignment.unaccepted_alert_minutes` ترفع تنبيهًا لمسؤول الحركة ليتصل بالسائق. هذا شبكة أمان وليس ضمانًا بوصول الإشعار.

---

## المراحل

كل مرحلة لها خطة مهام تفصيلية (TDD) تُكتب عند بدئها بعد اعتماد المرحلة السابقة، لأن كتابتها الآن ستعني تخمين واجهات كود لم يُكتب. المرحلتان 0 و1 مفصّلتان أدناه.

| # | المرحلة | الاختبارات الأساسية | شرط الانتقال |
|---|---|---|---|
| 0 | الأساسات: المستودع، CI، بيئة اختبار، انضباط الهجرات | smoke، فحص الأسرار، فحص الهجرات المدمرة | CI أخضر |
| 1 | الهوية والصلاحيات والتدقيق والإعدادات وهيكل الواجهة | مصفوفة صلاحيات، فحص RLS على كل جدول، audit append-only | لا جدول بلا RLS، وكل الاختبارات خضراء |
| 2 | السيارات والسائقون والتأهيلات والمستندات والعداد وربط السائق بالسيارة وسجله | قيود التفرد والتداخل، العداد المتزايد، RLS للسائق، `pair_vehicle` (تبديل السيارة وتبديل السائق) | فرض القيود في القاعدة لا الواجهة |
| 3 | المهام والإسناد اليدوي وآلة الحالات والإشعارات داخل التطبيق | كل انتقال مسموح وغير مسموح، `task_window_boundaries`، `task_stops_order` (محطة لا تُفتح قبل السابقة)، `assign_blockers`، `assignment.concurrency` | لا انتقال غير مسجل، لا تداخل |
| 4 | إعادة الإسناد وأثر تبديل السائق/السيارة على المهام، وإبطال الإسناد عند تغير الحالة | `reassign_task` (حتى أثناء مهمة جارية)، أثر `pair_vehicle` على المهام المسندة، `assignment_invalidation` | لا مهمة تبقى على سائق أو سيارة غير صالحة بصمت |
| 5 | واجهة السائق والرحلات وإثبات التسليم | مسار قبول/رفض/بدء/وصول/انتهاء تنزيل لمهمة بفرع واحد ولمهمة بثلاثة فروع (e2e) | سائق لا يرى إلا مهامه (اختبار مباشر على API) |
| 6 | GPS: الاستقبال، الخريطة الحية، السجل والإعادة، التنبيهات، تطبيق Android بوضع الوردية | `ingest_positions`، اختبار ميداني على جهاز حقيقي | موقع حقيقي من جهاز فعلي، ومزامنة بعد انقطاع مختبرة |
| 7 | الصيانة والأعطال والوقود والمصروفات | منع إسناد سيارة الصيانة، حسابات التكلفة | الأرقام تطابق الإدخال |
| 8 | الإشعارات الفورية عبر Supabase Realtime، والتقارير والتصدير Excel/PDF | مطابقة إجماليات التصدير مع الاستعلام | أرقام التصدير = أرقام الشاشة |
| 9 | التصليب: مراجعة أمنية، حمل، نسخ احتياطي واستعادة فعلية، التوثيق والنشر | مصفوفة RLS الكاملة، تمرين استعادة | استعادة ناجحة موثقة |

### تغطية الوثيقة

| القسم | المرحلة |
|---|---|
| 1 السيارات، 2 السائقون | 2 |
| 3 الدور | أُلغي بطلبك، ويحل محله الإسناد اليدوي في 3 وتبديل السائق/السيارة في 2 و4 |
| 4 المهام | 3 |
| 5 GPS | 6 |
| 6 تطبيق السائق | 5 (وإرسال الموقع في 6) |
| 7 الرحلات | 5 و6 |
| 8 الصيانة | 7 |
| 9 الوقود والمصروفات | 7 |
| 10 التنبيهات | 3 (داخل التطبيق)، 6 (GPS)، 8 (فوري) |
| 11 التقارير | 8 (وتشمل سجل إعادة الإسناد، وبدون بنود عدالة الدور لأنها أُلغيت) |
| 12 الصلاحيات والتدقيق | 1 |
| 13 الهندسة والأمن | 0 و1 ويتكرر في كل مرحلة، 9 للتصليب |
| 14 قواعد التنفيذ | Global Constraints |

---

## هيكل الملفات (المرحلتان 0 و1)

```
web/src/app/App.tsx                 # هيكل التطبيق (RTL)
web/src/app/App.test.tsx
web/src/auth/RequirePermission.tsx  # تجربة مستخدم فقط، وليست حماية
web/src/styles/tokens.css           # ألوان وخطوط ومسافات
supabase/migrations/0000_extensions.sql
supabase/migrations/0001_identity.sql
supabase/migrations/0002_identity_rls.sql
supabase/migrations/0003_audit.sql
supabase/migrations/0004_settings.sql
supabase/tests/helpers.sql          # للاختبار فقط، لا يُنشر
supabase/tests/001_identity.test.sql
supabase/tests/002_rls.test.sql
supabase/tests/003_audit.test.sql
supabase/tests/004_settings.test.sql
scripts/check-migrations.sh
scripts/check-migrations.test.sh
.github/workflows/ci.yml
```

## المرحلة 0: الأساسات

### Task 0.1: هيكل المشروع و CI

**Files:**
- Create: `package.json`, `vite.config.ts`, `tsconfig.json`, `index.html`, `web/src/main.tsx`, `web/src/app/App.tsx`, `.env.example`, `.github/workflows/ci.yml`, `README.md`
- Test: `web/src/app/App.test.tsx`, `web/src/no-secrets.test.ts`

**Interfaces:**
- Produces: `App(): JSX.Element`، وسكربتات npm: `test`, `typecheck`, `lint`, `db:test`, `e2e`.

- [ ] **Step 1: اكتب الاختبارات الفاشلة**

```ts
// App.test.tsx
it('renders Arabic RTL shell', () => {
  render(<App />);
  expect(document.documentElement.dir).toBe('rtl');
  expect(document.documentElement.lang).toBe('ar');
  expect(screen.getByRole('main')).toBeInTheDocument();
  expect(screen.getByRole('heading', { name: 'FleetMind' })).toBeInTheDocument();
});
// no-secrets.test.ts
it('has no service_role reference in web source', () => {
  expect(grepSource('web/src', /service_role/i)).toEqual([]);
});
```

- [ ] **Step 2: شغّل `npx vitest run`** — المتوقع: FAIL لأن `App` غير موجود.
- [ ] **Step 3: نفّذ `App(): JSX.Element` في `web/src/app/App.tsx`** يضبط `dir` و`lang` على `documentElement` ويعرض `<main>` وعنوان FleetMind. `.env.example` فيه `VITE_SUPABASE_URL` و`VITE_SUPABASE_ANON_KEY` فقط.
- [ ] **Step 4: شغّل `npx vitest run`** — المتوقع: PASS.
- [ ] **Step 5: `ci.yml`** بثلاث وظائف: `web` (typecheck + lint + vitest)، `db` (`supabase start` ثم `supabase db lint` ثم `supabase test db`)، `e2e` (Playwright). التحقق: دفع الفرع، وكل الوظائف خضراء.
- [ ] **Step 6: Commit** `chore: scaffold web app and CI`

### Task 0.2: انضباط الهجرات

**Files:**
- Create: `supabase/migrations/0000_extensions.sql`, `scripts/check-migrations.sh`
- Test: `scripts/check-migrations.test.sh`

**Interfaces:**
- Produces: `scripts/check-migrations.sh <migrations_dir>` يخرج بـ 1 إذا وُجد `DROP TABLE|DROP COLUMN|TRUNCATE` في migration بلا ملف `<migration>.review.md` بجانبه، أو إذا ظهر `INSERT INTO` على جداول البيانات التجريبية.

- [ ] **Step 1: اكتب الاختبار الفاشل:** migration مؤقتة فيها `DROP COLUMN` بلا ملف مراجعة ← `exit 1`؛ وبعد إضافة `.review.md` ← `exit 0`؛ وmigration عادية ← `exit 0`.
- [ ] **Step 2: شغّل `bash scripts/check-migrations.test.sh`** — المتوقع: FAIL (السكربت غير موجود).
- [ ] **Step 3: نفّذ السكربت** (`grep -E` على الملفات). `0000_extensions.sql` ينشئ `postgis`, `btree_gist`, `pg_cron`. أضف السكربت إلى وظيفة `db` في CI.
- [ ] **Step 4: شغّل الاختبار** — المتوقع: PASS.
- [ ] **Step 5: Commit** `chore: guard destructive migrations`

## المرحلة 1: الهوية والصلاحيات والتدقيق والإعدادات

### Task 1.1: الأدوار والصلاحيات و `has_permission`

**Files:**
- Create: `supabase/migrations/0001_identity.sql`, `supabase/tests/helpers.sql`
- Test: `supabase/tests/001_identity.test.sql`

**Interfaces:**
- Produces: `public.has_permission(p_code text) returns boolean` (`stable`, `security definer`، تقرأ `auth.uid()`، وتُرجع `false` للمجهول ولرمز غير موجود وللحساب غير النشط)؛ الجداول `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles`؛ الأدوار والرموز المذكورة أعلاه كبيانات مرجعية داخل الـ migration. الاختبار فقط: `tests.create_user(p_role text, p_active boolean default true) returns uuid` و`tests.as_user(p_user uuid)`.

- [ ] **Step 1: اكتب الاختبار الفاشل** (`plan(7)`):
  1. `anon` ← `has_permission('vehicles.read')` = false
  2. مستخدم بلا دور ← false
  3. `fleet_manager` ← `has_permission('vehicles.write')` = true
  4. `driver` ← `tasks.read_own` = true و`vehicles.write` = false
  5. `dispatcher` ← `settings.write` = false
  6. `fleet_manager` غير نشط ← false
  7. رمز غير موجود ← false بلا خطأ
- [ ] **Step 2: شغّل `supabase test db`** — المتوقع: FAIL (`has_permission` غير موجودة).
- [ ] **Step 3: نفّذ الجداول و`has_permission`** في `0001_identity.sql`، و`helpers.sql` للاختبار فقط (لا يدخل `migrations/`).
- [ ] **Step 4: شغّل `supabase test db`** — المتوقع: PASS.
- [ ] **Step 5: Commit** `feat(db): roles, permissions, has_permission`

### Task 1.2: RLS على الهوية وتعيين الأدوار

**Files:**
- Create: `supabase/migrations/0002_identity_rls.sql`
- Test: `supabase/tests/002_rls.test.sql`

**Interfaces:**
- Consumes: `has_permission(text)`.
- Produces: `public.assign_role(p_user uuid, p_role text, p_reason text) returns void` (تتطلب `users.manage`، والسبب إلزامي)؛ وسياسات RLS على الجداول الخمسة.

- [ ] **Step 1: اكتب الاختبار الفاشل:**
  - **اختبار شامل يبقى لكل المراحل:** `select tablename from pg_tables where schemaname='public' and not rowsecurity` يرجع صفرًا.
  - سائق لا يرى `user_roles` لغيره.
  - سائق يستدعي `assign_role` ← خطأ `42501`.
  - `system_admin` ينجح، وبدون سبب ← خطأ.
- [ ] **Step 2: شغّل الاختبار** — المتوقع: FAIL.
- [ ] **Step 3: نفّذ السياسات و`assign_role`** (`security definer`، تتحقق من `has_permission('users.manage')` داخل الدالة نفسها).
- [ ] **Step 4: شغّل الاختبار** — المتوقع: PASS.
- [ ] **Step 5: Commit** `feat(db): identity RLS and assign_role`

### Task 1.3: سجل التدقيق

**Files:**
- Create: `supabase/migrations/0003_audit.sql`
- Test: `supabase/tests/003_audit.test.sql`

**Interfaces:**
- Produces: `audit_log(id, actor_id, action, entity, entity_id, old_data, new_data, reason, at)`؛ `public.audit_row_change() returns trigger` قابلة للإرفاق بأي جدول؛ `public.write_audit(p_action text, p_entity text, p_entity_id uuid, p_reason text, p_data jsonb) returns void`. تُرفق `audit_row_change` بـ `user_roles` في هذه المهمة.

- [ ] **Step 1: اكتب الاختبار الفاشل:**
  - `assign_role` يكتب صفًا فيه الفاعل والسبب والتوقيت.
  - `update` و`delete` على `audit_log` مرفوضان حتى لـ `system_admin` عبر دور الـ API.
  - `audit.read` فقط من يقرأ.
- [ ] **Step 2: شغّل الاختبار** — المتوقع: FAIL.
- [ ] **Step 3: نفّذ الجدول والدوال** (سحب `UPDATE/DELETE` عن كل الأدوار، وسياسة قراءة بـ `audit.read`).
- [ ] **Step 4: شغّل الاختبار** — المتوقع: PASS.
- [ ] **Step 5: Commit** `feat(db): append-only audit log`

### Task 1.4: الإعدادات القابلة للضبط

**Files:**
- Create: `supabase/migrations/0004_settings.sql`
- Test: `supabase/tests/004_settings.test.sql`

**Interfaces:**
- Produces: `settings(key text primary key, value jsonb, updated_by, updated_at)`؛ `public.get_setting(p_key text) returns jsonb`؛ `public.set_setting(p_key text, p_value jsonb, p_reason text) returns void` (تتطلب `settings.write`، وتتحقق عبر `validate_setting(p_key text, p_value jsonb) returns boolean` وتكتب audit)؛ مفاتيح ابتدائية: `assignment.unaccepted_alert_minutes`, `gps.update_interval_seconds`, `gps.stale_after_seconds`, `gps.offline_after_seconds`, `gps.min_accuracy_m`, `alerts.speed_limit_kmh`.

- [ ] **Step 1: اكتب الاختبار الفاشل:**
  - `assignment.unaccepted_alert_minutes` بقيمة 0 أو سالبة مرفوضة.
  - `dispatcher` لا يستطيع `set_setting` (`42501`).
  - تغيير ناجح يظهر في `audit_log` مع السبب.
  - `gps.offline_after_seconds` أقل من `gps.stale_after_seconds` مرفوض.
- [ ] **Step 2: شغّل الاختبار** — المتوقع: FAIL.
- [ ] **Step 3: نفّذ الجدول والدوال** والقيم الابتدائية كبيانات مرجعية داخل الـ migration.
- [ ] **Step 4: شغّل الاختبار** — المتوقع: PASS.
- [ ] **Step 5: Commit** `feat(db): validated settings`

### Task 1.5: تسجيل الدخول وهيكل الواجهة

> هنا يُستخدم سكل Frontend Design لتحديد الهوية البصرية (ألوان وخطوط ومسافات) قبل كتابة المكونات.

**Files:**
- Create: `web/src/styles/tokens.css`, `web/src/auth/LoginPage.tsx`, `web/src/auth/RequirePermission.tsx`, `web/src/auth/useSession.ts`
- Test: `web/src/auth/RequirePermission.test.tsx`, `e2e/auth.spec.ts`

**Interfaces:**
- Consumes: `has_permission` عبر RPC.
- Produces: `RequirePermission({ code: string, children })` يعرض صفحة «غير مصرح» عند الرفض، و`useSession(): { user, permissions: Set<string>, loading }`.

- [ ] **Step 1: اكتب الاختبارات الفاشلة:**
  - وحدة: `RequirePermission` يخفي الأبناء ويعرض «غير مصرح» عند غياب الصلاحية.
  - e2e: المستخدم يدخل بالعربية وتظهر الصفحة RTL.
  - e2e: **سائق يستدعي API مخصصًا لمدير مباشرة (بدون الواجهة) فيفشل** — هذا هو الاختبار الذي يثبت أن الحماية في الخادم.
- [ ] **Step 2: شغّل `npx vitest run` ثم `npx playwright test`** — المتوقع: FAIL.
- [ ] **Step 3: نفّذ `tokens.css` وLoginPage وRequirePermission وuseSession**، بتصميم متجاوب يعمل على الموبايل.
- [ ] **Step 4: شغّل الاختبارات** — المتوقع: PASS.
- [ ] **Step 5: Commit** `feat(web): login and permission-guarded shell`

---

## مراجعة ذاتية

- **التغطية:** كل قسم من الأقسام 1 إلى 14 مربوط بمرحلة في جدول «تغطية الوثيقة»، ولا بند محذوف.
- **المهام المفصلة** للمرحلتين 0 و1 فقط. مهام المراحل 2 إلى 9 تُكتب بعد اعتماد ما قبلها (مبرر في قسم المراحل).
- **اتساق الأنواع:** `has_permission(text)` و`write_audit` و`set_setting` تُستخدم بالتوقيعات نفسها في المهام اللاحقة.
- **Review Focus:** كل بند مربوط باختبار مسمى في مرحلته.

## أسئلة مفتوحة

لا أسئلة مفتوحة تعطّل البدء.
