require "rails_helper"

RSpec.describe CourseUserDatum, type: :model do
  describe "#ggl_cache_key" do
    it "uses a stable fallback when the dependency timestamp is missing" do
      course = FactoryBot.create(:course)
      datum = FactoryBot.create(:course_user_datum, course:)
      datum.course.cgdub_dependencies_updated_at = nil

      expect(datum.ggl_cache_key).to include(Time.at(0).utc.to_s(:number))
    end
  end
end
