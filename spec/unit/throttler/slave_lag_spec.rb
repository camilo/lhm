require File.expand_path(File.dirname(__FILE__)) + '/../unit_helper'

require 'lhm/throttler/slave_lag'

describe Lhm::Throttler do
  include UnitHelper

  describe '#format_hosts' do
    describe 'with only localhost hosts' do
      it 'returns no hosts' do
        assert_equal([], Lhm::Throttler.format_hosts(['localhost:1234', '127.0.0.1:5678']))
      end
    end

    describe 'with only remote hosts' do
      it 'returns remote hosts' do
        assert_equal(['server.example.com', 'anotherserver.example.com'], Lhm::Throttler.format_hosts(['server.example.com:1234', 'anotherserver.example.com']))
      end
    end

    describe 'with only nil hosts' do
      it 'returns no hosts' do
        assert_equal([], Lhm::Throttler.format_hosts([nil]))
      end
    end

    describe 'with some nil hosts' do
      it 'returns the remaining hosts' do
        assert_equal(['server.example.com'], Lhm::Throttler.format_hosts([nil, 'server.example.com:1234']))
      end
    end
  end
end

describe Lhm::Throttler::Slave do
  include UnitHelper

  before :each do
    @logs = StringIO.new
    Lhm.logger = Logger.new(@logs)

    @dummy_mysql_client_config = lambda { {'username' => 'user', 'password' => 'pw', 'database' => 'db'} }
  end

  describe "#client" do
    before do
      class TestMysql2Client
        def initialize(config)
          raise Mysql2::Error.new("connection error")
        end
      end
    end

    describe 'on connection error' do
      it 'logs and returns nil' do
        assert_nil(Lhm::Throttler::Slave.new('slave', @dummy_mysql_client_config).connection)

        log_messages = @logs.string.lines
        assert_equal(2, log_messages.length)
        assert log_messages[0].include? "Connecting to slave on database: db"
        assert log_messages[1].include? "Error connecting to slave: Unknown MySQL server host 'slave'"
      end
    end

    describe 'with proper config' do
      it "creates a new Mysql2::Client" do
        expected_config = {username: 'user', password: 'pw', database: 'db', host: 'slave'}
        Mysql2::Client.stubs(:new).with(expected_config).returns(mock())

        assert Lhm::Throttler::Slave.new('slave', @dummy_mysql_client_config).connection
      end
    end

    describe 'with active record config' do
      it 'logs and creates client' do
        active_record_config = {username: 'user', password: 'pw', database: 'db'}
        ActiveRecord::Base.stubs(:connection_pool).returns(stub(spec: stub(config: active_record_config)))

        Mysql2::Client.stubs(:new).returns(mock())

        assert Lhm::Throttler::Slave.new('slave').connection

        log_messages = @logs.string.lines
        assert_equal(1, log_messages.length)
        assert log_messages[0].include? "Connecting to slave on database: db"
      end
    end
  end

  describe "#connection" do
    before do
      class Connection
        def self.query(query)
          if query == Lhm::Throttler::Slave::SQL_SELECT_MAX_SLAVE_LAG
            [{'Seconds_Behind_Master' => 20}]
          elsif query == Lhm::Throttler::Slave::SQL_SELECT_SLAVE_HOSTS
            [{'host' => '1.1.1.1:80'}]
          end
        end
      end

      @slave = Lhm::Throttler::Slave.new('slave', @dummy_mysql_client_config)
      @slave.instance_variable_set(:@connection, Connection)

      class StoppedConnection
        def self.query(query)
          [{'Seconds_Behind_Master' => nil}]
        end
      end

      @stopped_slave = Lhm::Throttler::Slave.new('stopped_slave', @dummy_mysql_client_config)
      @stopped_slave.instance_variable_set(:@connection, StoppedConnection)
    end

    describe "#lag" do
      it "returns the slave lag" do
        assert_equal(20, @slave.lag)
      end
    end

    describe "#lag with a stopped slave" do
      it "returns 0 slave lag" do
        assert_equal(0, @stopped_slave.lag)
      end
    end

    describe "#slave_hosts" do
      it "returns the hosts" do
        assert_equal(['1.1.1.1'], @slave.slave_hosts)
      end
    end

    describe "#lag on connection error" do
      it "logs and returns 0 slave lag" do
        client = mock()
        client.stubs(:query).raises(Mysql2::Error, "Can't connect to MySQL server")
        Lhm::Throttler::Slave.any_instance.stubs(:client).returns(client)
        Lhm::Throttler::Slave.any_instance.stubs(:config).returns([])

        slave = Lhm::Throttler::Slave.new('slave', @dummy_mysql_client_config)
        assert_send([Lhm.logger, :info, "Unable to connect and/or query slave: error"])
        assert_equal(0, slave.lag)
      end
    end
  end
end

