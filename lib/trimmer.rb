# This is a module to allow you to specify fields in the ActiveRecord
# object that should always have leading and trailing whitespace
# stripped. Useful for situations where an unintended space
# throws off equality checks.
module Trimmer
  # Load the functions we want on include.
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Don't pollute the namespace.
  module ClassMethods
    def trim_field(*field_list)
      before_validation do |model|
        field_list.each do |n|
          model[n] = model[n].strip if model[n].respond_to? "strip"
        end
      end
    end
  end
end
