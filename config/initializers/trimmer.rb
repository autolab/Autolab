# frozen_string_literal: true

# This loads a convenience method that allows you to
# ensure that leading and trailing whitespace is removed
# from fields. Just call trim_field the same way you
# would validate and it'll do the right thing.
require "trimmer"
module ActiveRecord
  class Base
    include Trimmer
  end
end
