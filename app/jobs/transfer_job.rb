class TransferJob < ActiveJob::Base
  queue_as :lupo_transfer

  # retry_on ActiveRecord::RecordNotFound, wait: 10.seconds, attempts: 3
  # retry_on Faraday::TimeoutError, wait: 10.minutes, attempts: 3

  # discard_on ActiveJob::DeserializationError

  def perform(doi_id, options={})
    doi = Doi.where(doi: doi_id).first

    if doi.present? && options[:target_id].present?
      doi.update_attributes(repository_id: options[:target_id])

      doi.__elasticsearch__.index_document

      Rails.logger.info "[Transfer] Transferred DOI #{doi.doi}."
    elsif doi.present?
      Rails.logger.error "[Transfer] Error transferring DOI " + doi_id + ": no target client"
    else
      Rails.logger.error "[Transfer] Error transferring DOI " + doi_id + ": not found"
    end
  end
end
