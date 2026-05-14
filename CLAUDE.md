# Sueño Bebé · Brief de implementación para IA generadora de código

> Este documento contiene **reglas, convenciones y decisiones** que la IA debe respetar al implementar la app. **No contiene código.** La IA es responsable de escribir el código siguiendo estas reglas.

---

## 0. Cómo leer y usar este documento

- Todas las reglas son **vinculantes salvo las marcadas como "(orientativo)"**.
- Los **literales** entre comillas o en `code` son exactos: nombres de campos, valores enum, claves de Firestore, IDs de productos, copies. **No traducir, no parafrasear, no renombrar.**
- Si una decisión no aparece aquí, **preguntar al humano antes de inventar**. No tomar decisiones de producto unilaterales.
- Cuando una regla es ambigua o contradice el sentido común, **detenerse y preguntar**. Es preferible una pregunta a una asunción.
- Las secciones "Excluido de V1" y "Reglas para la IA" al final son tan vinculantes como las demás.

### Orden de prevalencia (en caso de conflicto)

1. **§0.1 Spec preeminente de Home y estética global.**
2. El resto del documento.

Si una indicación de §0.1 contradice cualquier otra sección, **prevalece §0.1**.

---

## 0.1 Spec preeminente de Home y estética global

> Esta sección es la fuente de verdad para el diseño de la pantalla Home y para la estética general de la app (tokens, paleta, tipografía, iconografía).
>
> **Importante:** la spec original fue escrita para un prototipo en React 19 + Tailwind CSS v4. La app real es **Flutter**. Lo que prevalece es la **estética y la estructura visual descrita**. La traducción a Flutter se hace siguiendo las "Notas de portabilidad a Flutter" al final de esta sección.

### Spec original (preeminente)

Stack obligatorio: React 19 + TypeScript + Tailwind CSS v4 (tokens definidos en CSS con @theme inline, valores en oklch). Iconos: @phosphor-icons/react (instala con bun add @phosphor-icons/react). Tipografías: Fraunces (display, serif) + Plus Jakarta Sans (sans). Sin librerías de UI extra.

**1. Design system (en styles.css global)**
Define dos temas con tokens semánticos en oklch. Nunca uses colores hardcodeados en componentes — siempre tokens.

Modo día (:root):

- `--background: oklch(0.985 0.012 70)` (crema cálido)
- `--foreground: oklch(0.22 0.03 40)`
- `--card: oklch(1 0 0)`
- `--primary: oklch(0.72 0.15 35)` (coral cálido)
- `--muted: oklch(0.95 0.015 70)`, `--muted-foreground: oklch(0.52 0.03 50)`
- `--accent: oklch(0.85 0.10 60)` (melocotón)
- `--border: oklch(0.91 0.012 60)`
- `--sun: oklch(0.78 0.15 75)` (miel), `--moon: oklch(0.58 0.08 250)` (azul pizarra)
- `--trial: oklch(0.96 0.04 90)`, `--trial-foreground: oklch(0.40 0.10 60)`
- Tokens de evento: `--ev-feed: oklch(0.78 0.13 35)`, `--ev-sleep: oklch(0.70 0.10 240)`, `--ev-diaper: oklch(0.78 0.12 145)`, `--ev-play: oklch(0.80 0.14 75)`, `--ev-bath: oklch(0.78 0.10 200)`, `--ev-meds: oklch(0.75 0.12 10)`
- `--timeline-track: oklch(0.94 0.015 60)`, `--timeline-axis: oklch(0.78 0.02 50)`
- `--fab: oklch(0.30 0.05 40)`, `--fab-foreground: oklch(0.99 0.01 70)`
- `--radius: 1rem`

Modo noche (.dark):

- `--background: oklch(0.18 0.02 250)` (azul noche profundo)
- `--foreground: oklch(0.94 0.015 70)`
- `--card: oklch(0.22 0.025 250)`
- `--primary: oklch(0.78 0.13 35)` (coral más luminoso)
- `--muted: oklch(0.26 0.025 250)`, `--muted-foreground: oklch(0.72 0.03 240)`
- `--accent: oklch(0.40 0.06 250)`
- `--border: oklch(1 0 0 / 10%)`
- `--trial: oklch(0.32 0.05 80)`, `--trial-foreground: oklch(0.92 0.06 80)`
- `--fab: oklch(0.78 0.13 35)`, `--fab-foreground: oklch(0.18 0.02 250)`
- Eventos un poco más saturados (mismos hues)

Clase utilidad `.timeline-force-light`: redefine localmente los tokens de día (`--background`, `--foreground`, `--card`, `--border`, `--timeline-*`, `--ev-*`, `--muted-foreground`) para que el bloque de la línea temporal mantenga aspecto día incluso dentro de `.dark`.

Clase `.phone-frame`: 360×760 px, `border-radius: 44px`, fondo `var(--background)`, doble box-shadow para simular bisel + sombra ambiental. `.phone-notch`: pill 110×22 px, top 8px, centrado, color azul muy oscuro (`oklch(0.18 0.01 250)`).

Clase `.timeline-future`: `repeating-linear-gradient(to right, var(--timeline-axis) 0 4px, transparent 4px 8px)`, alto 2px (raya punteada para tramo estimado).

**2. Datos de ejemplo**
NOW = 16:42, TIMELINE_START = 07:32, TIMELINE_END = 20:30. Eventos (en minutos desde 00:00, kind, label):

1. Toma 07:32–07:50 · 2. Pañal 08:10 · 3. Siesta 09:15–10:40 · 4. Toma 11:00–11:20 · 5. Juego 11:30–12:30 · 6. Pañal 12:45 · 7. Siesta 13:10–15:30 · 8. Toma 16:00–16:20 · 9. Baño 16:35–16:42

Eventos con end → bloque coloreado. Sin end → marker circular.

**3. Estructura del componente `<HomeScreen mode="day" | "night">`**
Envuelto en `.phone-frame` + `.phone-notch`. Si `mode="night"` añade clase `.dark`. Layout vertical con `padding-bottom: 88px` para dejar hueco a la bottom nav (que se posiciona absolute).

De arriba a abajo:

- **Status bar** (`px-6 pt-3 pb-1`, font-size 11px semibold): a la izquierda 16:42. A la derecha en fila con gap 1.5: SVG señal (4 barras, la última opacity 0.4), SVG wifi (dos arcos + punto), batería (rect 24×12 con borde, relleno interno con margen 1.5px y derecha 7px = ~70%, más nipple 1.5×6).
- **Header** (`px-5`, `flex items-end justify-between`):
  - Botón izquierdo: pequeña etiqueta "HOY" 11px uppercase tracking 0.18em muted; debajo `<h1>` Fraunces 26px semibold "Lunes, 4 de mayo" + `CaretDown` Phosphor 16px bold muted desplazado -2px.
  - Avatar derecho: botón circular 40px, `bg var(--accent)`, letra "L" Fraunces bold centrada.
