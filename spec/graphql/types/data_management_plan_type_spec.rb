require "rails_helper"

describe DataManagementPlanType do
  describe "fields" do
    subject { described_class }

    it { is_expected.to have_field(:id).of_type(!types.ID) }
    it { is_expected.to have_field(:type).of_type("String!") }
  end

  describe "query data_management_plans", elasticsearch: true do
    let!(:data_management_plans) { create_list(:doi, 2, types: { "resourceTypeGeneral" => "Text", "resourceType" => "Data Management Plan" }, language: "de", aasm_state: "findable") }
    
    before do
      Doi.import
      sleep 2
      @dois = Doi.gql_query(nil, page: { cursor: [], size: 4 }).results.to_a
    end

    let(:query) do
      %(query {
        dataManagementPlans {
          totalCount
          registrationAgencies {
            id
            title
            count
          }
          licenses {
            id
            title
            count
          }
          languages {
            id
            title
            count
          }
          nodes {
            id
            registrationAgency {
              id
              name
            }
          }
        }
      })
    end

    it "returns all data_management_plans" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "dataManagementPlans", "totalCount")).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "languages")).to eq([{"count"=>2, "id"=>"de", "title"=>"German"}])
      expect(response.dig("data", "dataManagementPlans", "licenses")).to eq([{"count"=>2, "id"=>"cc0-1.0", "title"=>"CC0-1.0"}])
      expect(response.dig("data", "dataManagementPlans", "nodes").length).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "nodes", 0, "registrationAgency")).to eq("id"=>"datacite", "name"=>"DataCite")
    end
  end

  describe "query data_management_plans by language", elasticsearch: true do
    let!(:data_management_plans) { create_list(:doi, 2, types: { "resourceTypeGeneral" => "Text", "resourceType" => "Data Management Plan" }, language: "de", aasm_state: "findable") }
    
    before do
      Doi.import
      sleep 2
      @dois = Doi.gql_query(nil, page: { cursor: [], size: 4 }).results.to_a
    end

    let(:query) do
      %(query {
        dataManagementPlans(language: "de") {
          totalCount
          registrationAgencies {
            id
            title
            count
          }
          licenses {
            id
            title
            count
          }
          languages {
            id
            title
            count
          }
          nodes {
            id
            rights {
              rights
              rightsUri
              rightsIdentifier
            }
            language {
              id
              name
            }
            registrationAgency {
              id
              name
            }
          }
        }
      })
    end

    it "returns all data_management_plans" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "dataManagementPlans", "totalCount")).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "registrationAgencies")).to eq([{"count"=>2, "id"=>"datacite", "title"=>"DataCite"}])
      expect(response.dig("data", "dataManagementPlans", "licenses")).to eq([{"count"=>2, "id"=>"cc0-1.0", "title"=>"CC0-1.0"}])
      expect(response.dig("data", "dataManagementPlans", "nodes").length).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "nodes", 0, "rights")).to eq([{"rights"=>"Creative Commons Zero v1.0 Universal",
        "rightsIdentifier"=>"cc0-1.0",
        "rightsUri"=>"https://creativecommons.org/publicdomain/zero/1.0/legalcode"}])
      expect(response.dig("data", "dataManagementPlans", "nodes", 0, "registrationAgency")).to eq("id"=>"datacite", "name"=>"DataCite")
    end
  end

  describe "query data_management_plans by license", elasticsearch: true do
    let!(:data_management_plans) { create_list(:doi, 2, types: { "resourceTypeGeneral" => "Text", "resourceType" => "Data Management Plan" }, language: "de", aasm_state: "findable") }
    
    before do
      Doi.import
      sleep 2
      @dois = Doi.gql_query(nil, page: { cursor: [], size: 4 }).results.to_a
    end

    let(:query) do
      %(query {
        dataManagementPlans(license: "cc0-1.0") {
          totalCount
          registrationAgencies {
            id
            title
            count
          }
          languages {
            id
            title
            count
          }
          licenses {
            id
            title
            count
          }
          nodes {
            id
            registrationAgency {
              id
              name
            }
            language {
              id
              name
            }
            rights {
              rights
              rightsUri
              rightsIdentifier
            }
          }
        }
      })
    end

    it "returns all data_management_plans" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "dataManagementPlans", "totalCount")).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "registrationAgencies")).to eq([{"count"=>2, "id"=>"datacite", "title"=>"DataCite"}])
      expect(response.dig("data", "dataManagementPlans", "languages")).to eq([{"count"=>2, "id"=>"de", "title"=>"German"}])
      expect(response.dig("data", "dataManagementPlans", "nodes").length).to eq(2)
      expect(response.dig("data", "dataManagementPlans", "nodes", 0, "registrationAgency")).to eq("id"=>"datacite", "name"=>"DataCite")
    end
  end

  describe "query data_management_plans by person", elasticsearch: true do
    let!(:data_management_plans) { create_list(:doi, 3, types: { "resourceTypeGeneral" => "Text", "resourceType" => "Data Management Plan" }, aasm_state: "findable") }
    let!(:data_management_plan) { create(:doi, types: { "resourceTypeGeneral" => "Text", "resourceType" => "Data Management Plan" }, aasm_state: "findable", creators:
      [{
        "familyName" => "Garza",
        "givenName" => "Kristian",
        "name" => "Garza, Kristian",
        "nameIdentifiers" => [{"nameIdentifier"=>"https://orcid.org/0000-0003-3484-6875", "nameIdentifierScheme"=>"ORCID", "schemeUri"=>"https://orcid.org"}],
        "nameType" => "Personal",
      }])
    }
    before do
      Doi.import
      sleep 2
      @dois = Doi.gql_query(nil, page: { cursor: [], size: 4 }).results.to_a
    end

    let(:query) do
      %(query {
        dataManagementPlans(userId: "https://orcid.org/0000-0003-1419-2405") {
          totalCount
          published {
            id
            title
            count
          }
          nodes {
            id
          }
        }
      })
    end

    it "returns data_management_plans" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "dataManagementPlans", "totalCount")).to eq(3)
      expect(response.dig("data", "dataManagementPlans", "published")).to eq([{"count"=>3, "id"=>"2011", "title"=>"2011"}])
      expect(response.dig("data", "dataManagementPlans", "nodes").length).to eq(3)
    end
  end
end