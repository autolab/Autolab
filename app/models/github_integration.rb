class GithubIntegration < ApplicationRecord
  belongs_to :user

  # Returns the top 30 most recently pushed repos
  # Reasonably if a user wants to submit code, it should be among
  # the most recent repos updated...
  def repositories
    client = Octokit::Client.new(:access_token => access_token)
    repos = client.repos({},
      query: {
        sort:  "pushed",
        per_page:  30
      }
    )
    repos.map { |repo|  
      {full_name: repo[:full_name], 
        clone_url: repo[:clone_url],
        default_branch: repo[:default_branch],
      }
    }
  end
end