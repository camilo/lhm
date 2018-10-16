require 'test_helper'

describe Lhm::TableName do
  describe "#archived" do
    it "prefixes and timestamps the old table" do
      subject = Lhm::TableName.new("original", Time.new(2000,01,02,03,04,05))
      assert_equal "lhma_2000_01_02_03_04_05_000_original", subject.archived
    end

    it "truncates names below 64 characters" do
      subject = Lhm::TableName.new("some_very_long_original_table_name_that_exceeds_64_characters", Time.new(2000,01,02,03,04,05))
      assert_equal "lhma_2000_01_02_03_04_05_000_some_very_long_original_table_name_", subject.archived
    end
  end

  describe "#failed" do
    it "prefixes and postfixes and timestamps the old table" do
      subject = Lhm::TableName.new("original", Time.new(2000,01,02,03,04,05))
      assert_equal "lhma_2000_01_02_03_04_05_000_original_failed", subject.failed
    end

    it "truncates names below 64 characters" do
      subject = Lhm::TableName.new("some_very_long_original_table_name_that_exceeds_64_characters", Time.new(2000,01,02,03,04,05))
      assert_equal "lhma_2000_01_02_03_04_05_000_some_very_long_original_tabl_failed", subject.failed
    end
  end

  describe "#new" do
    it "prefixes and postfixes and timestamps the old table" do
      subject = Lhm::TableName.new("original")
      assert_equal "lhmn_original", subject.new
    end

    it "truncates names below 64 characters" do
      subject = Lhm::TableName.new("some_very_long_original_table_name_that_exceeds_64_characters")
      assert_equal "lhmn_some_very_long_original_table_name_that_exceeds_64_characte", subject.new
    end
  end
end
