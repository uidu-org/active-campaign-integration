# frozen_string_literal: true

module ActiveCampaignIntegration
  class CreateCustomValueJob < ApplicationJob
    queue_as 'crm.fifo'

    def perform(remote_contact, custom_value, _timestamp)
      # Do something later
      ac = ActiveCampaignIntegration.new
      ac.create_custom_value(remote_contact, custom_value)
    end
  end
end
