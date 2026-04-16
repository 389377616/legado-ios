#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Legado.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Legado' }

existing_files = target.source_build_phase.files.map { |f| f.file_ref&.path }.compact

exclude_dirs = ['Tests/', 'Widget/', 'ShareExtension/', 'docs/', 'scripts/', '.build/', 'DerivedData/']

swift_files = Dir.glob('**/*.swift').reject { |f|
  exclude_dirs.any? { |dir| f.start_with?(dir) }
}

added = 0
swift_files.each do |file_path|
  next if existing_files.include?(file_path)
  
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
puts "Project saved. Added #{added} new file(s)."
