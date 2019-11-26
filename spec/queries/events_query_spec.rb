# frozen_string_literal: true

require "rails_helper"

describe EventsQuery, elasticsearch: true do

  context "citation events" do
    let!(:event) { create(:event_for_datacite_related,  subj_id:"http://doi.org/10.0260/co.2004960.v2", obj_id:"http://doi.org/10.0260/co.2004960.v1") }
    let!(:event) { create_list(:event_for_datacite_related, 3, obj_id:"10.5061/dryad.47sd5/2", relation_type_id: "references") }
    let!(:copies) { create(:event_for_datacite_related,  subj_id:"http://doi.org/10.0260/co.2004960.v2", obj_id:"http://doi.org/10.0260/co.2004960.v1", relation_type_id: "cites") }

    before do
      Event.import
      sleep 1
    end

    it "doi_citations" do
      expect(EventsQuery.new.doi_citations("10.0260/co.2004960.v1")).to eq(1)
    end

    it "doi_citations wiht 0 citations" do
      expect(EventsQuery.new.doi_citations("10.5061/dryad.dd47sd5/1")).to eq(0)
    end

    it "citations" do
      results = EventsQuery.new.citations("10.5061/dryad.47sd5/1,10.5061/dryad.47sd5/2,10.0260/co.2004960.v1")
      citations = results.select { |item| item[:id] == "10.5061/dryad.47sd5/2" }.first
      no_citations = results.select { |item| item[:id] == "10.5061/dryad.47sd5/1" }.first
      expect(citations[:count]).to eq(3)
      expect(no_citations[:count]).to eq(0)
    end
  end
end