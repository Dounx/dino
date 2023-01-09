module Bilibili
  module Live
    class Room
      def initialize(id:)
        @raw_id = id

        @info = info
        @real_id = @info.dig(:data, :room_id)
      end

      def info
        result = Net::HTTP.get(URI("https://api.live.bilibili.com/room/v1/Room/get_info?room_id=#{@raw_id}"))
        HashWithIndifferentAccess.new(JSON.parse(result))
      end
    end
  end
end
