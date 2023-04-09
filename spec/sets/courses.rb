module Contexts
  module Courses
    # TODO: course creation creates a bunch of folders and files that persist
    # should implement some form of cleanup
    def create_course(asmt_name: "testassessment")
      @course = FactoryBot.create(:course) do |new_course|
        if asmt_name =~ /[^a-z0-9]/
          raise ArgumentError("Assessment name must contain only lowercase and digits")
        end

        @instructor_cud = FactoryBot.create(:course_user_datum, course: new_course,
                                                                user: @instructor_user,
                                                                instructor: true)
        # create assessment directory
        path = Rails.root.join("courses/#{new_course.name}/#{asmt_name}")
        FileUtils.mkdir_p(path)

        # create assessment
        FactoryBot.create(:assessment, course: new_course, name: asmt_name,
                                       is_positive_grading: false) do |asmt|
          # initialize config file and build handin directory
          asmt.construct_default_config_file
          asmt.load_config_file
          assessment_handin_path = Rails.root.join(path, asmt.handin_directory)
          FileUtils.mkdir_p(assessment_handin_path)

          problems = FactoryBot.create_list(:problem, 3, assessment_id: asmt.id)

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
            cud = FactoryBot.create(:nicknamed_student, course: new_course, user: student)

            FactoryBot.create(:submission,
                              filename: filename, course_user_datum: cud,
                              submitted_by: cud,
                              assessment: asmt) do |submission|
              # update aud to reflect latest submission
              aud.latest_submission_id = submission.id
              problems.each do |problem|
                FactoryBot.create(:score, score: problem.max_score, grader: @instructor_cud,
                                          problem: problem, released: true,
                                          submission: submission)
              end
            end
            # create dummy submission
            File.open(submission_path, 'w+') do |f|
              f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
            end
          end
        end

        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @admin_user,
                                              instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @course_assistant_user,
                                              instructor: false, course_assistant: true)

        @assessment = Assessment.where(course: new_course, name: asmt_name).first
      end
    end

    def create_autograded_course(asmt_name: "autogradedassessment")
      @course = FactoryBot.create(:course) do |new_course|
        if asmt_name =~ /[^a-z0-9]/
          raise ArgumentError("Assessment name must contain only lowercase and digits")
        end

        @instructor_cud = FactoryBot.create(:course_user_datum, course: new_course,
                                                                user: @instructor_user,
                                                                instructor: true)
        # create assessment directory
        path = Rails.root.join("courses/#{new_course.name}/#{asmt_name}")
        FileUtils.mkdir_p(path)
        FactoryBot.create(:assessment, course: new_course, name: asmt_name,
                                       is_positive_grading: false) do |asmt|
          asmt.construct_default_config_file
          asmt.load_config_file
          assessment_handin_path = Rails.root.join(path, asmt.handin_directory)
          FileUtils.mkdir_p(assessment_handin_path)
          problems = FactoryBot.create_list(:problem, 3, assessment_id: asmt.id)
          autograded_problem = FactoryBot.create(:problem, assessment_id: asmt.id,
                                                           name: "autograded")

          # copy over autograde configuration files from template
          autograde_makefile_template = Rails.root.join("templates/labtemplate/autograde-Makefile")
          autograde_tar_template = Rails.root.join("templates/labtemplate/autograde.tar")
          FileUtils.cp(autograde_makefile_template, path)
          FileUtils.cp(autograde_tar_template, path)

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
            cud = FactoryBot.create(:nicknamed_student, course: new_course, user: student)

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
              FactoryBot.create(:score, score: autograded_problem.max_score,
                                        grader: @instructor_cud,
                                        problem: autograded_problem, released: true,
                                        submission: submission)
            end
            File.open(submission_path, 'w+') do |f|
              f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
            end
          end

          FactoryBot.create(:autograder, assessment: asmt)
        end

        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @admin_user,
                                              instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @course_assistant_user,
                                              instructor: false, course_assistant: true)

        @assessment = Assessment.where(course: new_course, name: asmt_name).first
      end
    end
  end
end
