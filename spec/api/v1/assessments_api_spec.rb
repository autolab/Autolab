require 'rails_helper'
require_relative "api_shared_context"
require_relative "tango_mock"

RSpec.describe Api::V1::AssessmentsController, type: :controller do
  describe 'GET #index' do
    include_context "api shared context"

    it 'fails scope test' do
      get :index, params: { access_token: user_info_token.token, course_name: course.name }
      expect(response.response_code).to eq(403)
    end

    it 'fails to find the course' do
      get :index, params: { access_token: token.token, course_name: 8.times.map {
                                                                      rand(65..90).chr
                                                                    }.join } # random course name
      expect(response.response_code).to eq(404)
    end

    it 'returns all the released assessments of a course' do
      get :index, params: { access_token: token.token, course_name: course.name }
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg.length).to eq(course.assessments.released.count)
    end
  end

  describe 'POST #submit' do
    include_context "tango mock"
    include_context "api handin context"

    it 'fails scope test' do
      subm = {}
      subm['file'] = @handin_file
      post :submit,
           params: { access_token: bad_token.token, course_name: @ap_course.name,
                     assessment_name: @adder_asm.name, submission: subm }
      expect(response.response_code).to eq(403)
      msg = JSON.parse(response.body)
      expect(msg).to include('error')
      expect(msg['error']).to include('scope')
    end

    it 'rejects invalid handin with no submission[file] param' do
      subm = {}
      post :submit,
           params: { access_token: token.token, course_name: @ap_course.name,
                     assessment_name: @adder_asm.name, submission: subm }
      expect(response.response_code).to eq(400)
      msg = JSON.parse(response.body)
      expect(msg).to include('error')
      expect(msg['error']).to include('parameter')
    end

    it 'accepts the handin' do
      # count number of submissions before
      sub_count = Submission.where(course_user_datum_id: @ap_cud.id,
                                   assessment: @adder_asm).count

      # perform submission
      subm = {}
      subm['file'] = @handin_file
      post :submit,
           params: { access_token: token.token, course_name: @ap_course.name,
                     assessment_name: @adder_asm.name, submission: subm }
      msg = JSON.parse(response.body)
      expect(response.response_code).to eq(200)
      expect(msg).to include('version')
      expect(msg['version']).to eq(sub_count + 1)

      # count submissions after
      sub_count_after = Submission.where(course_user_datum_id: @ap_cud.id,
                                         assessment: @adder_asm).count
      expect(sub_count_after - 1).to eq(sub_count)
    end
  end
end
