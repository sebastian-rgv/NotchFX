<h1 align="center">notchFX</h1>

<p align="center">
  <strong>Convierte la muesca de tu MacBook en una superficie viva estilo Dynamic Island.</strong>
</p>

---

**notchFX** es una app nativa para macOS que transforma el notch en un widget interactivo:
media, temporizadores, alertas de sistema, HUDs y más — con animaciones de física real,
gestos naturales y cero dependencias pesadas.

## Estado del proyecto

| Hito | Contenido | Estado |
|------|-----------|--------|
| M1 | Esqueleto: ventana overlay sobre el notch, shape nativo, máquina de estados tipada + tests | ✅ |
| M2 | Motor de prioridades (preempt + expiración) + batería y timer reales | ✅ |
| M3 | Gestos (hover/click/swipe dismiss con rubber-band) + springs con física | ✅ |
| M4 | Settings tipados parse-once + cápsula flotante en pantallas sin notch | ✅ |
| M5 | CI + releases con actualizaciones automáticas | 🔜 |

## Requisitos

- macOS 14.0+
- Xcode 16+ para compilar

## Compilar

```bash
open notchFX.xcodeproj
```

Y ejecuta el scheme `notchFX` (⌘R).

O desde consola:

```bash
xcodebuild -project notchFX.xcodeproj -scheme notchFX -destination 'platform=macOS' build
```

## Tests

```bash
xcodebuild -project notchFX.xcodeproj -scheme notchFX -destination 'platform=macOS' test
```

## Arquitectura

```
notchFX/
├── App/              # Entry point + AppDelegate (AppKit-first) + menú de barra
├── Core/
│   ├── State/        # NotchState tipado (enum con valores asociados) + modelo observable
│   ├── Engine/       # Scheduler de prioridades (array ordenado, preempt, expiración) + GestureMath
│   ├── Services/     # Batería (IOKit push), timer local
│   ├── Settings/     # Config Codable parse-once con fallback a defaults seguros
│   └── Windowing/    # Panel overlay no activador + resolución de pantalla y estilo
└── UI/               # Superficie animada (springs), gestos y contenidos por actividad

Interacción: click para expandir/colapsar, arrastrar hacia abajo para descartar
(rubber-band + fade), hover deforma las esquinas como affordance, click fuera colapsa.

Pantallas sin muesca: la superficie se convierte automáticamente en una **cápsula
flotante** debajo de la barra de menú (también forzable desde el menú). Selección de
pantalla automática / con muesca / principal. La configuración se persiste como un solo
blob `Codable` que se parsea una vez al inicio; si está corrupto, cae a defaults seguros.
```

Principios: estados modelados con tipos (no strings), transiciones validadas por el
compilador vía `switch` exhaustivo, geometría como funciones puras sin AppKit.

## Licencia

TBD
