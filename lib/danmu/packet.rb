require "json"

module Danmu
  class Packet
    module Offset
      PACKET_LENGTH = 0
      HEADER_LENGTH = 4
      PROTOCOL_VERSION = 6
      OPERATION = 8
      SEQUENCE_ID = 12
      BODY = 16
    end

    module Protocol
      JSON = 0
      INT32_BIG_ENDIAN = 1
      ZLIB_BUFFER = 2
      BROTLI_BUFFER = 3
    end

    module Operation
      HEARTBEAT = 2
      HEARTBEAT_RESPONSE = 3
      NOTIFY = 5
      ENTER_ROOM = 7
      ENTER_ROOM_RESPONSE = 8
    end

    EMPTY_BODY_BYTES = [0, 0, 0, 1].freeze

    class EnterRoom
      def initialize(room_id:)
        body = {
          roomid: room_id
        }

        Packet.new(
          protocol_version: Protocol::JSON,
          operation: Operation::ENTER_ROOM,
          sequence_id: 1,
          body: body
        )
      end
    end

    class Heartbeat
      def initialize
        Packet.new(
          protocol_version: Protocol::JSON,
          operation: Operation::HEARTBEAT,
          sequence_id: 1,
          body: {}
        )
      end
    end

    class << self
      def from_bytes(data)
        protocol_version = data[Offset::PROTOCOL_VERSION...Offset::OPERATION].pack("n")
        operation = data[Offset::OPERATION...Offset::SEQUENCE_ID].pack("N")
        sequence_id = data[Offset::SEQUENCE_ID...Offset::BODY].pack("N")

        body_bytes = data[Offset::BODY..]
        body =
          if body_bytes == EMPTY_BODY_BYTES
            {}
          else
            JSON.parse(body_bytes.pack("C*"))
          end

        Packet.new(protocol_version: protocol_version, operation: operation, sequence_id: sequence_id, body: body)
      end
    end

    attr_accessor :protocol_version, :operation, :sequence_id, :body

    def initialize(protocol_version:, operation:, sequence_id:, body:)
      @protocol_version = protocol_version
      @operation = operation
      @sequence_id = sequence_id
      @body = Message.new(body)
    end

    def to_bytes
      header_bytes = []
      header_bytes += [packet_length].pack("N").unpack("C*")
      header_bytes += [header_length].pack("n").unpack("C*")
      header_bytes += [protocol_version].pack("n").unpack("C*")
      header_bytes += [operation].pack("N").unpack("C*")
      header_bytes += [sequence_id].pack("N").unpack("C*")
      header_bytes + JSON.generate(body).bytes
    end

    def header_length
      Offset::BODY - Offset::PACKET_LENGTH
    end

    def packet_length
      header_length + body.size
    end
  end
end
