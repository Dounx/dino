require_relative "packet"

module Bilibili
  module Live
    module Danmu
      class Client
        URL = "wss://broadcastlv.chat.bilibili.com/sub"

        def initialize(room_id:)
          @room_id = room_id
        end

        def run
          EM.run do
            @ws = Faye::WebSocket::Client.new(URL)

            @ws&.on :open do
              @ws.send(Packet::EnterRoom.new(room_id: @room_id).to_bytes)
            end

            @ws&.on :message do |event|
              packets = Packet.from_bytes(event.data)
              yield(packets) if block_given?
            end

            @ws&.on :close do |_event|
              @ws = nil
            end

            EM.add_periodic_timer(30) do
              @ws&.send(Packet::Heartbeat.new.to_bytes)
            end
          end
        end
      end
    end
  end
end
