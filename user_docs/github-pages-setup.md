# Deploying OpenScale Website to GitHub Pages

## Deploy from `docs` folder

The website files are located in the `docs/` folder, which is the standard location for GitHub Pages.

### 1. Push your repository to GitHub

```bash
git add .
git commit -m "Update website"
git remote add origin https://github.com/yourusername/OpenScale.git
git push -u origin main
```

### 2. Configure GitHub Pages

1. Go to your repository on GitHub
2. Navigate to Settings → Pages
3. Under "Source", select "Deploy from a branch"
4. Select `main` branch and `/docs` folder
5. Click Save

### 3. Access your site

Your site will be available at: `https://yourusername.github.io/OpenScale/`

## Website Structure

```
docs/
├── index.html          # Homepage
├── app.html            # Web Bluetooth app
├── assets/
│   └── css/
│       ├── style.css   # Homepage styles
│       └── app.css     # Web app styles
└── js/
    ├── app.js          # Web app logic
    └── bluetooth.js    # Web Bluetooth API wrapper
```

## Custom Domain (Optional)

To use a custom domain like `openscale.io`:

1. **Create CNAME file** in the docs folder:
   ```
   openscale.io
   ```

2. **Configure DNS** with your domain provider:
   - Add a CNAME record pointing to `yourusername.github.io`
   - Or add A records pointing to GitHub's IP addresses

3. **Enable HTTPS** in GitHub Pages settings

## Updating the Website

After making changes to the website files:

```bash
git add docs/
git commit -m "Update website"
git push
```

GitHub Pages will automatically rebuild and deploy your site.

## Local Testing

To test the website locally:

### Using Python
```bash
cd docs
python -m http.server 8000
```
Then open `http://localhost:8000`

### Using Node.js
```bash
npx serve docs
```

### Using VS Code
1. Install "Live Server" extension
2. Right-click `index.html` → "Open with Live Server"

## Web Bluetooth App

The web app (`app.html`) uses the Web Bluetooth API to connect to OpenScale devices.

### Requirements
- Chrome, Edge, or Opera browser
- HTTPS connection (or localhost for testing)
- Bluetooth enabled on your computer/phone

### Testing Locally
Web Bluetooth works on `localhost` without HTTPS:
```bash
cd docs
python -m http.server 8000
# Open http://localhost:8000/app.html
```

### Supported Browsers
| Browser | Desktop | Mobile |
|---------|---------|--------|
| Chrome | Yes | Yes (Android) |
| Edge | Yes | Yes (Android) |
| Opera | Yes | Yes (Android) |
| Safari | No | No |
| Firefox | No | No |

Note: iOS does not support Web Bluetooth in any browser.
