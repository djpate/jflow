module JFlow
  module Activity
    class Task
      # From: http://docs.aws.amazon.com/amazonswf/latest/apireference/API_FailWorkflowExecutionDecisionAttributes.html
      MAX_DETAILS_SIZE = 32768
      MAX_REASON_SIZE = 256

      TRUNCATION_IDENTIFIER = '[TRUNCATED]'

      attr_reader :task

      def initialize(task)
        @task = task
      end

      def input
        YAML.load(task.input)
      end

      def name
        task.activity_type.name
      end

      def version
        task.activity_type.version
      end

      def token
        task.task_token
      end

      def run_id
        task.workflow_execution.run_id
      end

      def workflow_id
        task.workflow_execution.workflow_id
      end

      def klass
        @klass_value ||= JFlow.configuration.activity_map.klass_for(name,version)
        raise "Could not find code to run for given activity" unless @klass_value
        @klass_value
      end

      def definition_options
        @definition_options ||= JFlow.configuration.activity_map.options_for(name,version)
        raise "Could not find activity definition for #{name}, #{version}" unless @definition_options
        @definition_options
      end

      def method
        if name.split('.').size > 1
          method = name.split('.').last
        else
          method = "process"
        end
      end

      def run!
        log "Started #{klass}##{method} with #{input}"

        result = klass.new.send(method, *input) || "done"
        log "Result is #{result.class} #{result}"
        completed!(result)
      end

      def completed!(result)
        log "Task Completed"
        swf_client.respond_activity_task_completed({
          task_token: token,
          result: result,
        })
      end

      def failed!(exception)
        log "Task Failed #{exception.message}"

        reason = truncate(exception.message, MAX_REASON_SIZE)

        if retryable?(exception)
          converted_exception = StandardError.new(exception.message)
          converted_exception.set_backtrace(exception.backtrace)
        else
          converted_exception = RuntimeError.new(exception.message)
          converted_exception.set_backtrace(exception.backtrace)
        end

        swf_client.respond_activity_task_failed(
          task_token: token,
          reason: reason,
          details: truncate(YAML.dump_stream(converted_exception, exception.backtrace), MAX_DETAILS_SIZE)
        )
      end

      private

      def retryable?(exception)
        !definition_options[:exceptions_to_exclude].include?(exception.class)
      end

      def truncate(message, max_length)
        return message unless message.length > max_length

        tail_room = max_length - TRUNCATION_IDENTIFIER.length

        "#{message[0, tail_room]}#{TRUNCATION_IDENTIFIER}"
      end

      def swf_client
        JFlow.configuration
             .swf_client
      end

      def log(str)
        JFlow.configuration.logger.info "[#{Thread.current.object_id}] #{str}"
      end
    end
  end
end
