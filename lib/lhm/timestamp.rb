module Lhm
  class Timestamp
    def initialize(time)
      @time = time
    end

    def to_s
      @time.strftime "%Y_%m_%d_%H_%M_%S_#{ '%03d' % (@time.usec / 1000) }"
    end
  end
end
