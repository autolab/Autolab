class LtiCourseDatum < ApplicationRecord
  belongs_to :course
  attribute :membership_url, :string
  attribute :platform, :string
  attribute :auto_sync, :boolean, default: false
  attribute :drop_missing_students, :boolean, default: false
  attribute :context_id, :integer
  attribute :course_id
  attribute :last_synced, :datetime
end