- **Toggle día/noche** (`mx-5, w-fit, rounded-full, bg secondary, padding 1`): dos pills. Pill activa: `bg card`, texto `foreground`, sombra sm. Pill inactiva: solo `muted-foreground`. Iconos `Sun` (color `--sun`) y `Moon` (color `--moon`) Phosphor weight fill 14px + label "Día"/"Noche" 12px semibold.
- **Trial banner** (`mx-5, rounded-xl, px-3.5 py-2`, bg `--trial`, color `--trial-foreground`): izquierda dot 1.5px + "Trial: te quedan 2 días" 12px. Derecha "Suscribirse" 12px bold underline.
- **Counters** (`mx-5, grid-cols-2 gap-2.5`): dos tarjetas rounded-2xl bg-card border p-3. Cada una: línea superior 11px muted con icono 12px (`Sun` honey / **`BabyBottle` coral**) + label ("Despierto hace" / "Última toma hace"). Debajo Fraunces 20px semibold ("1h 12 min" / "42 min").
- **Timeline** (`mx-5, rounded-3xl, border, bg-card, p-4`) — si `mode="night"` añade clase `.timeline-force-light`:
  - Header: "LÍNEA DEL DÍA" 11px uppercase tracking 0.18em semibold muted + a la derecha "07:32 – 20:30" 11px muted.
  - Contenedor relativo `h-[120px] pt-2`.
  - Eje a top: 58px, alto 2px, ancho completo color `--timeline-track`. Encima: tramo pasado (left:0, width: nowPct%) color `--timeline-axis`; tramo futuro (left: nowPct%, right:0) usa `.timeline-future` (punteado).
  - Marcas horarias cada 2h (08, 10, 12, 14, 16, 18, 20): a top:52px, posición left: pct(m)% con translateX(-50%). Tick vertical 1×14px color axis opacity 0.6 + debajo hora "HH:MM" 10px muted tabular-nums.
  - Bloques de duración (eventos con end): top:30px height:22px, left: pct(start)%, width: pct(end)-pct(start)% (mínimo 2%), bg = token del evento, opacity 0.9, rounded-md, icono Phosphor 11px blanco centrado.
  - Markers instantáneos (sin end): círculos 24px a top:70px, -translate-x-1/2, bg = token del evento, sombra sm, icono 11px blanco.
  - Indicador AHORA: en left: nowPct%, top:0, -translate-x-1/2. Pill "AHORA" 9px bold, bg `--primary`, texto `--primary-foreground`, padding 0.375rem×1px. Debajo línea vertical 2×78px color `--primary` (mt-1).
  - Leyenda (mt-2, flex-wrap, gap-x-3 gap-y-1, 10px muted): dot 8px del color + nombre, para feed/sleep/diaper/play/bath.
- **FAB** (`flex justify-center, -mt-1 mb-3`): círculo 56px bg `--fab`, color `--fab-foreground`, icono `Plus` 26px bold. Sombra: `0 12px 30px -8px color-mix(in oklab, var(--primary) 45%, transparent)`. `active:scale-95`.
- **Banner anuncio** (`mx-auto, 320×50`): rounded-md, border-dashed, bg muted/60. Esquina sup-izq: "ANUNCIO" 8px bold uppercase tracking. Centro: "320 × 50 · AdMob" 11px muted.
- **Bottom nav** (`absolute bottom-0 inset-x-0, pt-1 pb-4 px-4`, bg-card, border-t):
  - Tres botones (Home `House`, Estadísticas `ChartBar`, Ajustes `Gear`) Phosphor 22px. Activo: `weight="fill"` color `--primary`. Inactivo: `weight="regular"` color `--muted-foreground`. Label 10px semibold debajo, mismo color.
  - Debajo: home indicator pill 112×4 px, bg-foreground/30, mx-auto mt-2.

**4. Página contenedora**
Fondo: `radial-gradient(1200px 600px at 20% -10%, oklch(0.92 0.05 60 / 0.7), transparent 60%), radial-gradient(900px 500px at 90% 0%, oklch(0.88 0.08 240 / 0.35), transparent 60%), oklch(0.97 0.012 70)`.

Header centrado: eyebrow "PROTOTIPO · PANTALLA HOME" 12px bold uppercase tracking 0.25em color `--primary`. H1 Fraunces 4xl/5xl semibold. Subtítulo lg muted.

Grid `md:grid-cols-2 gap-12` con dos `<HomeScreen>` (day y night) cada uno con etiqueta debajo (dot del color sun/moon + "Modo día" / "Modo noche").

Panel "Anotaciones de interacción" `max-w-2xl rounded-3xl border bg-card/80 backdrop-blur p-8`. Lista numerada con badges circulares 20px bg `--primary`:

1. Tap en cabecera abre calendario. 2. Tap en marker abre detalle. 3. FAB abre bottom sheet "Añadir evento". 4. Trial banner lleva al paywall. 5. Toggle cambia tema manteniendo timeline en día.

**5. Reglas estrictas**
- NUNCA clases tipo `text-white`, `bg-black`, `text-gray-500`. Solo tokens (`bg-card`, `text-muted-foreground`, etc.) o `style={{ color: "var(--color-x)" }}` para tokens custom no mapeados a Tailwind.
- Iconos siempre Phosphor (`@phosphor-icons/react`), nunca lucide ni emoji.
- Las dos variantes son el mismo componente con prop `mode`. La única diferencia visual extra: en noche, el bloque timeline lleva `.timeline-force-light`.
- Cálculo posiciones: `pct(m) = ((m - START) / (END - START)) * 100`.

### Notas de portabilidad a Flutter

La spec anterior es de un prototipo React. La implementación real es Flutter. Reglas de traducción:

1. **Tokens oklch.** Flutter no tiene oklch nativo. Convertir cada valor oklch a sRGB (vía `material_color_utilities` o conversión manual) y exponer los tokens en una clase única `AppColors` (en `lib/app/theme/app_colors.dart`) con dos perfiles (día y noche). Conservar como **comentario al lado de cada token su valor oklch original** para trazabilidad.
2. **Tokens semánticos.** Cada token de la spec (`background`, `foreground`, `card`, `primary`, `muted`, `muted-foreground`, `accent`, `border`, `sun`, `moon`, `trial`, `trial-foreground`, `ev-feed`, `ev-sleep`, `ev-diaper`, `ev-play`, `ev-bath`, `ev-meds`, `timeline-track`, `timeline-axis`, `fab`, `fab-foreground`, `radius`, `primary-foreground`) debe existir como propiedad de `AppColors`.
3. **`primary-foreground` (no definido en spec).** Inferir: en modo día = `--background` (crema cálido sobre primary coral); en modo noche = `--background` (azul noche profundo sobre primary coral luminoso). Confirmar visualmente al implementar.
4. **`.timeline-force-light`.** Implementar como un widget envoltorio (`TimelineForceLightTheme`) que sobrescribe el `Theme` heredado con los tokens del modo día solo para su subárbol. La línea temporal **siempre** se renderiza con los tokens de día, incluso cuando la app está en modo noche.
5. **Tipografías.** `Fraunces` (display/serif) y `Plus Jakarta Sans` (sans) cargadas vía `google_fonts` y declaradas en `ThemeData`. Fraunces para H1, contadores numéricos grandes y números destacados. Plus Jakarta Sans para el resto.
6. **Iconos.** `phosphor_flutter`. Misma equivalencia que en spec original. Los `weight="fill"` / `weight="regular"` se traducen a las variantes correspondientes del paquete (`PhosphorIconsFill`, `PhosphorIconsRegular`).
7. **`.phone-frame` y `.phone-notch`.** Son envoltorios del prototipo React para emular un dispositivo. **No se trasladan a Flutter.** En Flutter la app ocupa la pantalla real.
8. **Status bar simulada del prototipo.** **No se renderiza.** Flutter usa la status bar nativa de Android. Configurar `SystemUiOverlayStyle` para que respete el modo de tema activo (icons claros sobre fondo oscuro y viceversa).
9. **Página contenedora con dos `<HomeScreen>` lado a lado.** Es el lienzo del prototipo. **No se traslada.** En Flutter `HomeScreen` es la única pantalla raíz de su pestaña.
10. **`mode="day" | "night"` como prop.** En Flutter es un valor leído desde el provider del modo activo (el toggle de §9 de este brief). El widget `HomeScreen` no recibe `mode` por parámetro; lo lee del estado.
11. **`color-mix(in oklab, ...)`.** En Flutter se aproxima con `Color.alphaBlend` o `Color.lerp` entre dos sRGB equivalentes.
12. **Datos de ejemplo del prototipo** (NOW=16:42, eventos del día con pañal, juego, baño…). Son **solo de referencia visual**. La app V1 implementa solo los 6 tipos de evento de §8.1; los tokens `--ev-diaper`, `--ev-play`, `--ev-bath`, `--ev-meds` se definen en el sistema pero **no se usan en V1** (quedan listos para V2+).
13. **Mapeo de los 6 tipos de evento V1 a tokens de color:**
    - `morning_wake`, `nap`, `bedtime`, `night_wake` → `ev-sleep`
    - `nursing`, `bottle` → `ev-feed`
14. **Banner anuncio del prototipo** (placeholder dashed). En la app real se sustituye por la unidad real de AdMob (banner adaptativo). El estilo visual del placeholder solo aplica a wireframes, no al producto.
15. **Bottom nav.** Tres pestañas con iconos Phosphor (`House`, `ChartBar`, `Gear`) y labels "Inicio" / "Estadísticas" / "Ajustes" (12px en lugar de 10px del prototipo si la legibilidad en Android lo requiere).

