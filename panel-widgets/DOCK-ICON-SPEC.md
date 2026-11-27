# Dock icon spec v2

Revision of v1 after an outside design review. v1 was geometrically disciplined but treated consistency of
construction as consistency of visual language: same extrusion, same shadow stack, same highlight, one
scale for everything. v2 keeps the paper-and-ink identity and the 1024 master, and drops the rules that
made eight icons look manufactured from the same cardboard.

References used, publicly available: Apple's macOS app-icon grid (1024 canvas, 824 body, transparent
margin) and Apple's icon guidance on optical centering, visual weight and simplification; Material's
system-icon grid (live area, keylines, bold geometric forms, nothing delicate at small sizes). The drawings
are original.

## 1. Composition

- Master canvas 1024. Plate body 90 units on the 100-unit grid (5 units of margin), radius 18.
  The review proposed 92; 92 leaves a 4-unit gap, which is 0.88 px at 22 px and reads as two icons
  touching. 90 keeps a 1.1 px gap, which is the same principle the review applies to features.
- Standard object 68 units on its dominant axis, large objects up to 72. Object occupies 74% of the plate.
- Optical correction per object, not one universal rule: round objects get 2 units of overshoot; a tall
  object gets 1 unit of horizontal compensation. No automatic scaling of every icon to one number.
- Asymmetry is allowed where the composition wants it; nothing is centred for its own sake.

## 2. Hierarchy

Identity first, object second, plate third. Target perceptual weights: primary object 65-75%, plate
20-30%, accents 5-10%. The plate establishes family membership; it is never the subject. If the object is
unreadable without the plate, the icon has failed.

## 3. Materials

- Paper: matte, warm, low-contrast gradient, no gloss.
- Ink: dense, dark, smooth; used for structure and for the prompt.
- Ochre: warm secondary material.
- Clay rose: the muted accent that is not green.
- Rust: a restrained accent, never a mandatory stripe.
- Cream: secondary paper surface, for page blocks and rear layers.
- No artificial bevel, no mandatory highlight strip, no gloss overlay.
- **No green and no sage anywhere**: not in plates, not in objects, not in details. Green is rejected for
  dock icons. The structural dark is charcoal, not ink green.

## 4. Depth

- Variable, not universal. Extrusion 0-3 units, and only where the object is physical.
- Zero to two secondary layers per object; the overlap is what carries the depth.
- The shared gesture of the family is one overlap per object: folder tab over body, notebook page block
  beside cover, window plane over plane, image's folded corner, palette pigment over body.
- Frontal perspective. Slight elevation only where it explains the object; no isometric angles.

## 5. Light and shadow

- One light direction: from the top, tilted 15 degrees left.
- One shadow per object: blur 1.5 units, opacity 12%, offset 0.8 units. No shadow stacks.
- Highlights follow the material: a thin light edge on the top of paper, nothing on ink.
- At 22 and 30 px a dedicated variant is used with a 1-unit hard shadow at 13%, because a 1.5-unit blur at
  that size is smaller than a pixel and turns into a dirty edge.

## 6. Colour and contrast

- Seven values, none of them green: paper `#f6f1e4`, cream `#e3dac4`, rust `#a05040`, ochre `#b08246`,
  warm brown `#4a3527`, charcoal `#26241f`, clay rose `#a8756a`; plus dark ochre `#7d5a2e` and pale cream
  `#cfc4a8` as plate and layer values.
- Plates vary within the family: charcoal for five icons, warm brown for terminal and settings, dark ochre
  for clock. Not eight identical dark tiles, not eight cream tiles that vanish into the dock.
- Measured on every build: object against plate 13.8:1 on charcoal, 10.2:1 on warm brown, 5.5:1 on dark
  ochre. The floor is 4.5:1; the clock's charcoal ring against its ochre plate is 1.7:1 by design, because
  the ring is structure and the paper face is the object.
- Rust is kept away from charcoal where it only reaches 1.9:1; rust appears on paper or cream, where it is
  4-5:1.

## 7. Sizes

Three levels of artwork, not one drawing scaled three times:

| level | target | treatment |
| --- | --- | --- |
| master | 1024 | full material, soft shadow |
| dock standard | 30 px | soft shadow off, hard 1-unit shadow, same geometry |
| dock compact | 22 px | same, plus the details that survive: prompt, page block, gear opening, thumb hole, hands |

## 8. Minimum features

- Structural gap 7 units; important detail 8-9; primary line-like feature 9-11. Nothing thinner carries
  meaning. At 22 px a 9-unit feature is 2 px.

## 9. Recognition

- One dominant metaphor and one unmistakable feature per icon: the folder's tab, the terminal's prompt, the
  notebook's page block and bookmark, the image's landscape, the gear's centre opening, the palette's thumb
  hole, the window's overlap, the clock's hands.
- Every icon must survive in monochrome; the family is checked as silhouettes as well as in colour.

## 10. Acceptance gate

An icon enters the dock only if all ten hold:

1. Recognizable at 22 px without its colour palette.
2. Recognizable as a silhouette against a neutral background.
3. Primary object visually dominant over its plate.
4. No essential detail depends on a subpixel feature.
5. Distinct from the other seven at dock size.
6. Coherent beside the other seven.
7. Works against the actual cream dock background.
8. Retains its material character at 30 px.
9. Optically balanced, not merely geometrically centred.
10. No unnecessary decorative element.

## 11. Shape craft

Added after review: colour alone does not make an icon refined; the geometry has to be. Rules the drawings
follow now.

- Curves, not polygons. Every silhouette is built from arcs, quadratics or cubics. The gear became a rosette
  of six lobes of one radius blended into the body, because a polygon gear reads as a stamped shape.
- One radius per role, not per object: plate 19; large object 9-11; medium 6-7; small 3-4; anything pill
  shaped uses half its height. No radius is chosen by eye per icon.
- Even negative space. The object sits 16 units in from the plate edge on every side; internal gaps between
  layers are 4-6 units and are the same wherever two layers meet.
- Overlaps are deliberate. Each icon has at most two overlapping layers and each overlap shows a 4-6 unit
  reveal, so the layering reads as depth rather than as a mistake.
- Inset rules, not full-bleed ones. The window's rust rule is inset 7 units from the plane edges.
- Optical centring for composite marks. The terminal prompt is centred as a unit, not as a chevron plus a bar
  centred separately.
- No silhouette may be a plain rectangle or a plain disc unless the metaphor needs it; where it does
  (terminal screen, clock face), the identity is carried by a mark that is at least 9 units.
- Detail lines are at least 1 unit and never carry meaning below 7 units of length.
