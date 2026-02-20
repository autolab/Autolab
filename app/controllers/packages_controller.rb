require "shellwords"

class PackagesController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  def search;
    prefix = params[:query].to_s.strip

    return render json: [] if prefix.blank?

    results = `apt-cache search '^#{prefix}'`.lines

    packages_names = results.map { |line| line.split.first }.uniq

    render json: packages_names.take(100)
  end

  def version_search;
    package = params[:package].to_s.strip

    results = `apt-cache madison #{Shellwords.escape(package)}`.lines

    versions = results.map do |line|
      line.split('|')[1]&.strip
    end.compact.uniq

    render json: versions.take(100)
  end
end
