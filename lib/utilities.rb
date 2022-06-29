module Utilities
  def self.serializable(attributes, serializable)
    attributes.keep_if { |f, _| serializable.include? f }
    attributes.delete_if { |_, v| v.nil? }
    attributes
  end

  def self.is_url?(name)
    require "uri"
    uri = URI.parse(name)
    return false if uri.nil? || uri.scheme.nil? || uri.scheme.empty?
    return true
  rescue URI::InvalidURIError
    return false
  end

  def self.execute_instructor_code(invoked_method_name)
    yield
  rescue Exception => e
    raise InstructorException.new("Error executing #{invoked_method_name}: #{e}")
  end

  def self.validated_score_value(score, invoked_method_name, allow_nil = false)
    message = "Error executing #{invoked_method_name}"

    if score
      if (score = Float(score) rescue nil)
        fail InvalidComputedScoreException.new("#{message}: returned infinite number") unless score.finite?
      else
        fail InvalidComputedScoreException.new("#{message}: error converting to float")
      end
    else
      fail InvalidComputedScoreException.new("#{message}: returned nil") unless allow_nil
    end

    score
  end

  def self.is_truthy?(val)
    val == true || val == "True" || val == "true" || val == "t" || val == 1 || val == "1" || val == "T"
  end
end

class InvalidScoreException < StandardError
end

class ScoreComputationException < StandardError
end

class InvalidComputedScoreException < ScoreComputationException
end

class InstructorException < ScoreComputationException
end
