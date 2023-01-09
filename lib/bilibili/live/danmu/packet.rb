module Bilibili
  module Live
    module Danmu
      class Packet
        module Offset
          PACKET_LENGTH = 0
          HEADER_LENGTH = 4
          PROTOCOL = 6
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

        class EnterRoom < Packet
          def initialize(room_id:)
            body = {
              roomid: room_id
            }.to_json

            super(
              protocol: Protocol::JSON,
              operation: Operation::ENTER_ROOM,
              sequence_id: 1,
              body: body
            )
          end
        end

        class Heartbeat < Packet
          def initialize
            super(
              protocol: Protocol::JSON,
              operation: Operation::HEARTBEAT,
              sequence_id: 1,
              body: {}.to_json
            )
          end
        end

        class << self
          def from_bytes(data)
            decoded_data = decode(data)
            protocol = decoded_data[:protocol]

            bodies =
              if decoded_data[:body_bytes] == EMPTY_BODY_BYTES
                {}.to_json
              else
                case protocol
                when Protocol::JSON
                  decoded_data[:body_bytes].pack("C*")
                when Protocol::ZLIB_BUFFER
                  decompressed_data = Zlib::Inflate.inflate(decoded_data[:body_bytes].pack("C*")).unpack("C*")
                  decode(decompressed_data)[:body_bytes].pack("C*")
                when Protocol::BROTLI_BUFFER
                  decompressed_data = Brotli.inflate(compressed).unpack("C*")
                  decode(decompressed_data)[:body_bytes].pack("C*")
                when Protocol::INT32_BIG_ENDIAN
                  raise "deprecated int32 big ending protocol"
                else
                  raise "unknown protocol version: #{protocol}"
                end
              end

            packets = []
            bodies.split(/[\x00-\x1f]+/) do |body|
              next unless json?(body)

              packets << Packet.new(
                protocol: protocol,
                operation: decoded_data[:operation],
                sequence_id: decoded_data[:sequence_id],
                body: body
              )
            end
            packets
          end

          def decode(data)
            {
              protocol: data[Offset::PROTOCOL...Offset::OPERATION].pack("C*").unpack1("n"),
              operation: data[Offset::OPERATION...Offset::SEQUENCE_ID].pack("C*").unpack1("N"),
              sequence_id: data[Offset::SEQUENCE_ID...Offset::BODY].pack("C*").unpack1("N"),
              body_bytes: data[Offset::BODY..]
            }
          end

          def json?(data)
            JSON.parse(data)
            true
          rescue JSON::ParserError
            false
          end
        end

        attr_accessor :protocol, :operation, :sequence_id, :body

        def initialize(protocol:, operation:, sequence_id:, body:)
          @protocol = protocol
          @operation = operation
          @sequence_id = sequence_id
          @body = body
        end

        def message
          HashWithIndifferentAccess.new(JSON.parse(body))
        end

        def to_bytes
          header_bytes = []
          header_bytes += [packet_length].pack("N").unpack("C*")
          header_bytes += [header_length].pack("n").unpack("C*")
          header_bytes += [protocol].pack("n").unpack("C*")
          header_bytes += [operation].pack("N").unpack("C*")
          header_bytes += [sequence_id].pack("N").unpack("C*")
          header_bytes + body.unpack("C*")
        end

        def header_length
          Offset::BODY - Offset::PACKET_LENGTH
        end

        def packet_length
          header_length + body.bytesize
        end
      end
    end
  end
end
