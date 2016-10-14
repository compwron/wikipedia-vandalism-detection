#!/usr/bin/env bash

#echo "install bundler"
#gem install bundler

echo "!!! remove Gemfile.lock"
rm Gemfile.lock

echo "!!! Install local custom built version of ruby-band from https://github.com/compwron/ruby-band/commit/a4f928dab4893eb760a641b1fbc44b570febfc68"
rm -rf vendor/gems/*
gem unpack ruby-band-0.2.0.gem --target vendor/gems/

echo "!!! bundle install"
bundle install

echo "!!! bundle exec rake prepare"
bundle exec rake prepare

echo "!!! bundle exec rake test"
bundle exec rake test

echo "!!! bundle exec gem build wikipedia-vandalism_detection.gemspec"
bundle exec gem build wikipedia-vandalism_detection.gemspec

echo "!!! show what version of ruby-band we have"
bundle show ruby-band
