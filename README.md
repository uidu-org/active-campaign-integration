# ActiveCampaignIntegration

ActiveCampaign allows updating and creating custom values for a contact, but it does so with single calls. This gem allows to selectively update only the custom values that changed since the last sync, and includes some ActiveJob helpers to do so asyncronously.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_campaign_integration'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install active_campaign_integration
```

## Usage

Setup you ActiveCampaign Integration with your user tokens. Puts this into an initializers `config/initializers/active_campaign_integration.rb`

```ruby
ActiveCampaignIntegration.setup do |config|
  config.base_url = ENV['AC_BASE_URL']
  config.api_token = ENV['AC_API_TOKEN']

  # user method to create the list of fields to pass to AC
  config.custom_fields_getter = :active_campaign_custom_fields
  config.queue_name = 'crm.fifo'
  config.evt_key = ENV['AC_API_EVT_KEY']
  config.evt_act_id = ENV['AC_API_EVT_ACT_ID']
end
```

In user model `user.rb`, define a method to create the list for AC. For instance:

```ruby
def active_campaign_custom_fields
  list = []

  # privacy
  list << { field: 381, value: self.cf_1273 ? 'Acconsento' : 'Non acconsento' }
  list << { field: 383, value: self.cf_1365 ? 'Acconsento' : 'Non acconsento' }
  list
end
```

Available jobs

| name                                     | params                                       |
| ---------------------------------------- | -------------------------------------------- |
| ActiveCampaignIntegration::Jobs::SyncJob | user                                         |
| ActiveCampaignIntegration::Jobs::SyncJob | user, event_name = 'test', event_value = nil |

Eg:

```ruby
  ActiveCampaignIntegration::Jobs::CreateEventJob.perform_later(current_user, 'JPAnalytics - MyPeople - Primo Dipendente', nil)
  ActiveCampaignIntegration::Jobs::SyncJob.perform_later(current_user)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/active_campaign_integration. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/active_campaign_integration/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveCampaignIntegration project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/active_campaign_integration/blob/master/CODE_OF_CONDUCT.md).
