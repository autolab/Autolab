namespace :user do
  task :fix_auds => :environment do
    AssessmentUserDatum.find_each do |aud|
      puts aud.update_latest_submission
    end
  end

  task :clear_cache => :environment do
    Rails.cache.clear
  end

  task :cleanup_cache => :environment do
    Rails.cache.cleanup
  end
end

