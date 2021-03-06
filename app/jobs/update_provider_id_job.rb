class UpdateProviderIdJob < ActiveJob::Base
  queue_as :lupo_transfer

  # retry_on ActiveRecord::RecordNotFound, wait: 10.seconds, attempts: 3
  # retry_on Faraday::TimeoutError, wait: 10.minutes, attempts: 3

  # discard_on ActiveJob::DeserializationError

  def perform(doi_id, options = {})
    doi = Doi.where(doi: doi_id).first

    if doi.present? && options[:provider_target_id].present?
      doi.__elasticsearch__.index_document

      Rails.logger.warn "[Transfer] updated DOI #{doi.doi}."
    elsif doi.present?
      Rails.logger.error "[Transfer] Error updateding DOI " + doi_id + ": no target client"
    else
      Rails.logger.error "[Transfer] Error updateding DOI " + doi_id + ": not found"
    end
  end
end
