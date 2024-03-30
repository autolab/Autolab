include ControllerMacros
require "rails_helper"

RSpec.describe Annotation, type: :model do
  context "when submissions exist" do
    let!(:users) do
      create_course_with_users
      [CourseUserDatum.where(user: @students.first).first,
       CourseUserDatum.where(user: @students.second).first]
    end
    after(:each) do
      delete_course_files(@course)
    end
    it "updates score correctly when annotations for non-autograded problem applied" do
      submission = Submission.where(course_user_datum: users[0]).first
      score = submission.scores.order(:problem_id).first
      score.update!(grader_id: users[1].id)
      problem = score.problem
      max_score = score.problem.max_score

      Annotation.destroy(Annotation.where(submission_id: submission.id).pluck(:id))

      annotation = Annotation.create!(filename: "/tmp",
                                      comment: "test",
                                      submission_id: submission.id,
                                      problem_id: problem.id,
                                      value: 20,
                                      submitted_by: 'admin@foo.bar')

      annotation.update_non_autograded_score

      # need to force reload lookup of score to avoid caching
      expect(Score.find(score.id).score).to eq(max_score + 20)

      Annotation.destroy(Annotation.where(submission_id: submission.id).pluck(:id))
    end
  end
end
