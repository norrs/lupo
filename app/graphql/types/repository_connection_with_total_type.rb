# frozen_string_literal: true

class RepositoryConnectionWithTotalType < BaseConnection
  edge_type(RepositoryEdgeType)
  field_class GraphQL::Cache::Field
  
  field :total_count, Integer, null: true, cache: true
  field :years, [FacetType], null: true, cache: true
  field :members, [FacetType], null: true, cache: true
  field :software, [FacetType], null: true, cache: true
  field :certificates, [FacetType], null: true, cache: true
  field :clientTypes, [FacetType], null: true, cache: true
  field :repositoryTypes, [FacetType], null: true, cache: true

  def total_count
    object.total_count
  end

  def years
    object.total_count.positive? ? facet_by_year(object.aggregations.years.buckets) : nil
  end

  def members
    object.total_count.positive? ? facet_by_combined_key(object.aggregations.providers.buckets) : nil
  end

  def software
    object.total_count.positive? ? facet_by_software(object.aggregations.software.buckets) : nil
  end

  def certificates
    object.total_count.positive? ? facet_by_key(object.aggregations.certificates.buckets) : nil
  end

  def client_types
    object.total_count.positive? ? facet_by_key(object.aggregations.client_types.buckets) : nil
  end

  def repository_types
    object.total_count.positive? ? facet_by_key(object.aggregations.repository_types.buckets) : nil
  end
end