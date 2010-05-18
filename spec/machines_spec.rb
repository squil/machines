require 'spec/spec_helper'

describe 'Machines' do
  before(:each) do
    @commands = []
    @log = []
    @password = 'default'
  end

  def log message
    @log << message
  end

  describe 'machine' do
    it 'should set environment, apps and role when it matches the configuration specified' do
      @config_name = 'config'
      machine 'config', :test, {:apps => ['app', 'another'], :role => 'role'}
      @environment.should == :test
      @apps.should == ['app', 'another']
      @role.should == 'role'
    end

    it 'should set environment when it matches specified configuration but no apps or role specified' do
      @config_name = 'config'
      machine 'config', :test
      @environment.should == :test
    end

    it 'should not set anything when it does not match specified configuration' do
      machine 'config', :test, {:apps => ['app', 'another'], :role => 'role'}
      @environment.should be_nil
      @apps.should be_nil
      @role.should be_nil
    end
  end

  describe 'development?' do
    it do
      @environment = :development
      development?.should be_true
    end

    it do
      development?.should be_false
    end
  end

  describe 'password' do
    it 'should add a password to existing passwords' do
      @passwords = {'app' => 'password'}
      password 'another', 'anotherpass'
      @passwords.should == {'app' => 'password', 'another' => 'anotherpass'}
    end

    it 'should add a password to empty passwords' do
      @passwords = {}
      password 'app', 'newpass'
      @passwords.should == {'app' => 'newpass'}
    end
  end

  describe 'configure' do
    before(:each) do
      should_receive(:discover_users)
    end

    it 'should set various instance variables' do
      configure %w(name host password dbmaster machine user)
      @config_name.should == 'name'
      @host.should == 'host'
      @dbmaster.should == 'dbmaster'
      @machinename.should == 'machine'
      @username.should == 'user'
      @password.should == 'password'
    end

    it 'should set defaults' do
      configure %w(name host password)
      @config_name.should == 'name'
      @host.should == 'host'
      @dbmaster.should == 'host'
      @machinename.should == 'name'
      @username.should == DEFAULT_USERNAME
      @password.should == 'password'
    end
  end

  describe 'start' do
    it 'should run commands in test mode' do
      should_receive(:run_commands)
      start 'test'
    end

    it 'should run commands in install mode' do
      @host = 'host'
      should_receive(:enable_root_login)
      mock_ssh = mock 'Ssh'
      Net::SSH.should_receive(:start).with('host', 'root', :password => TEMP_PASSWORD).and_yield mock_ssh
      should_receive(:set_machine_name_and_hosts)
      should_receive(:create_user).with mock_ssh
      should_receive(:run_commands).with mock_ssh
      should_receive(:disable_root_login)

      start 'install'
    end

    it 'should not do anything when unknown command is specified' do
      Net::SSH.should_not_receive(:start)
      should_not_receive(:run_commands)
      start 'something'
    end
  end

  describe 'discover_users' do
    it 'should find users through folder list' do
      Dir.stub!(:[]).and_return ['users/first', 'users/another']
      discover_users
      @users.should == ['first', 'another']
    end
  end

  describe 'run_commands' do
    before(:each) do
      @passwords = {}
    end

    it 'should display all commands queued in the @commands array' do
      @commands = [['cmd1', 'command 1'], ['cmd2', 'command 2']]
      run_commands
      @log.should == ['cmd1            command 1', 'cmd2            command 2']
    end

    it 'should run all commands queued in the @commands array' do
      @commands = [['cmd1', 'command 1'], ['cmd2', 'command 2']]
      mock_ssh = mock('Ssh')
      mock_ssh.should_receive(:exec!).with 'command 1'
      mock_ssh.should_receive(:exec!).with 'command 2'
      run_commands mock_ssh
    end

    it 'should run upload command' do
      @commands = [['cmd1', ['from', 'to']]]
      @host = 'host'
      mock_ssh = mock('Ssh')
      mock_scp = mock('Scp')
      Net::SCP.should_receive(:start).with('host', 'root', :password => TEMP_PASSWORD).and_yield mock_scp
      mock_scp.should_receive(:upload!).with 'from', 'to'
      run_commands mock_ssh
    end

    it 'should raise errors when command or name is missing' do
      @commands = [[nil, 'command']]
      lambda{run_commands}.should raise_error(ArgumentError)
      @commands = [['cmd', nil]]
      lambda{run_commands}.should raise_error(ArgumentError)
    end
  end

  describe 'enable_root_login' do
    it 'should set the root password ' do
      mock_ssh = mock('Ssh')
      @host = 'host'
      Net::SSH.should_receive(:start).with('host', DEFAULT_IDENTITY, :password => DEFAULT_IDENTITY).and_yield(mock_ssh)
      mock_ssh.should_receive(:exec!).with "echo #{TEMP_PASSWORD} | sudo -S usermod -p #{TEMP_PASSWORD_ENCRYPTED} root"
      enable_root_login
    end
  end

  describe 'disable_root_login' do
    it 'should remove the root password on the remote machine' do
      mock_ssh = mock('Ssh')
      @host = 'host'
      Net::SSH.should_receive(:start).with('host', 'root', :password => 'ubuntu').and_yield(mock_ssh)
      mock_ssh.should_receive(:exec!).with 'passwd -d root'
      disable_root_login
    end
  end

  describe 'set_machine_name_and_hosts' do
    it 'should upload /etc/hosts and set hostname' do
      stub!(:development?).and_return(true)
      File.stub!(:exist?).and_return(true)
      @machinename = 'machine'
      set_machine_name_and_hosts
      @added.should == [["etc/hosts", "/etc/hosts"], "sed -i 's/ubuntu/machine/' /etc/{hosts,hostname}"]
    end
  end

  describe 'create_user' do
    it 'should create a user on the remote machine and add it as an admin' do
      mock_ssh = mock('Ssh')
      mock_ssh.should_receive(:exec!).with 'useradd -p encrypted_password -G admin user'
      @username = 'user'
      @password = 'encrypted_password'
      create_user mock_ssh
    end

    it 'should create a user without password if not supplied' do
      mock_ssh = mock('Ssh')
      mock_ssh.should_receive(:exec!).with 'useradd -G admin user'
      @username = 'user'
      @password = nil
      create_user mock_ssh
    end
  end

end