### Reglas estrictas en Flutter (equivalentes a las del prototipo)

- **NUNCA** usar `Colors.white`, `Colors.black`, `Colors.grey[N]`, `Colors.red`, etc. Solo tokens vía `AppColors.of(context).background`, `Theme.of(context).colorScheme.primary`, etc.
- **NUNCA** hardcodear colores hex en widgets (`Color(0xFF123456)`). Solo en `AppColors`.
- **Iconos siempre Phosphor** (`phosphor_flutter`). Prohibido usar Material Icons (`Icons.*`) y emojis.
- El cálculo de posiciones de la línea temporal sigue la fórmula: `pct(m) = ((m - START) / (END - START)) * 100`.

---

## 1. Contexto del producto

- App **Android** (Flutter). iOS queda fuera de V1.
- Registro visual de eventos de sueño y alimentación de un bebé.
- **1 bebé por cuenta** en V1.
- Hasta **2 cuidadores** compartiendo el mismo bebé (papá + mamá).
- **Idioma único:** español (`es`).
- **Audiencia:** padres y madres mayores de edad. Uso frecuente en condiciones nocturnas (despertares).
- **Principio rector de UX:** registro rapidísimo, pocos taps, alto contraste en oscuro, contadores claros.

---

## 2. Stack técnico obligatorio

| Capa | Tecnología obligatoria |
|---|---|
| Frontend | Flutter, canal `stable`, Dart sound null safety |
| Estado | Riverpod 2.x con `riverpod_generator` (providers `@riverpod`) |
| Navegación | GoRouter |
| Backend | Firebase Cloud Functions, **TypeScript**, runtime Node 20, **gen 2** |
| BD | Cloud Firestore, región `europe-west1` |
| Auth | Firebase Auth (Google + Email/Password) |
| Storage | Firebase Storage (foto del bebé y CSV temporales) |
| Push | Firebase Cloud Messaging |
| Analytics | Firebase Analytics + Crashlytics |
| Pagos | Google Play Billing vía paquete `in_app_purchase` |
| Ads | Google Mobile Ads SDK + UMP de Google para consentimiento |
| Iconos | Phosphor (`phosphor_flutter`) |
| Tipografías | `google_fonts` con Fraunces (display/serif) + Plus Jakarta Sans (sans) |
| Modelos | Freezed + `json_serializable` |
| Calendario | `table_calendar` |
| Gráficas | `fl_chart` |

Versiones: usar las últimas estables compatibles con Flutter stable a fecha de implementación. No fijar versiones antiguas salvo necesidad explícita.

---

## 3. Restricciones técnicas (NO usar / NO hacer)

- **No** Clean Architecture académica con casos de uso obligatorios para cada acción trivial.
- **No** mezclar gestores de estado: solo Riverpod.
- **No** usar BLoC, GetX, MobX, ni `Provider` clásico.
- **No** introducir DI manual ni service locators (`get_it`, etc.). Riverpod cubre todo.
- **No** usar `setState` en widgets que tengan lógica de negocio. `setState` solo para UI puramente local (animaciones, toggles visuales).
- **No** crear capas `data`/`domain`/`presentation` en features que no las necesitan.
- **No** persistir nada relevante en `SharedPreferences` salvo preferencias de UI puramente locales (modo de tema forzado, último filtro de stats). La fuente de verdad es Firestore.
- **No** implementar lógica de negocio crítica en cliente que también deba estar en backend (validación de pagos, cálculo de estadísticas precomputadas, decisión de expiración de trial).
- **No** llamar a APIs de Google Play directamente desde el cliente. Toda validación de compras va por Cloud Function.
- **No** usar emojis en copies de la UI ni en iconografía.
- **No** usar `Colors.white`, `Colors.black`, `Colors.grey[N]`, ni colores hex hardcodeados en widgets. Solo tokens (`AppColors`) o `Theme.of(context).colorScheme`.
- **No** usar Material Icons (`Icons.*`). Solo Phosphor.

---

## 4. Arquitectura Flutter: feature-first ligera

- Carpeta raíz `lib/` con dos áreas no-feature: `app/` (router, theme, app shell) y `core/` (servicios, utils, widgets compartidos).
- Carpeta `features/` con una carpeta por feature.
- Cada feature **solo contiene las capas que necesita**. Reglas:
  - Si solo es UI con datos de otra feature → solo `presentation/`.
  - Si tiene su propio repositorio Firestore → añadir `data/`.
  - Si tiene reglas no triviales (validaciones, cálculos) → añadir `domain/` con modelos y/o usecases.
- Lista mínima de features V1: `auth`, `onboarding`, `baby`, `home`, `events`, `calendar`, `stats`, `settings`, `subscription`, `invitations`.
- Backend en carpeta hermana `functions/` con TypeScript.
- Documentos legales en `legal/` (markdown).

**Tema y tokens (centralizado):**
- Una sola clase `AppColors` en `lib/app/theme/app_colors.dart` con todos los tokens de §0.1, expuesta vía Riverpod o vía `Theme` extensions.
- Una sola clase `AppTypography` con los estilos derivados de Fraunces y Plus Jakarta Sans.
- Cualquier widget que necesite color o tipografía pasa por estas clases. Nunca hardcodear.

**Reglas de Riverpod:**
- Usar `@riverpod` con `riverpod_generator`. No `Provider`, `StateProvider`, `FutureProvider`... a mano.
- Repositorios expuestos como `@riverpod` providers.
- Streams de Firestore expuestos como `@riverpod` streams.
- Controllers de UI con estado complejo → `@riverpod class XxxController`.
- Estado efímero de UI → `setState` en `StatefulWidget`. **No usar `flutter_hooks`.**

---

## 5. Convenciones de nombres y datos

### 5.1 Literales exactos de tipos de evento

```
morning_wake
nap
bedtime
night_wake
nursing
bottle
```

No añadir, no renombrar, no traducir.

### 5.2 Literales de estado de evento

```
live
completed
```

### 5.3 Literales de estado de suscripción

```
none
trial
trial_expired
active
grace
on_hold
cancelled
expired
```

### 5.4 Literales de plan

```
monthly
annual
```

### 5.5 IDs de productos en Google Play Console

```
sb_monthly_399
sb_annual_1199
```

### 5.6 Mapeo de tipo de evento a icono Phosphor y a token de color

| `type` | Icono | Token de color |
|---|---|---|
| `morning_wake` | `Sun` | `ev-sleep` |
| `nap` | `Moon` | `ev-sleep` |
| `bedtime` | `Bed` | `ev-sleep` |
| `night_wake` | `MoonStars` | `ev-sleep` |
| `nursing` | `Baby` | `ev-feed` |
| `bottle` | `BabyBottle` | `ev-feed` |

Nota: el icono en el counter "Última toma hace" del header de Home es `BabyBottle` (no `Baby`), siguiendo §0.1.

### 5.7 Convenciones generales

- Claves de documentos con fecha: `YYYY-MM-DD` (ISO local del cuidador).
- Timestamps: **siempre UTC en Firestore**, render en zona local del dispositivo.
- Códigos de invitación: 6 dígitos numéricos (`000000`–`999999`), únicos vivos.
- IDs de Firestore: autogenerados salvo `dailyStats` (que usa `YYYY-MM-DD`) e `invitations` (que usa el código).
- Package Android: `com.monty.suenobebe`.

---

## 6. Modelo de datos Firestore

### 6.1 Colecciones y campos

