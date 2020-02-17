module ActiveCampaignIntegration
  class UpdateCustomValueJob < ApplicationJob
    queue_as 'crm.fifo'

    def perform(remote_contact, custom_value, _timestamp)
      # Do something later
      ac = ActiveCampaignIntegration.new
      ac.update_custom_value(remote_contact, custom_value)
    end
  end
end
