# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: lib/inspec/reporters/inspec.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "inspec.proto.TestResult" do
    optional :status, :string, 1
    optional :code_desc, :string, 2
    optional :run_time, :float, 3
    optional :start_time, :string, 4
    optional :resource, :string, 5
    optional :message, :string, 20
    optional :skip_message, :string, 21
    optional :exception, :string, 22
    repeated :backtrace, :string, 23
  end
  add_message "inspec.proto.ControlResults" do
    optional :id, :string, 1
    repeated :results, :message, 2, "inspec.proto.TestResult"
    optional :checksum, :string, 3
  end
  add_message "inspec.proto.ProfileResults" do
    optional :id, :string, 1
    optional :name, :string, 2
    optional :version, :string, 3
    optional :sha256, :string, 4
    repeated :controls, :message, 5, "inspec.proto.ControlResults"
    optional :skip_message, :string, 6
  end
  add_message "inspec.proto.Results" do
    repeated :profiles, :message, 1, "inspec.proto.ProfileResults"
  end
end

module Inspec
  module Proto
    TestResult = Google::Protobuf::DescriptorPool.generated_pool.lookup("inspec.proto.TestResult").msgclass
    ControlResults = Google::Protobuf::DescriptorPool.generated_pool.lookup("inspec.proto.ControlResults").msgclass
    ProfileResults = Google::Protobuf::DescriptorPool.generated_pool.lookup("inspec.proto.ProfileResults").msgclass
    Results = Google::Protobuf::DescriptorPool.generated_pool.lookup("inspec.proto.Results").msgclass
  end
end
