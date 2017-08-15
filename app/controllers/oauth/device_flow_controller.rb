class Oauth::DeviceFlowController < ActionController::Base
  def init
    puts "INIT"
    render :json => {:msg => "got init"}.to_json
  end

  def authorize
    puts "AUTHORIZE"
    render :json => {:msg => "got authorize"}.to_json
  end
end