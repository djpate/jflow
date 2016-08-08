module JFlow
  class Cli

    VALIDATION = {
      "number_of_workers" => "integer",
      "domain"            => "string",
      "tasklist"          => "string",
      "activities_path"   => "array"
    }

    attr_reader :number_of_workers, :domain, :tasklist, :worker_threads, :activities_path, :enable_stats

    def initialize(options)
      validate_options(options)
      @number_of_workers  = options["number_of_workers"]
      @domain             = options["domain"]
      @tasklist           = options["tasklist"]
      @activities_path    = options["activities_path"]
      @enable_stats       = options["enable_stats"] || true
      @worker_threads     = []
      setup
    end

    def start_workers
      number_of_workers.times do
        worker_threads << worker_thread
      end
      worker_threads << maintenance_thread if enable_stats || is_ec2_instance?
      worker_threads.each(&:join)
    end

    # here we want to handle all cases for clean kill of the workers.
    # there is two state on which the workers can be
    # - Polling : they are not working on anything and are just waiting for a task
    # - Working : they are processing an activity right now
    #
    # for Polling, we cannot stop it in flight, so we send a signal to stop
    # polling after the current long poll finishes, IF it picks up anything in the mean time
    # the activity will be force failed
    #
    # for Working, we give a grace period of 60 seconds to finish otherwise we just send
    # an exception to the thread to force the failure.
    #
    # Shutting down workers will take a exactly 60 secs in all cases.
    def shutdown_workers
      log "Sending kill signal to running threads. Please wait for current polling to finish"
      worker_threads.each do |thread|
        thread.mark_for_shutdown
        if thread.currently_working? && thread.alive?
          thread.raise("Workers are going down!")
        end
      end
    end

    private

    def setup
      JFlow.configure do |c|
        c.load_paths = activities_path
        c.swf_client = Aws::SWF::Client.new
        c.cloudwatch_client = Aws::CloudWatch::Client.new
      end
      JFlow.load_activities
    end

    def maintenance_thread
      JFlow::WorkerThread.new do
        Thread.current.set_state(:polling)
        stats = JFlow::Stats.new(@domain, @tasklist)
        protector = JFlow::TerminationProtector.new
        loop do
          break if Thread.current.marked_for_shutdown?
          begin
            protector.set_protection(should_protect?) if is_ec2_instance?
            stats.tick if enable_stats
            sleep 30
          rescue => e
            JFlow.handle_exception(e)
            sleep 180
          end
        end
      end
    end

    # returns true if any thread if working on someting
    def should_protect?
      worker_threads.each do |thread|
        return true if thread.currently_working?
      end
      return false
    end

    # This should exist on all EC2 instances
    def is_ec2_instance?
      @ec2_instance ||= File.exist?('/sys/hypervisor/uuid')
    end

    def log(str)
      JFlow.configuration.logger.info str
    end

    def worker_thread
      JFlow::WorkerThread.new do
        worker.start!
      end
    end

    def worker
      JFlow::Activity::Worker.new(domain, tasklist)
    end

    def validate_options(options)
      validator = HashValidator.validate(options, VALIDATION)
      raise "configuration is invalid! #{validator.errors}" unless validator.valid?
    end

  end
end
