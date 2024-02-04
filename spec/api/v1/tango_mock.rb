require Rails.root.join("config/autogradeConfig.rb")

RSpec.shared_context "tango mock" do
  before :each do
    base_uri = "#{RESTFUL_HOST}:#{RESTFUL_PORT}"

    default_resp_header = { 'Content-Type' => 'application/json' }

    #------#
    # open #
    #------#
    open_uri = Addressable::Template.new "#{base_uri}/open/{key}/{courselab}/"

    files = {}
    files["hello.c"] = SecureRandom.hex(32);
    files["Makefile"] = SecureRandom.hex(32);
    open_result = { statusId: 0,
                    statusMsg: "Found directory",
                    files: }

    @tango_stub_open = stub_request(:get, open_uri).
                       to_return(status: 200, body: open_result.to_json,
                                 headers: default_resp_header)

    #--------#
    # upload #
    #--------#
    upload_uri = Addressable::Template.new "#{base_uri}/upload/{key}/{courselab}/"

    upload_result = { statusId: 0,
                      statusMsg: "Uploaded file" }

    @tango_stub_upload = stub_request(:post, upload_uri).
                         to_return(status: 200, body: upload_result.to_json,
                                   headers: default_resp_header)

    #--------#
    # addJob #
    #--------#
    addjob_uri = Addressable::Template.new "#{base_uri}/addJob/{key}/{courselab}/"

    addjob_result = { statusId: 0,
                      statusMsg: "Job added",
                      jobId: 42 }

    @tango_stub_addjob = stub_request(:post, addjob_uri).
                         to_return(status: 200, body: addjob_result.to_json,
                                   headers: default_resp_header)

    # Mock a tango callback when autograding is done
    # params:
    #  - course_name: name of course
    #  - asmt_name: name of assessment
    #  - dave: dave number of submission
    #  - sub_id: submission id
    #  - filename: name of fixture file to send back as feedback
    def mock_tango_callback(course_name, asmt_name, dave, sub_id, filename)
      feedback_file = fixture_file_upload(filename, 'text/plain')
      # rubocop:disable Layout/LineLength
      post "/courses/#{course_name}/assessments/#{asmt_name}/autograde_done?dave=#{dave}&submission_id=#{sub_id}",
           params: { file: feedback_file }
      # rubocop:enable Layout/LineLength
    end
  end

  after :each do
    remove_request_stub(@tango_stub_open)
    remove_request_stub(@tango_stub_upload)
    remove_request_stub(@tango_stub_addjob)
  end
end
