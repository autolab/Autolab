##
# Scoreboards belong to Assessments, and basically specify how the scoreboard should display
#
class Scoreboard < ApplicationRecord
  belongs_to :assessment

  trim_field :banner, :colspec

  validate :colspec_is_well_formed

  after_commit -> { assessment.dump_yaml }

  SERIALIZABLE = Set.new %w[banner colspec]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

protected

  # Validates a JSON column spec for correctness before saving it the database
  def colspec_is_well_formed
    # An empty spec is OK
    return if colspec.blank?

    # The parse will throw an exception if the string has a JSON syntax error
    begin
      parsed = ActiveSupport::JSON.decode(colspec)
    rescue StandardError => e
      errors.add "colspec", e.to_s
      return
    end

    unless parsed.is_a? Hash
      errors.add "colspec", "must be a hash object"
      return
    end

    # Colspecs must include a scoreboard array object
    unless parsed["scoreboard"]
      errors.add "colspec", "missing 'scoreboard' array object"
      return
    end

    # Scoreboard object must be an array of hashes. The only valid keys are 'hdr' and 'asc'.
    unless parsed["scoreboard"][0]
      errors.add "colspec", "the 'scoreboard' object must be a non-empty array of hashes"
      return
    end

    parsed["scoreboard"].each_with_index do |hash, i|
      unless hash.is_a? Hash
        errors.add "colspec", "scoreboard[#{i}] is not a hash object"
        return
      end

      unless hash["hdr"]
        errors.add "colspec", "scoreboard[#{i}] hash is missing a 'hdr' object"
        return
      end

      hash.each_key do |k|
        unless %w[hdr asc img].include?(k)
          errors.add "colspec", "unknown key('#{k}') in scoreboard[#{i}]"
          return
        end
      end
    end
  end
end
