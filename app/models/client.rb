class Client < ActiveRecord::Base
  audited except: [:globus_uuid, :salesforce_id, :password, :updated, :comments, :experiments, :version, :doi_quota_allowed, :doi_quota_used]

  # include helper module for caching infrequently changing resources
  include Cacheable

  # include helper module for managing associated users
  include Userable

  # include helper module for setting password
  include Passwordable

  # include helper module for authentication
  include Authenticable

  # include helper module for Elasticsearch
  include Indexable

  # include helper module for sending emails
  include Mailable

  include Elasticsearch::Model

  # define table and attribute names
  # uid is used as unique identifier, mapped to id in serializer
  self.table_name = "datacentre"

  alias_attribute :flipper_id, :symbol
  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated
  alias_attribute :contact_email, :system_email
  attr_readonly :symbol
  delegate :symbol, to: :provider, prefix: true
  delegate :consortium_id, to: :provider, allow_nil: true

  attr_accessor :password_input

  validates_presence_of :symbol, :name, :system_email
  validates_uniqueness_of :symbol, message: "This Client ID has already been taken"
  validates_format_of :symbol, :with => /\A([A-Z]+\.[A-Z0-9]+(-[A-Z0-9]+)?)\Z/, message: "should only contain capital letters, numbers, and at most one hyphen"
  validates_length_of :symbol, minimum: 5, maximum: 18
  validates_format_of :system_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_format_of :salesforce_id, :with => /[a-zA-Z0-9]{18}/, message: "wrong format for salesforce id", if: :salesforce_id?
  validates_inclusion_of :role_name, :in => %w( ROLE_DATACENTRE ), :message => "Role %s is not included in the list"
  validates_inclusion_of :client_type, :in => %w( repository periodical ), :message => "Client type %s is not included in the list"
  validates_associated :provider
  validate :check_id, :on => :create
  validate :freeze_symbol, :on => :update
  validate :check_issn, if: :issn?
  validate :check_certificate, if: :certificate?
  validate :check_repository_type, if: :repository_type?
  validate :uuid_format, if: :globus_uuid?
  strip_attributes

  belongs_to :provider, foreign_key: :allocator, touch: true
  has_many :dois, foreign_key: :datacentre
  has_many :client_prefixes, dependent: :destroy
  has_many :prefixes, through: :client_prefixes
  has_many :provider_prefixes, through: :client_prefixes
  has_many :activities, as: :auditable, dependent: :destroy

  before_validation :set_defaults
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }

  attr_accessor :target_id

  # use different index for testing
  if Rails.env.test?
    index_name "clients-test"
  elsif ENV["ES_PREFIX"].present?
    index_name"clients-#{ENV["ES_PREFIX"]}"
  else
    index_name "clients"
  end

  settings index: {
    analysis: {
      analyzer: {
        string_lowercase: { tokenizer: 'keyword', filter: %w(lowercase ascii_folding) }
      },
      normalizer: {
        keyword_lowercase: { type: "custom", filter: %w(lowercase) }
      },
      filter: {
        ascii_folding: { type: 'asciifolding', preserve_original: true }
      }
    }
  } do
    mapping dynamic: 'false' do
      indexes :id,            type: :keyword
      indexes :uid,           type: :keyword, normalizer: "keyword_lowercase"
      indexes :symbol,        type: :keyword
      indexes :provider_id,   type: :keyword
      indexes :provider_id_and_name, type: :keyword
      indexes :consortium_id, type: :keyword
      indexes :re3data_id,    type: :keyword
      indexes :opendoar_id,   type: :integer
      indexes :salesforce_id, type: :keyword
      indexes :globus_uuid,   type: :keyword
      indexes :issn,          type: :object, properties: {
        issnl: { type: :keyword },
        electronic: { type: :keyword },
        print: { type: :keyword }}
      indexes :prefix_ids,    type: :keyword
      indexes :name,          type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :alternate_name, type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :description,   type: :text
      indexes :system_email,  type: :text, fields: { keyword: { type: "keyword" }}
      indexes :service_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :certificate,   type: :keyword
      indexes :language,      type: :keyword
      indexes :repository_type, type: :keyword
      indexes :version,       type: :integer
      indexes :is_active,     type: :keyword
      indexes :domains,       type: :text
      indexes :year,          type: :integer
      indexes :url,           type: :text, fields: { keyword: { type: "keyword" }}
      indexes :software,      type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :cache_key,     type: :keyword
      indexes :client_type,   type: :keyword
      indexes :created,       type: :date
      indexes :updated,       type: :date
      indexes :deleted_at,    type: :date
      indexes :cumulative_years, type: :integer, index: "false"

      # include parent objects
      indexes :provider,                       type: :object, properties: {
        id: { type: :keyword },
        uid: { type: :keyword },
        symbol: { type: :keyword },
        globus_uuid: { type: :keyword },
        client_ids: { type: :keyword },
        prefix_ids: { type: :keyword },
        name: { type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", "analyzer": "string_lowercase", "fielddata": true }} },
        display_name: { type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", "analyzer": "string_lowercase", "fielddata": true }} },
        system_email: { type: :text, fields: { keyword: { type: "keyword" }} },
        group_email: { type: :text, fields: { keyword: { type: "keyword" }} },
        version: { type: :integer },
        is_active: { type: :keyword },
        year: { type: :integer },
        description: { type: :text },
        website: { type: :text, fields: { keyword: { type: "keyword" }} },
        logo_url: { type: :text },
        region: { type: :keyword },
        focus_area: { type: :keyword },
        organization_type: { type: :keyword },
        member_type: { type: :keyword },
        consortium_id: { type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", "analyzer": "string_lowercase", "fielddata": true }} },
        consortium_organization_ids: { type: :keyword },
        country_code: { type: :keyword },
        role_name: { type: :keyword },
        cache_key: { type: :keyword },
        joined: { type: :date },
        twitter_handle: { type: :keyword },
        ror_id: { type: :keyword },
        salesforce_id: { type: :keyword },
        billing_information: { type: :object, properties: {
          postCode: { type: :keyword },
          state: { type: :text},
          organization: { type: :text},
          department: { type: :text},
          city: { type: :text },
          country: { type: :text },
          address: { type: :text }
        } },
        technical_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        secondary_technical_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        billing_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        secondary_billing_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        service_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        secondary_service_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        voting_contact: { type: :object, properties: {
          email: { type: :text },
          given_name: { type: :text},
          family_name: { type: :text }
        } },
        created: { type: :date },
        updated: { type: :date },
        deleted_at: { type: :date },
        cumulative_years: { type: :integer, index: "false" },
        consortium: { type: :object },
        consortium_organizations: { type: :object }
      }
    end
  end

  def as_indexed_json(options={})
    {
      "id" => uid,
      "uid" => uid,
      "provider_id" => provider_id,
      "provider_id_and_name" => provider_id_and_name,
      "consortium_id" => consortium_id,
      "re3data_id" => re3data_id,
      "opendoar_id" => opendoar_id,
      "salesforce_id" => salesforce_id,
      "globus_uuid" => globus_uuid,
      "issn" => issn,
      "prefix_ids" => options[:exclude_associations] ? nil : prefix_ids,
      "name" => name,
      "alternate_name" => alternate_name,
      "description" => description,
      "certificate" => Array.wrap(certificate),
      "symbol" => symbol,
      "year" => year,
      "language" => Array.wrap(language),
      "repository_type" => Array.wrap(repository_type),
      "service_contact" => service_contact,
      "system_email" => system_email,
      "domains" => domains,
      "url" => url,
      "software" => software,
      "is_active" => is_active,
      "password" => password,
      "cache_key" => cache_key,
      "client_type" => client_type,
      "created" => created,
      "updated" => updated,
      "deleted_at" => deleted_at,
      "cumulative_years" => cumulative_years,
      "provider" => options[:exclude_associations] ? nil : provider.as_indexed_json(exclude_associations: true)
    }
  end

  def self.query_fields
    ['uid^10', 'symbol^10', 'name^5', 'description^5', 'system_email^5', 'url', 'software^3', 'repository.subjects.text^3', 'repository.certificates.text^3', '_all']
  end

  def self.query_aggregations
    {
      years: { date_histogram: { field: 'created', interval: 'year', format: 'year', order: { _key: "desc" }, min_doc_count: 1 },
               aggs: { bucket_truncate: { bucket_sort: { size: 10 } } } },
      cumulative_years: { terms: { field: 'cumulative_years', size: 20, min_doc_count: 1, order: { _count: "asc" } } },
      providers: { terms: { field: 'provider_id_and_name', size: 10, min_doc_count: 1 } },
      software: { terms: { field: 'software.keyword', size: 10, min_doc_count: 1 } },
      client_types: { terms: { field: 'client_type', size: 10, min_doc_count: 1 } },
      repository_types: { terms: { field: 'repository_type', size: 10, min_doc_count: 1 } },
      certificates: { terms: { field: 'certificate', size: 10, min_doc_count: 1 } }
    }
  end

  def csv
    client = {
      name: name,
      client_id: symbol,
      provider_id: provider.present? ? provider.symbol : '',
      salesforce_id: salesforce_id,
      consortium_salesforce_id: provider.present? ? provider.salesforce_id : '',
      is_active: is_active == "\x01",
      created: created,
      updated: updated,
      re3data_id: re3data_id,
      client_type: client_type,
      alternate_name: alternate_name,
      description: description,
      url: url,
      software: software,
      system_email: system_email,
    }.values

    CSV.generate { |csv| csv << client }
  end

  def uid
    symbol.downcase
  end

  # workaround for non-standard database column names and association
  def provider_id
    provider_symbol.downcase
  end

  def provider_id_and_name
    "#{provider_id}:#{provider.name}"
  end

  def provider_id=(value)
    r = Provider.where(symbol: value).first
    return nil unless r.present?

    write_attribute(:allocator, r.id)
  end

  def re3data=(value)
    attr = value.present? ? value[16..-1] : nil
    write_attribute(:re3data_id, attr)
  end

  def opendoar=(value)
    attr = value.present? ? value[38..-1] : nil
    write_attribute(:opendoar_id, attr)
  end

  def prefix_ids
    prefixes.pluck(:uid)
  end

  def target_id=(value)
    c = self.class.find_by_id(value)
    return nil unless c.present?

    client_target = c.records.first
    Rails.logger.info "[Transfer] with target client #{client_target.symbol}"

    Doi.transfer(client_id: symbol.downcase, client_target_id: client_target.id)
  end

  # use keyword arguments consistently
  def transfer(provider_target_id: nil)
    if provider_target_id.blank?
      Rails.logger.error "[Transfer] No target provider provided."
      return nil
    end

    target_provider = Provider.where("role_name IN (?)", %w(ROLE_ALLOCATOR ROLE_CONSORTIUM_ORGANIZATION))
                              .where(symbol: provider_target_id).first

    if target_provider.blank?
      Rails.logger.error "[Transfer] Provider doesn't exist."
      return nil
    end

    # Transfer client
    update_attribute(:allocator, target_provider.id)

    # transfer prefixes
    transfer_prefixes(provider_target_id: target_provider.symbol)

    # Update DOIs
    TransferClientJob.perform_later(self, provider_target_id: provider_target_id)
  end

  # use keyword arguments consistently
  def transfer_prefixes(provider_target_id: nil)
    # These prefixes are used by multiple clients
    prefixes_to_keep = ["10.4124", "10.4225", "10.4226", "10.4227"]

    # delete all associated prefixes
    associated_prefixes = prefixes.reject{ |prefix| prefixes_to_keep.include?(prefix.uid)}
    prefix_ids = associated_prefixes.pluck(:id)
    prefixes_names = associated_prefixes.pluck(:uid)

    if prefix_ids.present?
      response = ProviderPrefix.where("prefix_id IN (?)", prefix_ids).destroy_all
      Rails.logger.info "[Transfer] #{response.count} provider prefixes deleted."
    end

    # Assign prefix(es) to provider and client
    prefixes_names.each do |prefix|
      provider_prefix = ProviderPrefix.create(provider_id: provider_target_id, prefix_id: prefix)
      Rails.logger.info "[Transfer] Provider prefix for provider #{provider_target_id} and prefix #{prefix} created."

      ClientPrefix.create(client_id: symbol, provider_prefix_id: provider_prefix.uid, prefix_id: prefix)
      Rails.logger.info "Client prefix for client #{symbol} and prefix #{prefix} created."
    end
  end

  def service_contact_email
    service_contact.fetch("email",nil) if service_contact.present?
  end

  def service_contact_given_name
    service_contact.fetch("given_name",nil) if service_contact.present?
  end

  def service_contact_family_name
    service_contact.fetch("family_name",nil) if service_contact.present?
  end

  # def index_all_dois
  #   Doi.index(from_date: "2011-01-01", client_id: id)
  # end

  def cache_key
    "clients/#{uid}-#{updated.iso8601}"
  end

  def password_input=(value)
    write_attribute(:password, encrypt_password_sha256(value)) if value.present?
  end

  # backwards compatibility
  def member
    Provider.where(symbol: provider_id).first if provider_id.present?
  end

  def year
    created_at.year if created_at.present?
  end

  # count years account has been active. Ignore if deleted the same year as created
  def cumulative_years
    if deleted_at && deleted_at.year > created_at.year
      (created_at.year...deleted_at.year).to_a
    elsif deleted_at
      []
    else
      (created_at.year..Date.today.year).to_a
    end
  end

  def to_jsonapi
    attributes = {
      "symbol" => symbol,
      "name" => name,
      "system-email" => system_email,
      "url" => url,
      "re3data_id" => re3data_id,
      "opendoar_id" => opendoar_id,
      "domains" => domains,
      "provider-id" => provider_id,
      "prefixes" => prefixes.map { |p| p.prefix },
      "is-active" => is_active.getbyte(0) == 1,
      "version" => version,
      "created" => created.iso8601,
      "updated" => updated.iso8601,
      "deleted_at" => deleted_at ? deleted_at.iso8601 : nil }

    { "id" => symbol.downcase, "type" => "clients", "attributes" => attributes }
  end

  protected

  def check_issn
    Array.wrap(issn).each do |i|
      if !(i.is_a?(Hash))
        errors.add(:issn, "ISSN should be an object and not a string.")
      elsif i["issnl"].present?
        errors.add(:issn, "ISSN-L #{i["issnl"]} is in the wrong format.") unless /\A\d{4}(-)?\d{3}[0-9X]+\z/.match(i["issnl"])
      end
      if i["electronic"].present?
        errors.add(:issn, "ISSN (electronic) #{i["electronic"]} is in the wrong format.") unless /\A\d{4}(-)?\d{3}[0-9X]+\z/.match(i["electronic"])
      end
      if i["print"].present?
        errors.add(:issn, "ISSN (print) #{i["print"]} is in the wrong format.") unless /\A\d{4}(-)?\d{3}[0-9X]+\z/.match(i["print"])
      end
    end
  end

  def check_language
    Array.wrap(language).each do |l|
      errors.add(:issn, "Language can't be empty.") unless l.present?
    end
  end

  def check_certificate
    Array.wrap(certificate).each do |c|
      errors.add(:certificate, "Certificate #{c} is not included in the list of supported certificates.") unless ["CoreTrustSeal", "DIN 31644", "DINI", "DSA", "RatSWD", "WDS", "CLARIN"].include?(c)
    end
  end

  def check_repository_type
    Array.wrap(repository_type).each do |r|
      errors.add(:repository_type, "Repository type #{r} is not included in the list of supported repository types.") unless %w(disciplinary governmental institutional multidisciplinary project-related other).include?(r)
    end
  end

  def uuid_format
    errors.add(:globus_uuid, "#{globus_uuid} is not a valid UUID") unless UUID.validate(globus_uuid)
  end

  def freeze_symbol
    errors.add(:symbol, "cannot be changed") if symbol_changed?
  end

  def check_id
    if symbol && symbol.split(".").first != provider.symbol
      errors.add(:symbol, ", Your Client ID must include the name of your provider. Separated by a dot '.' ")
    end
  end

  def user_url
    ENV["VOLPINO_URL"] + "/users?client-id=" + symbol.downcase
  end

  private

  def set_defaults
    self.domains = "*" unless domains.present?
    self.client_type = "repository" if client_type.blank?
    self.issn = {} if issn.blank? || client_type == "repository"
    self.certificate = [] if certificate.blank? || client_type == "periodical"
    self.repository_type = [] if repository_type.blank? || client_type == "periodical"
    self.is_active = is_active ? "\x01" : "\x00"
    self.version = version.present? ? version + 1 : 0
    self.role_name = "ROLE_DATACENTRE" unless role_name.present?
    self.doi_quota_used = 0 unless doi_quota_used.to_i > 0
    self.doi_quota_allowed = -1 unless doi_quota_allowed.to_i > 0
  end
end
