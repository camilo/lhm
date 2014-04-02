require File.expand_path(File.dirname(__FILE__)) + '/unit_helper'

require 'lhm'


describe Lhm do

  before(:each) do
    Lhm.remove_class_variable :@@logger if Lhm.class_variable_defined? :@@logger
    Lhm.remove_class_variable :@@logger_params if Lhm.class_variable_defined? :@@logger_params
  end

  describe "logger" do

    it "should use the default parameters if @@logger_params is not set" do
      Lhm.logger.must_be_kind_of Logger
      Lhm.logger.level.must_equal Logger::INFO
      Lhm.logger.instance_eval{ @logdev }.dev.must_equal STDOUT
    end

    it "should use the parameters defined in @@logger_params" do
      Lhm.logger_params =  {level: Logger::ERROR, file: 'omg.ponies' }

      Lhm.logger.level.must_equal Logger::ERROR
      Lhm.logger.instance_eval{ @logdev }.dev.must_be_kind_of File
      Lhm.logger.instance_eval{ @logdev }.dev.path.must_equal 'omg.ponies'
    end

  end
end
