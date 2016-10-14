#!/usr/bin/env bash

#echo "install bundler"
#gem install bundler

echo "!!! bundle install"
bundle install

echo "!!! bundle exec rake prepare"
bundle exec rake prepare

echo "!!! bundle exec rake test"
bundle exec rake test

echo "!!! bundle exec gem build wikipedia-vandalism_detection.gemspec"
bundle exec gem build wikipedia-vandalism_detection.gemspec
