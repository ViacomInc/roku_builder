# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Change stage of roku application
  class Stager

    def initialize(config:, options:)
      @config = config
      @options = options
      @method = get_method
      @ref = get_git_ref
      @scripts = get_scripts
      @root_dir = config.root_dir
      @logger = Logger.instance
      @stage_success = true
      @stash_key = "roku-builder-temp-stash"
    end

    # Helper method to get the staging method being used
    # @return [Symbol] staging method being used
    def method
      @method
    end


    # Change the stage of the app depending on the method
    # @return [Boolean] whether the staging was successful or not
    def stage
      @orginal_directory = Dir.pwd
      case @method
      when :current, :in
        # Do Nothing
      when :working
        switch_directory
      when :git
        switch_directory
        begin
          git_switch_to(branch: @ref)
        rescue Git::GitExecuteError
          git_rescue
          @stage_success = false
        end
      when :script
        switch_directory
        RokuBuilder.system(command: @scripts[:stage])
      end
      @stage_success
    end

    # Revert the change that the stage method made
    # @return [Boolean] whether the revert was successful or not
    def unstage
      @orginal_directory ||= Dir.pwd
      unstage_success = true
      case @method
      when :current, :in, :working
        # Do Nothing
      when :git
        switch_directory
        begin
          git_switch_from(branch: @ref, checkout: @stage_success)
        rescue Git::GitExecuteError
          git_rescue
          unstage_success = false
        end
        switch_directory_back
      when :script
        switch_directory
        RokuBuilder.system(command: @scripts[:unstage])  if @scripts[:unstage]
        switch_directory_back
      end
      unstage_success
    end

    private

    def get_method
      method = ([:in, :current, :working] & @options.keys).first
      if @config.project
        method = @config.project[:stage_method]
      end
      method
    end

    def get_git_ref
      if @options[:ref]
        @options[:ref]
      elsif @config.stage
        @config.stage[:branch]
      end
    end

    def get_scripts
      @config.stage[:script] if @config.stage
    end

    def switch_directory
      Dir.chdir(@root_dir) unless @root_dir.nil? or @root_dir == @orginal_directory
    end

    def switch_directory_back
      Dir.chdir(@orginal_directory) unless @root_dir == @orginal_directory
    end

    # Switch to the correct branch
    # @param branch [String] the branch to switch to
    def git_switch_to(branch:)
      if branch
        @git ||= Git.open(@root_dir)
        @git.branch.stashes.save(@stash_key)
        if @git and branch != @git.current_branch
          @current_branch = @git.current_branch
          @git.checkout(branch)
          save_state
        end
      end
    end

    # Switch back to the previous branch
    # @param branch [String] teh branch to switch from
    # @param checkout [Boolean] whether to actually run the checkout command
    def git_switch_from(branch:, checkout: true)
      @current_branch ||= nil
      if branch
        @git ||= Git.open(@root_dir)
        if @git and (@current_branch or load_state)
          @git.checkout(@current_branch) if checkout
        end
        if @git
          index = 0
          @git.branch.stashes.each do |stash|
            if stash.message == @stash_key
              @git.branch.stashes.pop("stash@{#{index}}")
              break
            end
            index += 1
          end
        end
      end
    end

    # Save staging state to file
    def save_state
      store = PStore.new(File.expand_path("~/.roku_pstore"))
      store.transaction do
        store[:current_branch] = @current_branch.to_s
      end
    end

    # Load staging state from file
    def load_state
      store = PStore.new(File.expand_path("~/.roku_pstore"))
      store.transaction do
        @git.branches.each do |branch|
          if branch.to_s == store[:current_branch]
            @current_branch = branch
            store[:current_branch] = nil
            break
          end
        end
        !!@current_branch
      end
      !!@current_branch
    end

    # Called if resuce from git exception
    def git_rescue
      @logger.error "Branch or ref does not exist"
    end
  end
end
