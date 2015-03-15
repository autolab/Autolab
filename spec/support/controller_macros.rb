module ControllerMacros
  def login_admin
    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:admin]
      admins = User.where(:administrator => true)
      sign_in admins.offset(rand(admins.count)).first
    end
  end

  def login_user
    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      admins = User.where(:administrator => false)
      sign_in admins.offset(rand(admins.count)).first
    end
  end
end

