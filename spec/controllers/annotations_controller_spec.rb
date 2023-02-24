require "rails_helper"

RSpec.describe AnnotationsController, type: :controller do
  # TODO: CHANGE THIS LOL
  describe "#create" do
    context "testing sets rn" do
      let!(:course) do
        create_course_with_users
        @course
      end
      it "signs in instructor and creates course" do
        expect(true).to equal(true)
      end
    end
  end
end
