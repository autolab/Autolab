require 'rails_helper'

RSpec.describe "handin_form", type: :view do
  let(:assessment) { create(:assessment) }
  let(:aud) { create(:assessment_user_datum, assessment: assessment, past_due_at: true) }
  let(:grace_late_info) { "using 1 late day" } 

  before do
    assign(:aud, aud)
    allow(view).to receive(:grace_late_info).and_return(grace_late_info)
    render partial: "assessments/handin_form", locals: { f: ActionView::Helpers::FormBuilder.new(nil, nil, self, {}) }
  end

  it "renders the Submit Late button with a confirmation prompt" do
    expect(rendered).to have_selector("input[type='submit'][id='fake-submit']")
    expect(rendered).to have_selector("input[data-confirm='You are #{grace_late_info}. Are you sure you want to continue?']")
  end
end