describe Lhm::Throttler::SlaveLag do
  include UnitHelper

  before :each do
    @throttler = Lhm::Throttler::SlaveLag.new
  end

  describe '#throttle_seconds' do
    describe 'with no slave lag' do
      before do
        def @throttler.max_current_slave_lag
          0
        end
      end

      it 'does not alter the currently set timeout' do
        timeout = @throttler.timeout_seconds
        assert_equal(timeout, @throttler.send(:throttle_seconds))
      end
    end

    describe 'with a large slave lag' do
      before do
        def @throttler.max_current_slave_lag
          100
        end
      end

      it 'doubles the currently set timeout' do
        timeout = @throttler.timeout_seconds
        assert_equal(timeout * 2, @throttler.send(:throttle_seconds))
      end

      it 'does not increase the timeout past the maximum' do
        @throttler.timeout_seconds = Lhm::Throttler::SlaveLag::MAX_TIMEOUT
        assert_equal(Lhm::Throttler::SlaveLag::MAX_TIMEOUT, @throttler.send(:throttle_seconds))
      end
    end

    describe 'with no slave lag after it has previously been increased' do
      before do
        def @throttler.max_current_slave_lag
          0
        end
      end

      it 'halves the currently set timeout' do
        @throttler.timeout_seconds *= 2 * 2
        timeout = @throttler.timeout_seconds
        assert_equal(timeout / 2, @throttler.send(:throttle_seconds))
      end

      it 'does not decrease the timeout past the minimum on repeated runs' do
        @throttler.timeout_seconds = Lhm::Throttler::SlaveLag::INITIAL_TIMEOUT * 2
        assert_equal(Lhm::Throttler::SlaveLag::INITIAL_TIMEOUT, @throttler.send(:throttle_seconds))
        assert_equal(Lhm::Throttler::SlaveLag::INITIAL_TIMEOUT, @throttler.send(:throttle_seconds))
      end
    end
  end

  describe '#max_current_slave_lag' do
    describe 'with multiple slaves' do
      it 'returns the largest amount of lag' do
        slave1 = mock()
        slave2 = mock()
        slave1.stubs(:lag).returns(5)
        slave2.stubs(:lag).returns(0)
        Lhm::Throttler::SlaveLag.any_instance.stubs(:slaves).returns([slave1, slave2])
        assert_equal 5, @throttler.send(:max_current_slave_lag)
      end
    end

    describe 'with MySQL stopped on the slave' do
      it 'assumes 0 slave lag' do
        client = mock()
        client.stubs(:query).raises(Mysql2::Error, "Can't connect to MySQL server")
        Lhm::Throttler::Slave.any_instance.stubs(:client).returns(client)

        Lhm::Throttler::Slave.any_instance.stubs(:prepare_connection_config).returns([])
        Lhm::Throttler::Slave.any_instance.stubs(:slave_hosts).returns(['1.1.1.2'])
        @throttler.stubs(:master_slave_hosts).returns(['1.1.1.1'])

        assert_equal 0, @throttler.send(:max_current_slave_lag)
      end
    end
  end

  describe '#get_slaves' do
    describe 'with no slaves' do
      before do
        def @throttler.master_slave_hosts
          []
        end
      end

      it 'returns no slaves' do
        assert_equal([], @throttler.send(:get_slaves))
      end
    end

    describe 'with multiple slaves' do
      before do
        class TestSlave
          attr_reader :host, :connection

          def initialize(host, _)
            @host = host
            @connection = 'conn' if @host
          end

          def slave_hosts
            if @host == '1.1.1.1'
              ['1.1.1.2', '1.1.1.3']
            else
              [nil]
            end
          end
        end

        @create_slave = lambda { |host, config|
          TestSlave.new(host, config)
        }
      end

      describe 'without the :check_only option' do
        before do
          def @throttler.master_slave_hosts
            ['1.1.1.1', '1.1.1.4']
          end
        end

        it 'returns the slave instances' do
          Lhm::Throttler::Slave.stubs(:new).returns(@create_slave) do
            assert_equal(["1.1.1.4", "1.1.1.1", "1.1.1.3", "1.1.1.2"], @throttler.send(:get_slaves).map(&:host))
          end
        end
      end

      describe 'with the :check_only option' do
        describe 'with a callable argument' do
          before do
            check_only = lambda {{'host' => '1.1.1.3'}}
            @throttler = Lhm::Throttler::SlaveLag.new :check_only => check_only
          end

          it 'returns only that single slave' do
            Lhm::Throttler::Slave.stubs(:new).returns(@create_slave) do
              assert_equal ['1.1.1.3'], @throttler.send(:get_slaves).map(&:host)
            end
          end
        end

        describe 'with a non-callable argument' do
          before do
            @throttler = Lhm::Throttler::SlaveLag.new :check_only => 'I cannot be called'
            def @throttler.master_slave_hosts
              ['1.1.1.1', '1.1.1.4']
            end
          end

          it 'returns all the slave instances' do
            Lhm::Throttler::Slave.stubs(:new).returns(@create_slave) do
              assert_equal(["1.1.1.4", "1.1.1.1", "1.1.1.3", "1.1.1.2"], @throttler.send(:get_slaves).map(&:host))
            end
          end
        end
      end
    end
  end
end
