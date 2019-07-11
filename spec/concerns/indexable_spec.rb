require 'rails_helper'

describe "Indexable", vcr: true do
  subject  { create(:doi) }

  it 'send_message' do
    response = subject.send_message(subject.to_jsonapi)
    expect(response.message_id).to be_present
  end

  it 'send_import_message' do
    response = subject.send_import_message(subject.to_jsonapi)
    expect(response.message_id).to be_present
  end

  it 'send_delete_message' do
    response = subject.send_delete_message(subject.to_jsonapi)
    expect(response.message_id).to be_present
  end
end

describe "Indexable class methods", elasticsearch: true do
  context "client" do
    let!(:client) { create(:client) }

    before do
      Client.import
      sleep 1
    end

    it 'find_by_id' do
      result = Client.find_by_id(client.symbol).results.first
      expect(result.symbol).to eq(client.symbol)
    end

    it 'find_by_id multiple' do
      results = Client.find_by_id(client.symbol).results
      expect(results.total).to eq(1)
    end

    it 'query' do
      results = Client.query(client.name).results
      expect(results.total).to eq(1)
    end
  end

  context "provider" do
    let!(:provider) { create(:provider) }

    before do
      Provider.import
      sleep 1
    end

    it 'find_by_id' do
      result = Provider.find_by_id(provider.symbol).results.first
      expect(result.symbol).to eq(provider.symbol)
    end

    it 'find_by_id multiple' do
      results = Provider.find_by_id(provider.symbol).results
      expect(results.total).to eq(1)
    end

    it 'query' do
      results = Provider.query(provider.name).results
      expect(results.total).to eq(1)
    end
  end

  context "doi" do
    let!(:doi) { create(:doi, titles: { title: "Soil investigations" }, publisher: "Pangaea", descriptions: { description: "this is a description" }, aasm_state: "findable") }
    let!(:dois) { create_list(:doi, 3, aasm_state: "findable") }

    before do
      Doi.import
      sleep 1
    end

    # it 'find_by_id' do
    #   result = Doi.find_by_id(doi.doi).results.first
    #   expect(result.doi).to eq(doi.doi)
    # end

    it 'query by doi' do
      results = Doi.query(doi.doi).results
      expect(results.total).to eq(1)
    end

    it 'query by title' do
      results = Doi.query("soil").results
      expect(results.total).to eq(1)
    end

    it 'query by publisher' do
      results = Doi.query("pangaea").results
      expect(results.total).to eq(1)
    end

    it 'query by description' do
      results = Doi.query("description").results
      expect(results.total).to eq(1)
    end

    it 'query by description not found' do
      results = Doi.query("climate").results
      expect(results.total).to eq(0)
    end

    it 'query with cursor navigation' do
      results = Doi.query(nil, page: { size: 2, cursor: [] }).results
      expect(results.total).to eq(2)

      # Initial length should match the size
      expect(results.to_a.length).to eq(2)

      # Move onto next based on search_after
      results = Doi.query(nil, page: { size: 1, cursor: results.to_a.last[:sort] }).results
      expect(results.to_a.length).to eq(1)
    end
  end
end
