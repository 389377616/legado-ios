#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Legado.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Legado' }

unless target
  puts "ERROR: Target 'Legado' not found!"
  exit 1
end

exclude_dirs = ['Tests/', 'Widget/', 'ShareExtension/', 'docs/', 'scripts/', '.build/', 'DerivedData/', 'inventory/']

swift_files_on_disk = Dir.glob('**/*.swift').reject { |f|
  exclude_dirs.any? { |dir| f.start_with?(dir) }
}.sort

puts "Found #{swift_files_on_disk.size} Swift files on disk"

removed = 0
added = 0

target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  path = file_ref.path
  next unless path && path.end_with?('.swift')
  
  unless swift_files_on_disk.include?(path)
    puts "Removing missing file: #{path}"
    build_file.remove_from_project
    file_ref.remove_from_project
    removed += 1
  end
end

project.main_group.recursive_children.each do |child|
  next unless child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
  next unless child.path && child.path.end_with?('.swift')
  
  unless swift_files_on_disk.include?(child.path)
    puts "Removing orphan file ref: #{child.path}"
    child.remove_from_project
    removed += 1
  end
end

existing_paths = target.source_build_phase.files.map { |f| f.file_ref&.path }.compact

swift_files_on_disk.each do |file_path|
  next if existing_paths.include?(file_path)
  
  begin
    file_ref = project.main_group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added: #{file_path}"
    added += 1
  rescue => e
    puts "Warning: #{file_path}: #{e.message}"
  end
end

project.save
puts "Project saved. Added #{added} file(s), removed #{removed} file(s)."
