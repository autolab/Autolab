##
# An Assessment can have many Problems, each one creates a score for each Submission
# for the Assessment.
#
class Problem < ApplicationRecord
  trim_field :name

  # don't need :dependent => :destroy as of 2/18/13
  has_many :scores, dependent: :delete_all
  belongs_to :assessment, touch: true
  has_many :annotations

  validates :name, presence: true
  validates_associated :assessment

  after_commit -> { assessment.dump_yaml }
  after_save :update_course_grade_watchlist_instances_if_past_end_at,
             if: :saved_change_to_max_score?
  after_create :update_course_grade_watchlist_instances_if_past_end_at
  after_destroy :update_course_grade_watchlist_instances_if_past_end_at

  delegate :update_course_grade_watchlist_instances_if_past_end_at, to: :assessment

  SERIALIZABLE = Set.new %w[name description max_score optional]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.deserialize_list(assessment, problems)
    problems.map { |p| assessment.problems.create(p) }
  end
end