```
/users/{userId}
  email: string
  displayName: string
  photoUrl: string | null
  caregiverAlias: string | null
  locale: 'es'
  fcmTokens: { [deviceId: string]: { token: string, updatedAt: timestamp } }
  currentBabyId: string | null
  legalAccepted: { privacyVersion: number, termsVersion: number, acceptedAt: timestamp }
  deletionScheduledAt: timestamp | null
  createdAt, updatedAt: timestamp

/babies/{babyId}
  name: string
  birthDate: date
  sex: 'male' | 'female' | 'other'
  photoUrl: string | null
  caregivers: array<userId>            // máx 2 en V1
  adminId: userId
  caregiversInfo: {
    [userId]: {
      alias: string,
      role: 'admin' | 'caregiver',
      joinedAt: timestamp
    }
  }
  subscription: {
    status: <enum §5.3>,
    plan: 'monthly' | 'annual' | null,
    source: 'play_billing' | null,
    purchaseToken: string | null,
    productId: string | null,
    expiresAt: timestamp | null,
    autoRenew: boolean,
    lastVerifiedAt: timestamp | null
  }
  trial: {
    firstEventAt: timestamp | null,
    expiresAt: timestamp | null,            // firstEventAt + 3 días
    hardExpiresAt: timestamp                // createdAt + 30 días
  }
  estimatedMorningWake: string              // 'HH:mm', ej '08:00'
  estimatedBedtime: string                  // 'HH:mm', ej '22:00'
  estimatesRecomputedAt: timestamp
  deletionScheduledAt: timestamp | null
  createdAt, updatedAt: timestamp

/babies/{babyId}/events/{eventId}
  type: <enum §5.1>
  startAt: timestamp
  endAt: timestamp | null                   // null si live o si type es puntual
  durationSec: number | null                // cache calculado
  status: <enum §5.2>
  metadata: {
    breast: 'left' | 'right' | null,
    leftDurationSec: number | null,
    rightDurationSec: number | null,
    bottleMl: number | null,
    note: string | null
  }
  dayKey: string                            // 'YYYY-MM-DD' del día del bebé (ver §9.4)
  createdBy: userId
  createdAt, updatedAt: timestamp

/babies/{babyId}/dailyStats/{YYYY-MM-DD}
  date: string
  totalSleepDayMinutes: number
  totalSleepNightMinutes: number
  totalSleepMinutes: number
  napCount: number
  nightWakeCount: number
  feedingCount: number
  totalFeedingMinutes: number
  totalBottleMl: number
  morningWakeAt: timestamp | null
  bedtimeAt: timestamp | null
  eventsCount: number
  computedAt: timestamp

/invitations/{code}
  babyId: string
  createdBy: userId
  expiresAt: timestamp                      // createdAt + 24h
  used: boolean
  usedBy: userId | null
  usedAt: timestamp | null

/config/sleep_defaults
  ranges: array<{ minMonths, maxMonths, morningWake, bedtime }>

/config/legal
  privacyVersion: number
  termsVersion: number
  privacyUrl: string
  termsUrl: string
  updatedAt: timestamp

/config/products
  monthly: { productId: 'sb_monthly_399', priceText: '3,99 €' }
  annual:  { productId: 'sb_annual_1199', priceText: '11,99 €', highlighted: true }
```

### 6.2 Storage

- Foto del bebé: `babies/{babyId}/photo.jpg`. URL pública en `babies.photoUrl`.
- Exportaciones CSV: `exports/{userId}/{timestamp}.csv`. Política de ciclo de vida que borre objetos a las 24h.

### 6.3 Reglas sobre escritura

- El cliente **nunca** escribe en `dailyStats`, `config/*` ni `invitations/*`. Solo Cloud Functions.
- El cliente **nunca** modifica `caregivers`, `caregiversInfo`, `adminId`, `subscription`, `trial.expiresAt`, `trial.hardExpiresAt`, `estimatedMorningWake`, `estimatedBedtime`, ni los `deletionScheduledAt`. Solo Cloud Functions.
- El cliente sí escribe `trial.firstEventAt` (la primera vez al crear su primer evento) si está vacío.

---

## 7. Reglas de seguridad Firestore (alto nivel)

- `/users/{userId}`: lectura/escritura solo del propio usuario.
- `/babies/{babyId}`: lectura solo si `request.auth.uid in resource.data.caregivers`. Escritura limitada a campos no protegidos (ver §6.3). Creación: solo si el `adminId` es el caller y `caregivers` solo contiene a ese caller.
- `/babies/{babyId}/events/*`: lectura/escritura solo si caller está en `caregivers` del bebé. Borrado permitido. Escritura debe respetar las restricciones de campo del modelo.
- `/babies/{babyId}/dailyStats/*`: solo lectura para caregivers. Escritura prohibida (Cloud Functions).
- `/invitations/{code}`: lectura permitida a cualquier usuario autenticado (necesita poder consultar para canjear). Escritura prohibida (Cloud Functions).
- `/config/*`: solo lectura para usuarios autenticados.

---

## 8. Reglas de eventos

### 8.1 Catálogo (los 6 tipos)

| `type` | Naturaleza | Campos `metadata` rellenos | Contador que afecta |
|---|---|---|---|
| `morning_wake` | Puntual (`endAt = startAt`) | — | Cierra contador "durmiendo", arranca "despierto" |
| `nap` | Inicio + fin | — | "Durmiendo hace X" mientras live; "Despierto hace X" al cerrar |
| `bedtime` | Puntual | — | Cierra "despierto", inicia "durmiendo"; pasa modo a noche |
| `night_wake` | Inicio + fin | — | "Despierto hace X" mientras live; al iniciar siguiente sueño se cierra |
| `nursing` | Inicio + fin | `breast`, `leftDurationSec`, `rightDurationSec` | "Última toma hace X" desde `startAt` |
| `bottle` | Inicio + fin | `bottleMl` | "Última toma hace X" desde `startAt` |

### 8.2 Modos de registro (todos los tipos)

- **En vivo:** se crea con `status='live'`, `endAt=null` (excepto puntuales: en puntuales no hay live, se registra `now` y se completa al instante con `status='completed'` y `endAt=startAt`).
- **Manual a pasado:** formulario con `startAt` (y `endAt` si aplica), guarda con `status='completed'`. Se requiere `endAt > startAt`.

### 8.3 Regla de exclusividad (live)

- En cualquier momento puede haber **como máximo un evento con `status='live'`** por bebé.
- Al iniciar un nuevo evento (live o puntual con `now`):
  - Si existe un evento `live` previo → cerrarlo primero con `endAt = now` y `status='completed'`.
- Esta operación **debe ser atómica** (transacción Firestore).

### 8.4 Regla de no-solapamiento (registro a pasado y edición)

- Antes de crear o editar un evento, calcular su rango temporal `[startAt, endAt]` (para puntuales el rango es `[startAt, startAt]`).
- Si existe **cualquier otro evento** del mismo bebé cuyo rango se cruza con el del nuevo → **bloquear** la operación con mensaje:
  `"Este horario se solapa con [tipo del existente] de [hora inicio]–[hora fin]. Edítalo primero."`
- Ofrecer atajo "Editar evento existente" en el diálogo.
- Esta validación se ejecuta en **cliente** (UX rápida) **y en Cloud Function callable** que el cliente usa para crear/editar.

### 8.5 Edición y borrado

- Cualquier evento es editable y borrable por cualquier cuidador del bebé.
- Borrado pide **confirmación** ("¿Borrar este evento? No se puede deshacer.").
- Edición re-valida no-solapamiento.

### 8.6 Lactancia en vivo (flujo)

1. Bottom sheet de añadir → "Lactancia" → "Iniciar ahora".
2. Pantalla con dos botones grandes: **Iniciar Izq** / **Iniciar Der**. Crea el evento con `status='live'`, `startAt=now`, `metadata.breast` = lado elegido.
3. Mientras el cronómetro corre, se acumulan segundos en `leftDurationSec` o `rightDurationSec` según el lado activo.
4. Botón **Cambiar lado** detiene el contador del lado activo (acumula sus segundos) y arranca el del otro lado.
5. Botón **Finalizar** cierra: `endAt=now`, `status='completed'`, congela `leftDurationSec`/`rightDurationSec`, `breast` = lado activo al finalizar.
6. El registro manual a pasado de lactancia pide: `startAt`, `endAt`, minutos por pecho, opcional nota.

### 8.7 Biberón

- En vivo: crea evento con cronómetro. Al finalizar pregunta `bottleMl` (entero, requerido, > 0).
- Manual: formulario `startAt`, `endAt`, `bottleMl`.

### 8.8 Eventos puntuales

- `morning_wake` y `bedtime` se registran con un único timestamp.
- En el modelo se almacenan con `endAt = startAt` (no null) para simplicidad de queries.
- "Iniciar ahora" registra `now`. "Manual" pide solo fecha+hora.

