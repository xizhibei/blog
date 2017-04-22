#!/usr/bin/env bash
github-issues-to-hexo --version || npm i github-issues-to-hexo -g
github-issues-to-hexo -u xizhibei -r blog -t ./template.md

git add source/_posts/

git commit -m "chore: update posts"

git push

