require 'maremma'

class Doi < ActiveRecord::Base
  include Metadatable
  include Cacheable
  include Licensable
  include Dateable

  # include helper module for generating random DOI suffixes
  include Helpable

  # include helper module for converting and exposing metadata
  include Crosscitable

  # include helper module for link checking
  include Checkable

  # include state machine
  include AASM

  # include helper module for Elasticsearch
  include Indexable

  # include helper module for sending emails
  include Mailable

  include Elasticsearch::Model

  aasm :whiny_transitions => false do
    # draft is initial state for new DOIs.
    state :draft, :initial => true
    state :tombstoned, :registered, :findable, :flagged, :broken

    event :register do
      # can't register test prefix
      transitions :from => [:draft], :to => :registered, :if => [:is_valid?, :not_is_test_prefix?]
    end

    event :publish do
      # can't index test prefix
      transitions :from => [:draft], :to => :findable, :if => [:is_valid?, :not_is_test_prefix?]
      transitions :from => :registered, :to => :findable
    end

    event :hide do
      transitions :from => [:findable], :to => :registered
    end

    event :flag do
      transitions :from => [:registered, :findable], :to => :flagged
    end

    event :link_check do
      transitions :from => [:tombstoned, :registered, :findable, :flagged], :to => :broken
    end
  end

  self.table_name = "dataset"
  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated
  alias_attribute :registered, :minted
  alias_attribute :state, :aasm_state

  attr_accessor :current_user
  attr_accessor :validate

  belongs_to :client, foreign_key: :datacentre
  has_many :media, -> { order "created DESC" }, foreign_key: :dataset, dependent: :destroy
  has_many :metadata, -> { order "created DESC" }, foreign_key: :dataset, dependent: :destroy

  delegate :provider, to: :client

  validates_presence_of :doi
  # validates_presence_of :url, if: :is_registered_or_findable?

  # from https://www.crossref.org/blog/dois-and-matching-regular-expressions/ but using uppercase
  validates_format_of :doi, :with => /\A10\.\d{4,5}\/[-\._;()\/:a-zA-Z0-9\*~\$\=]+\z/, :on => :create
  validates_format_of :url, :with => /\A(ftp|http|https):\/\/[\S]+/ , if: :url?, message: "URL is not valid"
  validates_uniqueness_of :doi, message: "This DOI has already been taken"
  validates :last_landing_page_status, numericality: { only_integer: true }, if: :last_landing_page_status?

  # validate :validation_errors

  after_commit :update_url, on: [:create, :update]
  after_commit :update_media, on: [:create, :update]

  before_save :set_defaults, :update_metadata
  before_create { self.created = Time.zone.now.utc.iso8601 }

  scope :q, ->(query) { where("dataset.doi = ?", query) }

  # use different index for testing
  index_name Rails.env.test? ? "dois-test" : "dois"

  mapping dynamic: 'false' do
    indexes :id,                             type: :keyword
    indexes :uid,                            type: :keyword
    indexes :doi,                            type: :keyword
    indexes :identifier,                     type: :keyword
    indexes :url,                            type: :text, fields: { keyword: { type: "keyword" }}
    indexes :creator,                        type: :object, properties: {
      type: { type: :keyword },
      id: { type: :keyword },
      name: { type: :text },
      givenName: { type: :text },
      familyName: { type: :text }
    }
    indexes :contributor,                    type: :object, properties: {
      type: { type: :keyword },
      id: { type: :keyword },
      name: { type: :text },
      givenName: { type: :text },
      familyName: { type: :text },
      contributorType: { type: :keyword }
    }
    indexes :creator_names,                  type: :text
    indexes :titles,                         type: :object, properties: {
      title: { type: :keyword },
      titleType: { type: :keyword },
      lang: { type: :keyword }
    }
    indexes :descriptions,                   type: :object, properties: {
      description: { type: :keyword },
      descriptionType: { type: :keyword },
      lang: { type: :keyword }
    }
    indexes :publisher,                      type: :text, fields: { keyword: { type: "keyword" }}
    indexes :publication_year,               type: :date, format: "yyyy", ignore_malformed: true
    indexes :client_id,                      type: :keyword
    indexes :provider_id,                    type: :keyword
    indexes :resource_type_id,               type: :keyword
    indexes :media_ids,                      type: :keyword
    indexes :media,                          type: :object, properties: {
      type: { type: :keyword },
      id: { type: :keyword },
      uid: { type: :keyword },
      url: { type: :text },
      media_type: { type: :keyword },
      version: { type: :keyword },
      created: { type: :date, ignore_malformed: true },
      updated: { type: :date, ignore_malformed: true }
    }
    indexes :alternate_identifiers,          type: :object, properties: {
      alternateIdentifierType: { type: :keyword },
      alternateIdentifier: { type: :keyword }
    }
    indexes :related_identifiers,            type: :object, properties: {
      relatedIdentifierType: { type: :keyword },
      relatedIdentifier: { type: :keyword },
      relationType: { type: :keyword },
      resourceTypeGeneral: { type: :keyword }
    }
    indexes :types,                          type: :object, properties: {
      resourceTypeGeneral: { type: :keyword },
      resourceType: { type: :keyword },
      schemaOrg: { type: :keyword },
      bibtex: { type: :keyword },
      citeproc: { type: :keyword },
      ris: { type: :keyword }
    }
    indexes :funding_references,             type: :object, properties: {
      funderName: { type: :keyword },
      funderIdentifier: { type: :keyword },
      funderIdentifierType: { type: :keyword },
      awardNumber: { type: :keyword },
      awardUri: { type: :keyword },
      awardTitle: { type: :keyword }
    }
    indexes :dates,                          type: :object, properties: {
      date: { type: :date, format: "yyyy-MM-dd||yyyy-MM||yyyy", ignore_malformed: true },
      dateType: { type: :keyword }
    }
    indexes :geo_locations,                  type: :object, properties: {
      geoLocationPoint: { type: :object },
      geoLocationBox: { type: :object },
      geoLocationPlace: { type: :keyword }
    }
    indexes :rights_list,                    type: :object, properties: {
      rights: { type: :keyword },
      rightsUri: { type: :keyword }
    }
    indexes :subjects,                       type: :object, properties: {
      subject: { type: :keyword },
      subjectScheme: { type: :keyword },
      schemeUri: { type: :keyword },
      valueUri: { type: :keyword }
    }
    indexes :periodical,                     type: :object, properties: {
      type: { type: :keyword },
      id: { type: :keyword },
      title: { type: :keyword },
      issn: { type: :keyword }
    }
    indexes :xml,                            type: :text, index: "not_analyzed"
    indexes :content_url,                    type: :keyword
    indexes :version_info,                   type: :keyword
    indexes :formats,                        type: :keyword
    indexes :sizes,                          type: :keyword
    indexes :language,                       type: :keyword
    indexes :is_active,                      type: :keyword
    indexes :aasm_state,                     type: :keyword
    indexes :schema_version,                 type: :keyword
    indexes :metadata_version,               type: :keyword
    indexes :source,                         type: :keyword
    indexes :prefix,                         type: :keyword
    indexes :suffix,                         type: :keyword
    indexes :reason,                         type: :text
    indexes :last_landing_page_status,       type: :integer
    indexes :last_landing_page_status_check, type: :date, ignore_malformed: true
    indexes :last_landing_page_content_type, type: :keyword
    indexes :last_landing_page_status_result, type: :object, properties: {
      error: { type: :keyword },
      redirectCount: { type: :integer },
      redirectUrls: { type: :keyword },
      downloadLatency: { type: :scaled_float, scaling_factor: 100 },
      hasSchemaOrg: { type: :boolean },
      schemaOrgId: { type: :object },
      dcIdentifier: { type: :keyword },
      citationDoi: { type: :keyword },
      bodyHasPid: { type: :boolean }
    }
    indexes :cache_key,                      type: :keyword
    indexes :registered,                     type: :date, ignore_malformed: true
    indexes :created,                        type: :date, ignore_malformed: true
    indexes :updated,                        type: :date, ignore_malformed: true

    # include parent objects
    indexes :client,                         type: :object
    indexes :provider,                       type: :object
    indexes :resource_type,                  type: :object
  end

  def as_indexed_json(options={})
    {
      "id" => uid,
      "uid" => uid,
      "doi" => doi,
      "identifier" => identifier,
      "url" => url,
      "creator" => creator,
      "contributor" => contributor,
      "creator_names" => creator_names,
      "titles" => titles,
      "descriptions" => descriptions,
      "publisher" => publisher,
      "client_id" => client_id,
      "provider_id" => provider_id,
      "resource_type_id" => resource_type_id,
      "media_ids" => media_ids,
      "prefix" => prefix,
      "suffix" => suffix,
      "types" => types,
      "alternate_identifiers" => alternate_identifiers,
      "related_identifiers" => related_identifiers,
      "funding_references" => funding_references,
      "publication_year" => publication_year,
      "dates" => dates,
      "geo_locations" => geo_locations,
      "rights_list" => rights_list,
      "periodical" => periodical,
      "content_url" => content_url,
      "version_info" => version_info,
      "formats" => formats,
      "sizes" => sizes,
      "language" => language,
      "subjects" => subjects,
      "xml" => xml,
      "is_active" => is_active,
      "last_landing_page_status" => last_landing_page_status,
      "last_landing_page_status_check" => last_landing_page_status_check,
      "last_landing_page_content_type" => last_landing_page_content_type,
      "last_landing_page_status_result" => last_landing_page_status_result,
      "aasm_state" => aasm_state,
      "schema_version" => schema_version,
      "metadata_version" => metadata_version,
      "reason" => reason,
      "source" => source,
      "cache_key" => cache_key,
      "registered" => registered,
      "created" => created,
      "updated" => updated,
      "client" => client.as_indexed_json,
      "provider" => provider.as_indexed_json,
      "resource_type" => resource_type.try(:as_indexed_json),
      "media" => media.map { |m| m.try(:as_indexed_json) }
    }
  end

  def self.query_aggregations
    {
      resource_types: { terms: { field: 'types.resourceTypeGeneral', size: 15, min_doc_count: 1 } },
      states: { terms: { field: 'aasm_state', size: 15, min_doc_count: 1 } },
      years: { date_histogram: { field: 'publication_year', interval: 'year', min_doc_count: 1 } },
      created: { date_histogram: { field: 'created', interval: 'year', min_doc_count: 1 } },
      registered: { date_histogram: { field: 'registered', interval: 'year', min_doc_count: 1 } },
      providers: { terms: { field: 'provider_id', size: 15, min_doc_count: 1 } },
      clients: { terms: { field: 'client_id', size: 15, min_doc_count: 1 } },
      prefixes: { terms: { field: 'prefix', size: 15, min_doc_count: 1 } },
      schema_versions: { terms: { field: 'schema_version', size: 15, min_doc_count: 1 } },
      link_checks: { terms: { field: 'last_landing_page_status', size: 15, min_doc_count: 1 } },
      sources: { terms: { field: 'source', size: 15, min_doc_count: 1 } }
    }
  end

  def self.query_fields
    ['doi^10', 'titles.title^10', 'creator_names^10', 'creator.name^10', 'creator.id^10', 'publisher^10', 'descriptions.description^10', 'types.resourceTypeGeneral^10', 'subjects.subject^10', 'alternate_identifiers.alternateIdentifier^10', 'related_identifiers.relatedIdentifier^10', '_all']
  end

  def self.find_by_id(id, options={})
    return nil unless id.present?

    __elasticsearch__.search({
      query: {
        term: {
          doi: id.downcase
        }
      },
      aggregations: query_aggregations
    })
  end

  def self.import_all(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    # get every day between from_date and until_date
    (from_date..until_date).each do |d|
      DoiImportByDayJob.perform_later(from_date: d.strftime("%F"))
      puts "Queued importing for DOIs created on #{d.strftime("%F")}."
    end    
  end

  def self.import_by_day(options={})
    return nil unless options[:from_date].present?
    from_date = Date.parse(options[:from_date])
    
    count = 0

    logger = Logger.new(STDOUT)

    Doi.where(created: from_date.midnight..from_date.end_of_day).find_each do |doi|
      begin
        string = doi.current_metadata.present? ? doi.current_metadata.xml : nil
        meta = doi.read_datacite(string: string, sandbox: doi.sandbox)
        attrs = %w(creator contributor titles publisher publication_year types descriptions periodical sizes formats language dates alternate_identifiers related_identifiers funding_references geo_locations rights_list subjects content_url).map do |a|
          [a.to_sym, meta[a]]
        end.to_h.merge(schema_version: meta["schema_version"] || "http://datacite.org/schema/kernel-4", version_info: meta["version"], xml: string)
        
        doi.update_columns(attrs)
      rescue TypeError, NoMethodError => error
        logger.error "[MySQL] Error importing metadata for " + doi.doi + ": " + error.message
      else
        count += 1
      end
    end

    if count > 0
      logger.info "[MySQL] Imported metadata for #{count} DOIs created on #{options[:from_date]}."
    end
  end

  def self.index(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current
    index_time = options[:index_time].presence || Time.zone.now.utc.iso8601

    # get every day between from_date and until_date
    (from_date..until_date).each do |d|
      DoiIndexByDayJob.perform_later(from_date: d.strftime("%F"), index_time: index_time)
      puts "Queued indexing for DOIs created on #{d.strftime("%F")}."
    end    
  end

  def self.index_by_day(options={})
    return nil unless options[:from_date].present?
    from_date = Date.parse(options[:from_date])
    index_time = options[:index_time].presence || Time.zone.now.utc.iso8601
    
    errors = 0
    count = 0

    logger = Logger.new(STDOUT)

    Doi.where(created: from_date.midnight..from_date.end_of_day).where("indexed < ?", index_time).find_in_batches(batch_size: 500) do |dois|
      response = Doi.__elasticsearch__.client.bulk \
        index:   Doi.index_name,
        type:    Doi.document_type,
        body:    dois.map { |doi| { index: { _id: doi.id, data: doi.as_indexed_json } } }

      # log errors
      errors += response['items'].map { |k, v| k.values.first['error'] }.compact.length
      response['items'].select { |k, v| k.values.first['error'].present? }.each do |err|
        logger.error "[Elasticsearch] " + err.inspect
      end

      dois.each { |doi| doi.update_column(:indexed, Time.zone.now) }
      count += dois.length
    end

    if errors > 1
      logger.error "[Elasticsearch] #{errors} errors indexing #{count} DOIs created on #{options[:from_date]}."
    elsif count > 1
      logger.info "[Elasticsearch] Indexed #{count} DOIs created on #{options[:from_date]}."
    end
  rescue Elasticsearch::Transport::Transport::Errors::RequestEntityTooLarge, Faraday::ConnectionFailed => error
    logger.info "[Elasticsearch] Error #{error.message} indexing DOIs created on #{options[:from_date]}."

    count = 0

    Doi.where(created: from_date.midnight..from_date.end_of_day).where("indexed < ?", index_time).find_each do |doi|
      IndexJob.perform_later(doi)
      doi.update_column(:indexed, Time.zone.now)  
      count += 1
    end
  
    logger.info "[Elasticsearch] Indexed #{count} DOIs created on #{options[:from_date]}."
  end

  def uid
    doi.downcase
  end

  def resource_type_id
    types["resourceTypeGeneral"].underscore.dasherize if types.to_h["resourceTypeGeneral"].present?
  end

  def media_ids
    media.pluck(:id).map { |m| Base32::URL.encode(m, split: 4, length: 16) }
  end

  def xml_encoded
    Base64.strict_encode64(xml) if xml.present?
  rescue ArgumentError => exception    
    nil
  end
 
  # creator name in natural order: "John Smith" instead of "Smith, John"
  def creator_names
    Array.wrap(creator).map do |a| 
      if a["familyName"].present? 
        [a["givenName"], a["familyName"]].join(" ")
      elsif a["name"].to_s.include?(", ")
        a["name"].split(", ", 2).reverse.join(" ")
      else
        a["name"]
      end
    end
  end

  def doi=(value)
    write_attribute(:doi, value.upcase) if value.present?
  end

  def identifier
    normalize_doi(doi, sandbox: !Rails.env.production?)
  end

  def client_id
    client.symbol.downcase if client.present?
  end

  def client_id=(value)
    r = ::Client.where(symbol: value).first
    #r = cached_client_response(value)
    fail ActiveRecord::RecordNotFound unless r.present?

    write_attribute(:datacentre, r.id)
  end

  def provider_id
    provider.symbol.downcase
  end

  def prefix
    doi.split('/', 2).first if doi.present?
  end

  def suffix
    uid.split("/", 2).last if doi.present?
  end

  def is_test_prefix?
    prefix == "10.5072"
  end

  def not_is_test_prefix?
    prefix != "10.5072"
  end

  def is_valid?
    validation_errors.blank? && url.present?
  end

  def is_registered_or_findable?
    %w(registered findable).include?(aasm_state)
  end

  # update URL in handle system for registered and findable state
  # providers europ and ethz do their own handle registration
  def update_url
    return nil if current_user.nil? || !is_registered_or_findable? || %w(europ ethz).include?(provider_id)

    HandleJob.perform_later(doi)
  end

  def update_media
    return nil unless content_url.present?

    media.delete_all

    Array.wrap(content_url).each do |c|
      media << Media.create(url: c, media_type: formats)
    end
  end

  # attributes to be sent to elasticsearch index
  def to_jsonapi
    attributes = {
      "doi" => doi,
      "state" => aasm_state,
      "created" => created,
      "updated" => date_updated }

    { "id" => doi, "type" => "dois", "attributes" => attributes }
  end

  def current_metadata
    metadata.order('metadata.created DESC').first
  end

  def metadata_version
    fetch_cached_metadata_version
  end

  def current_media
    media.order('media.created DESC').first
  end

  def resource_type
    cached_resource_type_response(types["resourceTypeGeneral"].underscore.dasherize.downcase) if types.to_h["resourceTypeGeneral"].present?
  end

  def date_registered
    minted
  end

  def date_updated
    updated
  end

  def cache_key
    timestamp = updated || Time.zone.now
    "dois/#{uid}-#{timestamp.iso8601}"
  end

  def event=(value)
    self.send(value) if %w(register publish hide).include?(value)
  end

  # update state for all DOIs in state "" starting from from_date
  def self.set_state(from_date: nil)
    from_date ||= Time.zone.now - 1.day
    Doi.where("updated >= ?", from_date).where(aasm_state: '').find_each do |doi|
      if doi.is_test_prefix? || (doi.is_active.getbyte(0) == 0 && doi.minted.blank?)
        state = "draft"
      elsif doi.is_active.to_s.getbyte(0) == 0 && doi.minted.present?
        state = "registered"
      else
        state = "findable"
      end
      UpdateStateJob.perform_later(doi.doi, state: state)
    end
  rescue ActiveRecord::LockWaitTimeout => exception
    Bugsnag.notify(exception)
  end

  # delete all DOIs with test prefix 10.5072 not updated since from_date
  # we need to use destroy_all to also delete has_many associations for metadata and media
  def self.delete_test_dois(from_date: nil)
    from_date ||= Time.zone.now - 1.month
    collection = Doi.where("updated < ?", from_date)
    collection.where("doi LIKE ?", "10.5072%").find_each do |d|
      logger = Logger.new(STDOUT)
      logger.info "Automatically deleted #{d.doi}, last updated #{d.updated.iso8601}."
      d.destroy
    end
  end

  # set minted date for DOIs that have been registered in an handle system (providers ETHZ and EUROP)
  def self.set_minted(from_date: nil)
    from_date ||= Time.zone.now - 1.day
    ids = ENV['HANDLES_MINTED'].to_s.split(",")
    return nil unless ids.present?

    collection = Doi.where("datacentre in (SELECT id from datacentre where allocator IN (:ids))", ids: ids).where("updated >= ?", from_date).where("updated < ?", Time.zone.now - 15.minutes)
    collection.where(is_active: "\x01").where(minted: nil).update_all(("minted = updated"))
  end

  # register DOIs in the handle system that have not been registered yet
  def self.register_all_urls(limit: nil)
    limit ||= 100

    Doi.where(minted: nil).where.not(url: nil).where.not(aasm_state: "draft").where("updated < ?", Time.zone.now - 15.minutes).order(created: :desc).limit(limit.to_i).find_each do |d|
      HandleJob.perform_later(d.doi)
    end
  end

  def self.set_url(from_date: nil)
    from_date = from_date.present? ? Date.parse(from_date) : Date.current - 1.day
    Doi.where(url: nil).where.not(minted: nil).where("updated >= ?", from_date).find_each do |doi|
      UrlJob.perform_later(doi)
    end

    "Queued storing missing URL in database for DOIs updated since #{from_date.strftime("%F")}."
  end

  # update metadata record when xml has changed
  def update_metadata
    metadata.build(doi: self, xml: xml, namespace: schema_version) if xml.present? && (changed & %w(xml)).present?
  end

  def set_defaults
    self.is_active = (aasm_state == "findable") ? "\x01" : "\x00"
    self.version = version.present? ? version + 1 : 0
    self.updated = Time.zone.now.utc.iso8601
  end
end
