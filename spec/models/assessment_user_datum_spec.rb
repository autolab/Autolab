require "rails_helper"

RSpec.describe AssessmentUserDatum, type: :model do
  describe "#cgdub_cache_key" do
    it "uses a stable fallback when the dependency timestamp is missing" do
      course = FactoryBot.create(:course)
      membership = FactoryBot.create(:course_user_datum, course:)
      assessment = FactoryBot.create(:assessment, course:)
      datum = AssessmentUserDatum.new(
        assessment:,
        course_user_datum: membership
      )
      datum.assessment.course.cgdub_dependencies_updated_at = nil

      expect(datum.send(:cgdub_cache_key)).to include(Time.at(0).utc.to_s(:number))
    end
  end
end
