# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class Debugger < Util
    extend Plugin

    def self.commands
      {debug_app: {source: true, device: true, stage: true}}
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-B", "--debug-app", "Sideload an app and run the remote debugger") do |m|
        options[:debug_app] = true
      end
    end

    def self.dependencies
      [Loader]
    end

    def debug_app(options:)
      loader = Loader.new(config: @config)
      options[:remoteDebug] = true
      @device = RokuBuilder.device_manager.reserve_device()
      loader.sideload(options: options, device: @device)
      begin
        @stopped = false
        initial_continue = false
        @queue = Thread::Queue.new
        start_socket
        start_input_monitor
        loop do
          begin 
            event = @queue.pop(true)
            case event[:type]
            when :logging
              puts event[:value]
            when :input
              process_command event[:value]
            end
          rescue ThreadError
            #Queue Empty
          end
          response = get_socket_response()
          process_response(response) if response
          if @stopped and not initial_continue
            initial_continue = true
            @socket.send_command(:continue)
          end
        end
      rescue IOError => e
        @logger.info "IOError #{e.message}"
      rescue Errno::ECONNRESET => e
        @logger.info "Connection Reset #{e.message}"
      rescue Errno::ETIMEDOUT => e
        @logger.info "Connection Reset #{e.message}"
      rescue Errno::ECONNREFUSED => e
        @logger.info "Connection Refused #{e.message}"
      ensure
        RokuBuilder.device_manager.release_device(@device) if @device
      end
    end

    def start_socket
      @logger.debug "Monitoring Socket"
      start_time = DateTime.now.to_time.to_i
      loop do
        begin
          @socket = RokuDebugSocket.open(@device.ip, 8081, @logger)
          break
        rescue Errno::ECONNREFUSED
          duration = DateTime.now.to_time.to_i - start_time
          raise Errno::ECONNRESET if duration > 60
        end
      end
      @logger.unknown "Started Connection"
      @socket.do_handshake
    end

    def get_socket_response
      response = nil
      begin
        response = @socket.get_response
      rescue IO::WaitReadable
        #Do nothing
      end
      response
    end

    def start_input_monitor
      @logger.debug "Monitoring User Input"
      input_thread = Thread.new(@queue) { |queue|
        loop do
          command = gets
          unless command.empty?
            @logger.debug "Recieved Input: #{command}"
            queue.push({
              type: :input,
              value: command.downcase.chomp
            })
          end
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
        when 4
          @logger.debug "Breakpoint Error"
        when 5
          @logger.debug "Compile Error"
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
      when :stacktrace
        stack = response[:data][:stack]
        log = "Thread Stack Trace:"
        stack.each do |stack_entry|
          log += "\n#{stack_entry[:function_name]}: #{stack_entry[:file_path]}(#{stack_entry[:line_number]})"
        end
        @logger.unknown log
      end
    end

    def open_logger(port)
      @logger.debug "Opening Logging Port"
      io_logger = TCPSocket.open(@device.ip, port)
      io_logger_thread = Thread.new(io_logger, @queue) { |socket,queue|
        text = ""
        loop do
          begin
            value = socket.recv_nonblock(1)
            unless value.nil?
              if value.ord == 10
                queue.push({
                  type: :logging,
                  value: text
                })
                text = ""
              else
                text += value
              end
            end
          rescue IO::WaitReadable
            #Do nothing
          end
        end
      }
    end

    def process_command(command)
      @logger.debug "Processing command: #{command}"
      case command
      when "s", "stop"
        @logger.debug "Sending Stop"
        @socket.send_command(:stop)
      when "c", "continue"
        @logger.debug "Sending Continue"
        @threads = nil
        @socket.send_command(:continue)
      when "t", "threads"
        if @stopped
          @logger.debug "Sending Threads"
          @socket.send_command(:threads)
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
      when /stacktrace (\d+)/
        thread = @threads[$1.to_i]
        if @threads and thread
          @socket.send_command(:stacktrace, {thread_index: $1.to_i})
        else
          @logger.error "Unknown Thread #{$1}"
        end
      else
        @logger.warn "Unknown Command: '#{command}'"
      end
    end
  end


  RokuBuilder.register_plugin(Debugger)

end
