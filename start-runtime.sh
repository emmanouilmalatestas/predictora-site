#!/bin/bash
cd /home/deploy/predictoraai
npx tsc
node dist/services/runtime/index.js
