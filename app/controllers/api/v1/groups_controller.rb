class Api::V1::GroupsController < Api::V1::BaseApiController
  before_action -> { require_privilege :instructor_all }

  before_action :set_assessment

  # endpoint to obtain all groups
  def index
    show_members = params[:show_members].to_boolean
    groups = @assessment.groups(show_members: show_members)

    if show_members
      groups_json = []
      groups.each do |group|
        group_json = get_group_json(group)
        groups_json << group_json
      end
    else
      groups_json = groups.as_json
    end

    group_size = @assessment.group_size

    respond_with({ group_size: group_size,
                   groups: groups_json,
                   assessment: @assessment })
  end

  def show
    require_params([:id])
    group = @assessment.groups(show_members: true).find_by(id: params[:id])

    if group.nil?
      raise ApiError.new("Couldn't find group with id #{params[:id]}", :bad_request)
    end

    group_json = get_group_json(group)

    respond_with group_json
  end

  # create group endpoint
  def create
    require_params([:groups])

    if @assessment.group_size <= 1
      raise ApiError.new("Group size of assessment is currently 1,"\
                         " so you can't create group", :bad_request)
    end
    group_members = params[:groups].map{ |group| group["group_members"] }

    if !group_members&.select{ |list| list.length > @assessment.group_size }&.empty?
      raise ApiError.new("Cannot have groups with size more than group_size", :bad_request)
    end

    all_emails = params[:groups].map{ |group| group["group_members"] }.flatten.uniq
    all_cuds = @course.course_user_data.joins(:user).where(users: { email: all_emails })

    all_cud_ids = all_cuds.map(&:id)
    all_auds = @assessment.assessment_user_data.where(course_user_datum_id: all_cud_ids )

    email_to_cuds = all_cuds.map{ |cud| { cud.email => cud } }.reduce({}, :merge)
    cuds_to_auds =  all_auds.map{ |aud| { aud.course_user_datum_id => aud } }.reduce({}, :merge)

    params[:groups].each do |g|
      group = Group.new
      group.name = g["name"] || "Unnamed Group"
      count = 0
      g["group_members"].each do |group_member|
        aud = cuds_to_auds[email_to_cuds[group_member]&.id]
        next unless aud&.group_confirmed(AssessmentUserDatum::UNCONFIRMED)

        aud.group = group
        aud.membership_status = AssessmentUserDatum::CONFIRMED
        count += 1 if aud.save!
      end
      group.save! if count > 0
    end

    respond_with_hash(@assessment.groups)
  end

  # endpoint to delete groups
  def destroy
    require_params([:id])
    group = @assessment.groups.find_by(id: params[:id].to_i)
    if group.nil?
      raise ApiError.new("Couldn't find group #{params[:id]}", :bad_request)
    end

    ActiveRecord::Base.transaction do
      group.assessment_user_data.each do |aud|
        aud.group_id = nil
        aud.membership_status = AssessmentUserDatum::UNCONFIRMED
        aud.save!
      end
      group.destroy!
    end
    respond_with_hash(message: "Group #{params[:id]} successfully deleted")
  end

private

  def get_group_json(group)
    members = []
    group.assessment_user_data.each do |assessment_user_datum|
      user_json = assessment_user_datum.course_user_datum.user.as_json
      user_json[:course_user_datum_id] = assessment_user_datum.course_user_datum_id
      members << user_json
    end

    group_json = group.as_json
    group_json[:members] = members
  end
end
