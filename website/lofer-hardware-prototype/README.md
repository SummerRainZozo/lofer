# Lofer hardware prototype · web page

An interactive view of the Lofer bench prototype. Visitors can select a part, a wire or a breadboard strip to see what it does and how it connects.

## Files

```
index.html          the page, including the breadboard drawing (inline SVG)
css/styles.css      all styling; colours are the tokens at the top of the file
js/board-data.js    parts, wires and breadboard nets shown in the side panel
js/app.js           selection, highlighting and side-panel logic
assets/             Lofer logo mark and wordmark
```

## Hosting

**Live copy:** the page files now live in `website/public/hardware/`, and the website build publishes them at `https://summerrainzozo.github.io/lofer/hardware/`. It is not linked from the landing page and has a `noindex` tag, so search engines should skip it. Edit the files in `public/hardware/`.

The folder is fully static, with no build step and no server code. Upload it as it is to any web host (Netlify, Vercel, GitHub Pages, Webflow or Squarespace file hosting, or your own server) and open `index.html`.

To place it inside an existing page on the Lofer site, host the folder and embed it:

```html
<iframe src="/hardware/index.html" title="Lofer hardware prototype"
        style="width:100%;height:1100px;border:0"></iframe>
```

To view it locally, open `index.html` in a browser. Everything works offline except the IBM Plex fonts, which load from Google Fonts and fall back to system fonts.

## Editing

- Background colour: `--bg` at the top of `css/styles.css` (currently `#F2EBE3`).
- Text in the side panel for a part or wire: `js/board-data.js`.
- Overview text: the `overview()` function in `js/app.js`.
