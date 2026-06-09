#!/bin/bash
set -e

cd ~

# Git identity (set GIT_USER_EMAIL and GIT_USER_NAME in .devcontainer/.env)
if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi

