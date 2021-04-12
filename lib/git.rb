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
    if git_key.blank? or classroom_name.blank? or assignment_name.blank? then
      raise "Git integration misconfigured - please contact your instructor"
    end

    student_name.squish!
    commit_hash.squish!

    if student_name.blank? or commit_hash.blank? then
      raise "Invalid Git username/hash provided"
    end

    # Avoid guessing other people's branch names
    if FORBIDDEN_BRANCHES.include?(commit_hash) then
      raise "Please specify a valid commit hash"
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
    commit_cmd = "git checkout #{commit_hash}"
    tar_cmd = "tar --exclude='./git' -cvzf #{tarfile_dest} *"


    clone_cmd = sanitize_cmd(clone_cmd)
    commit_cmd= sanitize_cmd(commit_cmd)
    tar_cmd= sanitize_cmd(tar_cmd)


    if not system(clone_cmd) 
      raise "Cloning repo failed"
    end

    Dir.chdir(destination) {
      # Ensure that valid commit was given 
      if not system(commit_cmd) 
        raise "Bad commit hash provided"
      end

      # Create compressed tarball
      if not system(tar_cmd) 
        raise "Creation of archive from Git submission failed"
      end
    }

    return tarfile_dest 
   end
end