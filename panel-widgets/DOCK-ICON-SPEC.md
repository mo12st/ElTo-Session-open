# Dock icon spec v1

Written before drawing, from two public references: Apple's macOS app-icon grid (1024 px canvas, 824 px
body, 100 px transparent margin, corners baked into the artwork) and Material's system-icon guidelines (a
24 dp grid, a 20 dp live area, 2 dp padding, keyline shapes, bold geometric forms, nothing delicate at
small sizes). The drawing is original; nothing is copied from either set.

## 1. Canvas and grid

- Master canvas 1024 x 1024. Plate body 824 x 824, centred, 100 px transparent margin.
- Drawing grid: 100 units = the canvas. Plate = 80.5 units square, centred.
- Live area: 58 units square, centred. Every object is scaled to fill 58 units on its dominant axis, so
  all eight icons carry the same optical weight; round objects get 2 units of overshoot (60) to offset the
  way a circle reads smaller than a square of equal size.
- Keylines inside the live area: square 58, circle 60, vertical rectangle 50 x 58, horizontal 58 x 50.

## 2. Corner logic

- Plate radius: 22.37% of the body = 18 units.
- Object radius: one scale - 3.2 units for boxes, 1.6 for inner details, height/2 for pills.

## 3. Light

- One direction for every icon: from the top, tilted 15 degrees left. Faces are gradients along that axis.
- One highlight per object: a 3.2-unit band along the top edge, paper at 50%, clipped to the silhouette.
- One cast shadow per object: three offset silhouettes (1.5, 3 and 5 units) at 10% deep ink, no blur, so it
  survives at 22 px.
- The plate gets one top gloss and nothing else.

## 4. Depth

- Every object is a 2.5D solid: one front face plus a 4-unit extruded side face behind it, offset (0, +4),
  one step darker. No third plane, no perspective.

## 5. Palette and contrast

- Seven values: ink `#164437`, deep ink `#0d2b22`, rust `#a05040`, sage `#7fa08c`, ochre `#b08246`,
  paper `#f6f1e4`, cream `#e3dac4`.
- A detail may use a tint of a palette hue (15% toward paper, e.g. `#ad5a47` for rust) to reach the floor.
- Floors, measured by the build script and printed on every run: main face against plate at least 3:1,
  detail against main face at least 2:1. Current set: 9.7 main/plate, details 2.3 to 13.4.

## 6. Metaphor

- One style: a solid object with one front face, one side face and one accent detail. No glyphs, no
  outlines, no symbol inside a box.

## 7. Legibility gate

- Each icon is rendered at 22 px and 30 px directly (not downscaled) and inspected before it is shown.
- Shape budget: three shapes per icon.
- Minimum feature 4 units, which is 0.9 px at 22 px; nothing thinner carries meaning.
- At 22 px the silhouette alone must say what the icon is.

## 8. Build

- Each icon is one SVG (100-unit viewBox) with the plate, the extruded object and its detail; rendered with
  cairosvg at 1024 for review and at 22/30 for the legibility gate. Nothing is raster-edited.
