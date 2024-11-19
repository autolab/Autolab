module Contexts
  module Submissions
    # Creates submissions for all students in the course for an assignment
    def create_submissions_for_assignment(asmt: @assessment)
      students = get_students_by_assessment(asmt)

      # create submissions
      students.each do |student|
        create_submissions_for_student(asmt:, student:)
      end
    end

    def create_submissions_for_student(asmt: @assessment, student: @students.first)
      course = asmt.course
      problems = get_problems_by_assessment(asmt.id)
      assessment_handin_path = get_handin_path(asmt)

      filename = "#{student.email}_0_#{asmt.handin_filename}"
      submission_path = File.join(assessment_handin_path, filename)

      # TODO: replace with factorybot
      # needed to bypass validations, but jank
      AssessmentUserDatum.create_modulo_callbacks(assessment_id: asmt.id,
                                                  course_user_datum_id: student.id,
                                                  version_number: 0)
      aud = AssessmentUserDatum.find_by(assessment_id: asmt.id,
                                        course_user_datum_id: student.id)
      # students in this course are given nicknames to bypass
      # initial cud edit redirect that occurs when no nickname is given
      cud = CourseUserDatum.find_by(course_id: course.id, user_id: student.id)
      @submissions = FactoryBot.create(:submission,
                                       filename:, course_user_datum: cud,
                                       submitted_by: cud,
                                       assessment: asmt) do |submission|
        aud.latest_submission_id = submission.id
        problems.each do |problem|
          FactoryBot.create(:score, score: problem.max_score, grader: @instructor_cud,
                                    problem:, released: true,
                                    submission:)
        end
      end
      File.open(submission_path, 'w+') do |f|
        f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
      end
      @submissions
    end
  end
end
