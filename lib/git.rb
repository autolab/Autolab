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

  def self.validate_git_un(un)
    not un.match(/^[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}$/i).nil?
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

    if student_name.blank? or not validate_git_un(student_name) or commit_hash.blank? then
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

    if not system("git --version") 
      raise "git not installed on system"
    end

    if not system *%W(git clone https://#{git_username}:#{git_key}@github.com/#{classroom_name}/#{repo_name} #{destination})
      raise "Cloning repo failed"
    end

    # Change to repo dir
    Dir.chdir(destination) {
      # Ensure that valid commit was given 
      if not system *%W(git checkout #{commit_hash})
        raise "Bad commit hash provided"
      end

      # Create compressed tarball
      if not system *%W(tar -cvzf #{tarfile_dest} --exclude=.git .)
        raise "Creation of archive from Git submission failed"
      end
    }

    return tarfile_dest 
   end
end