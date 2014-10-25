class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable
         
  devise :omniauthable, omniauth_providers: [:shibboleth]
  
  has_many :course_user_data, :dependent => :destroy
  has_many :courses, :through => :course_user_data
  has_many :authentications
  
  trim_field :school
  validates_presence_of :first_name, :last_name, :email

  
  def self.find_for_facebook_oauth(auth, signed_in_resource=nil)
    authentication = Authentication.where(provider: auth.provider, 
                                          uid: auth.uid).first
    if authentication && authentication.user
      return authentication.user
    end
  end
  
  def self.find_for_google_oauth2_oauth(auth, signed_in_resource=nil)
    authentication = Authentication.where(provider: auth.provider, 
                                          uid: auth.uid).first
    if authentication && authentication.user
      return authentication.user
    end
  end
  
  def self.find_for_shibboleth_oauth(auth, signed_in_resource=nil)
    authentication = Authentication.where(provider: "CMU-Shibboleth", 
                                          uid: auth.uid).first
    if authentication && authentication.user
      return authentication.user
    end
  end
  
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.facebook_data"]
        user.first_name = data["info"]["first_name"]
        user.last_name = data["info"]["last_name"]
        user.email = data["info"]["email"]
        user.authentications.new(provider: data["provider"],
                                 uid: data["uid"])
      elsif data = session["devise.google_oauth2_data"]
        user.first_name = data["info"]["first_name"]
        user.last_name = data["info"]["last_name"]
        user.email = data["info"]["email"]
        user.authentications.new(provider: data["provider"],
                                 uid: data["uid"])
      elsif data = session["devise.shibboleth_data"]
        user.email = data["uid"]  # email is uid in our case
        user.authentications.new(provider: "CMU-Shibboleth",
                                 uid: data["uid"])
      
      end
    end
  end
  
  # check if user is instructor in any course
  def self.instructor?
    cuds = course_user_data
    
    cuds.each do |cud|
      if cud.instructor?
        return true
      end
    end
    
    return false
  end
  
  # check if self is instructor of a user
  def self.instructor_of?(user)
    cuds = course_user_data
    
    cuds.each do |cud|
      if cud.instructor?
         if !cud.course.course_user_data.where(user: user).empty?
           return true
         end
      end
    end
    
    return false
  end

  def after_create
    COURSE_LOGGER.log("User CREATED #{self.email}:" +
      "{#{self.first_name},#{self.last_name}")
  end

  def after_update
    COURSE_LOGGER.log("User UPDATED #{self.email}:"+
      "{#{self.first_name},#{self.last_name}")
  end
  
  # user created by roster
  def self.roster_create(email, first_name, last_name)

    auth = Authentication.new
    auth.provider = "CMU-Shibboleth"
    auth.uid = email
    auth.save!

    user = User.new
    user.email = email
    user.first_name = first_name
    user.last_name = last_name
    user.authentications << auth

    temp_pass = Devise.friendly_token[0, 20]    # generate a random token
    user.password = temp_pass
    user.password_confirmation = temp_pass
    user.skip_confirmation!

    if (user.save) then
        #user.send_reset_password_instructions
        return user
    else
        return nil 
    end
  end
  
  # user (instructor) created by building a course
  def self.instructor_create(email, course_name)
    user = User.new
    user.email = email
    user.first_name = "Instructor"
    user.last_name = course_name

    temp_pass = Devise.friendly_token[0, 20]    # generate a random token
    user.password = temp_pass
    user.password_confirmation = temp_pass
    user.skip_confirmation!

    if (user.save) then
        user.send_reset_password_instructions
        return user
    else
        return nil 
    end
  end
  
  # list courses of a user
  # list all courses if he's an admin
  def self.courses_for_user(user)
    if user.administrator?
      return Course.all
    else
      return user.courses
    end
  end

  def full_name
    first_name + " " + last_name
  end

  def full_name_with_email
    first_name + " " + last_name + " (" + email + ")"
  end

  def display_name
    if first_name and last_name then
      full_name
    else
      email
    end
  end
end
