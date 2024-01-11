# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class ConfigValidator

    DEPRICATED_FILES_FOLDERS  = -1
    VALID_CONFIG              = 0
    MISSING_DEVICES           = 1
    MISSING_DEVICES_DEFAULT   = 2
    DEVICE_DEFAULT_BAD        = 3
    #                         = 4
    MISSING_PROJECTS_DEFAULT  = 5
    PROJECTS_DEFAULT_BAD      = 6
    DEVICE_MISSING_IP         = 7
    DEVICE_MISSING_USER       = 8
    DEVICE_MISSING_PASSWORD   = 9
    PROJECT_MISSING_APP_NAME  = 10
    PROJECT_MISSING_DIRECTORY = 11
    PROJECT_MISSING_PLUGIN    = 12
    PROJECT_FOLDERS_BAD       = 13
    PROJECT_MISSING_FILES     = 14
    PROJECT_FILES_BAD         = 15
    STAGE_MISSING_BRANCH      = 16
    STAGE_MISSING_SCRIPT      = 17
    PROJECT_STAGE_METHOD_BAD  = 18
    KEY_MISSING_PATH          = 19
    KEY_MISSING_PASSWORD      = 20
    INVALID_MAPPING_INFO      = 21
    INVALID_API_KEY           = 22
    MISSING_STAGE_METHOD      = 23

    def initialize(config:)
      @logger = Logger.instance
      @config = config
      validate_config
    end

    def print_errors
      @codes.each do |code|
        if code > 0
          @logger.fatal error_codes[code]
        end
        if code < 0
          @logger.warn error_codes[code]
        end
      end
    end

    def is_fatal?
      !@codes.select{|code| code > 0}.empty?
    end

    def is_depricated?
      !@codes.select{|code| code < 0}.empty?
    end

    def is_valid?
      @codes.select{|code| code > 0}.empty?
    end

    private

    def validate_config
      @codes = []
      validate_structure
      [:projects, :devices, :keys, :input_mappings, :api_keys].each do |section|
        validate_section(section: section) if @config[section]
      end
      @codes.uniq!
      @codes.push(VALID_CONFIG) if @codes.empty?
    end

    def validate_section(section:)
      @config[section].each do |key, value|
        next unless should_validate(key: key)
        call_validate_method_for_section(section: section, content: value)
        if has_stages(section_content: value)
          validate_stages(project_content: value)
        end
      end
    end

    def should_validate(key:)
      !([:default, :key_dir, :project_dir].include?(key))
    end

    def call_validate_method_for_section(section:, content:)
      section_singular = singularize(section: section.to_s)
      attrs = {}
      attrs[section_singular] = content
      method = "validate_#{section_singular}".to_sym
      send(method, **attrs)
    end

    def singularize(section:)
      section = section[0..-2] if section.end_with?("s")
      section.to_sym
    end

    def has_stages(section_content:)
      section_content.class == Hash and section_content[:stages]
    end

    def validate_stages(project_content:)
      project_content[:stages].each_value {|stage_config|
        validate_stage(stage: stage_config, project: project_content)
      }
    end


    def validate_structure
      errors = [
        [MISSING_DEVICES, !@config[:devices]],
        [MISSING_DEVICES_DEFAULT, (@config[:devices] and !@config[:devices][:default])],
        [DEVICE_DEFAULT_BAD, (@config[:devices] and @config[:devices][:default] and !@config[:devices][:default].is_a?(Symbol))],
        [MISSING_PROJECTS_DEFAULT, (@config[:projects] and @config[:projects][:default] and @config[:projects][:default] == "<project id>".to_sym)],
        [PROJECTS_DEFAULT_BAD, (@config[:projects] and @config[:projects][:default] and !@config[:projects][:default].is_a?(Symbol))]
      ]
      process_errors(errors: errors)
    end

    def validate_device(device:)
      errors = [
        [DEVICE_MISSING_IP, (!device[:ip])],
        [DEVICE_MISSING_IP, (device[:ip] == "xxx.xxx.xxx.xxx")],
        [DEVICE_MISSING_IP, (device[:ip] == "")],
        [DEVICE_MISSING_USER, (!device[:user])],
        [DEVICE_MISSING_USER, (device[:user] == "<username>")],
        [DEVICE_MISSING_USER, (device[:user] == "")],
        [DEVICE_MISSING_PASSWORD, (!device[:password])],
        [DEVICE_MISSING_PASSWORD, (device[:password] == "<password>")],
        [DEVICE_MISSING_PASSWORD, (device[:password] == "")]
      ]
      process_errors(errors: errors)
    end

    def validate_project(project:)
      errors= [
        [PROJECT_MISSING_APP_NAME, (!project[:app_name])],
        [PROJECT_MISSING_DIRECTORY, (!project[:directory])],
        [PROJECT_FOLDERS_BAD, (project[:folders] and !project[:folders].is_a?(Array))],
        [PROJECT_MISSING_FILES, (!project[:source_files] and !(project[:files] and project[:folders]))],
        [PROJECT_FILES_BAD, (project[:files] and !project[:files].is_a?(Array))],
        [MISSING_STAGE_METHOD, ( !project[:stage_method])],
        [PROJECT_STAGE_METHOD_BAD, (![:git, :script, :plugin, nil].include?(project[:stage_method]))],
        [PROJECT_MISSING_PLUGIN, (!project[:staging_plugin] and project[:stage_method] == :plugin)],
        [DEPRICATED_FILES_FOLDERS, (project[:files] or project[:folders])],
      ]
      process_errors(errors: errors)
    end

    def validate_stage(stage:, project:)
      errors= [
        [STAGE_MISSING_BRANCH, (!stage[:branch] and project[:stage_method] == :git)],
        [STAGE_MISSING_SCRIPT, (!stage[:script] and project[:stage_method] == :script)],
      ]
      process_errors(errors: errors)
    end

    def validate_key(key:)
      errors= [
        [KEY_MISSING_PATH, (!key[:keyed_pkg])],
        [KEY_MISSING_PATH, (key[:keyed_pkg] == "<path/to/signed/package>")],
        [KEY_MISSING_PASSWORD, (!key[:password])],
        [KEY_MISSING_PASSWORD, (key[:password] == "<password>")],
      ]
      process_errors(errors: errors)
    end

    def validate_input_mapping(input_mapping:)
      errors=[
        [INVALID_MAPPING_INFO, (input_mapping.count != 2)]
      ]
      process_errors(errors: errors)
    end

    def validate_api_key(api_key:)
      errors = [
        [INVALID_API_KEY, (api_key.class != String)]
      ]
      process_errors(errors: errors)
    end

    def process_errors(errors:)
      errors.each do |error|
        @codes.push(error[0]) if error[1]
      end
    end

    def error_codes
      [
        #===============FATAL ERRORS===============#
        "Valid Config.",
        "Devices config is missing.",
        "Devices default is missing.",
        "Devices default is not a hash.",
        "",
        "Projects default is missing.", #5
        "Projects default is not a hash.",
        "A device config is missing its IP address.",
        "A device config is missing its username.",
        "A device config is missing its password.",
        "A project config is missing its app_name.", #10
        "A project config is missing its directorty.",
        "A project is missing its staging plugin",
        "A project config's folders is not an array.",
        "A project config is missing its files.",
        "A project config's files is not an array.", #15
        "A project stage is missing its branch.",
        "A project stage is missing its script.",
        "A project as an invalid stage method.",
        "A key is missing its keyed package path.",
        "A key is missing its password.", #20
        "A input mapping is invalid",
        "A key is missing from the keys section",
        "A project is missing its stage method.",
        #===============Warnings===============#
        "Using depricated files/folders projects keys. Use the combined source_files instead" #-1
      ]
    end
  end
end
