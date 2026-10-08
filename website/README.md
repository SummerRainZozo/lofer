# Lofer website

The marketing landing page for Lofer. It's a plain HTML/CSS/JavaScript site built with [Vite](https://vite.dev). The glowing device in the hero is drawn with [three.js](https://threejs.org).

## Run it

You need [Node.js](https://nodejs.org) 20 or newer.

```bash
cd website
npm install      # first time only: downloads three.js and Vite into node_modules/
npm run dev      # starts a local server, usually at http://localhost:5173
```

Edits show up in the browser as soon as you save.

```bash
npm run build    # makes the final site in website/dist/ (ready to upload to any static host)
npm run preview  # serves dist/ locally so you can check the build
```

## Where things live

```
website/
├── index.html            ← all the page's text and sections
├── public/favicon.svg    ← browser-tab icon (the outline logo)
├── public/app/           ← real screenshots of the iOS app, used in "Guided checks"
├── public/renders/       ← web copies of the product renders (exploded view, tile details). The originals were not committed.
└── src/
    ├── main.js           ← entry point: starts the 3D tile, logo, Lofer Loop, tiling background and scroll animations
    ├── device3d.js       ← the rotating 3D tile in the hero: silicone cover, stitched seam, debossed logo, edge contacts, skin side (three.js)
    ├── tiling.js         ← the faint tiles behind the page. They regroup (3, 4, 5, 7) as you scroll: the cluster spins away and spins in on its new side
    ├── loop.js           ← animates the six-stage Lofer Loop (Listen → Consider → Check → Act → Reassess → Learn)
    ├── build.js          ← lights up one layer of the exploded tile render at a time as you scroll ("Inside Lofer")
    ├── logo.js           ← the logo mark (the device outline), as SVG
    ├── deviceShape.js    ← THE product outline (also in the app's LoferMark.swift), used by the 3D model, logo and fallback
    └── styles.css        ← colours, fonts, layout
```

| I want to change… | Look in |
|---|---|
| Any wording | `index.html` |
| Colours, fonts, spacing | the top of `src/styles.css` (same colours as the iOS app) |
| The product's shape | `OUTLINE` in `src/deviceShape.js` |
| The loop's speed or stages | `src/loop.js` and the `loop` section of `index.html` |
| How the hero device looks or moves | `src/device3d.js` (colour, shape and artwork of the tile; the real dimensions are in the comments) |
| The exploded hardware view | `src/build.js`, plus the layer list and marker positions in `index.html` |

## Design notes

- **Message:** Lofer is an **AI-powered smart wearable for personalised muscle care**. When something aches, people are left guessing where to focus, what to try and whether it's helping. Lofer is designed to **bridge the gap** between professional care (expert, but costly and hard to reach) and home tools like massage guns (always there, but blunt). It guides you to the most plausible area and how to work on it, delivers the care, and checks what changed, within safety limits. The page, in order:
  1. **Hero:** the device in the middle; underneath, the italic line "Know what to do when something aches, accessible at any time." and what Lofer is. Visible *In development* status.
  2. **Our mission:** the bridging story, then professional care and home tools (✓ what they do well, ✕ what they can't) next to Lofer, the best of both.
  3. **Guided checks:** real screens from the iOS app (`public/app/`, captured from the `-LoferDemoFull` demo). Re-capture them when the app's look changes.
  4. **The Lofer Loop:** six stages (`src/loop.js` animates however many nodes the diagram has).
  5. **Personal:** what's remembered (reported, checked, tried, afterwards).
  6. **Inside Lofer:** the real exploded render with seven layers (silicone cover, battery, circuit board, insulating foam, rigid chassis, heater film, hydrogel liner), then tile details (colourways, skin side, latching, dock) and a spec list. Micro-current stimulation is planned but not in the current hardware, and the section says so.
- **Claims rules** (check the app and hardware evidence before changing copy):
  - "AI-powered" is the positioning the founders chose. Today's app uses an on-device keyword parser, with an AI backend planned.
  - Name only hardware that's in the prototype drawings (heat: heater film with thermal cut-off; vibration motor; EMG electrodes in the hydrogel liner). EMG is "designed to read muscle activity", not a validated measurement. Compression and EMS are **not** in the current build, so the site no longer lists them.
  - Say "most plausible area", "designed to", "guides": never diagnosis, root cause, guaranteed relief, "always gentle", "smarter every time", or replacing a physiotherapist.
  - No price or "affordable" claims until pricing exists.
  - Present limits, pause/stop and in-session feedback as features, not as a guarantee of safety.
  - Don't use "not a medical device" as a disclaimer; the intended purpose and regulatory route aren't decided.
  - Never show sign-up success unless an email was actually saved.
- **Fonts:** the same as the app (`Lofer/DesignSystem/Typography.swift`): *Figtree* for all text, *Quicksand Light* for the "Lofer" wordmark. Sentence case, no all-caps headlines. Both load from Google Fonts.
- **Colours:** a cream page (`#f3ebe2`, the app's `loferCream`) with peach, lilac and mocha accents from `Lofer/DesignSystem/Colors.swift` and the brand sheet.
- **Accessibility:** if a visitor has "reduce motion" turned on, the device stays still and nothing animates in. Without WebGL, a flat glowing outline is shown instead.

## Not done yet

- **No email sign-up yet.** The page shows a disabled "Waitlist opening soon" button and collects nothing. When a form service or Lofer's backend exists, add the form back and only confirm after a successful save (see the note in `src/main.js`).
- **Hosting.** The site isn't deployed anywhere yet. `npm run build` produces a static folder that Vercel, Netlify, Cloudflare Pages or GitHub Pages can serve.
