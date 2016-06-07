# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ManifestManagerTest < Minitest::Test
  def test_manifest_manager_update
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    FileUtils.cp(File.join(root_dir, "manifest_template"), File.join(root_dir, "manifest"))
    build_version = nil
    Time.stub(:now, Time.new(2001, 02, 01)) do
      build_version = RokuBuilder::ManifestManager.update_build(root_dir: root_dir)
    end
    assert_equal "020101.2", build_version
    FileUtils.rm(File.join(root_dir, "manifest"))
  end

  def test_manifest_manager_update_missing_build_number
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    FileUtils.cp(File.join(root_dir, "manifest_template_2"), File.join(root_dir, "manifest"))
    build_version = nil
    Time.stub(:now, Time.new(2001, 02, 01)) do
      build_version = RokuBuilder::ManifestManager.update_build(root_dir: root_dir)
    end
    assert_equal "020101.1", build_version
    FileUtils.rm(File.join(root_dir, "manifest"))
  end

  def test_manifest_manager_build_version
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    FileUtils.cp(File.join(root_dir, "manifest_template"), File.join(root_dir, "manifest"))
    build_version = nil
    build_version = RokuBuilder::ManifestManager.build_version(root_dir: root_dir)
    assert_equal "010101.1", build_version
    FileUtils.rm(File.join(root_dir, "manifest"))
  end

  def test_manifest_manager_build_version_zip
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test", "test.zip")
    build_version = nil
    build_version = RokuBuilder::ManifestManager.build_version(root_dir: root_dir)
    assert_equal "010101.1", build_version
  end

  def test_manifest_manager_update_manifest
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    FileUtils.cp(File.join(root_dir, "manifest_template"), File.join(root_dir, "manifest"))
    attrs = {
      title: "New Title",
      major_version: 2,
      minor_version: 2,
      build_version: "020202.0002",
      mm_icon_focus_hd: "pkg:/images/focus1.png",
      mm_icon_focus_sd: "pkg:/images/focus2.png"
    }
    RokuBuilder::ManifestManager.update_manifest(root_dir: root_dir, attributes: attrs)
    assert FileUtils.compare_file(File.join(root_dir, "manifest"), File.join(root_dir, "updated_title_manifest"))
    FileUtils.rm(File.join(root_dir, "manifest"))
  end
  def test_manifest_manager_update_manifest_overwrite
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    attrs = {
      title: "New Title",
      major_version: 2,
      minor_version: 2,
      build_version: "020202.0002",
      mm_icon_focus_hd: "pkg:/images/focus1.png",
      mm_icon_focus_sd: "pkg:/images/focus2.png"
    }
    RokuBuilder::ManifestManager.update_manifest(root_dir: root_dir, attributes: attrs)
    RokuBuilder::ManifestManager.update_manifest(root_dir: root_dir, attributes: attrs)
    assert FileUtils.compare_file(File.join(root_dir, "manifest"), File.join(root_dir, "updated_title_manifest"))
    FileUtils.rm(File.join(root_dir, "manifest"))
  end
  def test_manifest_manager_update_manifest_partial
    root_dir = File.join(File.dirname(__FILE__), "test_files", "manifest_manager_test")
    attrs = {
      title: "New Title",
      major_version: 2,
      minor_version: 2,
      build_version: "020202.0002",
      mm_icon_focus_hd: "pkg:/images/focus1.png",
      mm_icon_focus_sd: "pkg:/images/focus2.png"
    }
    RokuBuilder::ManifestManager.update_manifest(root_dir: root_dir, attributes: attrs)
    attrs = {
      title: "New Title",
    }
    RokuBuilder::ManifestManager.update_manifest(root_dir: root_dir, attributes: attrs)
    assert FileUtils.compare_file(File.join(root_dir, "manifest"), File.join(root_dir, "updated_title_manifest"))
    FileUtils.rm(File.join(root_dir, "manifest"))
  end
end
