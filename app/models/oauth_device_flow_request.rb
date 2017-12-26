class OauthDeviceFlowRequest < ActiveRecord::Base
  belongs_to :oauth_application

  validates_uniqueness_of :device_code,     on: :create
  validates_uniqueness_of :user_code,       on: :create
  validates_presence_of :requested_at,      on: :create
  validates_associated :oauth_application,  on: :create

  # disallow others from instantiating requests on their own
  private_class_method :new, :create

  # app is a Doorkeeper::Application
  def self.create_request(app)
    device_code = self.gen_device_code
    user_code = self.gen_user_code

    # this loop is not expected to run for more than one iteration
    for iter in 0..2
      req = new(application_id: app.id,
                scopes: app.scopes,
                requested_at: Time.now,
                device_code: device_code,
                user_code: user_code)
      if req.save
        # success!
        return req
      elsif self.uniqueness_failed(req, :device_code)
        device_code = gen_device_code
      elsif self.uniqueness_failed(req, :user_code)
        user_code = gen_user_code
      else
        # unknown problem
        return nil
      end
    end

    # if for some reason we ran more than 3 times, return error
    return nil
  end


private

  def self.gen_device_code
    SecureRandom.hex(32)
  end

  def self.gen_user_code
    char_options = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
    (0...6).map { char_options[SecureRandom.random_number(char_options.length)] }.join
  end

  def self.uniqueness_failed(req, attr)
    req.errors[attr].first == "has already been taken"
  end

end