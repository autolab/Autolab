class RubricItem < ApplicationRecord
  belongs_to :problem

  validates :description, :points, :order, presence: true
  validates :points, numericality: true
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :order, uniqueness: { scope: :problem_id }

  default_scope { order(order: :asc) }
end 