# frozen_string_literal: true

module ActiveCampaignIntegration
  module Jobs
    class SyncJob < ApplicationJob
      queue_as ActiveCampaignIntegration.queue_name

      discard_on ActiveJob::DeserializationError
      # discard_on ::Aws::SQS::Errors::InvalidParameterValue

      def perform(user, _timestamp = Time.now.to_i)
        # Do something later
        ActiveCampaignIntegration.sync_custom_values(user)
      end
    end
  end
end
