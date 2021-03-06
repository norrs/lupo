# frozen_string_literal: true

class DescriptionType < BaseObject
  description "Information about descriptions"

  field :description, String, null: true, description: "Description"
  field :description_type, String, null: true, hash_key: "descriptionType", description: "Description type"
  field :lang, ID, null: true, description: "Language"
end
