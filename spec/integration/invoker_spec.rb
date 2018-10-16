require File.expand_path(File.dirname(__FILE__)) + '/integration_helper'

require 'lhm/invoker'

describe Lhm::Invoker do
  include IntegrationHelper

  before(:each) do
    connect_master!
    @origin = table_create('users')
    @destination = table_create('destination')
    @invoker = Lhm::Invoker.new(Lhm::Table.parse(:users, @connection), @connection)
    @migration = Lhm::Migration.new(@origin, @destination)
    @entangler = Lhm::Entangler.new(@migration, @connection)
    @entangler.before
  end

  after(:each) do
    @entangler.after if @invoker.triggers_still_exist?(@entangler)
  end

  describe 'triggers_still_exist?' do
    it 'should return true when triggers still exist' do
      assert @invoker.triggers_still_exist?(@entangler)
    end

    it 'should return false when triggers do not exist' do
      @entangler.after

      refute @invoker.triggers_still_exist?(@entangler)
    end
  end
end
