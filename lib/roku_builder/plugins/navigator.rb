# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Navigation methods
  class Navigator < Util
    extend Plugin

    def self.commands
      {
        nav: {device: true},
        navigate: {device: true},
        type: {device: true},
        screen: {device: true},
        screens: {}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator("Commands:")
      parser.on("-N", "--nav CMD", "Send the given command to the roku") do |n|
        options[:nav] = n
      end
      parser.on("--navigate", "Run interactive navigator") do
        options[:navigate] = true
      end
      parser.on("-y", "--type TEXT", "Type the given text on the roku device") do |t|
        options[:type] = t
      end
      parser.on("--screen SCREEN", "Show a screen") do |s|
        options[:screen] = s
      end
      parser.on("--screens", "Show possible screens") do
        options[:screens] = true
      end
    end

    # Setup navigation commands
    def init()
      @commands = {
        home: "Home",             rew: "Rev",                 ff: "Fwd",
        play: "Play",             select: "Select",           left: "Left",
        right: "Right",           down: "Down",               up: "Up",
        back: "Back",             replay: "InstantReplay",    info: "Info",
        backspace: "Backspace",   search: "Search",           enter: "Enter",
        volumedown: "VolumeDown", volumeup: "VolumeUp",       mute: "VolumeMute",
        channelup: "ChannelUp",   channeldown: "ChannelDown", tuner: "InputTuner",
        hdmi1: "InputHDMI1",      hdmi2: "InputHDMI2",        hdmi3: "InputHDMI3",
        hdmi4: "InputHDMI4",      avi: "InputAVI"
      }
      @screens = {
        platform: [:home, :home, :home, :home, :home, :ff, :play, :rew, :play, :ff],
        secret: [:home, :home, :home, :home, :home, :ff, :ff, :ff, :rew, :rew],
        secret2: [:home, :home, :home, :home, :home, :up, :right, :down, :left, :up],
        channels: [:home, :home, :home, :up, :up, :left, :right, :left, :right, :left],
        developer: [:home, :home, :home, :up, :up, :right, :left, :right, :left, :right],
        wifi: [:home, :home, :home, :home, :home, :up, :down, :up, :down, :up],
        antenna: [:home, :home, :home, :home, :home, :ff, :down, :rew, :down, :ff],
        bitrate: [:home, :home, :home, :home, :home, :rew, :rew, :rew, :ff, :ff],
        network: [:home, :home, :home, :home, :home, :right, :left, :right, :left, :right],
        reboot: [:home, :home, :home, :home, :home, :up, :rew, :rew, :ff, :ff]
      }
      @runable = [
        :secret, :channels
      ]
      mappings_init
    end


    # Send a navigation command to the roku device
    # @param command [Symbol] The smbol of the command to send
    # @return [Boolean] Success
    def nav(options:)
      commands = options[:nav].split(/, */).map{|c| c.to_sym}
      commands.each do |command|
        unless @commands.has_key?(command)
          raise ExecutionError, "Unknown Navigation Command"
        end
        conn = multipart_connection(port: 8060)
        path = "/keypress/#{@commands[command]}"
        @logger.debug("Send Command: "+path)
        response = conn.post path
        raise ExecutionError, "Navigation Failed" unless response.success?
      end
    end

    # Type text on the roku device
    # @param text [String] The text to type on the device
    # @return [Boolean] Success
    def type(options:)
      conn = multipart_connection(port: 8060)
      options[:type].split(//).each do |c|
        path = "/keypress/LIT_#{CGI::escape(c)}"
        @logger.debug("Send Letter: "+path)
        response = conn.post path
        return false unless response.success?
      end
      return true
    end

    def navigate(options:)
      running = true
      @logger.info("Key Mappings:")
      @mappings.each_value {|key|
        @logger.info(sprintf("%13s -> %s", key[1], @commands[key[0].to_sym]))
      }
      @logger.info(sprintf("%13s -> %s", "Ctrl + c", "Exit"))
      while running
        char = read_char
        @logger.debug("Char: #{char.inspect}")
        if char == "\u0003"
          running = false
        else
          Thread.new(char) {|character| handle_navigate_input(character)}
        end
      end
    end


    # Show the commands for one of the roku secret screens
    # @param type [Symbol] The type of screen to show
    # @return [Boolean] Screen found
    def screen(options:)
      type = options[:screen].to_sym
      unless @screens.has_key?(type)
        raise ExecutionError, "Unknown Screen"
      end
      if @runable.include?(type)
        nav(options: {nav: @screens[type].join(", ")})
      else
        @logger.unknown("Cannot run command automatically")
        display_screen_command(type)
      end
    end

    # Show avaiable roku secret screens
    def screens(options:)
      logger = ::Logger.new(STDOUT)
      logger.formatter = proc {|_severity, _datetime, _progname, msg|
        "%s\n\r" % [msg]
      }
      logger.unknown("----------------------------------------------------------------------")
      @screens.keys.each {|screen|
        logger.unknown(sprintf("%10s: %s", screen.to_s, get_screen_command(screen)))
        logger.unknown("----------------------------------------------------------------------")
      }
    end

    private

    def mappings_init()
      @mappings = {
        "\e[1~": [ "home", "Home" ],
        "<": [ "rew", "<" ],
        ">": [ "ff", ">" ],
        "=": [ "play", "=" ],
        "\r": [ "select", "Enter" ],
        "\e[D": [ "left", "Left Arrow" ],
        "\e[C": [ "right", "Right Arrow" ],
        "\e[B": [ "down", "Down Arrow" ],
        "\e[A": [ "up", "Up Arrow" ],
        "\t": [ "back", "Tab" ],
        #"": [ "replay", "" ],
        "*": [ "info", "*" ],
        "\u007f": [ "backspace", "Backspace" ],
        "?": [ "search", "?" ],
        "\e\r": [ "enter", "Alt + Enter" ],
        "\e[5~": [ "volumeup", "Page Up" ],
        "\e[6~": [ "volumedown", "Page Down" ],
        "\e[4~": [ "mute", "End" ],
        #"": [ "channeldown", "" ],
        #"": [ "channelup", "" ],
        #"": [ "tuner", "" ],
        #"": [ "hdmi1", "" ],
        #"": [ "hdmi2", "" ],
        #"": [ "hdmi3", "" ],
        #"": [ "hdmi4", "" ],
        #"": [ "avi", "" ]
      }
      @mappings.merge!(generate_maggings) if @config.input_mappings
    end

    def generate_maggings
      mappings = {}
      if @config.input_mappings
        @config.input_mappings.each_pair {|key, value|
          unless "".to_sym == key
            key = key.to_s.sub(/\\e/, "\e").to_sym
            mappings[key] = value
          end
        }
      end
      mappings
    end

    def read_char
      STDIN.echo = false
      STDIN.raw!
      input = STDIN.getc.chr
      if input == "\e" then
        input << STDIN.read_nonblock(3) rescue nil
        input << STDIN.read_nonblock(2) rescue nil
      end
      input
    ensure
      STDIN.echo = true
      STDIN.cooked!
    end

    def handle_navigate_input(char)
      if @mappings[char.to_sym] != nil
        nav(options: {nav: @mappings[char.to_sym][0]})
      elsif char.inspect.force_encoding("UTF-8").ascii_only?
        type(options: {type: char})
      end
    end

    def display_screen_command(type)
      logger = ::Logger.new(STDOUT)
      logger.formatter = proc {|_severity, _datetime, _progname, msg|
        "%s\n\r" % [msg]
      }
      logger.unknown(get_screen_command(type))
    end

    def get_screen_command(type)
      display, count, string = [], [], ""
      @screens[type].each do |command|
        if display.count > 0 and  display[-1] == command
          count[-1] = count[-1] + 1
        else
          display.push(command)
          count.push(1)
        end
      end
      display.each_index do |i|
        if count[i] > 1
          string = string + @commands[display[i]]+" x "+count[i].to_s+", "
        else
          string = string + @commands[display[i]]+", "
        end
      end
      string.strip
    end
  end
  RokuBuilder.register_plugin(Navigator)
end
