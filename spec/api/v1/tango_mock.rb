require Rails.root.join("config", "autogradeConfig.rb")

RSpec.shared_context "Tango Mock" do

  before(:each) do
    base_uri = "#{RESTFUL_HOST}:#{RESTFUL_PORT}"

    #------#
    # open #
    #------#
    open_uri = Addressable::Template.new "#{base_uri}/open/{key}/{courselab}"

    files = {}
    files["hello.c"] = SecureRandom.hex(32);
    files["Makefile"] = SecureRandom.hex(32);
    result = {statusId: 0,
              statusMsg: "Found directory",
              files: files}

    tango_stub_open = stub_request(:get, open_uri).
                      to_return(status: 200, body: result.to_json)
  end

end