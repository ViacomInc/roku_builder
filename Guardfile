# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exists?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"

guard :minitest do
  # with Minitest::Unit
  watch(%r{^test/roku_builder/(.*)\/?test_(.*)\.rb$})
  watch(%r{^lib/roku_builder.rb$}) { "test/roku_builder/test_roku_builder.rb" }
  watch(%r{^lib/roku_builder/(.*/)?([^/]+)\.rb$}) { |m| "test/roku_builder/#{m[1]}test_#{m[2]}.rb" }
  watch(%r{^test/roku_builder/test_helper\.rb$}) { 'test/roku_builder' }
end
