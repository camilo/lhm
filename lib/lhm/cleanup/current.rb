require 'lhm/timestamp'

module Lhm
  module Cleanup
    class Current
      def initialize(run, origin_table_name, connection)
        @run = run
        @table_name = TableName.new(origin_table_name)
        @connection = connection
        @ddls = []
      end

      attr_reader :run, :connection, :ddls

      def execute
        build_statements_for_drop_lhm_triggers_for_origin
        build_statements_for_rename_lhmn_tables_for_origin
        if run
          execute_ddls
        else
          report_ddls
        end
      end

      private

      def build_statements_for_drop_lhm_triggers_for_origin
        lhm_triggers_for_origin.each do |trigger|
          @ddls << "drop trigger if exists #{trigger}"
        end
      end

      def lhm_triggers_for_origin
        @lhm_triggers_for_origin ||= all_triggers_for_origin.select { |name| name =~ /^lhmt/ }
      end

      def all_triggers_for_origin
        @all_triggers_for_origin ||= connection.select_values("show triggers like '%#{@table_name.original}'").collect do |trigger|
          trigger.respond_to?(:trigger) ? trigger.trigger : trigger
        end
      end

      def build_statements_for_rename_lhmn_tables_for_origin
        lhmn_tables_for_origin.each do |table|
          @ddls << "rename table #{table} to #{@table_name.failed}"
        end
      end

      def lhmn_tables_for_origin
        @lhmn_tables_for_origin ||= connection.select_values("show tables like '#{@table_name.new}'")
      end

      def execute_ddls
        ddls.each do |ddl|
          connection.execute(ddl)
        end
      end

      def report_ddls
        puts "The following DDLs would be executed:"
        ddls.each { |ddl| puts ddl }
      end
    end
  end
end
