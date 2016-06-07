# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Navigation methods
  class Navigator < Util

    # Setup navigation commands
    def init
      @commands = {
        up: "Up",
        down: "Down",
        right: "Right",
        left: "Left",
        select: "Select",
        back: "Back",
        home: "Home",
        rew: "Rev",
        ff: "Fwd",
        play: "Play",
        replay: "InstantReplay"
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
    end

    # Send a navigation command to the roku device
    # @param command [Symbol] The smbol of the command to send
    # @return [Boolean] Success
    def nav(command:)
      if @commands.has_key?(command)
        conn = multipart_connection(port: 8060)

        path = "/keypress/#{@commands[command]}"
        response = conn.post path
        return response.success?
      else
        return false
      end
    end

    # Type text on the roku device
    # @param text [String] The text to type on the device
    # @return [Boolean] Success
    def type(text:)
      conn = multipart_connection(port: 8060)
      text.split(//).each do |c|
        path = "/keypress/LIT_#{CGI::escape(c)}"
        response = conn.post path
        return false unless response.success?
      end
      return true
    end

    # Show the commands for one of the roku secret screens
    # @param type [Symbol] The type of screen to show
    # @return [Boolean] Screen found
    def screen(type:)
      if @screens.has_key?(type)
        display = []
        count = []
        @screens[type].each do |command|
          if display.count > 0 and  display[-1] == command
            count[-1] = count[-1] + 1
          else
            display.push(command)
            count.push(1)
          end
        end
        string = ""
        display.each_index do |i|
          if count[i] > 1
            string = string + @commands[display[i]]+" x "+count[i].to_s+", "
          else
            string = string + @commands[display[i]]+", "
          end
        end
        @logger.unknown(string.strip)
      else
        return false
      end
      true
    end

    # Show avaiable roku secret screens
    def screens
      @screens.keys.each {|screen| @logger.unknown(screen)}
    end
  end
end
