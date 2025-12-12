module CustomExceptions
  class LimitExceeded < StandardError
    attr_reader :limit_type, :current_count, :limit

    def initialize(message = 'Limit exceeded', limit_type: nil, current_count: nil, limit: nil)
      super(message)
      @limit_type = limit_type
      @current_count = current_count
      @limit = limit
    end
  end
end

