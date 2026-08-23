<h1 align="center">NotchFX</h1>

<p align="center">
  <strong>Bring your notch to life.</strong>
</p>

<p align="center">
  Convierte la muesca de tu MacBook en una isla dinámica viva:<br>
  temporizadores, alertas de batería y más — con física real y gestos naturales.
</p>

---

## ¿Qué hace por ti?

La parte superior de tu MacBook tiene un espacio negro muerto.
**NotchFX lo convierte en un centro de información interactivo**: aparece cuando algo
importa, desaparece cuando no, y responde a tus dedos como si fuera parte del hardware.

### Música en tu notch

- Reproduce algo en **Spotify** o **Música** y la isla cobra vida sola
- **Ecualizador animado** que late con la reproducción
- Título y artista con **scroll automático** si son largos
- **Barra de progreso interactiva** al expandir: arrastra para buscar el momento exacto
- Controles completos: anterior / play-pause / siguiente, y los tiempos transcurrido y restante
- Click sobre el ecualizador **abre tu reproductor**
- Pausa unos segundos y la isla se retira educadamente

### Temporizadores vivos

- Lanza un temporizador y mira el **countdown en vivo** sobre tu notch
- Al terminar, la isla se expande sola para avisarte — nada de timers olvidados
- ¿Te arrepentiste? **Cáncelalo con un click** desde la propia isla

### Batería que te habla

- Aviso elegante al **conectar el cargador**
- Confirmación discreta cuando llega al **100%**
- Alerta temprana cuando la batería se pone **crítica**
- Las alertas aparecen, duran unos segundos y se retiran solas — cero interrupciones eternas

### Prioridad inteligente, estilo iPhone

¿Estás mirando tu temporizador y llega una alerta importante?
La alerta **toma el control del momento**, y cuando termina, tu contenido vuelve solo.
Nunca pierdes información, nunca te saturan.

### Gestos que se sienten físicos

| Tu gesto | Qué pasa |
|---|---|
| **Click** | La isla se expande o colapsa con spring físico |
| **Arrastrar hacia abajo** | Descartas lo que sea — con rubber-band y fade, como en iOS |
| **Pasar el cursor** | Las esquinas reaccionan invitándote a tocar |
| **Click fuera** | Todo se colapsa discretamente |

### Funciona en *cualquier* Mac

¿Tu Mac o monitor **no tiene muesca**? No importa: NotchFX se convierte automáticamente
en una **cápsula flotante** debajo de tu barra de menú. Elige pantalla automática,
la de la muesca o la principal — todo desde el menú.

### Simple de controlar

Un ícono discreto en la barra de menú gobierna todo:

- Modo de pantalla: automático / con muesca / principal
- Cápsula flotante activada o desactivada
- Gestos de descarte activados o desactivados
- Duración de las alertas
- Temporizador demo y alerta de prueba para verlo funcionar al instante

Tus preferencias **se recuerdan entre sesiones**.

### Ligero, nativo y privado

- 100% nativo en Swift/SwiftUI — se siente parte de macOS, no un overlay web
- **Despierta con eventos del sistema**, no sondea constantemente tu CPU
- Sin permisos invasivos, sin cuentas, sin telemetría, sin conexión a ningún servidor

---

## Instalación

1. Descarga el DMG más reciente desde [Releases](https://github.com/sebastian-rgv/NotchFX/releases)
2. Abre el DMG y arrastra **NotchFX** a Aplicaciones
3. Al primer arranque, macOS mostrará *"Apple could not verify..."*:

   **Opción rápida (terminal):**
   ```bash
   xattr -cr /Applications/NotchFX.app
   open /Applications/NotchFX.app
   ```

   **Opción gráfica:** intenta abrirlo, pulsa *OK*, luego ve a
   **Ajustes del Sistema → Privacidad y seguridad → "Open Anyway"**,
   autentica y abre. Solo pasa la primera vez.

> Requiere macOS 14.0 o posterior · MacBook con muesca, o cualquier Mac/monitor sin ella

## Lo que viene

| Próximamente | |
|---|---|
| Artwork del álbum en la isla | Siguiente evento del calendario |
| HUD de volumen y brillo | Temas y personalización visual |
| Multi-idioma | Progreso de descargas |

## Compilar desde el código fuente

```bash
git clone https://github.com/sebastian-rgv/NotchFX.git
cd notchFX
swift build && swift test     # compilar y probar
open notchFX.xcodeproj        # o abrirlo en Xcode (Cmd+R)
```

Generar el DMG instalable:

```bash
./Scripts/build_release.sh
```

## Créditos

Diseñado y desarrollado por [@sebastian-rgv](https://github.com/sebastian-rgv).

## Licencia

TBD
