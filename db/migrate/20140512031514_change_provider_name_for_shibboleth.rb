class ChangeProviderNameForShibboleth < ActiveRecord::Migration[4.2]
  # In migration 20131222162700_prepare_external_auth.rb, Shibboelth are
  # given provider name "CMU-Shibboleth" but it should just be "shibboleth"
  def up
    Authentication.find_each do |auth|
      if auth.provider == "CMU-Shibboleth" 
        auth.provider = "shibboleth"
        auth.save!
      end
    end
  end

  def down
    Authentication.find_each do |auth|
      if auth.provider == "shibboleth" 
        auth.provider = "CMU-Shibboleth"
        auth.save!
      end
    end
  end

end