### 8.9 Indicador de evento en curso

- Si existe un evento con `status='live'`, mostrar un **indicador persistente en home** (banner superior o tarjeta sticky) con:
  - Tipo del evento (ej.: "Siesta en curso").
  - Cronómetro corriendo (mm:ss o hh:mm:ss).
  - Botón **Finalizar**.
- El indicador se mantiene aunque se navegue a otras pestañas (Estadísticas, Ajustes).

### 8.10 Pausa intermedia

- **No existe.** Si el cuidador necesita "pausar", debe finalizar y luego editar a posteriori.

---

## 9. Reglas de modo día/noche

### 9.1 Definiciones

- **Día del bebé** = ventana entre el `morning_wake` (real o estimado) y el `bedtime` (real o estimado) del mismo día natural.
- **Noche del bebé** = ventana entre el `bedtime` de un día y el `morning_wake` del día natural siguiente.

### 9.2 Hora efectiva

- `morning_wake_efectiva` para una fecha D = timestamp del evento `morning_wake` registrado en D si existe, si no, hora estimada (`/babies/{id}.estimatedMorningWake` aplicada a D).
- `bedtime_efectiva` para una fecha D = ídem con `bedtime`.

### 9.3 Modo activo automático

```
Sea now = hora local actual; D = fecha local actual.
Sea bedtime_hoy = bedtime_efectiva(D); morning_hoy = morning_wake_efectiva(D).

Si now >= bedtime_hoy           → modo NOCHE (la noche pertenece a D)
Si now <  morning_hoy            → modo NOCHE (la noche pertenece a D-1)
Si morning_hoy <= now < bedtime_hoy → modo DÍA (el día es D)
```

### 9.4 dayKey de un evento

Reglas para asignar `dayKey` al crear o editar un evento con timestamp `T`:

1. Buscar el último `morning_wake` con `startAt <= T` para el mismo bebé.
2. Si existe → `dayKey = fecha local de ese morning_wake`.
3. Si no existe ningún `morning_wake` previo → `dayKey = fecha local de T`.

Si después se inserta un `morning_wake` nuevo en una fecha que afecta a la asignación de eventos existentes, una **Cloud Function** dispara recálculo de `dayKey` de los eventos posteriores (hasta el siguiente `morning_wake`).

### 9.5 Toggle manual (sol/luna)

- Botones sol y luna encima de la línea temporal.
- **Solo cambia visualización** de la línea temporal y del tema visual de la app. **No** cambia el día activo.
- El estado activo automático se reinstaura al navegar fuera y volver, o al cerrar y reabrir la app.

### 9.6 Tema visual sigue al modo

- Modo día → tema **claro** (tokens día de §0.1).
- Modo noche → tema **oscuro** (tokens noche de §0.1).
- La línea temporal mantiene siempre tokens día (vía `.timeline-force-light` / `TimelineForceLightTheme`).
- Override en Ajustes → "Tema": Auto (default) / Claro forzado / Oscuro forzado.

---

## 10. Reglas de estimación

### 10.1 Inicial (sin histórico)

- Buscar la franja de edad del bebé en `/config/sleep_defaults.ranges` por `birthDate`.
- Tomar `morningWake` y `bedtime` de esa franja.
- Fallback si la edad cae fuera de la tabla: `morningWake='08:00'`, `bedtime='22:00'`.

### 10.2 Con histórico (≥1 día)

- `estimatedMorningWake` = media de las **horas del día** (HH:mm) de los `morning_wake` registrados en los últimos 7 días.
- `estimatedBedtime` = media de las horas del día de los `bedtime` registrados en los últimos 7 días.
- Si hay menos de 7 días pero al menos 1 → usar todos los disponibles.
- Si hay 0 → usar §10.1.

### 10.3 Cuándo se recalcula

- **Cloud Function programada** diaria a las **03:00 Europe/Madrid** recalcula y actualiza `estimatedMorningWake` y `estimatedBedtime` para todos los bebés activos.
- El cliente **lee directamente** los valores desde Firestore. **No** recalcula.

---

## 11. Reglas de contadores (encima de la línea temporal)

### 11.1 Cantidad y refresh

- Máximo **2 contadores** visibles simultáneamente.
- Refresco: cada **60 segundos**.
- Formato:
  - `< 60 min` → `"X min"`
  - `≥ 60 min` → `"Hh Mmin"` (ej.: `"1h 23 min"`).

### 11.2 Contador 1 — Sueño / vigilia (icono `Sun` en color `--sun`)

```
Sea L = evento más reciente del bebé.

Si existe un evento de sueño (nap | bedtime | night_wake) con status='live':
  → "Durmiendo hace X" desde su startAt.
Sino:
  Si L es de sueño cerrado (incluye morning_wake como cierre de bedtime):
    → "Despierto hace X" desde el endAt del último sueño cerrado.
  Si no hay ningún evento aún en el día activo:
    → mostrar texto neutro: "Sin registros aún hoy".
```

(Notas: `morning_wake` no es "evento de sueño live" pero **cierra** el bedtime en curso lógicamente para el contador.)

### 11.3 Contador 2 — Última toma (icono `BabyBottle` en color `--primary` coral)

```
Sea F = última nursing o bottle del bebé (live o cerrada).

Si F es live:
  → "Comiendo desde hace X" desde su startAt.
Si F es cerrada:
  → "Última toma hace X" desde su startAt (no endAt).
Si no hay tomas en el día activo:
  → contador oculto (ni se renderiza el espacio).
```

---

## 12. Reglas de UX por pantalla

> La estructura visual exacta de **Home** (incluyendo cabecera, toggle, contadores, timeline, FAB, banner anuncio y bottom nav) está fijada en **§0.1**. Las reglas siguientes complementan esa estructura con comportamientos y otras pantallas.

### 12.1 Splash y rutas iniciales

- Ruta `/splash`. Decide en orden:
  1. Si no hay sesión Firebase Auth → `/auth/login`.
  2. Si hay sesión pero no hay `currentBabyId` → `/onboarding/baby`.
  3. Si todo OK → `/home`.

### 12.2 Login

- Dos botones: Google y Email/Password.
- Email/Password incluye flujo de recuperación de contraseña.
- Tras login crea/actualiza `/users/{uid}` con campos básicos.
- Estética siguiendo tokens y tipografías de §0.1.

### 12.3 Onboarding (orden)

1. `/onboarding/baby` → datos del bebé. Campos requeridos: nombre (string), fecha nacimiento (date, ≤ hoy), sexo (`male`|`female`|`other`). Foto opcional. Validar fecha.
2. `/onboarding/share` → tres opciones:
   - **Crear código de invitación** (genera código de 6 dígitos para compartir).
   - **Tengo un código** (campo numérico → canjea y se une al bebé existente).
   - **Más tarde** (continúa).
3. `/onboarding/legal` → checkbox "He leído y acepto la Política de Privacidad y los Términos". Botón continuar habilitado solo si está marcado.
4. `/onboarding/notifications` → solicita permiso de notificaciones. Botón "Saltar" disponible.
5. → `/home`.

Si el usuario llega vía código, se salta el paso 1, el sistema le pide solo `caregiverAlias` y vincula al bebé existente.

### 12.4 Home (referencia: §0.1)

Comportamientos clave:

- Tap en cabecera (fecha + CaretDown) → calendario modal.
- Tap en avatar → atajo a Ajustes (perfil).
- Toggle día/noche manual → cambia tema y vista timeline; **no** cambia día activo.
- Tap en marker o bloque de timeline → detalle de evento.
- Tap en FAB "+" → bottom sheet añadir evento.
- Tap en trial banner → paywall.
- Tap en pestañas inferiores → cambia entre Home / Estadísticas / Ajustes.

Elementos condicionales:

- Trial banner: visible solo si `subscription.status` ∈ {`trial`, `grace`, `cancelled`} **y** quedan días por mostrar. Texto adaptado: "Trial: te quedan N días", "Tu suscripción se cancela en N días", "Pago pendiente: regularízalo".
- Banner anuncio: oculto si `subscription.status` ∈ {`active`, `grace`, `cancelled`} (sin anuncios para suscriptores). Visible en el resto.
- Indicador de evento en curso (§8.9): se renderiza por encima del trial banner cuando hay live.

