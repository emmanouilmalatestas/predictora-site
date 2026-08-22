#!/usr/bin/env bash
set -e

echo "== PredictoraOS Frontend Init (Next 16 + App Router) =="

# 1. Go to clean folder
cd ~/predictoraai/predictora-frontend

# 2. Create Next.js 16 app
npx create-next-app@latest . \
  --ts \
  --app \
  --tailwind \
  --eslint \
  --src-dir=false \
  --import-alias "@/*"

echo "== Base Next.js app created =="

# 3. Align dependencies
npm install next@16.2.10 react@18.3.1 react-dom@18.3.1

echo "== Dependencies aligned to Next 16.2.10 =="

# 4. Clean default API
rm -rf app/api

echo "== Clean base ready at ~/predictoraai/predictora-frontend =="
