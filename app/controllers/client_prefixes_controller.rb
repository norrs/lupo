require 'base32/url'
require 'uri'

class ClientPrefixesController < ApplicationController
  before_action :set_client_prefix, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  before_action :set_include
  load_and_authorize_resource :except => [:index, :show, :set_created, :set_provider]
  around_action :skip_bullet, only: [:index], if: -> { defined?(Bullet) }

  def index
    sort = case params[:sort]
           when "name" then { "prefix.uid" => { order: 'asc' }}
           when "-name" then { "prefix.uid" => { order: 'desc' }}
           when "created" then { created_at: { order: 'asc' }}
           when "-created" then { created_at: { order: 'desc' }}
           else { created_at: { order: 'desc' }}
           end

    page = page_from_params(params)

    if params[:id].present?
      response = ClientPrefix.find_by_id(params[:id]) 
    else
      response = ClientPrefix.query(params[:query],
                                    client_id: params[:client_id],
                                    prefix_id: params[:prefix_id],
                                    year: params[:year],
                                    page: page,
                                    sort: sort)
    end

    begin
      total = response.results.total
      total_pages = page[:size].positive? ? (total.to_f / page[:size]).ceil : 0
      years = total.positive? ? facet_by_year(response.response.aggregations.years.buckets) : nil
      providers = total.positive? ? facet_by_combined_key(response.response.aggregations.providers.buckets) : nil
      clients = total.positive? ? facet_by_combined_key(response.response.aggregations.clients.buckets) : nil

      client_prefixes = response.results

      options = {}
      options[:meta] = {
        total: total,
        "totalPages" => total_pages,
        page: page[:number],
        years: years,
        providers: providers,
        clients: clients
      }.compact

      options[:links] = {
      self: request.original_url,
      next: client_prefixes.blank? ? nil : request.base_url + "/client-prefixes?" + {
        query: params[:query],
        prefix: params[:prefix],
        year: params[:year],
        "page[number]" => page[:number] + 1,
        "page[size]" => page[:size],
        sort: params[:sort] }.compact.to_query
      }.compact
      options[:include] = @include
      options[:is_collection] = true

      render json: ClientPrefixSerializer.new(client_prefixes, options).serialized_json, status: :ok
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => exception
      Raven.capture_exception(exception)

      message = JSON.parse(exception.message[6..-1]).to_h.dig("error", "root_cause", 0, "reason")

      render json: { "errors" => { "title" => message }}.to_json, status: :bad_request
    end
  end

  def show
    options = {}
    options[:include] = @include
    options[:is_collection] = false

    render json: ClientPrefixSerializer.new(@client_prefix, options).serialized_json, status: :ok
  end

  def create
    @client_prefix = ClientPrefix.new(safe_params)
    authorize! :create, @client_prefix

    if @client_prefix.save
      if @client_prefix.__elasticsearch__.index_document.dig("result") != "created"
        logger.error "Error adding Client Prefix #{@client_prefix.uid} to Elasticsearch index."
      end
      if @client_prefix.prefix.__elasticsearch__.index_document.dig("result") != "updated"
        logger.error "Error updating Elasticsearch index for Prefix #{@client_prefix.prefix.uid}."
      end
      if @client_prefix.provider_prefix.__elasticsearch__.index_document.dig("result") != "updated"
        logger.error "Error updating Elasticsearch index for Provider Prefix #{@client_prefix.provider_prefix.uid}."
      end

      options = {}
      options[:include] = @include
      options[:is_collection] = false

      render json: ClientPrefixSerializer.new(@client_prefix, options).serialized_json, status: :created
    else
      Rails.logger.error @client_prefix.errors.inspect
      render json: serialize_errors(@client_prefix.errors), status: :unprocessable_entity
    end
  end

  def update
    response.headers["Allow"] = "HEAD, GET, POST, DELETE, OPTIONS"
    render json: { errors: [{ status: "405", title: "Method not allowed" }] }.to_json, status: :method_not_allowed
  end

  def destroy
    message = "Client prefix #{@client_prefix.uid} deleted."

    if @client_prefix.destroy
      if @client_prefix.__elasticsearch__.delete_document.dig("result") != "deleted"
        logger.error "Error deleting Client Prefix #{@client_prefix.uid} from Elasticsearch index."
      end
      if @client_prefix.prefix.__elasticsearch__.index_document.dig("result") != "updated"
        logger.error "Error updating Elasticsearch index for Prefix #{@client_prefix.prefix.uid}."
      end
      if @client_prefix.provider_prefix.__elasticsearch__.index_document
        logger.error "Error updating Elasticsearch index for Provider Prefix #{@client_prefix.provider_prefix.uid}."
      end

      logger.warn message
      head :no_content
    else
      Rails.logger.error @client_prefix.errors.inspect
      render json: serialize_errors(@client_prefix.errors), status: :unprocessable_entity
    end
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore.to_sym }
      @include = @include & [:client, :prefix, :provider_prefix, :provider]
    else
      @include = []
    end
  end

  private

  def set_client_prefix
    @client_prefix = ClientPrefix.where(uid: params[:id]).first
    fail ActiveRecord::RecordNotFound if @client_prefix.blank?
  end

  def safe_params
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:id, :client, :prefix, :providerPrefix],
              keys: { "providerPrefix" => :provider_prefix }
    )
  end
end
