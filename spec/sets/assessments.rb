module Contexts
  module Assessments
    def create_assessment(asmt_name: "testassessment", course: @course)
      if asmt_name =~ /[^a-z0-9]/
        raise ArgumentError("Assessment name must contain only lowercase and digits")
      end

      path = Rails.root.join("courses/#{course.name}/#{asmt_name}")
      FileUtils.mkdir_p(path)
      # create assessment directory
      @assessment = FactoryBot.create(:assessment, name: asmt_name,
                                                   course:,
                                                   is_positive_grading: false) do |asmt|
        asmt.construct_default_config_file
        asmt.load_config_file
        assessment_handin_path = get_handin_path(asmt)
        FileUtils.mkdir_p(assessment_handin_path)
      end
    end
  end
end
