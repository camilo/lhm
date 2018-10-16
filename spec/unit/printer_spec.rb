require File.expand_path(File.dirname(__FILE__)) + '/unit_helper'

require 'lhm/printer'

describe Lhm::Printer do
  include UnitHelper

  describe 'percentage printer' do

    before(:each) do
      @printer = Lhm::Printer::Percentage.new
    end

    it 'prints the percentage' do
      mock = MiniTest::Mock.new
      10.times do |i|
        mock.expect(:write, :return_value) do |message|
          message = message.first if message.is_a?(Array)
          assert_match(/^\r/, message)
          assert_match(/#{i}\/10/, message)
        end
      end

      @printer.instance_variable_set(:@output, mock)
      10.times { |i| @printer.notify(i, 10) }
      mock.verify
    end

    it 'always prints a bigger message' do
      @length = 0
      printer_mock = mock()
      printer_mock.expects(:write).at_least_once

      def assert_length(printer)
        new_length = printer.instance_variable_get(:@max_length)
        assert new_length >= @length
        @length = new_length
      end

      @printer.instance_variable_set(:@output, printer_mock)
      @printer.notify(10, 100)
      assert_length(@printer)
      @printer.notify(0, 100)
      assert_length(@printer)
      @printer.notify(1, 1000000)
      assert_length(@printer)
      @printer.notify(0, 0)
      assert_length(@printer)
      @printer.notify(0, nil)
      assert_length(@printer)
    end

    it 'prints the end message' do
      mock = MiniTest::Mock.new
      mock.expect(:write, :return_value, [String])
      mock.expect(:write, :return_value, ["\n"])

      @printer.instance_variable_set(:@output, mock)
      @printer.end

      mock.verify
    end
  end

  describe 'dot printer' do

    before(:each) do
      @printer = Lhm::Printer::Dot.new
    end

    it 'prints the dots' do
      mock  = MiniTest::Mock.new
      10.times do
        mock.expect(:write, :return_value, ['.'])
      end

      @printer.instance_variable_set(:@output, mock)
      10.times { @printer.notify }

      mock.verify
    end

  end
end
