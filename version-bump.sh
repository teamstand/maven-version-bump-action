#!/bin/bash

# Directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#
# Takes a version number, and the mode to bump it, and increments/resets
# the proper components so that the result is placed in the variable
# `NEW_VERSION`.
#
# $1 = mode (major, minor, patch, release)
# $2 = version (x.y.z)
#
function bump {
  local mode="$1"
  local old="$2"
  local parts=( ${old//./ } )
  case "$1" in
    major)
      local bv=$((parts[0] + 1))
      NEW_VERSION="${bv}.${parts[1]}.${parts[2]}.${parts[3]}"
      ;;
    minor)
      local bv=$((parts[1] + 1))
      NEW_VERSION="${parts[0]}.${bv}.${parts[2]}.${parts[3]}"
      ;;
    patch)
      local bv=$((parts[2] + 1))
      NEW_VERSION="${parts[0]}.${parts[1]}.${bv}.${parts[3]}"
      ;;
    release)
      local bv=$((parts[3] + 1))
      NEW_VERSION="${parts[0]}.${parts[1]}.${parts[2]}.${bv}"
      ;;
    esac
}

git config --global user.email $EMAIL
git config --global user.name $NAME

OLD_VERSION=$($DIR/get-version.sh)

BUMP_MODE="none"
if git branch == production-63.0 ; then
  if git log -1 | grep -q "Merge"; then
    BUMP_MODE="major"
  else
    BUMP_MODE="patch"
  fi
elif git branch == ns-uat; then
  BUMP_MODE="minor"
elif git branch == master; then
  BUMP_MODE="release"
fi

if [[ "${BUMP_MODE}" == "none" ]]
then
  echo "No matching commit tags found."
  echo "pom.xml at" $POMPATH "will remain at" $OLD_VERSION
else
  echo $BUMP_MODE "version bump detected"
  bump $BUMP_MODE $OLD_VERSION
  echo "pom.xml at" $POMPATH "will be bumped from" $OLD_VERSION "to" $NEW_VERSION
  cd $POMPATH
  mvn -q versions:set -DnewVersion="${NEW_VERSION}"
  git ls-files --modified | grep pom.xml | xargs git add
  REPO="https://$GITHUB_ACTOR:$TOKEN@github.com/$GITHUB_REPOSITORY.git"
  git commit -m "Bump pom.xml from $OLD_VERSION to $NEW_VERSION"
  git push $REPO 
fi