### 12.5 Bottom sheet añadir evento

- Lista los 6 tipos de evento con sus iconos Phosphor (§5.6).
- **Inferencia contextual** del orden y tamaño:
  - Si no hay `morning_wake` aún hoy → `morning_wake` arriba (tarjeta grande).
  - Si hay `morning_wake` y aún no hay `bedtime` hoy → arriba: `nap`, `nursing`, `bottle`. Abajo: `bedtime`, `night_wake`.
  - Si hay `bedtime` sin `morning_wake` posterior → arriba: `night_wake`, `nursing`, `bottle`. Abajo: el resto.
  - Sin contexto → orden por defecto del catálogo.
- Tras elegir un tipo:
  - Para puntuales (`morning_wake`, `bedtime`): dos opciones grandes "Ahora" / "Otra hora".
  - Para los de duración: dos opciones grandes "Iniciar ahora" / "Introducir manualmente".
- En Lactancia, si "Iniciar ahora" → §8.6 paso 2.

### 12.6 Detalle/edición de evento

- Tap en cualquier evento de la línea temporal → pantalla de detalle.
- Muestra tipo, hora(s), duración, metadata, nota.
- Acciones: **Editar** (campos editables, valida no-solapamiento), **Borrar** (confirmación).
- Botón atrás vuelve a home.

### 12.7 Línea temporal (TimelineBar)

> Estructura visual exacta en §0.1. Aquí se especifica el mapeo de datos.

- Rango horizontal:
  - Modo **día**: `[morning_wake_efectiva, bedtime_efectiva]` del día activo.
  - Modo **noche**: `[bedtime_efectiva del día activo, morning_wake_efectiva del día siguiente]`.
- Marcas horarias cada **2 horas** (siguiendo §0.1). Si el rango es muy corto, mantener cada 2h igualmente; no añadir marcas a 1h.
- Color de bloque/marker: token `ev-feed` o `ev-sleep` según mapeo de §5.6.
- Icono dentro del bloque/marker: Phosphor según mapeo de §5.6, color blanco (sobre el token de evento).
- El indicador "AHORA" solo se muestra si la hora actual cae dentro del rango visible.
- Tramo futuro estimado: estilo punteado (`.timeline-future` / equivalente Flutter).

### 12.8 Calendario

- Modal desplegable desde la cabecera de home.
- Marcado por colores según número de eventos del día y posición temporal:
  - **Verde:** ≥3 eventos.
  - **Naranja:** 1–2 eventos.
  - **Rojo:** 0 eventos en un día dentro del rango (de `birthDate` a hoy).
  - **Gris:** anterior a `birthDate` o futuro.
  - **Blanco / destacado:** día actual.
- Tap → cambia día activo en home y cierra modal.
- En días pasados: **edición/añadir/borrar habilitado** con misma lógica que hoy.
- Los colores específicos del calendario derivan de tokens de evento o tokens semánticos de §0.1 (no inventar nuevos colores).

### 12.9 Estadísticas (V1)

- Tres rangos seleccionables: Hoy / 7 días / 30 días.
- Cards: total sueño día, total sueño noche, total sueño combinado, nº tomas, nº despertares nocturnos.
- Promedio sueño últimos 7 días.
- Una gráfica con tendencia (barras por día) últimos 7/30 días.
- Datos vienen de `/babies/{id}/dailyStats`. **No** se calculan en cliente.
- Estética siguiendo tokens y tipografías de §0.1.

### 12.10 Ajustes

Pantalla raíz con accesos a:

- Datos del bebé (editable).
- Cuidadores (lista, alias, generar nuevo código).
- Suscripción (estado, gestionar — deeplink Google Play).
- Notificaciones (on/off global; granularidad V2).
- Idioma (placeholder con un único valor: español).
- Tema (Auto / Claro / Oscuro).
- Exportar mis datos (CSV).
- Cerrar sesión.
- Borrar cuenta (con flujo de gracia — §15).
- Términos y Privacidad (links).
- Versión de la app (footer).

### 12.11 Paywall

Se muestra cuando:

- Trial expira y el usuario intenta crear/editar/borrar evento.
- Suscripción expira (`expired` o `on_hold`).
- Usuario navega manualmente desde Ajustes → Suscripción → "Suscribirse".

Contenido:
- Título y propuesta de valor (en V1: registro ilimitado, sin anuncios, futuras estadísticas avanzadas y predicciones).
- Dos botones de plan:
  - **Anual 11,99 €** (destacado visualmente, etiqueta "Ahorra 75 %").
  - **Mensual 3,99 €**.
- Botón "Suscribirme" (acción según plan seleccionado).
- Letra pequeña: renovación automática, gestión en Google Play, links a Términos y Privacidad.

### 12.12 Zonas que NO muestran banner AdMob

- Splash, login, onboarding completo, paywall, edición/detalle de evento, calendario modal, todas las subpantallas de Ajustes.
- Banner solo en Home y Estadísticas, en la parte inferior, encima del BottomNavigationBar.

---

## 13. Reglas de bloqueo por estado de suscripción

Aplicar según `babies.subscription.status`:

| Estado | Lectura | Crear/Editar/Borrar evento | Banner ads | Acción al pulsar "+" |
|---|---|---|---|---|
| `none` | ✅ | ✅ (registra primer evento → `trial`) | ✅ | Bottom sheet normal |
| `trial` | ✅ | ✅ | ✅ | Bottom sheet normal |
| `trial_expired` | ✅ | ❌ | ✅ | Abrir paywall |
| `active` | ✅ | ✅ | ❌ | Bottom sheet normal |
| `grace` | ✅ | ✅ | ❌ | Bottom sheet normal + aviso suave |
| `on_hold` | ✅ | ❌ | ✅ | Abrir paywall |
| `cancelled` (no expirado aún) | ✅ | ✅ | ❌ | Bottom sheet normal |
| `expired` | ✅ | ❌ | ✅ | Abrir paywall |

Cuando la escritura está bloqueada, los markers de la línea temporal siguen siendo tappables pero el detalle de evento esconde botones de Editar y Borrar y muestra CTA al paywall.

---

## 14. Reglas de Cloud Functions

Todas en `europe-west1`, runtime Node 20, gen 2.

| Función | Tipo | Disparo | Responsabilidades |
|---|---|---|---|
| `validatePlayBillingPurchase` | Callable | Cliente tras compra | Verifica `purchaseToken` con Google Play Developer API, escribe `subscription`. Idempotente. |
| `acknowledgePurchase` | Callable | Cliente tras validación | Acknowledge en Play (obligatorio < 3 días). |
| `playBillingRTDN` | HTTPS (Pub/Sub) | Notificaciones de Google Play | Actualiza `subscription` ante renovaciones, cancelaciones, holds, recoveries. |
| `recomputeEstimates` | Scheduled (diaria 03:00 Europe/Madrid) | — | Calcula `estimatedMorningWake` y `estimatedBedtime` por bebé (§10). |
| `computeDailyStats` | Firestore trigger onWrite events | Crear/editar/borrar evento | Recalcula `dailyStats/{dayKey}` afectado. Debe debouncear escrituras múltiples. |
| `recomputeDayKeys` | Firestore trigger onCreate / onUpdate de `morning_wake` | — | Recalcula `dayKey` de eventos posteriores hasta el siguiente `morning_wake` (§9.4). |
| `checkInactivity` | Scheduled (cada 30 min) | — | Detecta bebés en franja diurna sin registros >3h y envía push (respetando 22:00–08:00 hora local del cuidador). |
| `expireTrials` | Scheduled (horaria) | — | Cambia a `trial_expired` los bebés cuyo `trial.expiresAt` o `trial.hardExpiresAt` ha pasado y no tienen suscripción activa. |
| `cleanupGracePeriod` | Scheduled (diaria 04:00) | — | Aplica borrados de cuentas/bebés cuyo `deletionScheduledAt` cumplió 7 días. |
| `createInvitation` | Callable | Cliente | Genera código numérico de 6 dígitos único, persiste en `/invitations/{code}`. Expira en 24h. |
| `acceptInvitation` | Callable | Cliente | Valida código (existe, no usado, no expirado, hueco en `caregivers`), añade userId a `caregivers` y `caregiversInfo`, marca `used`. |
| `requestAccountDeletion` | Callable | Cliente | Setea `deletionScheduledAt = now + 7d` en `/users/{uid}`. |
| `cancelAccountDeletion` | Callable | Cliente | Limpia `deletionScheduledAt`. |
| `exportUserData` | Callable | Cliente | Genera CSV en Storage con todos los eventos del bebé activo del usuario. Devuelve URL firmada (24h). |
| `createEvent` / `updateEvent` / `deleteEvent` | Callable | Cliente | Encapsulan creación/edición/borrado de eventos para aplicar validación de no-solapamiento server-side y la regla de exclusividad live atómicamente. El cliente NO escribe `events/*` directamente; lo hace a través de estas funciones. |

