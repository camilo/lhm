# Copyright (c) 2011 - 2013, SoundCloud Ltd., Rany Keddo, Tobias Bielohlawek, Tobias
# Schmidt

require File.expand_path(File.dirname(__FILE__)) + '/unit_helper'

describe Lhm::ChunkFinder do
  before(:each) do
    @origin = Lhm::Table.new('foo')
    @destination = Lhm::Table.new('bar')
    @migration = Lhm::Migration.new(@origin, @destination)
    @connection = mock()
  end

  describe '#validate' do
    describe 'when start is greater than limit' do
      it 'raises' do
        assert_raises { Lhm::ChunkFinder.new(@connection, @migration, {start: 2, limit: 1}).validate }
      end
    end

    describe 'when start is greater than limit' do
      it 'does not raise' do
        Lhm::ChunkFinder.new(@connection, @migration, {start: 1, limit: 2}).validate # does not raise
      end
    end
  end

  describe '#start' do
    describe 'when initialized with 5' do
      before(:each) do
        @instance = Lhm::ChunkFinder.new(@connection, @migration, {start: 5, limit: 6})
      end

      it 'returns 5' do
        assert_equal @instance.start, 5
      end
    end

    describe 'when initialized with nil and the min(id) is 22' do
      before(:each) do
        @connection.expects(:select_value).returns(22)
        @instance = Lhm::ChunkFinder.new(@migration, @connection, {limit: 6})
      end

      it 'returns 22' do
        assert_equal @instance.start, 22
      end
    end
  end

  describe '#limit' do
    describe 'when initialized with 6' do
      before(:each) do
        @instance = Lhm::ChunkFinder.new(@connection, @migration, {start: 5, limit: 6})
      end

      it 'returns 6' do
        assert_equal @instance.limit, 6
      end
    end

    describe 'when initialized with nil and the max(id) is 33' do
      before(:each) do
        @connection.expects(:select_value).returns(33)
        @instance = Lhm::ChunkFinder.new(@migration, @connection, {start: 5})
      end

      it 'returns 33' do
        assert_equal @instance.limit, 33
      end
    end
  end
end
