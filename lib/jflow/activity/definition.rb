module JFlow
  module Activity
    class Definition

      DEFAULT_OPTIONS = {
        :exceptions_to_exclude => []
      }

      REGISTRATION_OPTIONS = %i(version domain name default_task_list)

      OPTIONS_VALIDATOR = {
        :version => "string",
        :domain  => "string",
        :name    => "string",
        :default_task_list => {
          :name => "string"
        },
        :exceptions_to_exclude => 'array'
      }

      attr_reader :options, :klass

      # Possible options are :
      # domain: "DomainName", # required
      # name: "Name", # required
      # version: "Version", # required
      # description: "Description",
      # default_task_start_to_close_timeout: "DurationInSecondsOptional",
      # default_task_heartbeat_timeout: "DurationInSecondsOptional",
      # default_task_list: {
      #   name: "Name", # required
      # },
      # default_task_priority: "TaskPriority",
      # default_task_schedule_to_start_timeout: "DurationInSecondsOptional",
      # default_task_schedule_to_close_timeout: "DurationInSecondsOptional",
      def initialize(klass, options = {})
        @klass = klass
        @options = DEFAULT_OPTIONS.merge(options)
        @options[:name] = name
        validate_activity!
        register_activity unless registered?
        add_to_activity_mapping
      end

      def register_activity
        JFlow.configuration.swf_client.register_activity_type(registration_options)
        JFlow.configuration.logger.info "Activity #{name} was registered successfuly"
      end

      def add_to_activity_mapping
        JFlow.configuration.activity_map.add_activity(name, options[:version], klass, options)
      end

      def name
        @options[:name] || klass.name.to_s.split('::').last.scan(/[A-Z][a-z]*/).join("_").downcase
      end

      def version
        @options[:version]
      end

      def domain
        JFlow::Domain.new(options[:domain])
      end

      def registered?
        response = JFlow.configuration.swf_client.list_activity_types({
          domain: domain.domain_name,
          name: name,
          registration_status: "REGISTERED"
        })

        response.type_infos.each do |type_info|
          if type_info.activity_type.name == name && type_info.activity_type.version == version
            JFlow.configuration.logger.info "Activity #{name} #{version} is already registered"
            return true
          end
        end

        return false
      end

      private

      def registration_options
        REGISTRATION_OPTIONS.each_with_object({}) do |key, hash|
          hash[key] = @options[key]
        end
      end

      def validate_activity!
        validator = HashValidator.validate(@options, OPTIONS_VALIDATOR)
        raise "Activity #{options[:name]}definition is invalid! #{validator.errors}" unless validator.valid?
      end

    end
  end
end
