#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Legado.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Legado' }

package_refs = project.root_object.package_references.to_a

existing = package_refs.any? do |ref|
  ref.respond_to?(:repositoryURL) && ref.repositoryURL == 'https://github.com/readium/swift-toolkit.git'
end

unless existing
  begin
    package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package_ref.repositoryURL = 'https://github.com/readium/swift-toolkit.git'
    package_ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '3.8.0' }
    project.root_object.package_references << package_ref
    puts "Added Readium Swift Toolkit package"
  rescue => e
    puts "Warning: Could not add SPM package: #{e.message}"
    puts "Continuing without SPM package..."
  end
end

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

existing_files = target.source_build_phase.files.map { |f| f.file_ref&.path }.compact

new_files.each do |file_path|
  next unless File.exist?(file_path)
  next if existing_files.include?(file_path)
  
  begin
    file_ref = project.main_group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added: #{file_path}"
  rescue => e
    puts "Warning: #{file_path}: #{e.message}"
  end
end

project.save
puts "Project saved"