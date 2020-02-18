# frozen_string_literal: true

require 'active_campaign_integration/railtie'

module ActiveCampaignIntegration
  module Jobs
    autoload :CreateCustomValueJob, 'active_campaign_integration/jobs/create_custom_value_job'
    autoload :CreateEventJob, 'active_campaign_integration/jobs/create_event_job'
    autoload :SyncJob, 'active_campaign_integration/jobs/sync_job'
    autoload :UpdateCustomValueJob, 'active_campaign_integration/jobs/update_custom_value_job'
  end

  mattr_accessor :base_url
  @@base_url = nil

  mattr_accessor :api_token
  @@api_token = nil

  # method to be called on model to get custom_fields
  mattr_accessor :custom_fields_getter
  @@custom_fields_getter = :custom_fields_getter

  mattr_accessor :evt_key
  @@evt_key = nil

  mattr_accessor :evt_act_id
  @@evt_act_id = nil

  mattr_accessor :queue_name
  @@queue_name = nil

  def self.setup
    yield self
  end

  def self.fetch(request, url, params = nil)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request['Api-Token'] = @@api_token
    request.body = params.to_json if params
    response = http.request(request)
    JSON.parse(response.body)
  end

  def self.get(url)
    request = Net::HTTP::Get.new(url)
    fetch(request, url)
  end

  def self.delete(url)
    request = Net::HTTP::Delete.new(url)
    fetch(request, url)
  end

  def self.post(url, params)
    request = Net::HTTP::Post.new(url)
    fetch(request, url, params)
  end

  def self.put(url, params)
    request = Net::HTTP::Post.new(url)
    fetch(request, url, params)
  end

  def self.custom_field_list(params = nil)
    url = URI("#{@@base_url}/fields#{params ? "?#{CGI.unescape(params.to_param)}" : ''}")
    get(url)
  end

  def self.create_or_update_contact(user)
    url = URI("#{@@base_url}/contact/sync")

    params = {
      contact: {
        email: user.email
      }
    }

    params[:contact][:firstName] = user.first_name if user.first_name
    params[:contact][:lastName] = user.last_name if user.last_name

    post(url, params)
  end

  def self.trigger_event(user, event_name, event_value = nil)
    url = URI('https://trackcmp.net/event')
    params = {
      'visit[email]' => user.email,
      key: @@evt_key,
      event: event_name,
      eventdata: event_value,
      actid: @@evt_act_id
    }
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.set_form_data(params)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def self.get_remote_contact(user)
    remote_contact = create_or_update_contact(user)
    if remote_contact && remote_contact['contact']
      remote_contact_id = create_or_update_contact(user)['contact']['id']
      url = URI("#{@@base_url}/contacts/#{remote_contact_id}")
      get(url)
    end
  end

  def self.create_custom_value(remote_contact, custom_value)
    url = URI("#{@@base_url}/fieldValues")
    params = {
      fieldValue: custom_value.merge!(contact: remote_contact['contact']['id'].to_i)
    }
    post(url, params)
  end

  def self.create_custom_values(user, remote_contact)
    return unless remote_contact['fieldValues']

    to_be_created = custom_values_hash(
      user,
      'remove',
      remote_contact['fieldValues'].map { |f| f['field'].to_i }
    )
    to_be_created.each do |k|
      ActiveCampaignIntegration::Jobs::CreateCustomValueJob.perform_later(remote_contact, k, Time.now.to_i)
    end
  end

  def self.update_custom_value(remote_contact, custom_field)
    url = URI("#{@@base_url}/fieldValues/#{custom_field[:id]}")
    params = {
      fieldValue: {
        contact: remote_contact['contact']['id'].to_i,
        value: custom_field[:value],
        field: custom_field[:field].to_i
      }
    }
    put(url, params)
  end

  def self.update_custom_values(user, remote_contact)
    to_be_updated = custom_values_hash(
      user,
      'only',
      remote_contact['fieldValues']
    )
    to_be_updated.each do |k|
      ActiveCampaignIntegration::Jobs::UpdateCustomValueJob.perform_later(remote_contact, k, Time.now.to_i)
    end
  end

  def self.create_tag(user, tag_id)
    remote_contact = get_remote_contact(user)
    return unless remote_contact

    params = {
      contactTag: {
        tag: tag_id,
        contact: remote_contact['contact']['id'].to_i
      }
    }

    url = URI("#{@@base_url}/contactTags")
    post(url, params)
  end

  def self.sync_custom_values(user)
    remote_contact = get_remote_contact(user)
    return unless remote_contact

    update_custom_values(user, remote_contact)
    create_custom_values(user, remote_contact)
  end

  def self.custom_values_hash(
    user,
    select_or_filter = 'only',
    select_or_filter_list = []
  )
    list = user.send(@@custom_fields_getter)

    if select_or_filter == 'remove'
      list = list.reject do |elem|
        select_or_filter_list.include?(elem[:field])
      end
    else
      list = list.select do |elem|
        select_or_filter_list.map { |f| f['field'] }.include?(elem[:field].to_s)
      end
      cleaned_list = []
      list.each do |elem|
        el = select_or_filter_list.select do |f|
          f['field'] == elem[:field].to_s
        end
        if elem[:value].to_s == el[0]['value']
          # skip update for same value
          puts "Skipped #{elem[:field]}"
          nil
        else
          cleaned_list << elem.merge!(id: el[0]['id'])
        end
      end
      list = cleaned_list
    end
    list
  end
end