---

## 15. Reglas de suscripción y trial

### 15.1 Inicio del trial

- Al guardar el primer evento del bebé:
  - Si `babies.trial.firstEventAt` está vacío → escribirlo con `now`.
  - Cloud Function (o el propio `createEvent` callable) escribe `trial.expiresAt = firstEventAt + 3 días` y cambia `subscription.status` a `trial`.

### 15.2 Hard expiration

- Al crear el bebé, escribir `trial.hardExpiresAt = createdAt + 30 días`.
- `expireTrials` cambia a `trial_expired` cuando se cumpla cualquiera de:
  - `firstEventAt` definido y `expiresAt < now`.
  - `firstEventAt` no definido y `hardExpiresAt < now`.

### 15.3 Compra exitosa

- Cliente recibe `purchaseToken` de Play Billing.
- Cliente llama `validatePlayBillingPurchase` con el token y `productId`.
- Function consulta API de Google Play, si OK escribe `subscription.status='active'`, `plan` (según `productId`), `source='play_billing'`, `purchaseToken`, `expiresAt`, `autoRenew=true`, `lastVerifiedAt=now`.
- Cliente llama `acknowledgePurchase`.

### 15.4 Cambios de estado por RTDN

- Suscripción renovada → `expiresAt` actualizado.
- Cancelada → `status='cancelled'` (mantener acceso hasta `expiresAt`).
- Pago fallido + gracia → `status='grace'`.
- Gracia agotada → `status='on_hold'`.
- Recovery → `status='active'`.
- Reembolso/revocación → `status='expired'`.

### 15.5 Suscripción a nivel de bebé, no usuario

- `subscription` vive en `/babies/{babyId}`. Ambos cuidadores la comparten.
- Si solo papá paga, mamá sigue con acceso premium mientras siga en `caregivers` del bebé.

### 15.6 Productos en Play Console

- `sb_monthly_399` — 3,99 €/mes.
- `sb_annual_1199` — 11,99 €/año.
- Sin trial nativo de Play Billing (el trial es nuestro, gestionado en backend).

---

## 16. Reglas de cuidadores compartidos

- Máximo 2 cuidadores por bebé en V1.
- Ambos tienen los mismos permisos sobre eventos. Solo el `adminId` puede borrar el bebé.
- **No se puede expulsar** al otro cuidador en V1.
- **No se puede abandonar** un bebé en V1 (solo borrar la propia cuenta).
- Códigos de invitación expiran en **24 horas** y son de un solo uso.
- Si el admin borra su cuenta y queda otro cuidador → el otro hereda admin tras los 7 días de gracia.
- Si todos los cuidadores borran su cuenta → tras 7 días desde el último, el bebé y sus subcolecciones se eliminan en cascada.

---

## 17. Reglas de AdMob

- **Una sola unidad** de anuncio en V1: banner adaptativo 320×50.
- Ubicaciones permitidas: parte inferior de Home y de Estadísticas, encima del BottomNavigationBar (siguiendo §0.1).
- Ubicaciones prohibidas: el resto.
- Suscriptores activos no ven anuncios. El estado se evalúa en cada apertura y al cambiar `subscription.status`.
- Integrar **UMP de Google** para gestión de consentimiento publicitario (UE).
- IDs de unidad de anuncio diferentes en debug y release. Nunca usar IDs reales en debug.
- Nunca colocar el banner sobre contenido interactivo crítico (botón "+"; el banner queda **debajo** del FAB, no encima).

---

## 18. Reglas de FCM (notificaciones push)

### 18.1 Tipos en V1

- **Inactividad diurna.** Lanzada por `checkInactivity` cuando un bebé:
  - Está en su franja diurna (entre `morning_wake_efectiva` y `bedtime_efectiva`).
  - Lleva más de **3 horas** sin nuevos eventos registrados.
  - La hora local del cuidador no está en el rango silencioso 22:00–08:00.
- Texto: `"¿Se durmió [nombre]? Llevas Xh sin registrar nada."`.

### 18.2 Horas silenciosas

- 22:00 a 08:00 hora local del cuidador. No configurable en V1.

### 18.3 Permisos y tokens

- Permiso solicitado en onboarding. Re-prompt sutil (banner discreto en home) tras 7 días si no se concedió.
- Al obtener token o cambiar, escribir en `/users/{uid}/fcmTokens[deviceId]`.
- Al cerrar sesión, eliminar token de ese deviceId.
- `checkInactivity` envía push a todos los `fcmTokens` válidos de los cuidadores del bebé.

---

## 19. Reglas de Analytics

### 19.1 Eventos a registrar

| Evento | Parámetros |
|---|---|
| `sign_up` | `method` (`google` / `email`) |
| `login` | `method` |
| `baby_created` | — |
| `caregiver_invited` | — |
| `caregiver_joined` | — |
| `event_logged` | `event_type`, `mode` (`live` / `manual`) |
| `event_edited` | `event_type` |
| `event_deleted` | `event_type` |
| `trial_started` | — |
| `trial_expired` | — |
| `paywall_viewed` | `source` (`event_block` / `settings` / `trial_expired`) |
| `subscription_started` | `plan` |
| `subscription_renewed` | `plan` |
| `subscription_cancelled` | `plan` |
| `export_data` | — |
| `delete_account_requested` | — |
| `delete_account_cancelled` | — |

### 19.2 Crashlytics

- Activo desde el primer build.
- Reportar excepciones no capturadas y errores de red de Cloud Functions con contexto del usuario (uid hasheado).
- No enviar PII en breadcrumbs (no email, no nombre del bebé).

---

## 20. Tema visual (referencia: §0.1)

> La paleta, tipografías y reglas estéticas oficiales están en **§0.1**. Esta sección solo añade aclaraciones operativas para Flutter.

### 20.1 Implementación

- Una sola clase `AppColors` en `lib/app/theme/app_colors.dart` con todos los tokens semánticos de §0.1, en dos perfiles (día / noche).
- Cada token conserva su valor oklch original como comentario.
- Conversión oklch → sRGB hecha al definir constantes (no en runtime).
- Una sola clase `AppTypography` con estilos derivados de `Fraunces` y `Plus Jakarta Sans` vía `google_fonts`.
- `ThemeData` claro y oscuro construidos a partir de `AppColors` y `AppTypography`.
- Un widget `TimelineForceLightTheme` envuelve el subárbol de la línea temporal y fuerza tokens día siempre, replicando `.timeline-force-light`.

### 20.2 Aplicación de tokens

- Backgrounds, surfaces, bordes, tipografías → siempre desde el tema o desde `AppColors`.
- Colores de eventos → desde tokens `ev-feed` y `ev-sleep` según mapeo §5.6 (otros tokens `ev-*` definidos pero no usados en V1).
- Texto sobre bloques de evento → blanco (`#FFFFFF` literal solo en este caso, ya que el contraste sobre los tokens de evento es válido en ambos modos).

### 20.3 Modos del tema

- **Auto** (default): sigue el modo día/noche del bebé (§9). Tema claro con tokens día / tema oscuro con tokens noche.
- **Forzado claro / Forzado oscuro:** opción en Ajustes → Tema.
- La línea temporal **siempre** usa tokens día (independientemente del modo activo).

---

## 21. Internacionalización y zona horaria

