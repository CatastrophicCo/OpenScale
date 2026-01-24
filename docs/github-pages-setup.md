# Deploying LineScale Website to GitHub Pages

## Option 1: Deploy from `website` folder

1. **Push your repository to GitHub**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/yourusername/LineScale.git
   git push -u origin main
   ```

2. **Configure GitHub Pages**
   - Go to your repository on GitHub
   - Navigate to Settings → Pages
   - Under "Source", select "Deploy from a branch"
   - Select `main` branch and `/website` folder
   - Click Save

3. **Access your site**
   - Your site will be available at: `https://yourusername.github.io/LineScale/`

## Option 2: Deploy from `docs` folder

If you prefer using the `docs` folder (common convention):

1. **Rename the website folder**
   ```bash
   mv website docs-website
   mkdir docs
   mv docs-website/* docs/
   mv docs-website/.nojekyll docs/
   ```

2. **Move existing docs**
   ```bash
   mkdir docs/documentation
   mv docs/*.md docs/documentation/
   ```

3. **Configure GitHub Pages**
   - Select `main` branch and `/docs` folder in GitHub Pages settings

## Custom Domain (Optional)

To use a custom domain like `linescale.io`:

1. **Create CNAME file** in the website folder:
   ```
   linescale.io
   ```

2. **Configure DNS** with your domain provider:
   - Add a CNAME record pointing to `yourusername.github.io`
   - Or add A records pointing to GitHub's IP addresses

3. **Enable HTTPS** in GitHub Pages settings

## Updating the Website

After making changes to the website files:

```bash
git add website/
git commit -m "Update website"
git push
```

GitHub Pages will automatically rebuild and deploy your site.

## Local Testing

To test the website locally:

1. **Using Python:**
   ```bash
   cd website
   python -m http.server 8000
   ```
   Then open `http://localhost:8000`

2. **Using Node.js:**
   ```bash
   npx serve website
   ```

3. **Using VS Code:**
   - Install "Live Server" extension
   - Right-click `index.html` → "Open with Live Server"
