#!/usr/bin/env bash
# exit on error
set -o errexit

# Install gems
bundle install

# Install root JS dependencies and build assets
npm install
npm run build
npm run build:css

# Build the frontend (React app)
cd frontend
npm install
npm run build
cd ..

# Precompile assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Run migrations
bundle exec rails db:prepare
