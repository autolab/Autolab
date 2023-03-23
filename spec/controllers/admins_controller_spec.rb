require "rails_helper"

RSpec.describe AdminsController, type: :controller do
  render_views

  describe "#email_instructors" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :email_instructors
        expect(response).to be_successful
        expect(response.body).to match(/From:/m)
        expect(response.body).to match(/Subject:/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders with failure" do
        get :email_instructors
        expect(response).not_to be_successful
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :email_instructors
        expect(response).not_to be_successful
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end
  end

  describe "#autolab_config" do
    describe "lti_config" do
      context "when user is Autolab admin" do
        user_id = get_admin
        login_as(user_id)
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
        user_id = get_instructor
        login_as(user_id)
        it "renders with failure" do
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end

      context "when user is student" do
        user_id = get_user
        login_as(user_id)
        it "renders with failure" do
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end

      context "when user is course assistant" do
        user_id = get_course_assistant_only
        login_as(user_id)
        it "renders with failure" do
          get :autolab_config, params: { active: :lti }
          expect(response).not_to be_successful
          expect(response.body).not_to match(/LTI Configuration Settings/m)
        end
      end
    end
  end
end
