module Contexts
  module Courses
    def create_course(asmt_name: "testassessment5")
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
          # create submissions
          # asmt.create_AUDs_modulo_callbacks
          #
          #
          # asmt.update_latest_submissions_modulo_callbacks
          @students.each do |student|
            filename = "#{student.email}_0_#{asmt.handin_filename}"
            submission_path = File.join(assessment_handin_path, filename)

            # TODO: replace with factorybot
            AssessmentUserDatum.create_modulo_callbacks(assessment_id: asmt.id,
                                                        course_user_datum_id: student.id)
            # students in this course are given nicknames to bypass
            # initial cud edit redirect that occurs when no nickname is given
            cud = FactoryBot.create(:nicknamed_student, course: new_course, user: student)

            # asmt.update_latest_submissions_modulo_callback
            FactoryBot.create(:submission, version: 0,
                                           filename: filename, course_user_datum: cud,
                                           submitted_by: cud,
                                           assessment: asmt, dave: "asfs") do |submission|
              problems.each do |problem|
                FactoryBot.create(:score, score: problem.max_score, grader: @instructor_cud,
                                          problem: problem, released: true,
                                          submission: submission)
              end
            end
            File.open(submission_path, 'w+') do |f|
              f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
            end
          end
          asmt.create_AUDs_modulo_callbacks
          asmt.update_latest_submissions_modulo_callbacks
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
