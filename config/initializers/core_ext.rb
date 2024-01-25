class String
  def to_boolean
    ActiveRecord::Type::Boolean.new.cast(self.downcase)
  end
end

class NilClass
  def to_boolean
    false
  end
end