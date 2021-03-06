# frozen_string_literal: true

class RepositoryPrefixConnectionWithTotalType < BaseConnection
  edge_type(RepositoryPrefixEdgeType)
  field_class GraphQL::Cache::Field
  
  field :total_count, Integer, null: false, cache: true
  field :years, [FacetType], null: false, cache: true

  def total_count
    object.total_count
  end

  def years
    facet_by_year(object.aggregations.years.buckets)
  end
end
