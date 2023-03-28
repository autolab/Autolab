module Contexts
  module Assessments
    def create_assessment(asmt_name: "testassessment", autograded: false, course: nil)
      course = @course if course.nil?
      if asmt_name =~ /[^a-z0-9]/
        raise ArgumentError("Assessment name must contain only lowercase and digits")
      end

      path = Rails.root.join("courses/#{course.name}/#{asmt_name}")
      FileUtils.mkdir_p(path)
      # create assessment directory
      @assessment = FactoryBot.create(:assessment, name: asmt_name,
                                                   course: course,
                                                   is_positive_grading: false) do |asmt|
        asmt.construct_default_config_file
        asmt.load_config_file
        assessment_handin_path = Rails.root.join(path, asmt.handin_directory)
        FileUtils.mkdir_p(assessment_handin_path)

        problems = FactoryBot.create_list(:problem, 3, assessment_id: asmt.id)

        if autograded
          autograded_problem = FactoryBot.create(:problem, assessment_id: asmt.id,
                                                           name: "autograded")

          # copy over autograde configuration files from template
          autograde_makefile_template = Rails.root.join("templates/labtemplate/autograde-Makefile")
          autograde_tar_template = Rails.root.join("templates/labtemplate/autograde.tar")
          FileUtils.cp(autograde_makefile_template, path)
          FileUtils.cp(autograde_tar_template, path)
        end

        # create submissions
        @students.each do |student|
          filename = "#{student.email}_0_#{asmt.handin_filename}"
          submission_path = File.join(assessment_handin_path, filename)

          # TODO: replace with factorybot
          # needed to bypass validations, but jank
          AssessmentUserDatum.create_modulo_callbacks(assessment_id: asmt.id,
                                                      course_user_datum_id: student.id)
          aud = AssessmentUserDatum.find_by(assessment_id: asmt.id,
                                            course_user_datum_id: student.id)
          # students in this course are given nicknames to bypass
          # initial cud edit redirect that occurs when no nickname is given
          cud = CourseUserDatum.find_by(course_id: course.id, user_id: student.id)
          FactoryBot.create(:submission,
                            filename: filename, course_user_datum: cud,
                            submitted_by: cud,
                            assessment: asmt) do |submission|
            aud.latest_submission_id = submission.id
            problems.each do |problem|
              FactoryBot.create(:score, score: problem.max_score, grader: @instructor_cud,
                                        problem: problem, released: true,
                                        submission: submission)
            end

            if autograded
              FactoryBot.create(:score, score: autograded_problem.max_score,
                                        grader: @instructor_cud,
                                        problem: autograded_problem, released: true,
                                        submission: submission)
            end
          end
          File.open(submission_path, 'w+') do |f|
            f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
          end
        end

        if autograded
          FactoryBot.create(:autograder, assessment: asmt)
        end
      end
    end
  end
end
