require "rails_helper"

RSpec.describe UnixGroupManager do
  before do
    allow(described_class).to receive_messages(
      delegate_enabled?: false,
      should_skip_operations?: true
    )
  end

  it "does not invoke Linux tools when adding group membership is disabled" do
    expect(Open3).not_to receive(:capture3)

    expect(described_class.add_user_to_group("autolab", "course")).to be(true)
  end

  it "does not invoke Linux tools when removing group membership is disabled" do
    expect(Open3).not_to receive(:capture3)

    expect(described_class.remove_user_from_group("autolab", "course")).to be(true)
  end
end
