require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UserTest < ActiveSupport::TestCase
  def setup
    @course = FactoryGirl.build(:course)
  end

	test "nickname length" do	
		u = FactoryGirl.build(:user, :course => @course)
		u.nickname = "This nickname is way too long and should never be allowed on autolab"
    assert(!u.valid?, u.nickname)
	end

	test "trim usernames" do 
		u = FactoryGirl.create(:user, :first_name => "Hunter ", :course => @course)
		assert_equal(u.first_name, "Hunter")
  end

	test "sudo permissions" do 
    instructor = FactoryGirl.build(:instructor, :course => @course)
    student = FactoryGirl.build(:user, :course => @course)
		assert(instructor.can_sudo_to?(student))
		assert(!(student.can_sudo_to?(instructor)))
	end
end
