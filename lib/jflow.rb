require "yaml"
require "json"
require "hash_validator"
require 'aws-sdk'
require 'logger'
require 'jflow_exceptions'
require "jflow/version"
require "jflow/configuration.rb"
require "jflow/domain.rb"
require "jflow/activity/definition.rb"
require "jflow/activity/mixin.rb"
require "jflow/activity/task.rb"
require "jflow/activity/map.rb"
require "jflow/activity/worker.rb"
require "jflow/worker_thread.rb"
require "jflow/termination_protector.rb"
require "jflow/stats.rb"
require "jflow/cli.rb"

module JFlow
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.load_activities
    configuration.load_paths.each do |path|
      path = File.join(ENV['APP_ROOT'], path) if ENV['APP_ROOT']
      Dir["#{path}/*.rb"].each do |file|
        configuration.logger.debug "found #{file}"
        require file
      end
    end
  end

  def self.handle_exception(exception)
    JFlow.configuration.error_handlers.each do |error_handler|
      begin
        error_handler.call(exception)
      rescue => e
        log_error("Error handler failed!")
        log_error(e.backtrace.join("\n")) unless e.backtrace.nil?
      end
    end
  end

  def self.log_error(str)
    JFlow.configuration.logger.error "[#{Thread.current.object_id}] #{str}"
  end
end
