# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Collects information on a package for submission
  class Inspector < Util

    # Inspects the given pkg
    # @param pkg [String] Path to the pkg to be inspected
    # @param password [String] Password for the given pkg
    # @return [Hash] Package information. Contains the following keys:
    #   * app_name
    #   * dev_id
    #   * creation_date
    #   * dev_zip
    def inspect(pkg:, password:)

      pkg = pkg+".pkg" unless pkg.end_with?(".pkg")
      # upload new key with password
      path = "/plugin_inspect"
      conn = multipart_connection
      payload =  {
        mysubmit: "Inspect",
        passwd: password,
        archive: Faraday::UploadIO.new(pkg, 'application/octet-stream')
      }
      response = conn.post path, payload

      app_name = /App Name:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)
      dev_id = nil
      creation_date = nil
      dev_zip = nil
      if app_name
        app_name = app_name[1]
        dev_id = /Dev ID:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
        creation_date = /new Date\(([^)]*)\)/.match(response.body.delete("\n"))[1]
        dev_zip = /dev.zip:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
      else
        app_name = /App Name:[^<]*<div[^>]*>([^<]*)<\/div>/.match(response.body)[1]
        dev_id = /Dev ID:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
        creation_date = /new Date\(([^\/]*)\)/.match(response.body.delete("\n"))[1]
        dev_zip = /dev.zip:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
      end

      return {app_name: app_name, dev_id: dev_id, creation_date: Time.at(creation_date.to_i).to_s, dev_zip: dev_zip}

    end

    # Capture a screencapture for the currently sideloaded app
    # @return [Boolean] Success
    def screencapture(out_folder:, out_file: nil)
      path = "/plugin_inspect"
      conn = multipart_connection
      payload =  {
        mysubmit: "Screenshot",
        passwd: @dev_password,
        archive: Faraday::UploadIO.new(File::NULL, 'application/octet-stream')
      }
      response = conn.post path, payload

      path = /<img src="([^"]*)">/.match(response.body)
      return false unless path
      path = path[1]
      unless out_file
        out_file = /time=([^"]*)">/.match(response.body)
        out_file = "dev_#{out_file[1]}.jpg" if out_file
      end

      conn = simple_connection

      response = conn.get path

      File.open(File.join(out_folder, out_file), "wb") do |io|
        io.write(response.body)
      end
      @logger.info "Screen captured to #{File.join(out_folder, out_file)}"
      return response.success?
    end
  end
end
