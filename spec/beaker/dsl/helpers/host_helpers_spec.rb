require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  let( :opts )   { Beaker::Options::Presets.env_vars }
  let( :command ){ 'ls' }
  let( :host )   { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  let( :master ) { make_host( 'master',   :roles => %w( master agent default)    ) }
  let( :agent )  { make_host( 'agent',    :roles => %w( agent )           ) }
  let( :custom ) { make_host( 'custom',   :roles => %w( custom agent )    ) }
  let( :dash )   { make_host( 'console',  :roles => %w( dashboard agent ) ) }
  let( :db )     { make_host( 'db',       :roles => %w( database agent )  ) }
  let( :hosts )  { [ master, agent, dash, db, custom ] }

  describe '#on' do

    before :each do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 0
    end

    it 'allows the environment the command is run within to be specified' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( Beaker::Command ).to receive( :new ).
        with( 'ls ~/.bin', [], {'ENV' => { :HOME => '/tmp/test_home' }} )

      subject.on( host, 'ls ~/.bin', :environment => {:HOME => '/tmp/test_home' } )
    end

    describe 'with a beaker command object passed in as the command argument' do
      let( :command ) { Beaker::Command.new('commander command', [], :environment => {:HOME => 'default'}) }

      it 'overwrites the command environment with the environment specified in #on' do
        expect( host ).to receive( :exec ) do |command|
          expect(command.environment).to eq({:HOME => 'override'})
        end
        subject.on( host, command, :environment => {:HOME => 'override'})
      end

      it 'uses the command environment if there is no overriding argument in #on' do
        expect( host ).to receive( :exec ) do |command|
          expect(command.environment).to eq({:HOME => 'default'})
        end
        subject.on( host, command )
      end

    end

    it 'if the host is a String Object, finds the matching hosts with that String as role' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( master ).to receive( :exec ).once

      subject.on( 'master', 'echo hello')
    end

    it 'if the host is a Symbol Object, finds the matching hosts with that Symbol as role' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( master ).to receive( :exec ).once

      subject.on( :master, 'echo hello')
    end

    it 'executes in parallel if run_in_parallel=true' do
      InParallel::InParallelExecutor.logger = logger
      FakeFS.deactivate!
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expected = []
      hosts.each_with_index do |host, i|
        expected << i
        allow( host ).to receive( :exec ).and_return( i )
      end

      # This will only get hit if forking processes is supported and at least 2 items are being submitted to run in parallel
      expect( InParallel::InParallelExecutor ).to receive(:_execute_in_parallel).with(any_args).and_call_original.exactly(5).times
      results = subject.on( hosts, command, {:run_in_parallel => true})
      expect( results ).to be == expected
    end

    it 'delegates to itself for each host passed' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expected = []
      hosts.each_with_index do |host, i|
        expected << i
        expect( host ).to receive( :exec ).and_return( i )
      end

      results = subject.on( hosts, command )
      expect( results ).to be == expected
    end

    context 'upon command completion' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
        @res = subject.on( host, command )
      end

      it 'returns the result of the action' do
        expect( @res ).to be == result
      end

      it 'provides access to stdout' do
        expect( @res.stdout ).to be == 'stdout'
      end

      it 'provides access to stderr' do
        expect( @res.stderr ).to be == 'stderr'
      end

      it 'provides access to exit_code' do
        expect( @res.exit_code ).to be == 0
      end
    end

    context 'when passed a block with arity of 1' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
      end

      it 'yields result' do
        subject.on host, command do |containing_class|
          expect( containing_class ).
            to be_an_instance_of( Beaker::Result )
        end
      end

      it 'provides access to stdout' do
        subject.on host, command do |containing_class|
          expect( containing_class.stdout ).to be == 'stdout'
        end
      end

      it 'provides access to stderr' do
        subject.on host, command do |containing_class|
          expect( containing_class.stderr ).to be == 'stderr'
        end
      end

      it 'provides access to exit_code' do
        subject.on host, command do |containing_class|
          expect( containing_class.exit_code ).to be == 0
        end
      end
    end

    context 'when passed a block with arity of 0' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
      end

      it 'yields self' do
        subject.on host, command do
          expect( subject ).
            to be_an_instance_of( ClassMixedWithDSLHelpers )
        end
      end

      it 'provides access to stdout' do
        subject.on host, command do
          expect( subject.stdout ).to be == 'stdout'
        end
      end

      it 'provides access to stderr' do
        subject.on host, command do
          expect( subject.stderr ).to be == 'stderr'
        end
      end

      it 'provides access to exit_code' do
        subject.on host, command do
          expect( subject.exit_code ).to be == 0
        end
      end
    end

    it 'errors if command is not a String or Beaker::Command' do
      expect {
        subject.on( host, Object.new )
      }.to raise_error( ArgumentError, /called\ with\ a\ String\ or\ Beaker/ )
    end

    it 'executes the passed Beaker::Command if given as command argument' do
      command_test = Beaker::Command.new( 'echo face_testing' )
      expect( master ).to receive( :exec ).with( command_test, anything )
      subject.on( master, command_test )
    end
  end

  describe "#retry_on" do
    it 'fails correctly when command never succeeds' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 1

      retries = 5

      opts = {
        :max_retries    => retries,
        :retry_interval => 0.0001,
      }

      allow( subject ).to receive(:on).and_return(result)
      expect( subject ).to receive(:on).exactly(retries+2)
      expect { subject.retry_on(host, command, opts) }.to raise_error(RuntimeError)
    end

    it 'will return success correctly if it succeeds the first time' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 0

      opts = {
        :max_retries    => 5,
        :retry_interval => 0.0001,
      }

      allow( subject ).to receive(:on).and_return(result)
      expect( subject ).to receive(:on).once

      result_given = subject.retry_on(host, command, opts)
      expect(result_given.exit_code).to be === 0
    end

    it 'will return success correctly if it succeeds after failing a few times' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'

      opts = {
        :max_retries    => 10,
        :retry_interval => 0.1,
      }

      reps_num = 4
      count = 0
      allow( subject ).to receive(:on) do
        result.exit_code = count > reps_num ? 0 : 1
        count += 1
        result
      end
      expect( subject ).to receive(:on).exactly(reps_num + 2)

      result_given = subject.retry_on(host, command, opts)
      expect(result_given.exit_code).to be === 0
    end
  end

  describe "shell" do
    it 'delegates to #on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :on ).with( master, "echo hello", {}).once

      subject.shell( "echo hello" )
    end
  end

  describe '#scp_from' do
    it 'delegates to the host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :logger ).exactly( hosts.length ).times
      expect( result ).to receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        expect( host ).to receive( :do_scp_from ).and_return( result )
      end

      subject.scp_from( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#scp_to' do
    it 'delegates to the host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :logger ).exactly( hosts.length ).times
      expect( result ).to receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        expect( host ).to receive( :do_scp_to ).and_return( result )
      end

      subject.scp_to( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#rsync_to' do
    it 'delegates to the host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      hosts.each do |host|
        expect( host ).to receive( :do_rsync_to ).and_return( result )
      end

      subject.rsync_to( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#create_remote_file using scp' do
    it 'scps the contents passed in to the hosts' do
      my_opts = { :silent => true }
      tmpfile = double

      expect( tmpfile ).to receive( :path ).exactly( 2 ).times.
        and_return( '/local/path/to/blah' )

      expect( Tempfile ).to receive( :open ).and_yield( tmpfile )

      expect( File ).to receive( :open )

      expect( subject ).to receive( :scp_to ).
        with( hosts, '/local/path/to/blah', '/remote/path', my_opts )

      subject.create_remote_file( hosts, '/remote/path', 'blah', my_opts )
    end
  end

  describe '#create_remote_file using rsync' do
    it 'scps the contents passed in to the hosts' do
      my_opts = { :silent => true, :protocol => 'rsync' }
      tmpfile = double

      expect( tmpfile ).to receive( :path ).exactly( 2 ).times.
        and_return( '/local/path/to/blah' )

      expect( Tempfile ).to receive( :open ).and_yield( tmpfile )

      expect( File ).to receive( :open )

      expect( subject ).to receive( :rsync_to ).
        with( hosts, '/local/path/to/blah', '/remote/path', my_opts )

      subject.create_remote_file( hosts, '/remote/path', 'blah', my_opts )
    end
  end

  describe '#run_script_on' do
    it 'scps the script to a tmpdir and executes it on host(s)' do
      expect( subject ).to receive( :scp_to )
      expect( subject ).to receive( :on )
      subject.run_script_on( 'host', '~/.bin/make-enterprisy' )
    end
  end

  describe '#run_script' do
    it 'delegates to #run_script_on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :run_script_on ).with( master, "/tmp/test.sh", {}).once

      subject.run_script( '/tmp/test.sh' )
    end
  end

  describe '#install_package' do
    it 'delegates to Host#install_package with arguments on the passed Host' do
      expect( host ).to receive( :install_package ).with( 'pkg_name', '', '1.2.3' )
      subject.install_package( host, 'pkg_name', '1.2.3' )
    end
  end

  describe '#uninstall_package' do
    it 'delegates to Host#uninstall_package on the passed Host' do
      expect( host ).to receive( :uninstall_package ).with( 'pkg_name' )
      subject.uninstall_package( host, 'pkg_name' )
    end
  end

  describe '#write_hosts' do
    def stub_yaml_store(file, contents)
      expect(YAML::Store).to receive(:new).with(file).and_return(contents)
      expect(contents).to receive(:transaction).and_yield
    end

    let(:file) { 'hosts.yaml' }

    context 'when the file does not exist' do
      before(:each) do
        allow(File).to receive(:exist?).with(file).and_return(false)
      end

      it 'creates the file and writes the hosts' do
        contents = {}

        stub_yaml_store(file, contents)

        expected_contents = {}
        expected_contents['HOSTS'] = {}
        hosts.each do |host|
          expected_contents['HOSTS'][host.hostname] = JSON.parse(host.host_hash.to_json)
        end

        subject.write_hosts(hosts, file)

        expect(contents).to eql(expected_contents)
      end
    end

    context 'when the file does exist' do
      let(:contents) do
        {
          'HOSTS' => {
            master.hostname => master.host_hash,
            agent.hostname  => agent.host_hash
          }
        }
      end

      before(:each) do
        allow(File).to receive(:exist?).with(file).and_return(true)
        allow(YAML).to receive(:load_file).with(file).and_return(contents)

        stub_yaml_store(file, contents)
      end

      it "adds new hosts" do
        input_hosts = hosts - [master, agent]

        expected_contents = contents.dup
        input_hosts.each do |host|
          expected_contents['HOSTS'][host.hostname] = JSON.parse(host.host_hash.to_json)
        end

        subject.write_hosts(input_hosts, file)

        expect(contents).to eql(expected_contents)
      end

      it "updates existing hosts" do
        master['some_key'] = 'some_value'

        expected_contents = contents.dup
        expected_contents['HOSTS'][master.hostname] = JSON.parse(master.host_hash.to_json)

        subject.write_hosts([master], file)

        expect(contents).to eql(expected_contents)
      end
    end
  end
end