- `flutter_localizations` + archivos `.arb`. Solo `app_es.arb` en V1, pero preparado para añadir más sin refactor.
- Todos los textos visibles deben venir de `.arb`. **Prohibido** hardcodear strings en widgets.
- Timestamps en UTC en Firestore. Render en zona local del dispositivo (paquete `timezone`).
- Cambio de hora verano/invierno: caer con la zona local del dispositivo. La barra reflejará una noche más larga o más corta sin lógica especial.

---

## 22. Privacidad y RGPD

- Edad mínima del usuario: **18+**, declarada en onboarding.
- Política de Privacidad y Términos en archivos markdown bajo `legal/`. Incluir aviso "Borrador para revisión por abogado". URLs públicas almacenadas en `/config/legal`.
- Versión aceptada por el usuario almacenada en `/users/{uid}.legalAccepted`.
- Borrado de cuenta:
  - Botón en Ajustes → "Borrar cuenta".
  - Llama a `requestAccountDeletion` (set `deletionScheduledAt`).
  - Pantalla muestra cuenta atrás de 7 días con botón "Cancelar borrado".
  - Tras 7 días, `cleanupGracePeriod` ejecuta el borrado en cascada (datos del usuario, salida de `caregivers`, posible borrado del bebé si queda huérfano, foto en Storage).
- Exportación de datos: CSV con todos los eventos del bebé activo. Encoding UTF-8 con BOM, separador `,`.

---

## 23. Decisiones cerradas (NO replantear)

1. La noche pertenece al día que **empezó** (regla `dayKey`).
2. Eventos no pueden solaparse: registro/edición a pasado bloqueado en caso de conflicto, con atajo a editar el conflictivo.
3. Despertar nocturno tiene `inicio + fin`. Se cierra automáticamente al iniciar el siguiente sueño o manualmente con Stop.
4. Lactancia con cronómetro doble por pecho.
5. Biberón guarda solo `bottleMl` en V1 (sin tipo de leche).
6. Trial de 3 días arranca con el primer evento. Hard expiration a 30 días si nunca se registra nada.
7. Suscripción a nivel de bebé. Compartida entre cuidadores.
8. Máximo 2 cuidadores en V1, mismos permisos, sin posibilidad de expulsar ni abandonar.
9. AdMob: solo banner inferior en Home y Estadísticas. Suscriptores no ven nada.
10. FCM en V1: solo notificación de inactividad diurna >3h. Silencio 22:00–08:00.
11. Estadísticas precomputadas en `dailyStats` por Cloud Function. Cliente solo lee.
12. Iconos: Phosphor con el mapeo dado en §5.6.
13. Solapamiento al editar a pasado: bloquear, no cortar.
14. Borrado: 7 días de gracia para cuenta y para bebé huérfano.
15. CSV de exportación: UTF-8 con BOM, separador `,`.
16. Umbral de inactividad para push: 3 horas.
17. Estética visual: paleta oklch + Fraunces + Plus Jakarta Sans + Phosphor (§0.1).
18. Counter "Última toma hace" usa icono `BabyBottle` (no `Baby`).
19. Línea temporal siempre con tokens día (incluso en modo noche).

---

## 24. Excluido de V1 (no implementar)

- iOS.
- Más de 1 bebé por cuenta.
- Más de 2 cuidadores por bebé.
- Tipo de leche en biberón (materna extraída / fórmula / mixto).
- Pausa intermedia en eventos en vivo.
- Predicciones inteligentes y recomendaciones de sueño.
- Estadísticas avanzadas (heatmaps, comparativas con rangos pediátricos).
- Notificaciones distintas a inactividad diurna.
- Notificaciones configurables granularmente.
- Multi-idioma activo (preparar la estructura, pero solo `es` traducido).
- Modo recién nacido (sin distinción día/noche).
- Eventos adicionales (pañales, juego, baño, medicamentos, peso, hitos). Tokens de color reservados para V2+.
- Expulsar cuidador / abandonar bebé.
- Onboarding de descubrimiento de funciones (tooltips guiados).
- Modo widget Android, atajos, App Actions.
- Backup/restore manual.

---

## 25. Reglas para la IA generadora de código

1. **No implementes nada que no esté en este documento.** Si algo es necesario y no está, **pregunta** antes de implementar.
2. **No cambies literales** de tipos, estados, IDs de productos, copies en español, claves de Firestore, tokens de la paleta. Son fijos.
3. **No introduzcas dependencias** fuera del stack de §2 sin justificación explícita y aprobación.
4. **No hagas refactors agresivos** del código existente sin pedir permiso.
5. **No mezcles capas:** la UI no llama directamente a Firestore; pasa por repositorios o providers Riverpod.
6. **No metas lógica de negocio en widgets.** Va en controladores, repositorios o usecases.
7. **No persistas tokens de Play Billing en cliente** más allá de lo que el SDK requiera.
8. **No omitas validación de no-solapamiento** ni la regla de exclusividad de eventos live. Son críticas.
9. **No envíes notificaciones fuera de la franja silenciosa** ni saltándote el umbral de 3h. La function debe respetarlo siempre.
10. **No expongas claves API ni IDs de AdMob de producción** en código fuente público. Usar `--dart-define` o flavors.
11. **No uses colores hardcodeados** (`Colors.white`, `Colors.black`, `Colors.grey[N]`, `Color(0xFFxxxxxx)`) en widgets. Solo tokens vía `AppColors` o `Theme.of(context)`.
12. **No uses Material Icons ni emojis.** Solo Phosphor.
13. **No sustituyas Fraunces o Plus Jakarta Sans** por otras fuentes.
14. **Antes de crear un archivo nuevo de código,** verificar que no existe ya algo equivalente en la feature. Reutilizar si lo hay.
15. **Antes de modificar el modelo de datos,** verificar que el cambio es compatible con datos ya existentes. Si requiere migración, **pedir confirmación**.
16. **Trata los borrados como definitivos** salvo que el flujo tenga gracia explícita (cuenta y bebé huérfano).
17. **Toda función Cloud Function callable** debe validar autenticación, autorización (caller pertenece a `caregivers`), y idempotencia donde aplique (compras, invitaciones).
18. **Toda escritura crítica** (eventos, suscripción, caregivers) debe hacerse en transacción cuando involucre lectura previa.
19. **Cobertura mínima de tests:** unit tests sobre lógica de §8, §9, §10, §11. Sin obligación de tests UI E2E en V1, pero los smoke tests de happy path son bienvenidos.
20. **Logs de Cloud Functions:** estructurados, sin PII (sin emails, sin nombres de bebé). Usar IDs.
21. **Idioma del código:** Dart/TypeScript en inglés (nombres de clases, variables, funciones). Strings de UI en español vía `.arb`. Comentarios en inglés.
22. **Si encuentras una contradicción** entre dos secciones, recordar el orden de prevalencia: §0.1 > resto.
23. **Si la spec preeminente §0.1 menciona algo en términos React/Tailwind** que no sea trivial trasladar a Flutter, aplicar las "Notas de portabilidad a Flutter" de §0.1. Si persisten dudas, **preguntar**.

---

## 26. Glosario rápido

- **Día activo:** la fecha que el usuario está viendo en home (hoy por defecto, otra si cambió desde el calendario).
- **dayKey:** clave `YYYY-MM-DD` que asigna un evento al día del bebé al que pertenece (§9.4).
- **Modo (de la barra):** `day` o `night`. Calculado automáticamente con override manual visual (§9).
- **Evento live:** `status='live'`, sin `endAt`, en curso. Solo puede haber uno por bebé.
- **Trial:** ventana gratuita de 3 días desde el primer evento. Hard cap de 30 días desde creación.
- **Bebé huérfano:** bebé sin cuidadores activos (todos borraron su cuenta). Se elimina tras 7 días.
- **Cuidador:** usuario en `babies.caregivers`. Hasta 2 en V1.
- **Admin:** cuidador con derecho a borrar el bebé. Inicialmente el creador. Hereda al otro si el admin se va.
- **Token (de paleta):** identificador semántico de color (ej. `--card`, `--primary`, `--ev-sleep`) definido en §0.1. Nunca usar valores literales.
- **TimelineForceLightTheme:** equivalente Flutter de `.timeline-force-light`. Mantiene la línea temporal con tokens día siempre.

---

**Fin del brief. Cualquier laguna debe resolverse preguntando, no asumiendo.**