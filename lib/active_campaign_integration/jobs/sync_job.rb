module ActiveCampaignIntegration
  class SyncJob < ApplicationJob
    queue_as 'crm.fifo'

    discard_on ActiveJob::DeserializationError

    def perform(user, _timestamp)
      puts "Sync for user #{user.id}"
      # Do something later
      ac = ActiveCampaignIntegration.new
      ac.sync_custom_values(user)
    end
  end
end
