# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Change or get dev key
  class Keyer < Util

    # Sets the key on the roku device
    # @param keyed_pkg [String] Path for a package signed with the desired key
    # @param password [String] Password for the package
    # @return [Boolean] True if key changed, false otherwise
    def rekey(keyed_pkg:, password:)
      oldId = dev_id

      # upload new key with password
      path = "/plugin_inspect"
      conn = multipart_connection
      payload =  {
        mysubmit: "Rekey",
        passwd: password,
        archive: Faraday::UploadIO.new(keyed_pkg, 'application/octet-stream')
      }
      conn.post path, payload

      # check key
      newId = dev_id
      @logger.info("Key did not change") unless newId != oldId
      newId != oldId
    end

    # Get the current dev id
    # @return [String] The current dev id
    def dev_id
      path = "/plugin_package"
      conn = simple_connection
      response = conn.get path

      dev_id = /Your Dev ID:\s*<font[^>]*>([^<]*)<\/font>/.match(response.body)
      if dev_id
        dev_id = dev_id[1]
      else
        dev_id = /Your Dev ID:[^>]*<\/label> ([^<]*)/.match(response.body)[1]
      end
      dev_id
    end
  end
end
