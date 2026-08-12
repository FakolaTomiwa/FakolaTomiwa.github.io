# Data Analytics Portfolio

Static site for Tomiwa Fakola's data analytics portfolio, built for GitHub Pages.

## Structure

```
index.html                          → homepage / project index
projects/nexus-retail-group.html    → Nexus Retail Group case study
assets/css/style.css                → shared styles
assets/images/                      → chart screenshots
assets/files/                       → downloadable SQL script + pptx
```

## Publish it on GitHub Pages (free)

1. Create a new repository on GitHub — name it exactly `FakolaTomiwa.github.io`.
   Keep it **public**.
2. Upload all the files in this folder into that repo, keeping the same folder
   structure (drag-and-drop on github.com works, or use git — see below).
3. Go to the repo's **Settings → Pages**, and under "Build and deployment"
   set Source to **Deploy from a branch**, branch `main`, folder `/ (root)`.
4. Wait 1–2 minutes, then visit `https://FakolaTomiwa.github.io` — your
   portfolio is live.

## Using git instead of drag-and-drop

```bash
git init
git remote add origin https://github.com/FakolaTomiwa/FakolaTomiwa.github.io.git
git add .
git commit -m "Initial portfolio"
git branch -M main
git push -u origin main
```

## Adding your next project

1. Duplicate `projects/nexus-retail-group.html` as a starting template.
2. Add a new `<a class="card">` block to `index.html` linking to it.
3. Drop any chart images into `assets/images/` and scripts/decks into `assets/files/`.

## To do before going live

- [ ] Swap "Lagos, Nigeria" in the hero meta (in `index.html`) if you'd rather not list a location.
