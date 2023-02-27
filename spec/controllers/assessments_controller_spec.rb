require "rails_helper"

RSpec.describe AssessmentsController, type: :controller do
  describe "GET index" do
    it "assigns all assessments as @assessments" do
      assessment = build(:assessment)
      FileUtils.mkdir_p assessment.handin_directory_path
      assessment.save
    end
  end
end
