# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Scene Graph Profiler
  class Profiler < Util
    extend Plugin

    def self.commands
      {
        profile: {device: true},
        sgperf: {device: true},
        devlog: {device: true},
        node_tracking: {device: true}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("--profile COMMAND", "Run various profiler options") do |c|
        options[:profile] = c
      end
      parser.on("--sgperf", "Run scenegraph profiler") do
        options[:sgperf] = true
      end
      parser.on("--devlog FUNCTION [TYPE]", "Run scenegraph profiler") do |f, t|
        options[:devlog] = t || "rendezvous"
        options[:devlog_function] = f
      end
      parser.on("--node-tracking [INTERVAL]", "Take snapshots of the current nodes and print difference since last snapshot") do |interval|
        options[:node_tracking] = true
        options[:node_tracking_interval] = interval
      end
      parser.separator "Options:"
      parser.on("--add-ids", "Add ids to stats command") do
        options[:add_ids] = true
      end
    end

    # Run the profiler commands
    # @param command [Symbol] The profiler command to run
    def profile(options:)
      @options = options
      @connection = nil
      case options[:profile].to_sym
      when :stats
        print_all_node_stats
      when :all
        print_all_nodes
      when :roots
        print_root_nodes
      when :images
        print_image_information
      when :memmory
        print_memmory_usage
      when :textures
        print_texture_information
      else
        print_nodes_by_id(options[:profile])
      end
      @connection.close if @connection
    end

    def sgperf(options:)
      telnet_config = nil
      get_device(no_lock: true) do |device|
        telnet_config ={
          'Host' => device.ip,
          'Port' => 8080
        }
      end
      @connection = Net::Telnet.new(telnet_config)
      @connection.puts("sgperf clear\n")
      @connection.puts("sgperf start\n")
      start_reg = /thread/
      end_reg = /#{SecureRandom.uuid}/
      prev_lines = 0
      begin
      while true
        lines = get_command_response(command: "sgperf report", start_reg: start_reg,
          end_reg: end_reg, ignore_warnings: true)
        results = []
        lines.each do |line|
          match = /thread node calls: create\s*(\d*) \+ op\s*(\d*)\s*@\s*(\d*\.\d*)% rendezvous/.match(line)
          results.push([match[1].to_i, match[2].to_i, match[3].to_f])
        end
        print "\r" + ("\e[A\e[K"*prev_lines)
        prev_lines = 0
        results.each_index do |i|
          line = results[i]
          if line[0] > 0 or line[1] > 0 or options[:verbose]
            prev_lines += 1
            puts "Thread #{i}: c:#{line[0]} u:#{line[1]} r:#{line[2]}%"
          end
        end
      end
      rescue SystemExit, Interrupt
        @connection.close if @connection
      end
    end

    def devlog(options:)
      telnet_config = nil
      get_device(no_lock: true) do |device|
        telnet_config ={
          'Host' => device.ip,
          'Port' => 8080
        }
      end
      connection = Net::Telnet.new(telnet_config)
      connection.puts("enhanced_dev_log #{options[:devlog]} #{options[:devlog_function]}\n")
    end

    def node_tracking(options:)
      @options = options
      @connection = nil
      begin
        current_nodes = nil
        previous_nodes = nil
        while true
          current_nodes = get_stats
          diff = diff_node_stats(current_nodes, previous_nodes)
          print_stats(stats: diff)
          previous_nodes = current_nodes
          current_nodes = nil
          STDIN.read(1)
        end
      rescue SystemExit, Interrupt
        @connection.close if @connection
      end
    end

    private

    # Print the node stats
    def print_all_node_stats
      print_stats(stats: get_stats)
    end

    # Print the node stats
    def get_stats
      end_reg = /<\/All_Nodes>/
      start_reg = /<All_Nodes>/
      lines = get_command_response(command: "sgnodes all", start_reg: start_reg, end_reg: end_reg)
      xml_string = lines.join("\n")
      stats = {"Total" => {count: 0}}
      doc = Nokogiri::XML(xml_string)
      handle_node(stats: stats, node: doc.root)
      stats
    end

    def print_stats(stats:)
      stats = stats.to_a
      stats = stats.sort do |a, b|
        next -1 if a[0] == "Total"
        next 1 if b[0] == "Total"
        b[1][:count] <=> a[1][:count]
      end
      if @options[:add_ids]
        printf "%30s | %5s | %s\n%s\n", "Name", "Count", "Ids", "-"*60
      else
        printf "%30s | %5s\n%s\n", "Name", "Count", "-"*60
      end
      stats.each do |key_pair|
        if key_pair[0] == "Total" and key_pair[1][:total]
          printf "%30s | %5d %5d", key_pair[0], key_pair[1][:count], key_pair[1][:total]
        else
          printf "%30s | %5d", key_pair[0], key_pair[1][:count]
        end
        if @options[:add_ids] and key_pair[1][:ids] and key_pair[1][:ids].count > 0
          id_string = key_pair[1][:ids].join(",")
          printf "[#{id_string}]"
        end
        printf "\n"
      end
    end

    def handle_node(stats:,  node:)
      if node
        node.element_children.each do |element|
          attributes = element.attributes.map{|attr| {"#{attr.name}": attr.value}}.reduce({}, :merge)
          stats[element.name] ||= {count: 0, ids: []}
          stats[element.name][:count] += 1
          stats[element.name][:ids].push(attributes[:name]) if attributes[:name]
          stats["Total"][:count] += 1
          handle_node(stats: stats, node: element)
        end
      end
    end

    def diff_node_stats(current, previous)
      return current unless previous
      diff = current.deep_dup
      diff.each_pair do |node, stats|
        if previous[node]
          stats[:count] = stats[:count] - previous[node][:count]
          if stats[:count] == 0 and node != "Total"
            diff.delete(node)
          elsif stats[:ids]
            stats[:ids] = stats[:ids] - previous[node][:ids]
          end
        end
      end
      removed = previous.reject{|k,v| current.keys.include?(k)}
      removed.each_pair do |node, stats|
        stats[:count] *= -1
        diff[node] = stats
      end
      diff["Total"][:total] = current["Total"][:count]
      diff
    end

    def print_all_nodes
      start_reg = /<All_Nodes>/
      end_reg = /<\/All_Nodes>/
      lines = get_command_response(command: "sgnodes all", start_reg: start_reg, end_reg: end_reg)
      lines.each {|line| print line}
    end
    def print_root_nodes
      start_reg = /<Root_Nodes>/
      end_reg = /<\/Root_Nodes>/
      lines = get_command_response(command: "sgnodes roots", start_reg: start_reg, end_reg: end_reg)
      lines.each {|line| print line}
    end
    def print_nodes_by_id(id)
      start_reg = /<#{id}>/
      end_reg = /<\/#{id}>/
      lines = get_command_response(command: "sgnodes #{id}", start_reg: start_reg, end_reg: end_reg)
      lines.each {|line| print line}
    end
    def print_image_information
      start_reg = /RoGraphics instance/
      end_reg = /Available memory/
      lines = get_command_response(command: "r2d2_bitmaps", start_reg: start_reg, end_reg: end_reg)
      lines = sort_image_lines(lines, /0x[^\s]+\s+\d+\s+\d+\s+\d+\s+\d+/, 4)
      lines.each {|line| print line}
    end
    def print_memmory_usage
      start_reg = /RoGraphics instance/
      end_reg = /Available memory/
      begin
      while true
        lines = get_command_response(command: "r2d2_bitmaps", start_reg: start_reg, end_reg: end_reg, ignore_warnings: true)
        memmory_data = get_memmory_data(lines)
        print_memmory_data(memmory_data)
        sleep 1
      end
      rescue SystemExit, Interrupt
        #Exit
      end
    end
    def print_texture_information
      start_reg = /\*+/
      end_reg = /#{SecureRandom.uuid}/
      lines = get_command_response(command: "loaded_textures", start_reg: start_reg, end_reg: end_reg)
      lines = sort_image_lines(lines, /\s*\d+\sx\s+\d+\s+\d/, 3)
      lines.each {|line| print line}
    end

    # Retrive list of all nodes
    # @return [Array<String>] Array of lines
    def get_command_response(command:, start_reg:, end_reg:, unique: false, ignore_warnings: false)
      waitfor_config = {
        'Match' => /.+/,
        'Timeout' => 1
      }
      unless @connection
        telnet_config = nil
        get_device(no_lock: true) do |device|
          telnet_config ={
            'Host' => device.ip,
            'Port' => 8080
          }
        end
        @connection = Net::Telnet.new(telnet_config)
      end

      @lines = []
      @all_txt = ""
      @begun = false
      @done = false
      @connection.puts("#{command}\n")
      while not @done
        begin
          @connection.waitfor(waitfor_config) do |txt|
            handle_text(txt: txt, start_reg: start_reg, end_reg: end_reg, unique: unique)
          end
        rescue Net::ReadTimeout
          @logger.warn "Timed out reading profiler information" unless ignore_warnings
          @done = true
        end
      end
      @lines
    end

    # Handle profiling text
    # @param all_txt [String] remainder text from last run
    # @param txt [String] current text from telnet
    # @param in_nodes [Boolean] currently parsing test text
    # @return [Boolean] currently parsing test text
    def handle_text(txt:, start_reg:, end_reg:, unique:)
      @all_txt += txt
      while line = @all_txt.slice!(/^.*\n/) do
        if line =~ start_reg
          @begun = true
          @done = false
          @lines = [] if unique
        end
        @lines.push(line) if @begun
        if line =~ end_reg
          @begun = false
          @done = true
        end
      end
    end

    def sort_image_lines(lines, reg, size_index)
      new_lines = []
      line = lines.shift
      while line != nil
        line_data = []
        while line =~ reg
          line_data.push({line: line, size: line.split[size_index].to_i})
          line = lines.shift
        end
        line_data.sort! {|a, b| b[:size] <=> a[:size]}
        line_data.each {|data| new_lines.push(data[:line])}
        new_lines.push(line)
        line = lines.shift
      end
      return new_lines
    end

    def get_memmory_data(lines)
      data = {}
      line = lines.shift
      while line != nil
        first_match = /RoGraphics instance (0x.*)/.match(line)
        if first_match
          while line != nil
            usage_match = /Available memory (\d*) used (\d*) max (\d*)/.match(line)
              if usage_match
                data[first_match[1]] = [usage_match[1].to_i, usage_match[2].to_i, usage_match[3].to_i]
                break
              end
            line = lines.shift
          end
        end
        line = lines.shift
      end
      return data
    end

    def print_memmory_data(data)
      @prev_lines ||= 0
      print "\r" + ("\e[A\e[K"*@prev_lines)
      data.each_key do |key|
        print "#{key}: #{(data[key][1]*100)/data[key][2]}%\n"
      end
      @prev_lines = data.count
    end
  end
  RokuBuilder.register_plugin(Profiler)
end
