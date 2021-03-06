require 'spec_helper'

describe JFlow::Activity::Task do

  class FooActivity
  end

  class MockErrorService
    def self.capture_exception(e); end
  end

  class FooError < StandardError; end

  let(:mock_activity) do
    double(:activity,{
      :input => "--- foo\n",
      :task_token => "tokenbar",
      :activity_type => activity_type
    })
  end

  let(:activity_type) do
    double(:activity_type, {name: 'somename.somemethod', version: '1.0'})
  end

  let(:task) { JFlow::Activity::Task.new(mock_activity) }

  describe "#input" do
    it "should parse the input properly" do
      expect(task.input).to eq "foo"
    end
  end

  describe "#token" do
    it "should return token" do
      expect(task.token).to eq "tokenbar"
    end
  end

  describe "#name" do
    it "should return name" do
      expect(task.name).to eq "somename.somemethod"
    end
  end

  describe "#version" do
    it "should return version" do
      expect(task.version).to eq "1.0"
    end
  end

  describe "#klass" do
    it "should return the proper class if registered" do
      expect(JFlow.configuration.activity_map).to receive(:klass_for)
                                              .and_return("Foo")
      expect(task.klass).to eq "Foo"
    end

    it "should return raise if not found" do
      expect(JFlow.configuration.activity_map).to receive(:klass_for)
                                              .and_return(nil)
      expect{task.klass}.to raise_error RuntimeError, "Could not find code to run for given activity"
    end
  end

  describe "#method" do
    context "with specified method" do
      it "should return method if set" do
        expect(task.method).to eq "somemethod"
      end
    end
    context "with default" do
      let(:activity_type) do
        double(:activity_type, {name: 'somename', version: '1.0'})
      end
      it "should return the default method" do
        expect(task.method).to eq "process"
      end
    end
  end

  describe "#run!" do
    before(:each) do
      expect(JFlow.configuration.activity_map).to receive(:klass_for)
                                              .and_return(FooActivity)
    end
    it "should call the proper method on the expected class" do
      expect_any_instance_of(FooActivity).to receive(:somemethod)
      expect(task).to receive(:completed!)
      task.run!
    end
    it "should call completed with the right ouput" do
      expect_any_instance_of(FooActivity).to receive(:somemethod).and_return("result")
      expect(task).to receive(:completed!).with("result")
      task.run!
    end
    it "should call completed with the default string if none returned" do
      expect_any_instance_of(FooActivity).to receive(:somemethod)
      expect(task).to receive(:completed!).with("done")
      task.run!
    end
  end

  describe "#completed!" do
    it "should send the right signal to SWF" do
      expect(JFlow.configuration.swf_client).to receive(:respond_activity_task_completed)
                                            .with(:task_token => task.token, :result => "foo")
      task.completed!("foo")
    end
  end

  describe "#failed!" do
    context "exception to exclude" do
      before(:each) do
        expect(JFlow.configuration.activity_map).to receive(:options_for)
                                              .and_return({ exceptions_to_exclude: [FooError]})
      end

      let(:exception) do
        e = FooError.new("beer")
        e.set_backtrace(%w(n o w))
        e
      end

      it "should wrap exception types that are excluded as SignalException" do
        yaml_error = JFlow::Exceptions::Fatal.new(exception)

        expect(JFlow.configuration.swf_client).to receive(:respond_activity_task_failed)
                                              .with({
                                                :task_token => task.token,
                                                :reason => "beer",
                                                :details => YAML.dump_stream(yaml_error, yaml_error.backtrace)
                                              })
        task.failed!(exception)
      end
    end

    context "no exceptions to exclude" do
      before(:each) do
        expect(JFlow.configuration.activity_map).to receive(:options_for)
                                                .and_return({ exceptions_to_exclude: []})
      end

      context "short exception strings" do
        let(:exception){double(:exception,{ :message => "foo", :backtrace => ["b","a","r"]})}
        it "should send the right signal to SWF" do
          yaml_error = JFlow::Exceptions::Common.new(exception)

          expect(JFlow.configuration.swf_client).to receive(:respond_activity_task_failed)
                                                .with({
                                                  :task_token => task.token,
                                                  :reason => "foo",
                                                  :details => YAML.dump_stream(yaml_error, yaml_error.backtrace)
                                                })
          task.failed!(exception)
        end
      end

      context "exception messages that are too long" do
        let(:message) { "X" * 257 }
        let(:backtrace) { ["X" * 32769] }
        let(:exception) { double(:exception,{ :message => message, :backtrace => backtrace } ) }

        after { task.failed!(exception) }

        it "truncates and adds the truncate message" do
          long_yaml = "X" * 32769
          expect(YAML).to receive(:dump_stream).and_return("--- #{long_yaml}")

          expect(JFlow.configuration.swf_client).to receive(:respond_activity_task_failed)
            .with(
              :task_token => task.token,
              :reason => "#{'X' * 245}[TRUNCATED]",
              :details => "--- #{'X' * 32753}[TRUNCATED]"
            )
        end
      end
    end
  end

  describe "#handle_exception" do
    let(:exception) { double(:exception, { :message => 'message', :backtrace => 'backtrace' } ) }

    context 'error handlers configured' do
      before do
        JFlow.configuration.error_handlers <<
              Proc.new {|e| MockErrorService.capture_exception(e) }
      end

      it 'calls error handler' do
        expect(MockErrorService).to receive(:capture_exception).with(exception)

        task.handle_exception(exception)
      end
    end

    context 'error handler fails' do
      before do
        JFlow.configuration.error_handlers <<
              Proc.new {|e| fail('Handler error') }
      end

      it 'it logs error' do
        expect(JFlow.configuration.logger).to receive(:error).twice

        task.handle_exception(exception)
      end
    end
  end
end
