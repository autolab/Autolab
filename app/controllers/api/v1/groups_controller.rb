class Api::V1::GroupsController < Api::V1::BaseApiController
  before_action -> { require_privilege :instructor_all }

  before_action :set_assessment

  # endpoint to obtain all groups
  def index
    groups = @assessment.groups
    group_size = @assessment.group_size
    respond_with({ group_size: group_size,
                   groups: groups,
                   assessment: @assessment,
                   grouplessCUDs: @assessment.grouplessCUDs })
  end

  # endpoint to create groups
  # {
  #  "groups" : [{
  #      "name": "hello",
  #      "group_members": [1,2,3]
  #  }]
  # }
  def create
    require_params([:groups])
    
    all_emails = params[:groups].map{ |group| group["group_members"] }.flatten.uniq
    all_cuds = @course.course_user_data.joins(:user).where(users: { email: all_emails })
    
    all_cud_ids = all_cuds.map(&:id)
    all_auds = @assessment.assessment_user_data.where(course_user_datum_id: all_cud_ids )

    email_to_cuds = all_cuds.map{ |cud| { cud.email => cud } }.reduce({}, :merge)
    cuds_to_auds =  all_auds.map{ |aud| { aud.course_user_datum_id => aud } }.reduce({}, :merge)
    
    params[:groups].each do |g|
      group = Group.new
      group.name = g["name"]
      count = 0
      g["group_members"].each do |group_member|
        aud = cuds_to_auds[email_to_cuds[group_member]&.id]
        puts(aud)
        next unless aud&.group_confirmed(AssessmentUserDatum::UNCONFIRMED)
        aud.group = group
        aud.membership_status = AssessmentUserDatum::GROUP_CONFIRMED
        count += 1 if aud.save!
      end
      group.save! if count > 0
    end

   respond_with_hash(@assessment.groups)
  end
end
