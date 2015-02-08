require_relative "../ModuleBase.rb"

module Partners
  include ModuleBase

  def partnersModuleInstall
    UserModule.create(:name=>"Partners.2",:course_id=>@assessment.id)
    um = UserModule.load("Partners.2",@assessment.id)
    um.addColumn("partnerID",Integer)
  end

  def partner
    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2",@assessment.id)
    end
    
    #does this student have a partner already?
    currentPartner = @pModule.get("partnerID",@cud.id)

    puts "hey"
    puts currentPartner
    puts "current user"
    puts @cud.id

    @confirm = false
    if currentPartner then
      partnerConfirm = @pModule.get("partnerID",currentPartner)
      @partner = @course.course_user_data.find_cud_for_course(@course, currentPartner)
      if partnerConfirm == @cud.id then
        @confirm = true
      end
    else
      @partner = nil
    end

    render(:file=>"lib/modules/views/viewPartner.html.erb",
           :layout=>true)
  end
  
  def cancelRequest
    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2",@assessment.id)
    end
    currentPartner = @pModule.get("partnerID",@cud.id)	
    if currentPartner then
      confirmed = @pModule.get("partnerID", currentPartner)
      if confirmed then
        flash[:error] = "You must talk to an instructor to cancel a partnership once it has been confirmed."
      else
        @pModule.delete("partnerID",@cud.id)
      end
    else
      flash[:error] = "You have not made a partner request yet."
    end
    render(:file=>"lib/modules/views/viewPartner.html.erb",
           :layout=>true)
  end

  def setPartner
    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2",@assessment.id)
    end
    if params[:id] then
      # isAdmin = true
      # @cud = @course.course_user_data.find(params[:id])

      # should we assert that this person is an admin?
      # isn't this easily hacked?
    else
      isAdmin = false
    end
    #does this student have a partner already?
    currentPartner = @pModule.get("partnerID",@cud.id)

    COURSE_LOGGER.log("yolo")

    if currentPartner then
      redirect_to :action=>"partner" and return
    end
    if request.post? then

      COURSE_LOGGER.log("POST")

      if params[:partner] then
        if (params[:partner].to_s == @cud.email) then
          flash[:error] = "You cannot be your own partner."
          redirect_to :action=>"partner" and return
        end

        user = User.find_by(:email => params[:partner])
        if user then
          partner = @course.course_user_data.find_cud_for_course(@course, user)
        end

        #partner_cud = @course.course_user_data.where(:email => params[:partner]).first
        if partner then
          puts "partnery"
          COURSE_LOGGER.log("PARTNER FOUND")

          puts partner.id
          @pModule.put("partnerID",@cud.id,partner.id)
        else
          COURSE_LOGGER.log("NOT PARTNER")
          #puts partner.id
          flash[:error] = "User #{params[:partner]} does not exist in this class!"
        end
      end
    end
    if isAdmin then
      #redirect_to :action=>"adminPartners"
    else
      redirect_to :action=>"partner"
    end
  end

  def adminPartners
    if !(@cud.instructor?) then
     flash[:error] = "You are not authorized to view this page"
     redirect_to :action=>"error",:controller=>"home" and return
    end
    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2",@assessment.id)
    end
    @users = @course.course_user_data
    #.order("email ASC")

    @pairs = Array.new
    for u in @users do
      pair = Hash.new
      pair["user"] = u
      partner = @pModule.get("partnerID",u.id)

      if partner then
        pair["partner"] = @course.course_user_data.find_cud_for_course(@course, partner)
        if @pModule.get("partnerID",partner) == u.id then
          pair["partnerConfirmed"] = true
        else
          pair["partnerConfirmed"] = false
        end
      end

      @pairs.push(pair)
    end

    # Grab all assessments that also have the partners module
    assessments = @course.assessments
    @assessments = []
    for ass in assessments do
      if @assessment.id == ass.id then
        next
      end

      tempModule = UserModule.load("Partners.2", ass.id)
      if tempModule then
        @assessments << ass
      end
    end

    render(:file=>"lib/modules/views/adminPartners.html.erb",
           :layout=>true) and return
  end

  # this one will change later, when students can drop 
  # partners themselves
  def deletePartner 
    if !(@user.instructor?) then
      flash[:error] = "You are not authorized to view this page!"
      redirect_to :action=>"error",:controller=>"home" and return
    end
    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2",@assessment.id)
    end
    @user = @course.course_user_data.find(params[:id])
    @pModule.delete("partnerID",@user.id)
    redirect_to :action=>"adminPartners" and return
  end

  def importPartners
    unless @user.instructor?
      flash[:error] = "You are not authorized to perform this action"
      redirect_to :action=>"error", :controller=>"home" and return
    end
    assessment = @course.assessments.find(params[:importfrom])
    oldModule = UserModule.load("Partners.2",assessment.id)
    if !oldModule
      flash[:error] = "The partners module was not used in that " +
        "assessment!"
      redirect_to :action=>"adminPartners" and return
    end

    @pModule = UserModule.load("Partners.2",@assessment.id)
    if !@pModule then
      partnersModuleInstall()
      @pModule = UserModule.load("Partners.2", @assessment.id)
    end
    
    for user in @course.course_user_data do
      # When importing, clear all current entries
      if @pModule.get("partnerID", user.id) then
        @pModule.delete("partnerID", user.id)
      end

      # And then add the new ones!
      if oldModule.get("partnerID", user.id) then
        @pModule.put("partnerID", user.id, oldModule.get("partnerID", user.id))
      end
    end
    flash[:info] = "Partners were imported successfully"
    redirect_to :action=>"adminPartners" and return
  end

  protected

  # get the partner of a user if he has one
  def getPartner(user_cud)
    @pModule = UserModule.load("Partners.2", @assessment.id)
    return unless @pModule
    # @pModule.get returns a map of user_id => partner_id
    partner_map = @pModule.get("partnerID", user_cud)
    if partner_map then
      partner_id = partner_map[user_cud.id]
      return CourseUserDatum.find_cud_for_course(@course, partner_id) unless (partner_id.nil? || partner_id == 0)
    end
  end
  
  def partnersAfterAutograde(submission)
    partner_cud = getPartner(submission.course_user_datum)
    if partner_cud then

      pSubmission = Submission.create(:assessment_id=>@assessment.id,
                                      :course_user_datum_id=>partner_cud.id,
                                      :submitter_ip => request.remote_ip)

      path = File.join(Rails.root, "courses",
                       submission.course_user_datum.course.name,
                       submission.assessment.name,
                       submission.assessment.handin_directory,
                       submission.filename)

      pathMirror = File.join(Rails.root, "tmp", submission.filename)
      `cp #{path} #{pathMirror}`
      sub = { }
      sub["tar"] = pathMirror
      pSubmission.saveFile(sub)
      
      pSubmission.save

      return pSubmission
    end
  end

end	
