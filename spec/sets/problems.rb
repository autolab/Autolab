module Contexts
  module Problems
    def create_problems(num_problems: 3, assessment: nil)
      asmt = @assessment if assessment.nil?

      FactoryBot.create_list(:problem, num_problems, assessment_id: asmt.id)
    end

    def create_autograded_problem(assessment: nil)
      asmt = @assessment if assessment.nil?

      FactoryBot.create(:problem, assessment_id: asmt.id, name: "autograded")

      # copy over autograde configuration files from template
      autograde_makefile_template = Rails.root.join("templates/labtemplate/autograde-Makefile")
      autograde_tar_template = Rails.root.join("templates/labtemplate/autograde.tar")
      FileUtils.cp(autograde_makefile_template, path)
      FileUtils.cp(autograde_tar_template, path)

      FactoryBot.create(:autograder, assessment: asmt)
    end
  end
end
