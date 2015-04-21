namespace :admin do
  desc ""
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
end
