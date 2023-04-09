require "rails_helper"
require_relative "controllers_shared_context"

RSpec.describe AdminsController, type: :controller do
  render_views

  shared_examples "email_instructors_success" do
    it "renders successfully" do
      sign_in(user)
      get :email_instructors
      expect(response).to be_successful
      expect(response.body).to match(/From:/m)
      expect(response.body).to match(/Subject:/m)
    end
  end

  shared_examples "email_instructors_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :email_instructors
      expect(response).not_to be_successful
      expect(response.body).not_to match(/From:/m)
      expect(response.body).not_to match(/Subject:/m)
    end
  end

  describe "#email_instructors" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "email_instructors_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab normal user" do
      it_behaves_like "email_instructors_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "email_instructors_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "#autolab_config" do
    describe "lti_config" do
      include_context "controllers shared context"
      context "when user is Autolab admin" do
        let!(:user_id) { admin_user }
        before(:each) { sign_in(user_id) }
        it "renders successfully" do
          get :autolab_config, params: { active: :lti }
          expect(response).to be_successful
          expect(response.body).to match(/LTI Configuration Settings/m)
        end
        it "loads existing config correctly" do
          @lti_config_hash = YAML.safe_load(
            File.read("#{Rails.configuration.config_location}/lti_config_template.yml")
          )
          @lti_tool_jwk_file = Rack::Test::UploadedFile.new(
            "#{Rails.configuration.config_location}/lti_tool_jwk_template.json"
          )
          @lti_platform_jwk_file = Rack::Test::UploadedFile.new(
            "#{Rails.configuration.config_location}/lti_platform_jwk_template.json"
          )

          File.open("#{Rails.configuration.config_location}/lti_config.yml", "w") do |file|
            file.write(YAML.dump(@lti_config_hash.deep_stringify_keys))
          end
          get :autolab_config, params: { active: :lti }
          expect(response).to be_successful
          expect(response.body).to match(/LTI Configuration Settings/m)

          if File.exist?("#{Rails.configuration.config_location}/lti_config.yml")
            File.delete("#{Rails.configuration.config_location}/lti_config.yml")
          end
          if File.exist?("#{Rails.configuration.config_location}/lti_tool_jwk.json")
            File.delete("#{Rails.configuration.config_location}/lti_tool_jwk.json")
          end
          if File.exist?("#{Rails.configuration.config_location}/lti_platform_jwk.json")
            File.delete("#{Rails.configuration.config_location}/lti_platform_jwk.json")
          end
        end
      end

      context "when user is Instructor" do
        let!(:user_id) { instructor_user }
        it "renders with failure" do
          sign_in(user_id)
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end

      context "when user is student" do
        let!(:user_id) { student_user }
        it "renders with failure" do
          sign_in(user_id)
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end

      context "when user is course assistant" do
        let!(:user_id) { course_assistant_user }
        it "renders with failure" do
          sign_in(user_id)
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end
    end
  end
end
