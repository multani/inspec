#!/usr/bin/env rake

require "bundler"
require "bundler/gem_helper"
require "rake/testtask"
require "train"
require_relative "tasks/maintainers"
require_relative "tasks/spdx"
require "fileutils"

Bundler::GemHelper.install_tasks name: "inspec"

def prompt(message)
  print(message)
  STDIN.gets.chomp
end

# The docs tasks rely on ruby-progressbar. If we can't load it, then don't
# load the docs tasks. This is necessary to allow this Rakefile to work
# when the "tests" gem group in the Gemfile has been excluded, such as
# during an appbundle-updater run.
begin
  require "ruby-progressbar"
  require_relative "tasks/docs"
rescue LoadError
  puts "docs tasks are unavailable because the ruby-progressbar gem is not available."
end

begin
  require "git"
  require_relative "tasks/contrib"
rescue LoadError
  puts "contrib tasks are unavailable because the git gem is not available."
end

task :install do
  inspec_bin_path = ::File.join(::File.dirname(__FILE__), "inspec-bin")
  Dir.chdir(inspec_bin_path)
  sh("rake install")
end

GLOBS = [
  "test/unit/**/*_test.rb",
  "test/functional/**/*_test.rb",
  "lib/plugins/inspec-*/test/**/*_test.rb",
].freeze

# run tests
task default: ["test:lint", "test:default"]
task test: ["test:lint", "test:default"]

