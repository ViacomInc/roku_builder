# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  MISSING_DEVICES           = 1
  MISSING_DEVICES_DEFAULT   = 2
  DEVICE_DEFAULT_BAD        = 3
  MISSING_PROJECTS          = 4
  MISSING_PROJECTS_DEFAULT  = 5
  PROJECTS_DEFAULT_BAD      = 6
  DEVICE_MISSING_IP         = 7
  DEVICE_MISSING_USER       = 8
  DEVICE_MISSING_PASSWORD   = 9
  PROJECT_MISSING_APP_NAME  = 10
  PROJECT_MISSING_DIRECTORY = 11
  PROJECT_MISSING_FOLDERS   = 12
  PROJECT_FOLDERS_BAD       = 13
  PROJECT_MISSING_FILES     = 14
  PROJECT_FILES_BAD         = 15
  STAGE_MISSING_BRANCH      = 16
  STAGE_MISSING_SCRIPT      = 17
  PROJECT_STAGE_METHOD_BAD  = 18
  KEY_MISSING_PATH          = 19
  KEY_MISSING_PASSWORD      = 20
  INVALID_MAPPING_INFO      = 21
  MISSING_KEY               = 22

  MISSING_STAGE_METHOD      = -1

  # Validate Config File
  class ConfigValidator

    # Validates the roku config
    # @param config [Hash] roku config object
    # @return [Array] error codes for valid config (see self.error_codes)
    def self.validate_config(config:)
      codes = []
      validate_structure(codes: codes, config: config)
      if config[:devices]
        config[:devices].each {|device, device_config|
          next if device == :default
          validate_device(codes: codes, device: device_config)
        }
      end
      if config[:projects]
        config[:projects].each {|project,project_config|
          next if project == :default or project == :project_dir
          validate_project(codes: codes, project: project_config)
          if project_config[:stages]
            project_config[:stages].each {|_stage, stage_config|
              validate_stage(codes: codes, stage: stage_config, project: project_config, config: config)
            }
          end
        }
      end
      if config[:keys]
        config[:keys].each {|key,key_config|
          next if key == :key_dir
          validate_key(codes: codes, key: key_config)
        }
      end
      if config[:input_mapping]
        config[:input_mapping].each_value {|info| validate_mapping(codes: codes, mapping: info) }
      end
      codes.uniq!
      codes.push(0) if codes.empty?
      codes
    end

    # Error code messages for config validation
    # @return [Array] error code messages
    def self.error_codes()
      [
        #===============FATAL ERRORS===============#
        "Valid Config.",
        "Devices config is missing.",
        "Devices default is missing.",
        "Devices default is not a hash.",
        "Projects config is missing.",
        "Projects default is missing.", #5
        "Projects default is not a hash.",
        "A device config is missing its IP address.",
        "A device config is missing its username.",
        "A device config is missing its password.",
        "A project config is missing its app_name.", #10
        "A project config is missing its directorty.",
        "A project config is missing its folders.",
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
        #===============WARNINGS===============#
        "A project is missing its stage method."
      ]
    end

    # Validates the roku config structure
    # @param codes [Array] array of error codes
    # @param config [Hash] roku config object
    def self.validate_structure(codes:, config:)
      errors = [
        [MISSING_DEVICES, !config[:devices]],
        [MISSING_DEVICES_DEFAULT, (config[:devices] and !config[:devices][:default])],
        [DEVICE_DEFAULT_BAD, (config[:devices] and config[:devices][:default] and !config[:devices][:default].is_a?(Symbol))],
        [MISSING_PROJECTS, (!config[:projects])],
        [MISSING_PROJECTS_DEFAULT, (config[:projects] and !config[:projects][:default])],
        [MISSING_PROJECTS_DEFAULT, (config[:projects] and config[:projects][:default] == "<project id>".to_sym)],
        [PROJECTS_DEFAULT_BAD, (config[:projects] and config[:projects][:default] and !config[:projects][:default].is_a?(Symbol))]
      ]
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_structure

    # Validates a roku config device
    # @param codes [Array] array of error codes
    # @param device [Hash] device config object
    def self.validate_device(codes:, device:)
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
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_device

    # Validates a roku config project
    # @param codes [Array] array of error codes
    # @param project [Hash] project config object
    def self.validate_project(codes:, project:)
      errors= [
        [PROJECT_MISSING_APP_NAME, (!project[:app_name])],
        [PROJECT_MISSING_DIRECTORY, (!project[:directory])],
        [PROJECT_MISSING_FOLDERS, (!project[:folders])],
        [PROJECT_FOLDERS_BAD, (project[:folders] and !project[:folders].is_a?(Array))],
        [PROJECT_MISSING_FILES, (!project[:files])],
        [PROJECT_FILES_BAD, (project[:files] and !project[:files].is_a?(Array))],
        [MISSING_STAGE_METHOD, ( !project[:stage_method])],
        [PROJECT_STAGE_METHOD_BAD, (![:git, :script, nil].include?(project[:stage_method]))]
      ]
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_project

    # Validates a roku config project
    # @param codes [Array] array of error codes
    # @param project [Hash] project config object
    def self.validate_stage(codes:, stage:, project:, config:)
      errors= [
        [STAGE_MISSING_BRANCH, (!stage[:branch] and project[:stage_method] == :git)],
        [STAGE_MISSING_SCRIPT, (!stage[:script] and project[:stage_method] == :script)],
        [MISSING_KEY, (!!stage[:key] and stage[:key].class == String and (!config[:keys] or !config[:keys][stage[:key].to_sym]))]
      ]
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_stage

    # Validates a roku config project
    # @param codes [Array] array of error codes
    # @param project [Hash] project config object
    def self.validate_key(codes:, key:)
      errors= [
        [KEY_MISSING_PATH, (!key[:keyed_pkg])],
        [KEY_MISSING_PATH, (key[:keyed_pkg] == "<path/to/signed/package>")],
        [KEY_MISSING_PASSWORD, (!key[:password])],
        [KEY_MISSING_PASSWORD, (key[:password] == "<password>")],
      ]
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_key

    def self.validate_mapping(codes:, mapping:)
      errors=[
        [INVALID_MAPPING_INFO, (mapping.count != 2)]
      ]
      process_errors(codes: codes, errors: errors)
    end
    private_class_method :validate_mapping

    def self.process_errors(codes:, errors:)
      errors.each do |error|
        codes.push(error[0]) if error[1]
      end
    end
  end
end
