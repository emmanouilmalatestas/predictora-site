#!/bin/bash
set -e

echo "=== PredictoraOS Productization Wizard ==="

# 1. Git config
read -p "GitHub username (e.g. emmanouilmalestas): " GH_USER
read -p "GitHub repo name (e.g. predictoraos): " GH_REPO

REPO_URL="git@github.com:${GH_USER}/${GH_REPO}.git"

echo
echo "→ Initializing git repo..."
git init

echo "→ Adding all files..."
git add .

# 2. LICENSE
echo
read -p "Use MIT license? (y/n): " USE_MIT
if [ "$USE_MIT" = "y" ]; then
  cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 PredictoraOS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[...κόψε/συμπλήρωσε το κλασικό MIT κείμενο όπως θες...]
EOF
  echo "→ LICENSE (MIT) created."
else
  echo "→ Skipping LICENSE (you can add commercial later)."
fi

# 3. README
echo
read -p "Short product description (one line): " DESC

cat > README.md << EOF
# PredictoraOS

${DESC}

## Key modules

- Enterprise backend (Mode A + Mode B)
- Deterministic runtime, ledger hashing, event sourcing, replay
- Billing, revenue recognition, chaos engine
- Observability exporter, analytics pipeline, runtime sharding

## Deployment

See \`k8s/\` and \`docker/\` directories for manifests and Dockerfiles.
EOF

echo "→ README.md created."

# 4. VERSION
echo
read -p "Initial version (default v1.0.0): " VERSION
VERSION=${VERSION:-v1.0.0}

echo "${VERSION}" > VERSION
echo "→ VERSION set to ${VERSION}"

# 5. Structure dirs
mkdir -p docker k8s docs
echo "→ Created docker/, k8s/, docs/ directories."

# 6. Commit
echo
git add LICENSE README.md VERSION docker k8s docs || true

read -p "Commit message (default: 'Initial PredictoraOS productization'): " COMMIT_MSG
COMMIT_MSG=${COMMIT_MSG:-Initial PredictoraOS productization}

git commit -m "${COMMIT_MSG}"

# 7. Remote + push
echo
echo "→ Setting remote to ${REPO_URL}"
git remote add origin "${REPO_URL}" || true

read -p "Push to GitHub now? (y/n): " DO_PUSH
if [ "$DO_PUSH" = "y" ]; then
  git branch -M main
  git push -u origin main
  echo "→ Pushed to GitHub: ${REPO_URL}"
else
  echo "→ Skipping push. Run 'git push -u origin main' later."
fi

# 8. Tag release
echo
read -p "Tag release ${VERSION}? (y/n): " DO_TAG
if [ "$DO_TAG" = "y" ]; then
  git tag "${VERSION}"
  git push origin "${VERSION}" || true
  echo "→ Tagged release ${VERSION}"
else
  echo "→ Skipping tag."
fi

echo
echo "=== NEXT STEPS ==="
echo "1) Μετακίνησε Dockerfiles σε docker/ και K8s manifests σε k8s/."
echo "2) Κάνε commit/push ό,τι λείπει."
echo "3) Στο GitHub βάλε description, topics κτλ."
echo "4) Μετά πάμε σε CI/CD TLS fix + domain."
