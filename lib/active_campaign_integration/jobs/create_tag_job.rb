# frozen_string_literal: true

module ActiveCampaignIntegration
  module Jobs
    class CreateTagJob < ApplicationJob
      queue_as ActiveCampaignIntegration.queue_name

      discard_on ActiveJob::DeserializationError

      def perform(user, tag_id, _timestamp = Time.now.to_i)
        ActiveCampaignIntegration.create_tag(user, tag_id)
      end
    end
  end
end
