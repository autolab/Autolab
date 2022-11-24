namespace :admin do
  desc "Promote a user to the admin level"
  task :promote_user, [:email] => [:environment] do |t, args|
    unless args.email
      puts "Which user did you want to promote?"
      next
    end

    u = User.where(email: args.email).first
    u.administrator = true
    u.save!

    puts "Successfully promoted user with email #{args.email} to admin level."
  end
  
  desc "Confirm a user's email address manually"
  task :confirm_email, [:email] => [:environment] do |t, args|
    unless args.email
      puts "Which email did you want to confirm?"
      next
    end
    
    u = User.where(email: args.email).first
    u.confirm!
    
    puts "Successfully confirmed user with email #{args.email}"
  end

  desc "Create a new root user"
  task :create_root_user, [:email, :password, :first_name, :last_name] => [:environment] do |t, args|
    u = User.new(email: args.email, first_name: args.first_name, last_name: args.last_name, password: args.password, administrator: true, school: "My School", major: "CS", year: "4")
    u.skip_confirmation!
    u.save!
    puts "Successfully created root user with email #{args.email}"
  end

  desc "Create a new user"
  task :create_user, [:email, :password, :first_name, :last_name] => [:environment] do |t, args|
    u = User.new(email: args.email, first_name: args.first_name, last_name: args.last_name, password: args.password, administrator: false, school: "My School", major: "CS", year: "4")
    u.skip_confirmation!
    u.save!
    puts "Successfully created user with email #{args.email}"
  end

end
