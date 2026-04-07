#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Legado.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Legado' }

# Add Readium Swift Toolkit package
package_refs = project.root_object.package_references || []

# Check if Readium already exists
readium_exists = package_refs.any? { |ref| ref.respond_to?(:repositoryURL) && ref.repositoryURL.include?('readium/swift-toolkit') }

unless readium_exists
  package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package.repositoryURL = 'https://github.com/readium/swift-toolkit.git'
  package.requirement = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference::VersionRequirement.new(
    kind: 'upToNextMajorVersion',
    minimumVersion: '3.8.0'
  )
  project.root_object.package_references << package
  puts "Added Readium Swift Toolkit package"
end

# New files to add
new_files = [
  'Features/ReaderEnhanced/ReaderEnhanced.swift',
  'Features/ReaderEnhanced/Preferences/EPUBPreferences.swift',
  'Features/ReaderEnhanced/Preferences/PreferencesApplier.swift',
  'Features/ReaderEnhanced/Tweaks/StyleTweakManager.swift',
  'Features/ReaderEnhanced/Settings/ReaderSettingsView.swift',
  'Core/API/APIServer.swift',
  'Core/API/BookSourceAPI.swift',
  'Core/API/BookAPI.swift',
]

# Get existing file references
existing_files = target.source_build_phase.files.map { |f| f.file_ref&.path }.compact

new_files.each do |file_path|
  next unless File.exist?(file_path)
  next if existing_files.include?(file_path)
  
  begin
    file_ref = project.main_group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added: #{file_path}"
  rescue => e
    puts "Warning: Could not add #{file_path}: #{e.message}"
  end
end

project.save
puts "Project saved successfully"