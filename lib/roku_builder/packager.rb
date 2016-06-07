# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Method of packaging app for submission
  class Packager < Util

    # Sign and download the currently sideloaded app
    # @param app_name_version [String] The name and version of the package
    # @param out_file [String] Location to download signed package to
    # @param password [String] Password for the devices current key
    # @return [Boolean] True on package success and download, false otherwise
    def package(app_name_version:, out_file:, password:)
      # Sign package
      path = "/plugin_package"
      conn = multipart_connection
      payload =  {
        mysubmit: "Package",
        app_name: app_name_version,
        passwd: password,
        pkg_time: Time.now.to_i
      }
      response = conn.post path, payload

      # Check for error
      failed = /(Failed: [^\.]*\.)/.match(response.body)
      return failed[1] if failed

      # Download signed package
      pkg = /<a href="pkgs[^>]*>([^<]*)</.match(response.body)[1]
      path = "/pkgs/#{pkg}"
      conn = Faraday.new(url: @url) do |f|
        f.request :digest, @dev_username, @dev_password
        f.adapter Faraday.default_adapter
      end
      response = conn.get path
      return false if response.status != 200

      File.open(out_file, 'w+') {|fp| fp.write(response.body)}
      true
    end
  end
end
