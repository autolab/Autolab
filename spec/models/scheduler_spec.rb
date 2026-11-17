require "rails_helper"

RSpec.describe Scheduler, type: :model do
  it "requires an expiration time" do
    scheduler = described_class.new(until: nil)

    expect(scheduler).not_to be_valid
    expect(scheduler.errors[:until]).to include("can't be blank")
  end
end
