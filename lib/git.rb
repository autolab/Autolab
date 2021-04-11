module Git
  FORBIDDEN_BRANCHES = ["main", "master"]
  FORBIDDEN_CHARS = [';', '&', '|', '`', '\"', '\'', '{', '}', '(', ')']

  def self.sanitize_cmd(cmd)
    # Strip dangerous stuff
    for badchar in FORBIDDEN_CHARS
      cmd.tr(badchar, '')
    end
    return cmd
  end


  ##
  # Clones a repository, and returns location of the tarfile containing the repo
  #
  def self.clone_repo(git_key, git_username, classroom_name, assignment_name, 
        student_name, commit_hash)
    if git_key.blank? or classroom_name.blank? or assignment_name.blank?
      flash[:error] = "Git integration misconfigured - please contact your instructor"
      redirect_to(action: :show)
      return
    end

    student_name.squish!
    commit_hash.squish!

    if student_name.blank? or commit_hash.blank?
      flash[:error] = "Invalid Git username/hash provided"
      redirect_to(action: :show)
    end

    # Avoid guessing other people's branch names
    if FORBIDDEN_BRANCHES.include?(commit_hash)
      flash[:error] = "Please specify a valid commit hash"
      redirect_to(action: :show)
    end

    repo_name = "#{assignment_name}-#{student_name}"

    # Slap on random 8 bytes at the end
    repo_unique_name = "#{repo_name}_#{(0...8).map { (65 + rand(26)).chr }.join}"
    tarfile_name = "#{repo_unique_name}.tgz"
    destination = "/tmp/#{repo_unique_name}"
    tarfile_dest = "/tmp/#{tarfile_name}"

    # TODO look at
    # https://stackoverflow.com/questions/4650636/forming-sanitary-shell-commands-or-system-calls-in-ruby
    # and make call go to execve of base command directly
    clone_cmd = "git clone https://#{git_username}:#{git_key}@github.com/#{classroom_name}/#{repo_name} #{destination}"
    commit_cmd = "cd #{destination} && git checkout #{commit_hash}"
    tar_cmd = "tar --exclude='./git' -cvzf #{tarfile_dest} #{destination}/*"


    clone_cmd = sanitize_cmd(clone_cmd)
    commit_cmd= sanitize_cmd(commit_cmd)
    tar_cmd= sanitize_cmd(tar_cmd)


    if not system(clone_cmd) 
      flash[:error] = "Cloning repo failed"
      redirect_to(action: :show)
    end

    # Ensure that valid commit was given 
    if not system(commit_cmd) 
      flash[:error] = "Bad commit hash provided"
      redirect_to(action: :show)
    end

    # Create compressed tarball
    if not system(tar_cmd) 
      flash[:error] = "Creation of archive failed"
      redirect_to(action: :show)
    end

    return tarfile_dest 
   end
end