class RubricItem < ApplicationRecord
  belongs_to :problem
  has_many :rubric_item_assignments, dependent: :destroy
  has_many :submissions, through: :rubric_item_assignments

  validates :description, :points, :order, presence: true
  validates :points, numericality: true
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :order, uniqueness: { scope: :problem_id }

  default_scope { order(order: :asc) }
  
  # Check if this rubric item is assigned to a specific submission
  def assigned_to?(submission)
    rubric_item_assignments.where(submission: submission, assigned: true).exists?
  end
end