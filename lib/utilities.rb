# frozen_string_literal: true

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

    true
  rescue URI::InvalidURIError
    false
  end

  def self.execute_instructor_code(invoked_method_name)
    yield
  rescue Exception => e
    raise InstructorException, "Error executing #{invoked_method_name}: #{e}"
  end

  def self.validated_score_value(score, invoked_method_name, allow_nil = false)
    message = "Error executing #{invoked_method_name}"

    if score
      if (score = begin
        Float(score)
      rescue StandardError
        nil
      end)
        unless score.finite?
          raise InvalidComputedScoreException, "#{message}: returned infinite number"
        end
      else
        raise InvalidComputedScoreException, "#{message}: error converting to float"
      end
    else
      raise InvalidComputedScoreException, "#{message}: returned nil" unless allow_nil
    end

    score
  end

  def self.is_truthy?(val)
    [true, "True", "true", "t", 1, "1", "T"].include?(val)
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
