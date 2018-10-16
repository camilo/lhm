module Lhm
  class TableName
    def initialize(original, time = Time.now)
      @original = original
      @time = time
      @timestamp = Timestamp.new(time)
    end

    attr_reader :original

    def archived
      "lhma_#{@timestamp}_#{@original}"[0...64]
    end

    def failed
      archived[0...57] + "_failed"
    end

    def new
      "lhmn_#{@original}"[0...64]
    end
  end
end
