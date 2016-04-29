require 'spec_helper'

describe JFlow::Activity::Definition do
  let(:swf_client) { JFlow.configuration.swf_client = Aws::SWF::Client.new(stub_responses: true) }

  before(:each) do
    swf_client.stub_data(:list_domains)
    swf_client.stub_data(:list_activity_types)
    allow(swf_client).to receive(:register_activity_type)
    allow(JFlow.configuration.activity_map).to receive(:add_activity)
  end

  let(:definition) do
    JFlow::Activity::Definition.new(klass, args)
  end

  let(:activity_types) do
    double(:activity_types, :type_infos => [])
  end

  let(:klass) { "Foo" }

  let(:args) do
    {
      :name => "Foo",
      :version => "1.0",
      :domain => "foo",
      :default_task_list => {
        :name => "tasklist"
      }
    }
  end

  describe "#initialize" do
  end

  describe "#name" do
    it "should return the proper name" do
      expect(definition.name).to eq "Foo"
    end
  end

  describe "#version" do
    it "should return the proper version" do
      expect(definition.version).to eq "1.0"
    end
  end

  describe "#add_to_activity_mapping" do
    it "should register the activity to the mapping" do
      definition
      expect(JFlow.configuration.activity_map).to have_received(:add_activity)
                                              .with("Foo",
                                                    "1.0",
                                                    "Foo",
                                                    {:name=>"Foo",
                                                     :version=>"1.0",
                                                     :domain=>"foo",
                                                     :default_task_list=>{:name=>"tasklist"},
                                                     :exceptions_to_exclude=>[]
                                                    })
    end
  end

  describe "#register_activity" do
    it "should register the activity to SWF" do
      definition
      expect(JFlow.configuration.swf_client).to have_received(:register_activity_type)
                                              .with({
                                                :name=>"Foo",
                                                :version=>"1.0",
                                                :domain=>"foo",
                                                :default_task_list=>{:name=>"tasklist"}
                                              })
    end
  end

end
