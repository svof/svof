lua generate.lua -r "$TRAVIS_TAG"

if [ -z "$TRAVIS_TAG" ]
then
  echo "No tag, no update in documentation needed."
  exit 0
fi

lua precommit.lua "$TRAVIS_TAG"

cd doc/_build/html
touch .nojekyll

git init

git config user.name "svof-machine-account"
git config user.email "machine@svof.com"

git add .
git commit -m "Deploy to GitHub Pages"

# Force push from the current repo's master branch to the remote
# repo's gh-pages branch. (All previous history on the gh-pages branch
# will be lost, since we are overwriting it.) We redirect any output to
# /dev/null to hide any sensitive credential data that might otherwise be exposed.
git push --force --quiet "https://${GH_USER}:${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 1>&2

# create release body

# get all releases first
http_code=`curl -s -w "%{http_code}" -o output.txt "https://api.github.com/repos/keneanung/svof/releases?access_token=${GH_TOKEN}"`
out=$?
if [ "$out" != "0" ]
then
  echo "Getting releases failed:" "$out"
  exit 1
fi
if [ "$http_code" != "200" ]
then
  echo "Getting releases failed:" "$http_code"
  exit 1
fi


# now generate changelog
github_changelog_generator --since-tag `cat output.txt | jq '.[1].tag_name | tonumber'` -t ${GH_TOKEN} --no-unreleased --no-issues

# modify the changelog a little
echo "`cat CHANGELOG.md | grep -v "# Change Log" | grep -v "^##" | egrep -v "This Change Log"`" > CHANGELOG.md

# now upload the changelog
data=$(jq -n --arg v "`cat CHANGELOG.md`" '{"body": $v}')
http_code=curl -s -w "%{http_code}" --request PATCH --data "data" "https://api.github.com/repos/svof/svof/releases/`cat output.txt | jq ".[0].id | tonumber"`?access_token=${GH_TOKEN}"
if [ "$out" != "0" ]
then
  echo "Updating release body failed:" "$out"
  exit 1
fi
if [ "$http_code" != "200" ]
then
  echo "Updating release body failed:" "$http_code"
  exit 1
fi
