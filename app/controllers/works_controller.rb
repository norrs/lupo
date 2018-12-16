class WorksController < ApplicationController
  prepend_before_action :authenticate_user!
  before_action :set_doi, only: [:show]
  before_action :set_include, only: [:index, :show]
  before_bugsnag_notify :add_metadata_to_bugsnag

  def index
    authorize! :read, Doi

    sort = case params[:sort]
          when "name" then { "doi" => { order: 'asc' }}
          when "-name" then { "doi" => { order: 'desc' }}
          when "created" then { created: { order: 'asc' }}
          when "-created" then { created: { order: 'desc' }}
          when "updated" then { updated: { order: 'asc' }}
          when "-updated" then { updated: { order: 'desc' }}
          when "relevance" then { "_score": { "order": "desc" }}
          else { updated: { order: 'desc' }}
          end

    page = params[:page] || {}
    if page[:size].present?
      page[:size] = [page[:size].to_i, 1000].min
      max_number = page[:size] > 0 ? 10000/page[:size] : 1
    else
      page[:size] = 25
      max_number = 10000/page[:size]
    end
    page[:number] = page[:number].to_i > 0 ? [page[:number].to_i, max_number].min : 1

    if params[:id].present?
      response = Doi.find_by_id(params[:id])
    elsif params[:ids].present?
      response = Doi.find_by_ids(params[:ids], page: page, sort: sort)
    else
      response = Doi.query(params[:query],
                          state: "findable",
                          created: params[:created],
                          registered: params[:registered],
                          provider_id: params[:member_id],
                          client_id: params[:data_center_id],
                          prefix: params[:prefix],
                          person_id: params[:person_id],
                          resource_type_id: params[:resource_type_id],
                          schema_version: params[:schema_version],
                          page: page,
                          sort: sort)
    end

    total = response.results.total
    total_pages = page[:size] > 0 ? ([total.to_f, 10000].min / page[:size]).ceil : 0

    resource_types = total > 0 ? facet_by_resource_type(response.response.aggregations.resource_types.buckets) : nil
    registered = total > 0 ? facet_by_year(response.response.aggregations.registered.buckets) : nil
    providers = total > 0 ? facet_by_provider(response.response.aggregations.providers.buckets) : nil
    clients = total > 0 ? facet_by_client(response.response.aggregations.clients.buckets) : nil

    @dois = response.results.results

    options = {}
    options[:meta] = {
      "resource-types" => resource_types,
      registered: registered,
      "data-centers" => clients,
      total: total,
      "total-pages" => total_pages,
      page: page[:number]
    }.compact

    options[:links] = {
      self: request.original_url,
      next: @dois.blank? ? nil : request.base_url + "/dois?" + {
        query: params[:query],
        "member-id" => params[:provider_id],
        "data-center-id" => params[:client_id],
        "page[size]" => params.dig(:page, :size) }.compact.to_query
      }.compact
    options[:include] = @include
    options[:is_collection] = true
    options[:links] = nil
    options[:params] = {
      :current_ability => current_ability,
    }

    render json: WorkSerializer.new(@dois, options).serialized_json, status: :ok
  end

  def show
    authorize! :read, @doi

    options = {}
    options[:include] = @include
    options[:is_collection] = false
    options[:params] = { 
      current_ability: current_ability,
      detail: true 
    }

    render json: WorkSerializer.new(@doi, options).serialized_json, status: :ok
  end

  protected

  def set_doi
    @doi = Doi.where(doi: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @doi.present?

    # capture username and password for reuse in the handle system
    @doi.current_user = current_user
  end

  def set_include
    if params[:include].present?
      include_keys = {
        "data_center" => :client,
        "member" => :provider,
        "resource_type" => :resource_type
      }
      @include = params[:include].split(",").reduce([]) do |sum, i|
        k = include_keys[i.downcase.underscore]
        sum << k if k.present?
        sum
      end
    else
      @include = nil
    end
  end

  def add_metadata_to_bugsnag(report)
    return nil unless params.dig(:data, :attributes, :xml).present?

    report.add_tab(:metadata, {
      metadata: Base64.decode64(params.dig(:data, :attributes, :xml))
    })
  end
end