class GithubIntegration < ApplicationRecord
  belongs_to :user

  # Returns the top 30 most recently pushed repos
  # Reasonably if a user wants to submit code, it should be among
  # the most recent repos updated...
  def repositories
    if not self.access_token
      return nil
    end

    client = Octokit::Client.new(:access_token => access_token)
    repos = client.repos({},
                         query: {
                           sort: "pushed",
                           per_page: 30,
                         })
    repos.map { |repo|
      { repo_name: repo[:full_name],
        clone_url: repo[:clone_url],
        default_branch: repo[:default_branch] }
    }
  end

  def is_connected
    self.access_token.present?
  end

  ##
  # Clones a repository, and returns location of the tarfile containing the repo
  #
  # repo_name is of the form user/repo
  # clone_url is of the form https://github.com/user/repo.git
  #
  def clone_repo(repo_name)
    client = Octokit::Client.new(:access_token => access_token)
    repo_info = client.repo(repo_name)
    clone_url = repo_info[:clone_url]

    if self.access_token.nil? or self.access_token.empty?
      raise "Account not connected to Github"
    end

    if not system("git --version")
      raise "git not installed on server - please contact your instructor"
    end

    clone_url.sub! "https://", "https://#{self.access_token}@"
    repo_name.gsub! "/", "-"

    # Slap on random 8 bytes at the end
    repo_unique_name = "#{repo_name}_#{(0...8).map { (65 + rand(26)).chr }.join}"
    tarfile_name = "#{repo_unique_name}.tgz"
    destination = "/tmp/#{repo_unique_name}"
    tarfile_dest = "/tmp/#{tarfile_name}"

    if not system *%W(git clone #{clone_url} #{destination})
      raise "Cloning repo failed"
    end

    # Change to repo dir
    Dir.chdir(destination) {
      # Create compressed tarball
      if not system *%W(tar -cvzf #{tarfile_dest} --exclude=.git .)
        raise "Creation of archive from Git submission failed"
      end
    }

    return tarfile_dest
  end

  ##
  # Revokes Github access token
  def revoke
    if self.access_token
      client = Octokit::Client.new(:client_id => Rails.configuration.x.github.client_id, :client_secret => Rails.configuration.x.github.client_secret)
      client.revoke_application_authorization(self.access_token)
    end
  end


  ##
  # Checks whether a valid Github client ID and secret is passed in
  # If so, current rate limit information is returned; else 
  # nil is returned
  def self.check_github_authorization
    client = Octokit::Client.new(:client_id => Rails.configuration.x.github.client_id, 
      :client_secret => Rails.configuration.x.github.client_secret)

    begin
      client.rate_limit!
    rescue
      return nil
    end
  end

  ##
  # Returns whether Autolab is connected to Github
  def self.connected
    not self.check_github_authorization.nil?
  end
end
