if [ -z "$TRAVIS_TAG" ]
then
  echo "No tag, no release."
  exit 0
fi

lua generate.lua -r "$TRAVIS_TAG"
lua precommit.lua "$TRAVIS_TAG"

cd doc/_build/html
touch .nojekyll

git init

git config user.name "Travis CI"
git config user.email "keneanung@googlemail.com"

git add .
git commit -m "Deploy to GitHub Pages"

# Force push from the current repo's master branch to the remote
# repo's gh-pages branch. (All previous history on the gh-pages branch
# will be lost, since we are overwriting it.) We redirect any output to
# /dev/null to hide any sensitive credential data that might otherwise be exposed.
git push --force --quiet "https://${GH_USER}:${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 1>&2
