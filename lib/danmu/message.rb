module Danmu
  class Message
    attr_reader :body

    def initialize(body)
      @body = HashWithIndifferentAccess.new(body)
    end

    def code
      body[:code]
    end

    def command
      body[:cmd]
    end

    def data
      body[:data]
    end

    def empty?
      body.empty?
    end

    def to_s
      body.to_s
    end
  end
end
