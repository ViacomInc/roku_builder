module RokuBuilder

  class RokuDebugSocket < TCPSocket

    MAGIC = 29120988069524322

    def initialize(ip, port, logger)
      super ip, port
      @logger = logger
      @request_id = 1
      @active_requests = {}
      @current_packet_length = 0
    end

    def do_handshake
      send_uint64(MAGIC)
      raise SocketError, 'Non-matching Magic Numbers' unless MAGIC == read_uint64
      version = [read_uint32(), read_uint32(), read_uint32()]
      raise IOError, "Unsupported Version" unless support_version?(version)
      remaining_length = read_uint32()-12
      platform_revision_timestamp = Time.at(read_int64()/1000).to_datetime
      @logger.debug "Platform Revision Timestamp: #{platform_revision_timestamp}"
      @logger.debug "Remaining bytes: #{remaining_length}"
      remaining_length.times {read_int8}
    end

    def get_response
      response = {}
      @current_packet_length = read_uint32(true) - 4
      response[:request_id] = read_uint32
      @logger.debug "Recieved Response: #{response[:request_id]}, bytes left: #{@current_packet_length}"
      response[:error_code] = read_uint32
      if response[:request_id] == 0
        response[:update_type] = read_uint32
        case response[:update_type]
        when 0
          raise IOError, "Undefined Update Type"
        when 1
          response[:data] = read_uint32
        when 2..3
          data = {}
          data[:primary_thread_index] = read_int32
          data[:stop_reason] = read_uint8
          data[:stop_reason_detail] = read_utf8z
          response[:data] = data
        when 4
          data = {}
          data[:flags] = read_uint32
          data[:breakpoint_id] = read_uint32
          [:compile, :runtime, :other].each do |error|
            data["num_#{error}_errors".to_sym] = read_uint32
            data["#{error}_errors".to_sym] = []
            data["num_#{error}_errors".to_sym].times do
              data["#{error}_errors".to_sym].push read_utf8z
            end
          end
          response[:data] = data
        when 5
          data[:flags] = read_uint32
          data[:error_string] = read_utf8z
          data[:file_spec] = read_utf8z
          data[:line_number] = read_uint32
          data[:library_name] = read_utf8z
          response[:data] = data
        end
      elsif @active_requests[response[:request_id].to_s]
        if response[:error_code] != 0
          response[:error_flags] = read_uint32() 
          response[:error_data] = []
          response[:error_flags].times do
            response[:error_data].push read_uint8()
          end
        else
          response[:data] = read_uint8()
        end
        response[:command] = @active_requests[response[:request_id].to_s]
        response[:data] = get_data(response[:command])
        @active_requests.delete response[:request_id].to_s
      elsif response[:request_id] != nil
        clean_packet
        raise IOError, "Unknown request id: #{response[:request_id]}"
      end
      clean_packet
      response
    end

    def clean_packet
      @logger.debug "Cleaning #{@current_packet_length} bytes" if @current_packet_length > 0
      while @current_packet_length > 0
        read_int8
      end
    end

    def send_command(command, params = nil)
      @logger.debug "Sending Command: #{command}"
      commands = {
        stop: 1,
        continue: 2,
        threads: 3,
        stacktrace: 4
      }
      size = get_size(command)
      send_uint32(size)
      send_uint32(@request_id)
      send_uint32(commands[command])
      send_params(command, params) if params
      @active_requests[@request_id.to_s] = command
      @request_id += 1
    end

    def get_text
      read_utf8z
    end

    private

    def get_size(command)
      command_size = {
        stop: 12,
        continue: 12,
        threads: 12,
        stacktrace: 16
      }
      return command_size[command]
    end

    def send_params(command, params)
      case command
      when :stacktrace
        if params[:thread_index]
          send_uint32(params[:thread_index])
        else
          raise IOError, "Missing Param for 'stasktrace' command"
        end
      end
    end

    def get_data(command)
      case command
      when :stop
        return nil
      when :continue
        return nil
      when :threads
        data = {
          count: read_uint32,
          threads: []
        }
        data[:count].times do
          thread = {
            flags: read_uint8,
            stop_reason: read_uint32,
            stop_reason_detail: read_utf8z,
            line_number: read_uint32,
            function_name: read_utf8z,
            file_path: read_utf8z,
            code_snippet: read_utf8z
          }
          data[:threads].push(thread)
        end
        return data
      when :stacktrace
        data = {
          count: read_uint32,
          stack: []
        }
        data[:count].times do
          stack_entry = {
            line_number: read_uint32,
            function_name: read_utf8z,
            file_name: read_utf8z
          }
          data[:stack].push(stack_entry)
        end
        return data
      end
    end

    def send_uint64(val)
      @logger.debug "SEND VALUE: #{val}"
      send([val].pack('Q'), 0)
    end

    def send_uint32(val)
      @logger.debug "SEND VALUE: #{val}"
      send([val].pack('L'), 0)
    end

    def read_uint64(non_block = nil)
      read(8, 'Q', non_block)
    end

    def read_int64(non_block = nil)
      read(8, 'q', non_block)
    end

    def read_uint32(non_block = nil)
      read(4, 'L', non_block)
    end

    def read_int32(non_block = nil)
      read(4, 'l', non_block)
    end

    def read_uint8(non_block = nil)
      read(1, 'C', non_block)
    end

    def read_int8(non_block = nil)
      read(1, 'c', non_block)
    end

    def read(length, map, non_block = nil)
      @current_packet_length -= length if @current_packet_length > 0
      if non_block
        value = recv_nonblock(length, Socket::MSG_PEEK)
        check_value(value, length)
        @logger.debug "READ VALUE: #{value.unpack("M")}"
        return recv_nonblock(length).unpack(map).first
      else
        value = recv(length, Socket::MSG_PEEK)
        check_value(value, length)
        @logger.debug "READ VALUE: #{value.unpack("M")}"
        return recv(length).unpack(map).first
      end
    end

    def check_value(value, length)
      unless value.length == length
        raise IOError, "Unexpected EOF reading debug stream"
      end
    end

    def read_utf8z
      string = ""
      loop do
        char = recv(1)
        @current_packet_length -= 1
        break if char == "\0"
        string += char
      end
      string
    end

    def support_version?(version)
      supported_versions = [
        [3, 1, 0],
        [3, 0, 0]
      ]
      supported_versions.include?(version)
    end
  end
end
