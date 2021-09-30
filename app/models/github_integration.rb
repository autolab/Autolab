class GithubIntegration < ApplicationRecord
  belongs_to :user

  def repositories
    client = Octokit::Client.new(:access_token => access_token)
    repos = client.repos()
    repos.map { |repo|  
      {full_name: repo[:full_name], 
        clone_url: repo[:clone_url]}
    }
  end
end