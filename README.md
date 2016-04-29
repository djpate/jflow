# Jflow

[![Build Status](https://travis-ci.org/djpate/jflow.svg?branch=master)](https://travis-ci.org/djpate/jflow)

JFlow is a gem that aims to let you start SWF flow activity workers for JRuby.

The official framework uses Forking and thus not compatible with the JVM. This aims to give an alternative for Jruby.

*For now this only works for Activities and not workflows*

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jflow'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jflow

## Usage

### Create an Activity

```ruby
Class FooActivity
  include JFlow::Activity::Mixin

  activity "policy_scan.run" do
    {
      domain: "alexandria-development",
      default_task_list: {
        name: "xray_activity_tasklist"
      },
      version: "1.4",
      default_task_schedule_to_start_timeout: "600",
      default_task_schedule_to_close_timeout: "600",
      default_task_start_to_close_timeout: "600",
      default_task_heartbeat_timeout: "600",
      exceptions_to_exclude: [PermanentError]
    }
  end

  def run
    "foo"
  end
end
```

### Launch the workers

This gem provides you with a binary called jflow_worker. This binary requires a json configuration file.

```bash
jflow_worker -f worker.json
```

Example of a worker.json
```json
{
  "domain": "foodomain",
  "tasklist": "footasklist",
  "number_of_workers": 100,
  "activities_path": ["/home/pate/git/foobar/lib/flow/activities"]
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/djpate/jflow.

