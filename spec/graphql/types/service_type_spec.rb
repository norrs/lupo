require "rails_helper"

describe ServiceType do
  describe "fields" do
    subject { described_class }

    it { is_expected.to have_field(:id).of_type(!types.ID) }
    it { is_expected.to have_field(:type).of_type("String!") }
  end

  describe "query services", elasticsearch: true do
    let(:provider) { create(:provider, symbol: "DATACITE") }
    let(:client) { create(:client, symbol: "DATACITE.SERVICES", provider: provider) }
    let!(:services) { create_list(:doi, 3, aasm_state: "findable", client: client, 
      types: { "resourceTypeGeneral" => "Service" }, titles: [{ "title" => "Test Service"}], subjects:
      [{
        "subject": "FOS: Computer and information sciences",
        "schemeUri": "http://www.oecd.org/science/inno/38235147.pdf",
        "subjectScheme": "Fields of Science and Technology (FOS)"
      },
      {
        "subject": "Instrument",
        "subjectScheme": "PidEntity"
      }])
    }

    before do
      Provider.import
      Client.import
      Doi.import
      sleep 3
    end

    let(:query) do
      %(query {
        services(pidEntity: "Instrument") {
          totalCount
          pageInfo {
            endCursor
            hasNextPage
          }
          years {
            id
            title
            count
          }
          pidEntities {
            id
            title
            count
          }
          fieldsOfScience {
            id
            title
            count
          }
          nodes {
            id
            doi
            identifiers {
              identifier
              identifierType
            }
            types {
              resourceTypeGeneral
            }
            titles {
              title
            },
            descriptions {
              description
              descriptionType
            }
          }
        }
      })
    end

    it "returns services" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "services", "totalCount")).to eq(3)
      expect(response.dig("data", "services", "pidEntities")).to eq([{"count"=>3, "id"=>"instrument", "title"=>"Instrument"}])
      expect(response.dig("data", "services", "fieldsOfScience")).to eq([{"count"=>3,
        "id"=>"computer_and_information_sciences",
        "title"=>"Computer and information sciences"}])
      expect(Base64.urlsafe_decode64(response.dig("data", "services", "pageInfo", "endCursor")).split(",", 2).last).to eq(services.last.uid)
      expect(response.dig("data", "services", "pageInfo", "hasNextPage")).to be false
      expect(response.dig("data", "services", "years")).to eq([{"count"=>3, "id"=>"2011", "title"=>"2011"}])
      expect(response.dig("data", "services", "nodes").length).to eq(3)

      service = response.dig("data", "services", "nodes", 0)
      expect(service.fetch("id")).to eq(services.first.identifier)
      expect(service.fetch("doi")).to eq(services.first.doi)
      expect(service.fetch("identifiers")).to eq([{"identifier"=>
        "Ollomo B, Durand P, Prugnolle F, Douzery EJP, Arnathau C, Nkoghe D, Leroy E, Renaud F (2009) A new malaria agent in African hominids. PLoS Pathogens 5(5): e1000446.",
        "identifierType"=>nil}])
      expect(service.fetch("types")).to eq("resourceTypeGeneral"=>"Service")
      expect(service.dig("titles", 0, "title")).to eq("Test Service")
      expect(service.dig("descriptions", 0, "description")).to eq("Data from: A new malaria agent in African hominids.")
    end
  end
end
