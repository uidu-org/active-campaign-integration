require "active_campaign_integration/version"

module ActiveCampaignIntegration
  class Error < StandardError; end
  # Your code goes here...

  def initialize
    @base_url = 'https://jobpricing.api-us1.com/api/3'
  end

  def fetch(request, url, params = nil)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request['Api-Token'] = 'ebf1c07ce8bf9a71d46bbf92d8c987f4134a67bf8d4a8e741659b7d8219ab7c2b73c1c96'
    request.body = params.to_json if params
    response = http.request(request)
    JSON.parse(response.body)
  end

  def get(url)
    request = Net::HTTP::Get.new(url)
    fetch(request, url)
  end

  def delete(url)
    request = Net::HTTP::Delete.new(url)
    fetch(request, url)
  end

  def post(url, params)
    request = Net::HTTP::Post.new(url)
    fetch(request, url, params)
  end

  def put(url, params)
    request = Net::HTTP::Post.new(url)
    fetch(request, url, params)
  end

  def custom_field_list(params = nil)
    url = URI("#{@base_url}/fields#{params ? "?#{CGI.unescape(params.to_param)}" : ''}")
    get(url)
  end

  def create_or_update_contact(user)
    url = URI("#{@base_url}/contact/sync")

    params = {
      contact: {
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        phone: nil
      }
    }

    post(url, params)
  end

  def trigger_event(user, event_name, event_value = nil)
    url = URI('https://trackcmp.net/event')
    params = {
      'visit[email]' => user.email,
      key: '380b9ea546783a3d8a0f87467a0ffa26a7f094e5',
      event: event_name,
      eventdata: event_value,
      actid: '89861744'
    }
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.set_form_data(params)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def get_remote_contact(user)
    remote_contact = create_or_update_contact(user)
    if remote_contact && remote_contact['contact']
      remote_contact_id = create_or_update_contact(user)['contact']['id']
      url = URI("#{@base_url}/contacts/#{remote_contact_id}")
      get(url)
    end
  end

  def create_custom_value(remote_contact, custom_value)
    url = URI("#{@base_url}/fieldValues")
    params = {
      fieldValue: custom_value.merge!(contact: remote_contact['contact']['id'].to_i)
    }
    post(url, params)
  end

  def create_custom_values(user, remote_contact)
    to_be_created = custom_values_hash(
      user,
      'remove',
      remote_contact['fieldValues'].map { |f| f['field'].to_i }
    )
    to_be_created.each do |k|
      Crm::CreateCustomValueJob.perform_later(remote_contact, k, Time.now.to_i)
    end
  end

  def update_custom_value(remote_contact, custom_field)
    url = URI("#{@base_url}/fieldValues/#{custom_field[:id]}")
    params = {
      fieldValue: {
        contact: remote_contact['contact']['id'].to_i,
        value: custom_field[:value],
        field: custom_field[:field].to_i
      }
    }
    put(url, params)
  end

  def update_custom_values(user, remote_contact)
    to_be_updated = custom_values_hash(
      user,
      'only',
      remote_contact['fieldValues']
    )
    to_be_updated.each do |k|
      Crm::UpdateCustomValueJob.perform_later(remote_contact, k, Time.now.to_i)
    end
  end

  def sync_custom_values(user)
    remote_contact = get_remote_contact(user)
    return unless remote_contact

    update_custom_values(user, remote_contact)
    create_custom_values(user, remote_contact)
  end

  def custom_values_hash(
    user,
    select_or_filter = 'only',
    select_or_filter_list = []
  )
    # TODO: chiedere cosa sono questi e come pensano di tracciarli
    # ALL  A chi è assegnato?  Info ?
    # PRO  richiesta caricamento massivo  Info
    # PRO  Caricamento massivo avvenuto?  Info
    # Partner serve con nomi del CRM o basta stringa di testo?

    subscription = user.subscription
    plan = subscription&.plan
    product = plan&.product

    list = []

    # privacy
    list << { field: 381, value: user.cf_1273 ? 'Acconsento' : 'Non acconsento' }
    list << { field: 383, value: user.cf_1365 ? 'Acconsento' : 'Non acconsento' }

    # user confirmation
    list << { field: 379, value: user.confirmed? ? user.confirmed_at.strftime('%Y-%m-%d') : nil }

    if user.cf_1383
      # L'utente è stato aggiunto manualmente?
      list << { field: 273, value: user.cf_1383 ? 1 : 0 }
    end

    # plan info
    # Tipo di piano
    list << { field: 355, value: plan.name }
    list << { field: 357, value: product.name }
    # Data Attivazione piano
    list << { field: 356, value: subscription.created_at.strftime('%Y-%m-%d') }
    # Instant Partner  Piano con Partner  Info
    # list << { field: '', value: ''}

    if product.name == 'JPAnalytics PRO'
      # Data scadenza piano
      list << { field: 358, value: (subscription.stripe_current_period_end || subscription.finishes_at).strftime('%Y-%m-%d') }
      # Rinnovo automatico
      list << { field: 360, value: subscription.auto_renew? ? 1 : 0 }
      # Data aggiunta prima persona MyPeople
      if user.employees.count.positive?
        list << {
          field: 361,
          value: user.employees.first.created_at.strftime('%Y-%m-%d')
        }
      end
      # Quante persone ha su MyPeople?
      list << { field: 362, value: user.employees.count }
      # Quante persone ha aggiunto su MyPeople nell'ultimo periodo?
      list << {
        field: 363,
        value: user.employees.where('created_at >= ?', Time.now - 3.months).count
      }
      # Quante persone ha aggiunto a MyMarket nell'ultimo periodo?
      list << {
        field: 364,
        value: user.searches.where('created_at >= ?', Time.now - 3.months).count
      }
      # Quante schede ha scaricato da My Market nell'ultimo periodo?
      list << {
        field: 365,
        value: user.report_views.where('created_at >= ?', Time.now - 3.months).count
      }
    elsif product.name == 'Instant Benchmark'
      # Posizioni in carrello
      list << { field: 366, value: user.searches.in_cart.count }
      # InstantBenchmark - Primo Instant scaricato
      list << { field: 380, value: user.searches.paid.any? ? user.searches.paid.first.created_at.strftime('%Y-%m-%d') : nil }
      # InstantBenchmark - Numero schede generate
      list << { field: 368, value: user.searches.paid.count }
      # InstantBenchmark - Data acquisto ultima scheda
      if user.searches.paid.any?
        list << { field: 369, value: user.searches.paid.last.created_at.strftime('%Y-%m-%d') }
      end
      # Quanti Instant ha acquistato nell'ultimo periodo?
      list << {
        field: 370,
        value: user.searches.paid.where('created_at >= ?', Time.now - 3.months).count
      }
    end

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
