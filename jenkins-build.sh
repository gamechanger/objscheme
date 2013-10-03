#!/bin/bash --login
export LANG=en_US.UTF-8

# install ruby dependencies
rvm use 1.9.3@objscheme --create
cd $WORKSPACE
bundle install && pod install
if [ $? -ne 0 ]
then
    echo "Dependency installation failed"
    exit 1
fi

