require 'rails_helper'
require 'fileutils'

RSpec.describe SchedulersController, :type => :controller do

  render_views

  before(:suite) {
    Scheduler.delete_all
  }

  after(:suite) {
    Scheduler.delete_all
  }

  describe "#index" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :index, {:course_id => cid}
        expect(response).to be_success
        expect(response.body).to match(/Manage Schedulers/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :index, {:course_id => cid}
        expect(response).to be_success
        expect(response.body).to match(/Manage Schedulers/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders with failure" do
        get :index, {:course_id => cid}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Manage Schedulers/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :index, {:course_id => 1}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Manage Schedulers/m)
      end
    end
  end

  describe "#new" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :new, {:course_id => cid}
        expect(response).to be_success
        expect(response.body).to match(/New scheduler/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :new, {:course_id => cid}
        expect(response).to be_success
        expect(response.body).to match(/New scheduler/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders with failure" do
        get :new, {:course_id => cid}
        expect(response).not_to be_success
        expect(response.body).not_to match(/New scheduler/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :new, {:course_id => 1}
        expect(response).not_to be_success
        expect(response.body).not_to match(/New scheduler/m)
      end
    end
  end

  describe "#edit" do

    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :edit, {:course_id => cid, :id => s.id}
        expect(response).to be_success
        expect(response.body).to match(/Editing scheduler/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :edit, {:course_id => cid, :id => s.id}
        expect(response).to be_success
        expect(response.body).to match(/Editing scheduler/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :edit, {:course_id => cid, :id => s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Editing scheduler/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :edit, {:course_id => 1, :id => s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Editing scheduler/m)
      end
    end
  end

  describe "#show" do

    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :show, {:course_id => cid, :id => s.id}
        expect(response).to be_success
        expect(response.body).to match(/Action:/m)
        expect(response.body).to match(/Interval:/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :show, {:course_id => cid, :id => s.id}
        expect(response).to be_success
        expect(response.body).to match(/Action:/m)
        expect(response.body).to match(/Interval:/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :show, {:course_id => cid, :id => s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Action:/m)
        expect(response.body).not_to match(/Interval:/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :show, {:course_id => 1, :id => s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Action:/m)
        expect(response.body).not_to match(/Interval:/m)
      end
    end
  end
end
