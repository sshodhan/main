# Math Quest Garden Deployment Guide

This project is a static web app composed of three files:

- `index.html`
- `style.css`
- `script.js`

Because everything runs in the browser, you can host it on any static website service. Below are three kid-friendly options that require no server configuration.

## Option 1: GitHub Pages (free, no ads)
1. Create a GitHub account (if you do not already have one).
2. Create a new public repository and upload `index.html`, `style.css`, and `script.js`.
3. In the repository settings, enable **Pages** and select the `main` branch with the `/root` folder. GitHub builds the site automatically.
4. Wait 1–2 minutes, then visit `https://<your-username>.github.io/<repo-name>/` and bookmark it for your child.

## Option 2: Netlify Drop (simplest drag-and-drop)
1. Go to [https://app.netlify.com/drop](https://app.netlify.com/drop).
2. Drag the three project files into the upload area.
3. Netlify instantly publishes the app and shows a unique URL (for example `https://sparkly-math.netlify.app`).
4. You can customize the site name by creating a free Netlify account and linking the deployment.

## Option 3: Local offline copy (no internet required)
1. Copy the entire project folder onto your computer.
2. Double-click `index.html` to open it in a web browser.
3. For a desktop shortcut, right-click the open browser tab and choose **Create shortcut** (name it “Math Quest Garden”).

## Optional: Add a custom domain
- Purchase or use an existing domain from a registrar.
- Follow the DNS setup guide of the chosen hosting service (GitHub Pages or Netlify both support custom domains for free).

Once deployed, share the final link with your child and it will work on any modern browser, including tablets.
