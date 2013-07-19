# Copyright (c) 2011 - 2013, SoundCloud Ltd., Rany Keddo, Tobias Bielohlawek, Tobias
# Schmidt

require File.expand_path(File.dirname(__FILE__)) + '/unit_helper'

require 'lhm/table'
require 'lhm/migration'
require 'lhm/chunker'
require 'lhm/throttler'

describe Lhm::Chunker do
  include UnitHelper

  before(:each) do
    @origin = Lhm::Table.new("foo")
    @destination = Lhm::Table.new("bar")
    @migration = Lhm::Migration.new(@origin, @destination)
    @connection = MiniTest::Mock.new
    # This is a poor man's stub
    @throttler = Object.new
    def @throttler.run
      #noop
    end
    def @throttler.stride
      1
    end
    @chunker = Lhm::Chunker.new(@migration, @connection, :throttler => @throttler,
                                                         :start     => 1,
                                                         :limit     => 10)
  end

  describe "#run" do
    it "chunks the result set according to the stride size" do
      def @throttler.stride
        2
      end

      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 1 and 2/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 3 and 4/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 5 and 6/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 7 and 8/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 9 and 10/
      end

      @chunker.run
      @connection.verify
    end
  end

  describe "copy into" do
    before(:each) do
      @origin.columns["secret"] = { :metadata => "VARCHAR(255)"}
      @destination.columns["secret"] = { :metadata => "VARCHAR(255)"}
    end

    it "should copy the correct range and column" do
      @chunker.copy(from = 1, to = 100).must_equal(
        "insert ignore into `destination` (`secret`) " +
        "select origin.`secret` from `origin` " +
        "where origin.`id` between 1 and 100"
      )
    end
  end

  describe "copy into with a different column to order by" do
    before(:each) do
      @migration   = Lhm::Migration.new(@origin, @destination, "weird_id")
      @chunker     = Lhm::Chunker.new(@migration, nil, { :start => 1, :limit => 10 })
      @origin.columns["secret"] = { :metadata => "VARCHAR(255)"}
      @destination.columns["secret"] = { :metadata => "VARCHAR(255)"}
    end

    it "should copy the correct range and column" do
      @chunker.copy(from = 1, to = 100).must_equal(
        "insert ignore into `destination` (`secret`) " +
        "select origin.`secret` from `origin` " +
        "where origin.`weird_id` between 1 and 100"
      )
    end
  end


  describe "invalid" do
    before do
      @chunker = Lhm::Chunker.new(@migration, nil, { :start => 0, :limit => -1 })
    end

    it "should have zero chunks" do
      @chunker.traversable_chunks_size.must_equal 0
    end


    it "handles stride changes during execution" do
      #roll our own stubbing
      def @throttler.stride
        @run_count ||= 0
        @run_count = @run_count + 1
        if @run_count > 1
          3
        else
          2
        end
      end

      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 1 and 2/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 3 and 5/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 6 and 8/
      end
      @connection.expect(:update, 2) do |stmt|
        stmt.first =~ /between 9 and 10/
      end

      @chunker.run
      @connection.verify
    end

    it "separates filter conditions from chunking conditions" do
      @chunker = Lhm::Chunker.new(@migration, @connection, :throttler => @throttler,
                                                           :start     => 1,
                                                           :limit     => 2)
      @connection.expect(:update, 1) do |stmt|
        stmt.first =~ /where \(foo.created_at > '2013-07-10' or foo.baz = 'quux'\) and `foo`/
      end

      def @migration.conditions
        "where foo.created_at > '2013-07-10' or foo.baz = 'quux'"
      end

      @chunker.run
      @connection.verify
    end

    it "doesn't mess with inner join filters" do
      @chunker = Lhm::Chunker.new(@migration, @connection, :throttler => @throttler,
                                                           :start     => 1,
                                                           :limit     => 2)
      @connection.expect(:update, 1) do |stmt|
        puts stmt
        stmt.first =~ /inner join bar on foo.id = bar.foo_id and/
      end

      def @migration.conditions
        "inner join bar on foo.id = bar.foo_id"
      end

      @chunker.run
      @connection.verify
    end
  end
end
