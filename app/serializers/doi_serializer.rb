class DoiSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :camel_lower
  set_type :dois
  set_id :uid

  attributes :doi, :prefix, :suffix, :identifier, :creator, :titles, :publisher, :periodical, :publication_year, :subjects, :contributor, :dates, :language, :types, :alternate_identifiers, :related_identifiers, :sizes, :formats, :version, :rights_list, :descriptions, :geo_locations, :funding_references, :xml, :url, :content_url, :metadata_version, :schema_version, :source, :state, :reason, :landing_page, :created, :registered, :updated
  attributes :prefix, :suffix, if: Proc.new { |record, params| params && params[:detail]}

  belongs_to :client, record_type: :clients
  has_many :media

  attribute :xml, if: Proc.new { |record, params| params && params[:detail] } do |record|
    record.xml_encoded
  end

  attribute :doi do |object|
    object.doi.downcase
  end

  attribute :version do |object|
    object.version_info
  end

  attribute :landing_page do |object|
    { status: object.last_landing_page_status,
      contentType: object.last_landing_page_content_type,
      checked: object.last_landing_page_status_check,
      result: object.try(:last_landing_page_status_result) }
  end
end
