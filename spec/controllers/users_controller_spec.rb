require "rails_helper"

RSpec.describe UsersController, type: :controller do
  render_views

  describe "#index" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :index
        expect(response).to be_success
        expect(response.body).to match(/Users List/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders successfully" do
        get :index
        expect(response).to be_success
        expect(response.body).to match(/Users List/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :index
        expect(response).not_to be_success
        expect(response.body).not_to match(/Users List/m)
      end
    end
  end

  describe "#new" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :new
        expect(response).to be_success
        expect(response.body).to match(/New user/m)
      end
    end

    context "when user is Autolab instructor" do
      login_instructor
      it "renders successfully" do
        get :new
        expect(response).to be_success
        expect(response.body).to match(/New user/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders with failure" do
        get :new
        expect(response).not_to be_success
        expect(response.body).not_to match(/New user/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :new
        expect(response).not_to be_success
        expect(response.body).not_to match(/New user/m)
      end
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      it "renders successfully" do
        get :show, params: {id: u.id}
        expect(response).to be_success
        expect(response.body).to match(/Showing user/m)
      end
    end

    context "when user is Autolab normal user" do
      u = get_user
      login_as(u)
      it "renders successfully" do
        get :show, params: {id: u.id}
        expect(response).to be_success
        expect(response.body).to match(/Showing user/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :show, params: {id: 0}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Showing user/m)
      end
    end
  end
end
