require_relative '20160912012308_add_custom_form_field_to_assessments'
require_relative '20160912012551_add_textfields_to_assessments'
require_relative '20160912012406_add_languages_to_assessments'
require_relative '20160912012512_add_settings_to_submissions'

class RemoveCustomFormFieldFromAssessments < ActiveRecord::Migration[6.0]
  def change
    revert AddCustomFormFieldToAssessments
    revert AddTextfieldsToAssessments
    revert AddLanguagesToAssessments
    revert AddSettingsToSubmissions
  end
end
