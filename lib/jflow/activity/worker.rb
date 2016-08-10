module JFlow
  module Activity
    class Worker

      attr_reader :domain, :tasklist

      def initialize(domain, tasklist)
        @domain = domain
        @tasklist = tasklist
      end

      def start!
        while should_be_working?
          log "Polling for task on #{domain} - #{tasklist}"
          begin
            poll
          rescue => e
            JFlow.configuration.logger.error e.message
          end
        end
        log "Thread is marked as exiting, stopping the poll"
      end


      def poll
        Thread.current.set_state(:polling)
        response = JFlow.configuration.swf_client.poll_for_activity_task(poll_params)
        if response.task_token
          task = JFlow::Activity::Task.new(response)
          log "Got task #{task.workflow_id}-#{task.run_id}"
          if should_be_working?
            process(task)
          else
            #The worker is shuting down, we don't want to start working on anything
            #so we fail the task and let the decider queue it up for retry later
            task.failed!(Exception.new("Worker is going down!"))
          end
        else
          log "Got no task"
        end
      end

      def process(task)
        begin
          Thread.current.set_state(:working)
          task.run!
        rescue => exception
          Thread.current.set_state(:polling)
          task.handle_exception(exception)
          task.failed!(exception)
        end
      end

      private

      def identity
        @identity ||= "#{`hostname`.chomp}-#{Thread.current.object_id}"
      end

      def log(str)
        JFlow.configuration.logger.info "[#{Thread.current.object_id}] #{str}"
      end

      def poll_params
        {
          domain: domain,
          task_list: {
            name: tasklist,
          },
          identity: identity,
        }
      end

      def should_be_working?
        !Thread.current.marked_for_shutdown?
      end

    end
  end
end
