class MediaController < ApplicationController
  before_action :set_doi
  before_action :set_media, only: [:show, :update, :destroy]
  before_action :set_include
  before_action :authenticate_user!

  def index
    collection = @doi.media
    total = @doi.cached_media_count.reduce(0) { |sum, d| sum + d[:count].to_i }

    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total_pages = (total.to_f / page[:size]).ceil

    order = case params[:sort]
            when "name" then "dataset.doi"
            when "-name" then "dataset.doi DESC"
            when "created" then "media.created"
            else "media.created DESC"
            end

    @media = collection.order(order).page(page[:number]).per(page[:size])

    meta = { total: total,
             total_pages: total_pages,
             page: page[:number].to_i }

    render jsonapi: @media, meta: meta, include: @include
  end

  def show
    render jsonapi: @media, include: @include
  end

  def create
    authorize! :update, @doi

    @media = Media.new(safe_params.merge(doi: @doi))

    if @media.save
      render jsonapi: @media, status: :created
    else
      Rails.logger.warn @media.errors.inspect
      render jsonapi: serialize(@media.errors), status: :unprocessable_entity
    end
  end

  def update
    authorize! :update, @doi

    if @media.update_attributes(safe_params.merge(doi: @doi))
      render jsonapi: @media
    else
      Rails.logger.warn @media.errors.inspect
      render jsonapi: serialize(@media.errors), status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :update, @doi

    if @media.destroy
      head :no_content
    else
      Rails.logger.warn @media.errors.inspect
      render jsonapi: serialize(@media.errors), status: :unprocessable_entity
    end
  end

  protected

  def set_doi
    @doi = Doi.where(doi: params[:doi_id]).first
    fail ActiveRecord::RecordNotFound unless @doi.present?
  end

  def set_media
    id = Base32::URL.decode(URI.decode(params[:id]))
    fail ActiveRecord::RecordNotFound unless id.present?

    @media = Media.where(id: id.to_i).first
    fail ActiveRecord::RecordNotFound unless @media.present?
  end

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["doi"]
    end
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: ["media-type", :url],
              keys: { "media-type" => :media_type }
    )
  end
end
