module Contexts
  module Users
    def create_users
      @admin_user = FactoryBot.create(:admin_user)
      @instructor_user = FactoryBot.create(:instructor_user)
      @course_assistant_user = FactoryBot.create(:ca_user)
      @students = FactoryBot.create_list(:user, 5)
    end
  end
end
