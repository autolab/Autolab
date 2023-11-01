class String
  def to_boolean
    ActiveRecord::Type::Boolean.new.cast(self)
  end
end

class NilClass
  def to_boolean
    false
  end
end