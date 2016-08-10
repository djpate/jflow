require 'spec_helper'

describe JFlow::TerminationProtector do
  subject { described_class.new(aws_autoscaling_client, aws_ec2_client) }
  let(:aws_autoscaling_client) { Aws::AutoScaling::Client.new(stub_responses: true) }
  let(:aws_ec2_client) { Aws::EC2::Client.new(stub_responses: true) }
  let(:instance_identity) do
    {
      "availabilityZone" => "us-west-2b",
      "instanceType" => "m3.large",
      "imageId" => "ami-464da726",
      "region" => "us-west-2",
      "instanceId" => "foobar"
    }.to_json
  end

  before do
    allow(Net::HTTP).to receive(:get).and_return(instance_identity)
    aws_ec2_client.stub_responses(:describe_tags, tags: [{key: 'aws:autoscaling:groupName', resource_id: 'foobar', resource_type: 'instance', value: 'some_asg_name'}])
  end

  describe "#set_protection" do
    context "call more than once" do
      it "set_instance_protection once for true" do
        expect(aws_autoscaling_client).to receive(:set_instance_protection).with({instance_ids: ['foobar'], auto_scaling_group_name: 'some_asg_name', protected_from_scale_in: true}).once
        subject.set_protection(true)
        subject.set_protection(true)
      end

      it "set_instance_protection once for false" do
        expected_slace_in_args = {instance_ids: ['foobar'], auto_scaling_group_name: 'some_asg_name', protected_from_scale_in: true}
        expected_scale_out_args = {instance_ids: ['foobar'], auto_scaling_group_name: 'some_asg_name', protected_from_scale_in: false}

        expect(aws_autoscaling_client).to receive(:set_instance_protection).with(expected_slace_in_args).once
        expect(aws_autoscaling_client).to receive(:set_instance_protection).with(expected_scale_out_args).once

        subject.set_protection(true)
        subject.set_protection(false)
        subject.set_protection(false)
      end
    end
  end
end
