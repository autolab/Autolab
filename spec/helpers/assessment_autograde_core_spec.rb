require "rails_helper"

RSpec.describe AssessmentAutogradeCore do
  subject(:helper_instance) { Class.new { include AssessmentAutogradeCore }.new }

  let(:course) { instance_double("Course", name: "cs101") }
  let(:assessment) { instance_double("Assessment", name: "hw1", disable_network: false) }
  let(:upload_file_list) {
    [{ "remoteFile" => "remote.tar", "destFile" => "autograde/remote.tar" }]
  }
  let(:callback_url) { "https://example.com/callback" }
  let(:job_name) { "job-name" }
  let(:output_file) { "output.txt" }
  let(:instance_type) { nil }
  let(:use_access_key) { false }
  let(:access_key) { nil }
  let(:access_key_id) { nil }

  let(:autograder) do
    instance_double(
      "Autograder",
      autograde_image: "ubuntu",
      autograde_timeout: 90,
      instance_type:,
      use_access_key?: use_access_key,
      access_key:,
      access_key_id:
    )
  end

  let(:captured_payload) { JSON.parse(@captured_payload_json) }

  before do
    helper_instance.instance_variable_set(:@autograde_prop, autograder)
    allow(TangoClient).to receive(:addjob) do |_queue, payload|
      @captured_payload_json = payload
      { "jobId" => 1 }
    end
  end

  around do |example|
    original_flag = Rails.configuration.x.ec2_ssh
    Rails.configuration.x.ec2_ssh = ec2_enabled
    example.run
  ensure
    Rails.configuration.x.ec2_ssh = original_flag
  end

  def fire_request
    helper_instance.tango_add_job(course, assessment, upload_file_list,
                                  callback_url, job_name, output_file)
  end

  context "when EC2 SSH is disabled" do
    let(:ec2_enabled) { false }

    it "omits EC2-specific properties" do
      fire_request
      expect(captured_payload.keys).not_to include("ec2Vmms", "instanceType", "accessKey",
                                                   "accessKeyId")
    end
  end

  context "when EC2 SSH is enabled" do
    let(:ec2_enabled) { true }

    context "and no custom access key is used" do
      it "includes instance details but omits secrets" do
        fire_request
        expect(captured_payload["ec2Vmms"]).to eq(true)
        expect(captured_payload["instanceType"]).to eq("t3.micro")
        expect(captured_payload).not_to include("accessKey", "accessKeyId")
      end
    end

    context "and custom access keys are provided" do
      let(:use_access_key) { true }
      let(:instance_type) { "c5.large" }
      let(:access_key) { "secret_access_key" }
      let(:access_key_id) { "ABCDEFGHIJKLMNOP" }

      it "sends credentials alongside EC2 options" do
        fire_request
        expect(captured_payload["ec2Vmms"]).to eq(true)
        expect(captured_payload["instanceType"]).to eq("c5.large")
        expect(captured_payload["accessKey"]).to eq("secret_access_key")
        expect(captured_payload["accessKeyId"]).to eq("ABCDEFGHIJKLMNOP")
      end
    end
  end
end
