class RubricItemAssignment < ApplicationRecord
  include ScoreCalculation
  
  belongs_to :rubric_item
  belongs_to :submission
  
  validates :rubric_item_id, uniqueness: { scope: :submission_id }
  
  after_save :update_score
end
