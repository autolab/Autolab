require "rails_helper"

RSpec.describe Autograder, type: :model do
  subject(:autograder) { build(:autograder) }

  describe "validations" do
    it "rejects invalid instance types" do
      autograder.instance_type = "invalid-type"

      expect(autograder).not_to be_valid
      expect(autograder.errors[:instance_type]).to include("is not included in the list")
    end

    it "allows listed instance types" do
      autograder.instance_type = Autograder::INSTANCE_TYPES.sample

      expect(autograder).to be_valid
    end

    context "when access keys are enabled" do
      before do
        autograder.use_access_key = true
        autograder.access_key = nil
        autograder.access_key_id = "SHORT"
      end

      it "requires secrets" do
        expect(autograder).not_to be_valid
        expect(autograder.errors[:access_key]).to include("can't be blank")
        expect(autograder.errors[:access_key_id]).to include("looks invalid")
      end
    end

    context "when access keys are disabled" do
      it "does not require secrets" do
        autograder.use_access_key = false
        autograder.access_key = nil
        autograder.access_key_id = nil

        expect(autograder).to be_valid
      end
    end
  end
end
