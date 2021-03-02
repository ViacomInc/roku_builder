# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class Debugger < Util
    extend Plugin

    def self.commands
      {debug: {source: true, device: true, stage: true}}
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-B", "--debug", "Sideload an app and run the remote debugger") do |m|
        options[:debug] = true
      end
    end

    def self.dependencies
      [Loader]
    end

    def debug(options:)
      loader = Loader.new(config: @config)
      options[:remoteDebug] = true
      loader.sideload(options: options)
      begin
        @stopped = false
        initial_continue = false
        @lock = Mutex.new
        @queue = Queue.new
        start_socket_monitor
        start_input_monitor
        loop do
          event = @queue.pop
          case event[:type]
          when :logging
            @logger.unknown event[:value]
          when :socket
            process_response event[:value]
          when :input
            process_command event[:value]
          end
          if @stopped and not initial_continue
            initial_continue = true
            @lock.synchronize do
              @socket.send_command(:continue)
            end
          end
        end
      rescue IOError => e
        @logger.info "IOError #{e.message}"
      rescue Errno::ECONNRESET => e
        @logger.info "Connection Reset #{e.message}"
      rescue Errno::ETIMEDOUT => e
        @logger.info "Connection Reset #{e.message}"
      end
    end

    def start_socket_monitor
      @logger.debug "Monitoring Socket"
      @socket = RokuDebugSocket.open(@roku_ip_address, 8081, @logger)
      @logger.unknown "Started Connection"
      @socket.do_handshake
      socket_thread = Thread.new(@socket, @queue) { |socket,queue|
        loop do
          begin
            response = nil
            @lock.synchronize do
              response = socket.get_response
            end
            if response[:request_id]
              queue.push({
                type: :socket,
                value: response
              })
            end
          rescue IO::WaitReadable
            #Do nothing
          end
        end
      }
    end

    def start_input_monitor
      @logger.debug "Monitoring User Input"
      input_thread = Thread.new(@queue) { |queue|
        loop do
          command = gets
          queue.push({
            type: :input,
            value: command.downcase.chomp
          })
        end
      }
    end

    def process_response(response)
      if response[:request_id] == 0
        case response[:update_type]
        when 1
          open_logger(response[:data])
        when 2
          @stopped  = true
          @logger.debug "All Threads Stopped"
          @logger.debug " --- reason: #{response[:data][:stop_reason]}"
          @logger.debug " --- detail: #{response[:data][:stop_reason_detail]}"
        when 3
          @logger.debug "Thread Attached"
          @logger.debug " --- reason: #{response[:data][:stop_reason]}"
          @logger.debug " --- detail: #{response[:data][:stop_reason_detail]}"
        end
      else
        @logger.debug "Command Response"
        @logger.debug " --- command: #{response[:command]}"
        @logger.debug " --- error_code: #{response[:error_code]}"
        process_command_response(response)
      end
    end

    def process_command_response(response)
      case response[:command]
      when :threads
        @threads = response[:data][:threads]
        @threads.each_with_index do |thread, idx|
          @logger.unknown "Thread #{idx}: #{thread[:file_path]}"
        end
      end
    end

    def open_logger(port)
      @logger.debug "Opening Logging Port"
      io_logger = TCPSocket.open(@roku_ip_address, port)
      io_logger_thread = Thread.new(io_logger, @queue) { |socket,queue|
        text = ""
        loop do
          begin
            value = socket.recv_nonblock(1)
            if value.ord == 10
              queue.push({
                type: :logging,
                value: text
              })
              text = ""
            else
              text += value
            end
          rescue IO::WaitReadable
            #Do nothing
          end
        end
      }
    end

    def process_command(command)
      case command
      when "s", "stop"
        @logger.debug "Sending Stop"
        @lock.synchronize do
          @socket.send_command(:stop)
        end
      when "c", "continue"
        @logger.debug "Sending Continue"
        @threads = nil
        @lock.synchronize do
          @socket.send_command(:continue)
        end
      when "t", "threads"
        if @stopped
          @logger.debug "Sending Threads"
          @lock.synchronize do
            @socket.send_command(:threads)
          end
        else
          @logger.warn "Must be stopped to use that command"
        end
      when /thread (\d+)/
        thread = @threads[$1.to_i]
        if @threads and thread
           @logger.unknown "Thread #{$1}:\nFunction: #{thread[:function_name]}\nFile Path: #{thread[:file_path]}\nLine Number: #{thread[:line_number]}"
        else
          @logger.error "Unknown Thread #{$1}"
        end
      else
        @logger.warn "Unknown Command: '#{command}'"
      end
    end
  end


  RokuBuilder.register_plugin(Debugger)

  class RokuDebugSocket < TCPSocket

    MAGIC = 29120988069524322

    def initialize(ip, port, logger)
      super ip, port
      @logger = logger
      @request_id = 1
      @active_requests = {}
    end

    def do_handshake
      send_uint64(MAGIC)
      raise SocketError, 'Non-matching Magic Numbers' unless MAGIC == read_uint64
      version = [read_uint32(), read_uint32(), read_uint32()]
      raise IOError, "Unsupported Version" unless support_version?(version)
    end

    def get_response
      response = {}
      response[:request_id] = read_uint32(true)
      @logger.debug "Recieved Response #{response[:request_id]}"
      if response[:request_id] == 0
        response[:error_code] = read_uint32
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
        end
      elsif @active_requests[response[:request_id].to_s]
        response[:error_code] = read_uint32
        response[:command] = @active_requests[response[:request_id].to_s]
        response[:data] = get_data(response[:command])
        @active_requests.delete response[:request_id].to_s
      elsif response[:request_id] != nil
        raise IOError, "Unknown request id: #{response[:request_id]}"
      end
      response
    end

    def send_command(command)
      @logger.debug "Sending Command: #{command}"
      commands = {
        stop: 1,
        continue: 2,
        threads: 3
      }
      size = get_size(command)
      send_uint32(size)
      send_uint32(@request_id)
      send_uint32(commands[command])
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
        threads: 12
      }
      return command_size[command]
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
      end
    end

    def send_uint64(val)
      send([val].pack('Q'), 0)
    end

    def send_uint32(val)
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
        break if char == "\0"
        string += char
      end
      string
    end

    def support_version?(version)
      supported_versions = [
        [2, 0, 0],
        [1, 0, 1]
      ]
      supported_versions.include?(version)
    end
  end
end
