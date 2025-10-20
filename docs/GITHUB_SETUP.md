# GitHub Repository Setup Guide

## 🚀 Quick Start: Push to GitHub

Your project is now secure and ready to push to GitHub. Follow these steps:

### 1. Create GitHub Repository

**Option A: Via GitHub Website**
1. Go to https://github.com/new
2. Repository name: `versfeld` (or your preferred name)
3. Description: "Flutter/Firebase tool management system for workshop QR code-based tool tracking"
4. Choose: **Private** (recommended initially) or Public
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

**Option B: Via GitHub CLI**
```bash
gh repo create versfeld --private --source=. --remote=origin
```

### 2. Initialize Git (if not already done)

```bash
# Check if git is initialized
git status

# If not initialized:
git init
git branch -M main
```

### 3. Stage and Commit Files

```bash
# Add all files (sensitive files are already in .gitignore)
git add .

# Create initial commit
git commit -m "Initial commit: Versfeld Tool Manager

- Flutter/Firebase tool management system
- QR code-based tool tracking
- Role-based access control (Admin/Supervisor/Worker)
- Provider-based state management
- Mallon design system (white/black/green palette)"
```

### 4. Add GitHub Remote and Push

```bash
# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/versfeld.git

# OR if using SSH:
git remote add origin git@github.com:YOUR_USERNAME/versfeld.git

# Push to GitHub
git push -u origin main
```

### 5. Verify Push

1. Go to your GitHub repository
2. Check that these files **ARE PRESENT**:
   - ✅ `.gitignore`
   - ✅ `lib/firebase_options.dart.template`
   - ✅ `android/app/google-services.json.template`
   - ✅ `ios/Runner/GoogleService-Info.plist.template`
   - ✅ `docs/SECURITY_SETUP.md`
   - ✅ All source code files

3. Check that these files **ARE NOT PRESENT**:
   - ❌ `lib/firebase_options.dart` (actual config)
   - ❌ `android/app/google-services.json` (actual config)
   - ❌ `ios/Runner/GoogleService-Info.plist` (actual config)
   - ❌ `.firebase/` directory
   - ❌ `.env` files

## 🔐 Security Verification

Before pushing, always run:

```bash
# Run security check
./scripts/security_check.sh

# Verify git status
git status

# Check what will be pushed
git diff origin/main
```

## 👥 Setting Up GitHub Secrets (For CI/CD)

If you plan to use GitHub Actions:

1. Go to your repository → Settings → Secrets and variables → Actions
2. Add these secrets:
   - `FIREBASE_WEB_API_KEY`
   - `FIREBASE_ANDROID_API_KEY`
   - `FIREBASE_IOS_API_KEY`
   - `FIREBASE_PROJECT_ID`

## 📋 Repository Settings

### Recommended Settings

**1. Branch Protection (Settings → Branches)**
- Protect `main` branch
- Require pull request reviews
- Require status checks to pass

**2. Security Settings**
- Enable Dependabot alerts
- Enable Dependabot security updates
- Enable secret scanning

**3. Collaboration**
- Add team members as collaborators
- Set appropriate permission levels

## 🔄 Daily Workflow

### Making Changes

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ... edit files ...

# Stage and commit
git add .
git commit -m "feat: add your feature description"

# Push to GitHub
git push origin feature/your-feature-name

# Create Pull Request on GitHub
```

### Pulling Updates

```bash
# Ensure main branch is up to date
git checkout main
git pull origin main

# Rebase your feature branch
git checkout feature/your-feature-name
git rebase main
```

## 📝 Commit Message Convention

Use conventional commits:

```
feat: add new feature
fix: bug fix
docs: documentation changes
style: formatting, missing semicolons, etc.
refactor: code restructuring
test: adding tests
chore: updating build tasks, configs, etc.
```

Examples:
```bash
git commit -m "feat: add batch tool checkout functionality"
git commit -m "fix: resolve scan processing lock-up issue"
git commit -m "docs: update security setup guide"
```

## 🆘 Troubleshooting

### "Repository not found" error
```bash
# Check remote URL
git remote -v

# Update remote URL
git remote set-url origin https://github.com/YOUR_USERNAME/versfeld.git
```

### "Updates were rejected" error
```bash
# Pull latest changes first
git pull origin main --rebase

# Then push
git push origin main
```

### Accidentally committed sensitive files
```bash
# Remove from staging
git reset HEAD lib/firebase_options.dart

# Remove from last commit
git reset --soft HEAD~1

# If already pushed, see docs/SECURITY_SETUP.md for recovery steps
```

## 📚 Additional Resources

- [GitHub Docs](https://docs.github.com/)
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

## ✅ Pre-Push Checklist

Before every push:
- [ ] Run `./scripts/security_check.sh`
- [ ] Run `flutter analyze` (no errors)
- [ ] Run `flutter test` (all tests pass)
- [ ] Check `git status` (no sensitive files staged)
- [ ] Review `git diff` (changes make sense)
- [ ] Commit message follows convention
- [ ] All team members notified of breaking changes

---

**Happy Coding! 🎉**

For security concerns, review `docs/SECURITY_SETUP.md`
