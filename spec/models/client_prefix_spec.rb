require 'rails_helper'

describe ClientPrefix, type: :model do
  let(:provider) { create(:provider) }
  let(:client) { create(:client, provider: provider) }
  let(:prefix) { create(:prefix, uid: "10.5083") }
  let(:provider_prefix) { create(:provider_prefix, prefix: prefix, provider: provider) }
  subject { create(:client_prefix, client: client, prefix: prefix, provider_prefix: provider_prefix) }

  describe "Validations" do
    it { should validate_presence_of(:client) }
    it { should validate_presence_of(:prefix) }
    it { should validate_presence_of(:provider_prefix) }
  end

  describe "methods" do
    it "is valid" do
      expect(subject.client.name).to eq("My data center")
      expect(subject.prefix.uid).to eq("10.5083")
    end
  end
end