namespace :test do

  Rake::TestTask.new(:default) do |t|
    t.libs << "test"
    t.test_files = Dir[*GLOBS].sort
    t.warning = !!ENV["W"]
    t.verbose = !!ENV["V"] # default to off. the test commands are _huge_.
    t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
  end
  task default: [:accept_license]

  begin
    require "chefstyle"
    require "rubocop/rake_task"
    RuboCop::RakeTask.new(:lint) do |task|
      task.options += ["--display-cop-names", "--no-color", "--parallel"]
    end
  rescue LoadError
    puts "rubocop is not available. Install the rubocop gem to run the lint tests."
  end

  task :list do
    puts Dir[*GLOBS].sort
  end

  task :missing do
    missing = Dir["test/**/*"] - Dir[*GLOBS]

    missing.reject! { |f| ! File.file? f }
    missing.reject! { |f| f =~ %r{test/(integration|cookbooks)} }
    missing.reject! { |f| f =~ %r{test/unit/mock} }
    missing.reject! { |f| f =~ /test.*helper/ }
    missing.reject! { |f| f =~ %r{test/docker} }

    puts missing.sort
  end

  task :isolated do
    failures = Dir[*GLOBS]
    failures.reject! do |file|
      system(Gem.ruby, "-Ilib:test", file)
    end

    unless failures.empty?
      puts "These test files failed:\n"
      puts failures
      raise "broken tests..."
    end
  end

  task :accept_license do
    FileUtils.mkdir_p(File.join(Dir.home, ".chef", "accepted_licenses"))
    # If the user has not accepted the license, touch the acceptance
    # file, but also touch a marker that it is only for testing.
    unless File.exist?(File.join(Dir.home, ".chef", "accepted_licenses", "inspec"))
      puts "\n\nTemporarily accepting Chef user license for the duration of testing...\n"
      FileUtils.touch(File.join(Dir.home, ".chef", "accepted_licenses", "inspec"))
      FileUtils.touch(File.join(Dir.home, ".chef", "accepted_licenses", "inspec.for_testing"))
    end

    # Regardless of what happens, when this process exits, check for cleanup.
    at_exit do
      if File.exist?(File.join(Dir.home, ".chef", "accepted_licenses", "inspec.for_testing"))
        puts "\n\nRemoving temporary Chef user license acceptance file that was placed for test duration.\n"
        FileUtils.rm_f(File.join(Dir.home, ".chef", "accepted_licenses", "inspec"))
        FileUtils.rm_f(File.join(Dir.home, ".chef", "accepted_licenses", "inspec.for_testing"))
      end
    end
  end

  Rake::TestTask.new(:functional) do |t|
    t.libs << "test"
    t.test_files = Dir.glob([
      "test/functional/**/*_test.rb",
      "lib/plugins/inspec-*/test/functional/**/*_test.rb",
    ])
    t.warning = !!ENV["W"]
    t.verbose = !!ENV["V"] # default to off. the test commands are _huge_.
    t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
  end
  # Inject a prerequisite task
  task functional: [:accept_license]

  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.test_files = Dir.glob([
      "test/unit/**/*_test.rb",
      "lib/plugins/inspec-*/test/unit/**/*_test.rb",
    ])
    t.warning = !!ENV["W"]
    t.verbose = !!ENV["V"] # default to off. the test commands are _huge_.
    t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
  end
  # Inject a prerequisite task
  task unit: [:accept_license]

  task :resources do
    tests = Dir["test/unit/resource/*_test.rb"]
    return if tests.empty?

    sh(Gem.ruby, "test/docker_test.rb", *tests)
  end

  task :integration, [:os] do |task, args|
    concurrency = ENV["CONCURRENCY"] || 1
    os = args[:os] || ENV["OS"] || ""
    ENV["DOCKER"] = "true" if ENV["docker"].nil?
    sh("bundle exec kitchen test -c #{concurrency} #{os}")
  end
  # Inject a prerequisite task
  task 'integration': [:accept_license]

  task :ssh, [:target] do |_t, args|
    tests_path = File.join(File.dirname(__FILE__), "test", "integration", "test", "integration", "default")
    key_files = ENV["key_files"] || File.join(ENV["HOME"], ".ssh", "id_rsa")

    sh_cmd =  "bin/inspec exec #{tests_path}/"
    sh_cmd += ENV["test"] ? "#{ENV["test"]}_spec.rb" : "*"
    sh_cmd += " --sudo" unless args[:target].split("@")[0] == "root"
    sh_cmd += " -t ssh://#{args[:target]}"
    sh_cmd += " --key_files=#{key_files}"
    sh_cmd += " --format=#{ENV["format"]}" if ENV["format"]

    sh("sh", "-c", sh_cmd)
  end

  project_dir = File.dirname(__FILE__)
  namespace :aws do
    %w{default minimal}.each do |account|
      integration_dir = File.join(project_dir, "test", "integration", "aws", account)
      attribute_file = File.join(integration_dir, ".attribute.yml")

      task :"setup:#{account}", :tf_workspace do |t, args|
        tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
        abort("You must either call the top-level test:aws:#{account} task, or set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace
        puts "----> Setup"
        abort("You must set the environment variable AWS_REGION") unless ENV["AWS_REGION"]
        puts "----> Checking for required AWS profile..."
        sh("aws configure get aws_access_key_id --profile inspec-aws-test-#{account} > /dev/null")
        sh("cd #{integration_dir}/build/ && terraform init -upgrade")
        sh("cd #{integration_dir}/build/ && terraform workspace new #{tf_workspace}")
        sh("cd #{integration_dir}/build/ && AWS_PROFILE=inspec-aws-test-#{account} terraform plan -out inspec-aws-#{account}.plan")
        sh("cd #{integration_dir}/build/ && AWS_PROFILE=inspec-aws-test-#{account} terraform apply -auto-approve inspec-aws-#{account}.plan")
        Rake::Task["test:aws:dump_attrs:#{account}"].execute
      end

      task :"dump_attrs:#{account}" do
        sh("cd #{integration_dir}/build/ && AWS_PROFILE=inspec-aws-test-#{account} terraform output > #{attribute_file}")
        raw_output = File.read(attribute_file)
        yaml_output = raw_output.gsub(" = ", " : ")
        File.open(attribute_file, "w") { |file| file.puts yaml_output }
      end

      task :"run:#{account}" do
        puts "----> Run"
        sh("bundle exec inspec exec #{integration_dir}/verify -t aws://${AWS_REGION}/inspec-aws-test-#{account} --attrs #{attribute_file}")
      end

      task :"cleanup:#{account}", :tf_workspace do |t, args|
        tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
        abort("You must either call the top-level test:aws:#{account} task, or set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace
        puts "----> Cleanup"
        sh("cd #{integration_dir}/build/ && AWS_PROFILE=inspec-aws-test-#{account} terraform destroy -force")
        sh("cd #{integration_dir}/build/ && terraform workspace select default")
        sh("cd #{integration_dir}/build && terraform workspace delete #{tf_workspace}")
      end

      task :"#{account}" do
        tf_workspace = ENV["INSPEC_TERRAFORM_ENV"] || prompt("Please enter a workspace for your integration tests to run in: ")
        begin
          Rake::Task["test:aws:setup:#{account}"].execute({ tf_workspace: tf_workspace })
          Rake::Task["test:aws:run:#{account}"].execute
        rescue
          abort("Integration testing has failed for the #{account} account")
        ensure
          Rake::Task["test:aws:cleanup:#{account}"].execute({ tf_workspace: tf_workspace })
        end
      end
    end
  end
  desc "Perform AWS Integration Tests"
  task aws: %i{aws:default aws:minimal}

  namespace :azure do
    # Specify the directory for the integration tests
    integration_dir = File.join(project_dir, "test", "integration", "azure")
    tf_vars_file = File.join(integration_dir, "build", "terraform.tfvars")
    attribute_file = File.join(integration_dir, ".attribute.yml")

    task :setup, :tf_workspace do |t, args|
      tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
      abort("You must either call the top-level test:azure task, or set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace

      puts "----> Setup Terraform Workspace"

      sh("cd #{integration_dir}/build/ && terraform init -upgrade")
      sh("cd #{integration_dir}/build/ && terraform workspace new #{tf_workspace}")

      Rake::Task["test:azure:vars"].execute
      Rake::Task["test:azure:plan"].execute
      Rake::Task["test:azure:apply"].execute
    end

    desc "Generate terraform.tfvars file"
    task :vars do |t, args|

      next if File.exist?(tf_vars_file)

      puts "----> Generating Vars"

      # Generate Azure crendentials
      connection = Train.create("azure").connection
      creds = connection.options

      # Determine the storage account name and the admin password
      require "securerandom"
      sa_name = ("a".."z").to_a.sample(15).join
      admin_password = SecureRandom.alphanumeric 72

      # Use the first 4 characters of the storage account to create a suffix
      suffix = sa_name[0..3]

      content = <<~VARS
        subscription_id = "#{creds[:subscription_id]}"
        client_id = "#{creds[:client_id]}"
        client_secret = "#{creds[:client_secret]}"
        tenant_id = "#{creds[:tenant_id]}"
        storage_account_name = "#{sa_name}"
        admin_password = "#{admin_password}"
        suffix = "#{suffix}"
      VARS

      content << "location = \"#{ENV["AZURE_LOCATION"]}\"\n" if ENV["AZURE_LOCATION"]

      File.write(tf_vars_file, content)
    end

    desc "generate plan from state using terraform.tfvars file"
    task :plan, [:tf_workspace] => [:vars] do |t, args|
      tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
      abort("You must set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace

      puts "----> Generating Plan"

      sh("cd #{integration_dir}/build/ && terraform plan -out inspec-azure.plan")
    end

    desc "apply terraform plan"
    task :apply, [:tf_workspace] => [:plan] do |t, args|
      tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
      abort("You must set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace
      puts "----> Applying Plan"

      sh("cd #{integration_dir}/build/ && terraform workspace select #{tf_workspace}")

      sh("cd #{integration_dir}/build/ && terraform apply inspec-azure.plan")

      Rake::Task["test:azure:dump_attrs"].execute
    end

    task :dump_attrs do
      sh("cd #{integration_dir}/build/ && terraform output > #{attribute_file}")
      raw_output = File.read(attribute_file)
      yaml_output = raw_output.gsub(" = ", " : ")
      File.open(attribute_file, "w") { |file| file.puts yaml_output }
    end

    task :run do
      puts "----> Run"
      sh("bundle exec inspec exec #{integration_dir}/verify -t azure://1e0b427a-d58b-494e-ae4f-ee558463ebbf")
    end

    task :cleanup, :tf_workspace do |t, args|
      tf_workspace = args[:tf_workspace] || ENV["INSPEC_TERRAFORM_ENV"]
      abort("You must either call the top-level test:azure task, or set the INSPEC_TERRAFORM_ENV variable.") unless tf_workspace
      puts "----> Cleanup"

      sh("cd #{integration_dir}/build/ && terraform destroy -force ")

      sh("cd #{integration_dir}/build/ && terraform workspace select default")
      sh("cd #{integration_dir}/build && terraform workspace delete #{tf_workspace}")
      File.delete(tf_vars_file)
    end
  end

  desc "Perform Azure Integration Tests"
  task :azure do
    tf_workspace = ENV["INSPEC_TERRAFORM_ENV"] || prompt("Please enter a workspace for your integration tests to run in: ")
    begin
      Rake::Task["test:azure:setup"].execute({ tf_workspace: tf_workspace })
      Rake::Task["test:azure:run"].execute
    rescue
      abort("Integration testing has failed")
    ensure
      Rake::Task["test:azure:cleanup"].execute({ tf_workspace: tf_workspace })
    end
  end
end

# Print the current version of this gem or update it.
#
# @param [Type] target the new version you want to set, or nil if you only want to show
def inspec_version(target = nil)
  path = "lib/inspec/version.rb"
  require_relative path.sub(/.rb$/, "")

  nu_version = target.nil? ? "" : " -> #{target}"
  puts "Inspec: #{Inspec::VERSION}#{nu_version}"

  unless target.nil?
    raw = File.read(path)
    nu = raw.sub(/VERSION.*/, "VERSION = '#{target}'.freeze")
    File.write(path, nu)
    load(path)
  end
end

# Check if a command is available
#
# @param [Type] x the command you are interested in
# @param [Type] msg the message to display if the command is missing
def require_command(x, msg = nil)
  return if system("command -v #{x} || exit 1")

  msg ||= "Please install it first!"
  puts "\033[31;1mCan't find command #{x.inspect}. #{msg}\033[0m"
  exit 1
end

# Check if a required environment variable has been set
#
# @param [String] x the variable you are interested in
# @param [String] msg the message you want to display if the variable is missing
def require_env(x, msg = nil)
  exists = `env | grep "^#{x}="`
  return unless exists.empty?

  puts "\033[31;1mCan't find environment variable #{x.inspect}. #{msg}\033[0m"
  exit 1
end

# Check the requirements for running an update of this repository.
def check_update_requirements
  require_command "git"
end

# Show the current version of this gem.
desc "Show the version of this gem"
task :version do
  inspec_version
end

desc "Release a new docker image"
task :release_docker do
  version = Inspec::VERSION
  cmd = "rm *.gem; gem build *gemspec && "\
        "mv *.gem inspec.gem && "\
        "docker build -t chef/inspec:#{version} . && "\
        "docker push chef/inspec:#{version} && "\
        "docker tag chef/inspec:#{version} chef/inspec:latest &&"\
        "docker push chef/inspec:latest"
  puts "--> #{cmd}"
  sh("sh", "-c", cmd)
end
