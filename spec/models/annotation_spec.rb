require "rails_helper"

RSpec.describe Annotation, type: :model do
  it "updates score correctly when annotations for non-autograded problem applied" do
    submission = Submission.first
    score = submission.scores.order(:problem_id).first
    score.update!(grader_id: 1)
    problem = score.problem
    max_score = score.problem.max_score

    Annotation.destroy(Annotation.where(submission_id: submission.id).pluck(:id))

    annotation = Annotation.create!(filename: "/tmp",
                                    comment: "test",
                                    submission_id: submission.id,
                                    problem_id: problem.id,
                                    value: 20,
                                    submitted_by: 'admin@foo.bar')

    annotation.update_non_autograded_score()

    # need to force reload lookup of score to avoid caching
    expect(Score.find(score.id).score).to eq(max_score + 20)

    Annotation.destroy(Annotation.where(submission_id: submission.id).pluck(:id))
  end
end
