# DYTAVA — Asset specification

## Art direction
Clean, tech-oriented 2.5D vector. Cyan/blue/purple layers, soft lavender shadow, white data cards, limited green success / red difference / amber unresolved. Floating background shapes are intentionally part of the illustration; **no full opaque canvas**.

## Size, semantics
Square SVG intrinsic 1024x1024 viewBox → PNG 4096x4096. Wide SVG 1600x900 viewBox → PNG 4096x2304. All PNG are RGBA. Text should be presented by Flutter widgets, not rasterized inside the illustration. Status icon and description must be presented together; color alone is insufficient.

## Graphic policy
These SVG are human-scripted vector artwork referencing the image supplied in the conversation. They are not extracted from the original Figma source. Status diagrams are conceptual product UI illustrations, not evidence of runtime availability or support for every depicted file format.

## Performance
Use SVG through flutter_svg or derived 768px raster. Do not bundle 4K PNG in production mobile build by default. 4096x4096x4 bytes = 64MiB uncompressed. Raster caching budget and rendering benchmarking are app-dependent.
