lua precommit.lua "$TRAVIS_TAG"
lua generate.lua -r "$TRAVIS_TAG"

if [ -z "$TRAVIS_TAG" ]
then
  echo "No tag, no update in documentation needed."
  exit 0
fi

# Create documentation for the release
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

# return to repo root directory
cd -

# create release body

# get all releases first
http_code=`curl -s -w "%{http_code}" -o output.txt "https://api.github.com/repos/svof/svof/releases?access_token=${GH_TOKEN}"`
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
# Don't use the tag before, because there is a bug that adds everything of that tag to the current release
# instead we remove the second release in the list with the awk command below.
github_changelog_generator --since-tag `cat output.txt | jq --raw-output '.[2].tag_name'` -t ${GH_TOKEN} --no-unreleased --no-issues -u svof -p svof

# modify the changelog a little
echo "`awk -v RS='##' -v ORS="##" 'NR==1{print} NR==2{print;printf"\n";exit}' CHANGELOG.md | grep -v "# Change Log" | grep -v "^##"`" > CHANGELOG.md

# now upload the changelog
data=$(jq -n --arg v "`cat CHANGELOG.md`" '{"body": $v}')
http_code=$(curl -s -w "%{http_code}" --request PATCH --data "${data}" -o /dev/null "`cat output.txt | jq --raw-output ".[0].url"`?access_token=${GH_TOKEN}")
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

# Upload release zip files via sftp so automatic updates work

# Change to output directory
cd output

# Create current_version file
echo "${TRAVIS_TAG}" > current_version.txt

# upload everything here.
for f in *
do
  echo "Uploading ${f}"
  curl -3 -v --disable-epsv --ftp-skip-pasv-ip \
  --ftp-ssl -u "svof-machine-account:${FTP_PASS}" -T "${f}" "ftp://ftp.pathurs.com"
done
