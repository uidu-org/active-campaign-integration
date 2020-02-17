module ActiveCampaignIntegration
  class CreateEventJob < ApplicationJob
    queue_as 'crm.fifo'

    def perform(user, event_name, event_value = nil, _timestamp = Time.now.to_i)
      ac = ActiveCampaignIntegration.new
      ac.trigger_event(user, event_name, event_value)
    end
  end
end
