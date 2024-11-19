class GithubIntegration < ApplicationRecord
  belongs_to :user
  has_encrypted :access_token

  # Returns the top 30 most recently pushed repos
  # Reasonably if a user wants to submit code, it should be among
  # the most recent repos updated...
  def repositories
    if !access_token
      return nil
    end

    client = Octokit::Client.new(access_token:)

    begin
      repos = client.repos({},
                           query: {
                             sort: "pushed",
                             per_page: 30,
                           })
      repos.map { |repo|
        { repo_name: repo[:full_name],
          clone_url: repo[:clone_url] }
      }
    rescue StandardError => e
      if e.response_status == 401 # unauthorized
        # User revoked permissions via Github UI, destroy it
        destroy!
      end
      nil
    end
  end

  # Returns all the branches for a repository
  # repo should be of the form `github_user/repo_name`
  def branches(repo)
    if !access_token
      return nil
    end

    client = Octokit::Client.new(access_token:)
    branches = client.branches(repo, query: { per_page: 100 })
    branches.map { |branch|
      { name: branch[:name] }
    }
  end

  # Returns all the commits for a branch
  # repo should be of the form `github_user/repo_name`
  def commits(repo, branch)
    if !access_token
      return nil
    end

    client = Octokit::Client.new(access_token:)
    commits = client.commits(repo, query: { per_page: 100, sha: branch })
    commits.map { |commit|
      { sha: commit[:sha].truncate(7, omission: ""),
        msg: commit[:commit][:message].truncate(72) }
    }
  end

  def is_connected
    access_token.present?
  end

  ##
  # Clones a repository, and returns location of the tarfile containing the repo
  #
  # repo_name is of the form user/repo
  # repo_branch should be a valid branch of repo_name
  # max_size is in MB
  def clone_repo(repo_name, repo_branch, commit, max_size)
    client = Octokit::Client.new(access_token:)
    repo_info = client.repo(repo_name)

    if !repo_info
      raise "Querying repository information failed"
    end

    clone_url = repo_info[:clone_url]

    if repo_info[:size] * 1000 > max_size
      raise "Repository size too large, please ensure that you are "\
            "not checking in unnecessary files"
    end

    if access_token.nil? || access_token.empty?
      raise "Account not connected to Github"
    end

    if !system("git --version")
      raise "git not installed on server - please contact your instructor"
    end

    clone_url.sub! "https://", "https://#{access_token}@"
    repo_name.gsub! "/", "-"

    if !check_allowed_chars(repo_name) || !check_allowed_chars(repo_branch) ||
       !check_allowed_chars(commit)
      raise "Bad repository name / branch / commit"
    end

    # Slap on random 8 bytes at the end
    repo_unique_name = "#{repo_name}_#{(0...8).map { rand(65..90).chr }.join}"
    tarfile_name = "#{repo_unique_name}.tgz"
    destination = "/tmp/#{repo_unique_name}"
    tarfile_dest = "/tmp/#{tarfile_name}"

    # depth should match the per_page limit in commits()
    if !system(*%W(git clone --depth=100 --branch #{repo_branch} #{clone_url} #{destination}))
      raise "Cloning repo failed"
    end

    # Change to repo dir
    Dir.chdir(destination) {
      # Checkout commit
      if !system(*%W(git checkout #{commit}))
        raise "Checkout of commit failed"
      end

      # Create compressed tarball
      if !system(*%W(tar -cvzf #{tarfile_dest} --exclude=.git .))
        raise "Creation of archive from Git submission failed"
      end
    }

    # Clean
    if !system(*%W(rm -rf #{destination}))
      raise "Cleaning temporary files failed"
    end

    tarfile_dest
  end

  ##
  # Revokes Github access token
  def revoke
    return if !access_token

    client = Octokit::Client.new(client_id: Rails.configuration.x.github.client_id,
                                 client_secret: Rails.configuration.x.github.client_secret)
    client.revoke_application_authorization(access_token)
  end

  ##
  # Checks whether a valid Github client ID and secret is passed in
  # If so, current rate limit should be in the order of thousands;
  # else it is 60 (as of June 2022)
  def self.check_github_authorization
    client = Octokit::Client.new(client_id: Rails.configuration.x.github.client_id,
                                 client_secret: Rails.configuration.x.github.client_secret)

    begin
      limit = client.rate_limit!
    rescue StandardError
      limit = ActiveSupport::OrderedOptions.new
      limit.limit = 0
    end
    limit
  end

  ##
  # Returns whether Autolab is connected to Github
  def self.connected
    check_github_authorization.limit > 1000
  end

private

  ALLOWED_CHARS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + ['.', '-']

  def check_allowed_chars(user_input)
    user_input.each_char { |c|
      if !ALLOWED_CHARS.include?(c)
        return false
      end
    }
    true
  end
end
