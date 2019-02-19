require 'rails_helper'

describe 'Clients', type: :request, elasticsearch: true do
  let(:ids) { clients.map { |c| c.uid }.join(",") }
  let(:bearer) { User.generate_token }
  let(:provider) { create(:provider, password_input: "12345") }
  let!(:client) { create(:client, provider: provider) }
  let(:params) do
    { "data" => { "type" => "clients",
                  "attributes" => {
                    "symbol" => provider.symbol + ".IMPERIAL",
                    "name" => "Imperial College",
                    "contactName" => "Madonna",
                    "contactEmail" => "bob@example.com"
                  },
                  "relationships": {
              			"provider": {
              				"data":{
              					"type": "providers",
              					"id": provider.symbol.downcase
              				}
              			}
              		}} }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + bearer}}
  let(:query) { "jamon"}

  describe 'GET /clients', elasticsearch: true do
    let!(:clients)  { create_list(:client, 3) }

    before do
      Client.import
      sleep 1
      get '/clients', headers: headers
    end

    it 'returns clients' do
      expect(json['data'].size).to eq(4)
      expect(json.dig('meta', 'total')).to eq(4)
    end

    it 'returns status code 200' do
      expect(response).to have_http_status(200)
    end
  end

  # # Test suite for GET /clients
  # describe 'GET /clients query' do
  #   before { get "/clients?query=#{query}", headers: headers }
  #
  #   it 'returns clients' do
  #     expect(json).not_to be_empty
  #     expect(json['data'].size).to eq(11)
  #   end
  #
  #   it 'returns status code 200' do
  #     expect(response).to have_http_status(200)
  #   end
  # end

  # describe 'GET /clients?ids=', elasticsearch: true do
  #   before do
  #     sleep 1
  #     get "/clients?ids=#{ids}", headers: headers
  #   end

  #   it 'returns clients' do
  #     expect(json).not_to be_empty
  #     expect(json['data'].size).to eq(10)
  #   end

  #   it 'returns status code 200' do
  #     expect(response).to have_http_status(200)
  #   end
  # end

  # Test suite for GET /clients/:id
  describe 'GET /clients/:id' do
    before { get "/clients/#{client.uid}", headers: headers }

    context 'when the record exists' do
      it 'returns the client' do
        expect(json.dig('data', 'attributes', 'name')).to eq(client.name)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when the record does not exist' do
      before { get "/clients/xxx", headers: headers }

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a not found message' do
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end

  describe 'POST /clients' do
    context 'when the request is valid' do
      before { post '/clients', params: params.to_json, headers: headers }
    
      it 'creates a client' do
        attributes = json.dig('data', 'attributes')
        expect(attributes["name"]).to eq("Imperial College")
        expect(attributes["contactName"]).to eq("Madonna")

        relationships = json.dig('data', 'relationships')
        expect(relationships.dig("provider", "data", "id")).to eq(provider.symbol.downcase)
      end
    
      it 'returns status code 201' do
        expect(response).to have_http_status(201)
      end
    end

    context 'when the request is invalid' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "symbol" => provider.symbol + ".IMPERIAL",
                        "name" => "Imperial College",
                        "contactName" => "Madonna"
                      },
                      "relationships": {
                  			"provider": {
                  				"data": {
                  					"type": "providers",
                  					"id": provider.symbol.downcase
                  				}
                  			}
                  		}} }
      end

      before { post '/clients', params: params.to_json, headers: headers }

      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end

      it 'returns a validation failure message' do
        expect(json["errors"]).to eq([{"source"=>"contact_email", "title"=>"Can't be blank"}, {"source"=>"contact_email", "title"=>"Is invalid"}])
      end
    end
  end

  describe 'PUT /clients/:id' do
    context 'when the record exists' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "name" => "Imperial College 2"}} }
      end
      before { put "/clients/#{client.symbol}", params: params.to_json, headers: headers }

      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College 2")
        expect(json.dig('data', 'attributes', 'name')).not_to eq(client.name)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'using basic auth', vcr: true do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "name" => "Imperial College 2"}} }
      end
      let(:credentials) { provider.encode_auth_param(username: provider.symbol.downcase, password: "12345") }
      let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Basic ' + credentials } }

      before { put "/clients/#{client.symbol}", params: params.to_json, headers: headers }

      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College 2")
        expect(json.dig('data', 'attributes', 'name')).not_to eq(client.name)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when the request is invalid' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "symbol" => client.symbol + "MegaCLient",
                        "email" => "bob@example.com",
                        "name" => "Imperial College"}} }
      end

      before { put "/clients/#{client.symbol}", params: params.to_json, headers: headers }

      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("source"=>"symbol", "title"=>"Cannot be changed")
      end
    end
  end

  describe 'DELETE /clients/:id' do
    before { delete "/clients/#{client.uid}", headers: headers }

    it 'returns status code 204' do
      expect(response).to have_http_status(204)
    end

    context 'when the resources doesnt exist' do
      before { delete '/clients/xxx', params: params.to_json, headers: headers }

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end

  describe "doi transfer", elasticsearch: true do
    let!(:dois) { create_list(:doi, 3, client: client) }
    let(:target) { create(:client, provider: provider, symbol: provider.symbol + ".TARGET", name: "Target Client") }
    let(:params) do
      { "data" => { "type" => "clients",
                    "attributes" => {
                      "targetId" => target.symbol }} }
    end

    before do
      Doi.import
      sleep 1
      put "/clients/#{client.symbol}", params: params.to_json, headers: headers
      sleep 1
    end

    it 'returns status code 200' do
      expect(response).to have_http_status(200)
    end

    # it "transfered all DOIs" do
    #   expect(Doi.query(nil, client_id: client.symbol.downcase).results.total).to eq(0)
    #   expect(Doi.query(nil, client_id: target.symbol.downcase).results.total).to eq(3)
    # end
  end
end
