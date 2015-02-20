require 'rails_helper'

RSpec.describe "groups/new", :type => :view do
  before(:each) do
    assign(:group, Group.new(
      :name => "MyString"
    ))
  end

  it "renders new group form" do
    render

    assert_select "form[action=?][method=?]", groups_path, "post" do

      assert_select "input#group_name[name=?]", "group[name]"
    end
  end
end
