# frozen_string_literal: true

module ActiveCampaignIntegration
  module Jobs
    class UpdateCustomValueJob < ApplicationJob
      queue_as ActiveCampaignIntegration.queue_name

      discard_on ActiveJob::DeserializationError

      def perform(remote_contact, custom_value, _timestamp = Time.now.to_i)
        # Do something later
        ActiveCampaignIntegration.update_custom_value(remote_contact, custom_value)
      end
    end
  end
end
