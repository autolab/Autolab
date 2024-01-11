##
# Users are specific to a real-world person.  Each User is enrolled in a course using
# the CourseUserData join table.
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  devise :omniauthable, omniauth_providers: [:shibboleth, :google_oauth2]

  has_many :course_user_data, dependent: :destroy
  has_many :courses, through: :course_user_data
  has_many :authentications, dependent: :destroy
  has_one :github_integration

  trim_field :school
  validates :email, presence: true
  validate :first_or_last_name

  # check if user is instructor in any course
  def instructor?
    cuds = course_user_data

    cuds.each { |cud| return true if cud.instructor? }

    false
  end

  # check if self is instructor of a user
  def instructor_of?(user)
    cuds = course_user_data

    cuds.each do |cud|
      next unless cud.instructor?
      return true unless cud.course.course_user_data.where(user:).empty?
    end

    false
  end

  def full_name
    [first_name, last_name].reject(&:empty?).join(' ')
  end

  def full_name_with_email
    "#{full_name} (#{email})"
  end

  def display_name
    first_name.present? && last_name.present? ? full_name : email
  end

  def after_create
    COURSE_LOGGER.log("User CREATED #{email}: #{full_name}")
  end

  def after_update
    COURSE_LOGGER.log("User UPDATED #{email}: #{full_name}")
  end

  # Reset user fields with LDAP lookup
  def ldap_reset
    return unless email.include? "@andrew.cmu.edu"

    ldap_result = User.ldap_lookup(email.split("@")[0])
    if ldap_result
      self.first_name = ldap_result[:first_name]
      self.last_name = ldap_result[:last_name]
      self.school = ldap_result[:school]
      self.major = ldap_result[:major]
      self.year = ldap_result[:year]
    end

    # If LDAP lookup failed, use (blank) as place holder
    self.first_name = "(blank)" if first_name.nil?
    self.last_name = "(blank)" if last_name.nil?

    save
  end

  def self.find_for_facebook_oauth(auth, _signed_in_resource = nil)
    authentication = Authentication.find_by(provider: auth.provider,
                                            uid: auth.uid)
    authentication.user if authentication&.user
  end

  def self.find_for_google_oauth2_oauth(auth, _signed_in_resource = nil)
    authentication = Authentication.find_by(provider: auth.provider,
                                            uid: auth.uid)
    authentication.user if authentication&.user
  end

  def self.find_for_shibboleth_oauth(auth, _signed_in_resource = nil)
    authentication = Authentication.find_by(provider: "CMU-Shibboleth",
                                            uid: auth.uid)
    authentication.user if authentication&.user
  end

  def self.assign_random_password(user)
    return if user.nil?

    temp_pass = Devise.friendly_token[0, 20] # generate a random token
    user.password = temp_pass
    user.password_confirmation = temp_pass
    user.skip_confirmation!
    user.save!
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if (data = session["devise.facebook_data"])
        user.first_name = data["info"]["first_name"]
        user.last_name = data["info"]["last_name"]
        user.email = data["info"]["email"]
        User.assign_random_password user
        User.add_oauth_if_user_exists session
      elsif (data = session["devise.google_oauth2_data"])
        user.first_name = data["info"]["first_name"]
        user.last_name = data["info"]["last_name"]
        user.email = data["info"]["email"]
        User.assign_random_password user
        User.add_oauth_if_user_exists session
      elsif (data = session["devise.shibboleth_data"])
        user.email = data["uid"] # email is uid in our case
        User.assign_random_password user
        User.add_oauth_if_user_exists session
      end
    end
  end

  def self.add_oauth_if_user_exists(session)
    email, provider, uid = "", "", ""
    if (data = session["devise.facebook_data"])
      email = data["info"]["email"]
      provider = data["provider"]
      uid = data["uid"]
    elsif (data = session["devise.google_oauth2_data"])
      email = data["info"]["email"]
      provider = data["provider"]
      uid = data["uid"]
    elsif (data = session["devise.shibboleth_data"])
      email = data["uid"] # email is uid in our case
      provider = "CMU-Shibboleth"
      uid = data["uid"]
    end

    user = User.find_by(email:)
    return if user.nil?

    user.authentications.new(provider:, uid:)
    user.skip_confirmation!
    user.save!

    user
  end

  # user created by roster
  def self.roster_create(email, first_name, last_name, school, major, year)
    auth = Authentication.new
    auth.provider = "CMU-Shibboleth"
    auth.uid = email
    auth.save!

    user = User.new
    user.email = email
    user.first_name = first_name
    user.last_name = last_name
    user.school = school
    user.major = major
    user.year = year
    user.authentications << auth

    User.assign_random_password user

    user.save!
    user
  end

  # user (instructor) created by building a course
  def self.instructor_create(email, course_name)
    user = User.new
    user.email = email
    user.first_name = "Instructor"
    user.last_name = course_name

    User.assign_random_password user

    user.send_reset_password_instructions
    user
  end

  # list courses of a user
  # list all courses if he's an admin
  def self.courses_for_user(user)
    if user.administrator?
      Course.order("display_name ASC")
    else
      user.courses.order("display_name ASC")
    end
  end

  # use LDAP to look up a user
  def self.ldap_lookup(andrew_id)
    return unless andrew_id

    require "rubygems"
    require "net/ldap"

    host = "ldap.cmu.edu"
    ldap = Net::LDAP.new(host:, port: 389)

    user = ldap.search(base: "uid=#{andrew_id},ou=AndrewPerson,dc=andrew,dc=cmu,dc=edu")[0]

    return unless user

    # Create result hash and parse ldap response
    result = {}
    result[:first_name] = user[:givenname][-1]
    result[:last_name] = user[:sn][-1]
    result[:major] = case user[:cmudepartment][0]
                     when "Architecture" then "ARC"
                     when "Computational Biology" then "CB"
                     when "Computer Science and Arts" then "BCA"
                     when "Computer Science Department" then "CSD"
                     when "HCII: Human Computer Interaction Institute" then "HCI"
                     when "Humanities and Arts" then "BHA"
                     when "General CIT" then "C00"
                     when "Civil & Environmental Engineering" then "CEE"
                     when "Chemical Engineering" then "CHE"
                     when "Computer Science" then "CS"
                     when "Electrical & Computer Engineering" then "ECE"
                     when "Entertainment Technology Pittsburgh" then "ETC"
                     when "Economics" then "ECO"
                     when "History" then "HIS"
                     when "H&SS Interdisciplinary" then "HSS"
                     when "Information Networking Institute" then "INI"
                     when "Institute for Software Research" then "ISR"
                     when "Information Systems:Sch of IS & Mgt" then "ISM"
                     when "Mechanical Engineering" then "MEG"
                     when "Mathematical Sciences" then "MSC"
                     when "General MCS" then "M00"
                     when "Software Engineering" then "SE"
                     when "Science and Humanities Scholars" then "SHS"
                     when "Business Administration" then "BA"
                     when "Machine Learning" then "ML"
                     when "NREC: National Robotics Engineering Center" then "Robotics"
                     else user[:cmudepartment][0]
                     end

    result[:year] = case user[:cmustudentclass][0]
                    when "Freshman" then "1"
                    when "First-Year student" then "1"
                    when "First-Year Student" then "1"
                    when "Sophomore" then "2"
                    when "Junior" then "3"
                    when "Senior" then "4"
                    when "Masters" then "10"
                    else user[:cmustudentclass][0]
                    end

    # There is no consistent pattern about where the college name is
    # within the eduPrsonSchoolCollegeName record, so we iterate through
    # them until we find something.  Per Chaos "I remember it being that
    # hard."
    user[:edupersonschoolcollegename].each do |college|
      result[:school] = case college
                        when "College of Fine Arts" then "CFA"
                        when "Carnegie Institute of Technology" then "CIT"
                        when "Carnegie Mellon University" then "CMU"
                        when "School of Computer Science" then "SCS"
                        when "SCS - SCH of Computer Science" then "SCS"
                        when "H. John Heinz III College" then "HC"
                        when "College of Humanities and Social Sciences" then "HSS"
                        when "Mellon College of Science" then "MCS"
                        when "David A. Tepper School of Business" then "TSB"
                        else college
                        end

      # Break as soon as we find the correct record.
      break if result[:school]
    end

    # If nothing matches, we fall back to the first record
    result[:school] ||= user[:edupersonschoolcollegename][0]

    result
  end

private

  def first_or_last_name
    return if first_name.present? || last_name.present?

    errors.add(:first_name, "First name and last name can't both be blank")
    errors.add(:last_name, "First name and last name can't both be blank")
  end
end
