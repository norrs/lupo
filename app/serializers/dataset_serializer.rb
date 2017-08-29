class DatasetSerializer < ActiveModel::Serializer
  # include helper module for extracting identifier
  type "works"
  include Identifiable

  # include metadata helper methods
  include Metadatable


  attributes   :doi, :url, :version, :datacenter_id, :is_active, :created, :minted, :updated
  attribute    :datacenter_id
  belongs_to :datacenter, serializer: DatacenterSerializer
  # [:doi, :url, :datacenter_id, :version, :datacentre, :is_active, :created, :deposited, :updated].map{|a| attribute(a) {object[:_source][a]}}


  def id
    object.uid.downcase
  end
  #
  #
  # def deposited
  #   object.minted
  # end
  #
  # def datacenter
  #   object.datacenter[:symbol]
  # end
  #
  # def datacenter_id
  #   object.datacenter[:symbol].downcase
  # end
  #
  # def updated
  #   object.updated.iso8601
  # end
  #
  # def created
  #   object.created.iso8601
  # end

end
