#!/bin/bash --login

echo publishing $1

rvm use 1.9.3@objscheme --create
cd $WORKSPACE
bundle install && pod install
if [ $? -ne 0 ]
then
    echo "Dependency installation failed"
    exit 1
fi

git checkout master
git reset --hard $GIT_COMMIT
$WORKSPACE/publish-version.sh $1