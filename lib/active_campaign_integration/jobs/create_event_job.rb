# frozen_string_literal: true

module ActiveCampaignIntegration
  module Jobs
    class CreateEventJob < ApplicationJob
      queue_as ActiveCampaignIntegration.queue_name

      discard_on ActiveJob::DeserializationError

      def perform(user, event_name, event_value = nil, _timestamp = Time.now.to_i)
        ActiveCampaignIntegration.trigger_event(user, event_name, event_value)
      end
    end
  end
end
