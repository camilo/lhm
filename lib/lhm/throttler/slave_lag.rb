module Lhm
  module Throttler

    def self.format_hosts(hosts)
      formatted_hosts = []
      hosts.each do |host|
        if host && !host.match(/localhost/) && !host.match(/127.0.0.1/)
          formatted_hosts << host.partition(':')[0]
        end
      end
      formatted_hosts
    end

    class SlaveLag
      include Command

      INITIAL_TIMEOUT = 0.1
      DEFAULT_STRIDE = 2_000
      DEFAULT_MAX_ALLOWED_LAG = 10

      MAX_TIMEOUT = INITIAL_TIMEOUT * 1024

      attr_accessor :timeout_seconds, :allowed_lag, :stride, :connection

      def initialize(options = {})
        @timeout_seconds = INITIAL_TIMEOUT
        @stride = options[:stride] || DEFAULT_STRIDE
        @allowed_lag = options[:allowed_lag] || DEFAULT_MAX_ALLOWED_LAG
        @slaves = {}
        @get_config = options[:current_config]
        @check_only = options[:check_only]
      end

      def execute
        sleep(throttle_seconds)
      end

      private

      def throttle_seconds
        lag = max_current_slave_lag

        if lag > @allowed_lag && @timeout_seconds < MAX_TIMEOUT
          Lhm.logger.info("Increasing timeout between strides from #{@timeout_seconds} to #{@timeout_seconds * 2} because #{lag} seconds of slave lag detected is greater than the maximum of #{@allowed_lag} seconds allowed.")
          @timeout_seconds = @timeout_seconds * 2
        elsif lag <= @allowed_lag && @timeout_seconds > INITIAL_TIMEOUT
          Lhm.logger.info("Decreasing timeout between strides from #{@timeout_seconds} to #{@timeout_seconds / 2} because #{lag} seconds of slave lag detected is less than or equal to the #{@allowed_lag} seconds allowed.")
          @timeout_seconds = @timeout_seconds / 2
        else
          @timeout_seconds
        end
      end

      def slaves
        @slaves[@connection] ||= get_slaves
      end

      def get_slaves
        slaves = []
        if @check_only.nil? or !@check_only.respond_to?(:call)
          slave_hosts = master_slave_hosts
          while slave_hosts.any? do
            host = slave_hosts.pop
            slave = Slave.new(host, @get_config)
            if !slaves.map(&:host).include?(host) && slave.connection
              slaves << slave
              slave_hosts.concat(slave.slave_hosts)
            end
          end
        else
          slave_config = @check_only.call
          slaves << Slave.new(slave_config['host'], @get_config)
        end
        slaves
      end

      def master_slave_hosts
        Throttler.format_hosts(@connection.select_values(Slave::SQL_SELECT_SLAVE_HOSTS))
      end

      def max_current_slave_lag
        max = slaves.map { |slave| slave.lag }.push(0).max
        Lhm.logger.info "Max current slave lag: #{max}"
        max
      end
    end

    class Slave
      SQL_SELECT_SLAVE_HOSTS = "SELECT host FROM information_schema.processlist WHERE command LIKE 'Binlog Dump%'"
      SQL_SELECT_MAX_SLAVE_LAG = 'SHOW SLAVE STATUS'

      attr_reader :host, :connection

      def initialize(host, connection_config = nil)
        @host = host
        @connection_config = prepare_connection_config(connection_config)
        @connection = client(@connection_config)
      end

      def slave_hosts
        Throttler.format_hosts(query_connection(SQL_SELECT_SLAVE_HOSTS, 'host'))
      end

      def lag
        query_connection(SQL_SELECT_MAX_SLAVE_LAG, 'Seconds_Behind_Master').first.to_i
      end

      private

      def client(config)
        begin
          Lhm.logger.info "Connecting to #{@host} on database: #{config[:database]}"
          Mysql2::Client.new(config)
        rescue Mysql2::Error => e
          Lhm.logger.info "Error connecting to #{@host}: #{e}"
          nil
        end
      end

      def prepare_connection_config(config_proc)
        config = if config_proc
          if config_proc.respond_to?(:call) # if we get a proc
            config_proc.call
          else
            raise ArgumentError, "Expected #{config_proc.inspect} to respond to `call`"
          end
        else # otherwise default to ActiveRecord provided config
          ActiveRecord::Base.connection_pool.spec.config.dup
        end
        config.deep_symbolize_keys!
        config[:host] = @host
        config
      end

      def query_connection(query, result)
        begin
          @connection.query(query).map { |row| row[result] }
        rescue Mysql2::Error => e
          Lhm.logger.info "Unable to connect and/or query #{host}: #{e}"
          [nil]
        end
      end
    end
  end
end
