# Dytava typography — Precision Core

The default pairing from `branding/typography_lab.html` is applied to the Web app,
help/privacy pages, Flutter app and brand showcase. The lab remains a preview of
alternative pairings; choosing a card there does not change the application.

| Role | Family | Bundled weights | Usage |
| --- | --- | --- | --- |
| Display | Plus Jakarta Sans | 400, 500, 600, 700, 800 | Headings, titles |
| Interface | Be Vietnam Pro | 400, 500, 600, 700, 800 | Body text, controls, Vietnamese labels |
| Data | IBM Plex Mono | 400, 500, 600, 700 | Cell values, metrics, identifiers, rule IDs |

Web uses `web/css/fonts.css`, local WOFF2 files in `web/assets/fonts/`, and
`--font-display`, `--font-interface`, `--font-data` tokens. Plus Jakarta Sans uses
its variable WOFF2 (200–800); all font files retain the complete upstream glyph
coverage, including Vietnamese. Data values use tabular figures. No external font
service is required at runtime.

Flutter declares each TTF and weight explicitly in `mobile/pubspec.yaml`.
`DytavaTheme.lightTheme` applies `DytavaTypography.textTheme` to `MaterialApp`;
`dataMedium` and `metricNumber` provide the monospace data styles. A distributable
copy of the TTFs and declarations is in `branding/mobile/`.

The approved logo assets are unchanged. UI fonts do not replace the lettering
inside existing logo SVGs or reference images.

Sources are pinned to the Google Fonts revision recorded in
[FONT_SOURCES.json](FONT_SOURCES.json). Plus Jakarta Sans TTF weights are static
instances of the upstream variable font; WOFF2 files are converted from the full
TTF sources using fontTools. Per-family SIL Open Font License files are shipped
beside the fonts in both Web and Flutter assets and copied into the Flutter asset
bundle. The source manifest records file sizes and SHA256 hashes.
