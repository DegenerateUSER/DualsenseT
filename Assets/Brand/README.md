# Sticky Fingers Icon

## Selected Mark

**Concept 3A** is the primary application and Dock icon.

It was selected over 3B because the filled controller silhouette remains recognizable at
16–32 px, carries more visual weight in the Dock, and avoids the detailed PlayStation marks
present in the previous icon.

Concept 3B's outline treatment is better suited to monochrome or menu-bar use. Sticky
Fingers currently keeps separate USB and Bluetooth menu-bar symbols because they communicate
connection state.

## Files

- `AppIcon-3A.svg` — editable 1024×1024 vector source
- `../AppIcon.icns` — generated macOS icon with ten 1×/2× representations

Regenerate the `.icns` after editing the SVG:

```bash
./generate-app-icon.sh
```

## Palette

- Cyan accent: `#4FD8FF`
- Controller: `#E6EDF5`
- Controls: `#1B1D22`
- Background: `#33373F` → `#212429` → `#121317`

Keep the mark generic. Do not add Sony, PlayStation, or controller-product logos.

