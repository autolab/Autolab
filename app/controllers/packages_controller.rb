class PackagesController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  def search;
    prefix = params[:query].to_s.strip

    return render json: [] if prefix.blank?

    results = `apt-cache search '^#{prefix}'`.lines

    packages_names = results.map { |line| line.split.first }.uniq

    p packages_names

    render json: packages_names.take(25)
  end
end
