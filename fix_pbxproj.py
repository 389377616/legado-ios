#!/usr/bin/env python3
"""
安全地添加新文件到 project.pbxproj
遵循 Xcode 的 plist 格式规范
"""

import re
import uuid

def generate_uuid():
    """生成 Xcode 风格的 UUID"""
    return ''.join(['{:08X}'.format(uuid.uuid4().int >> 32 & 0xFFFFFFFF)])

# 新文件列表（相对路径）
NEW_FILES = [
    ("PageDirection.swift", "Core/Reader/Models/"),
    ("TextPos.swift", "Core/Reader/Models/"),
    ("BaseColumn.swift", "Core/Reader/Models/"),
    ("TextColumn.swift", "Core/Reader/Models/"),
    ("ImageColumn.swift", "Core/Reader/Models/"),
    ("TextLine.swift", "Core/Reader/Models/"),
    ("TextPage.swift", "Core/Reader/Models/"),
    ("TextChapter.swift", "Core/Reader/Models/"),
    ("ContentTextView.swift", "Core/Reader/Views/"),
]

def add_files_to_pbxproj(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 生成 UUID
    file_uuids = {}
    build_uuids = {}
    for filename, folder in NEW_FILES:
        base = filename.replace('.swift', '')
        file_uuids[filename] = generate_uuid()
        build_uuids[filename] = generate_uuid()
    
    # 1. 添加 PBXBuildFile 条目
    buildfile_entries = []
    for filename, folder in NEW_FILES:
        build_uuid = build_uuids[filename]
        file_uuid = file_uuids[filename]
        entry = f'\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};'
        buildfile_entries.append(entry)
    
    # 找到 /* Begin PBXBuildFile section */ 并在其后插入
    buildfile_section = '\n'.join(buildfile_entries)
    pattern = r'(\/\* Begin PBXBuildFile section \*\/\n)'
    content = re.sub(pattern, r'\1' + buildfile_section + '\n', content)
    
    # 2. 添加 PBXFileReference 条目
    fileref_entries = []
    for filename, folder in NEW_FILES:
        file_uuid = file_uuids[filename]
        entry = f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};'
        fileref_entries.append(entry)
    
    fileref_section = '\n'.join(fileref_entries)
    pattern = r'(\/\* Begin PBXFileReference section \*\/\n)'
    content = re.sub(pattern, r'\1' + fileref_section + '\n', content)
    
    # 3. 添加到 PBXGroup (Features 组)
    # 先找到 Features 组的 UUID
    features_match = re.search(r'([0-9A-F]{24}) /\* Features \*/ = \{', content)
    if features_match:
        features_uuid = features_match.group(1)
        # 在 Features 组的 children 中添加
        for filename, folder in NEW_FILES:
            file_uuid = file_uuids[filename]
            # 根据文件夹找到对应的组
            if "Config" in folder:
                group_name = "Config"
            elif "Bookshelf" in folder:
                group_name = "Bookshelf"
            elif "Download" in folder:
                group_name = "Download"
            elif "Reader" in folder:
                group_name = "Reader"
            else:
                continue
            
            # 找到对应组的 children 部分
            group_pattern = f'({{isa = PBXGroup; children = \(\n[^)]*?/\* {group_name} \*/[^}}]*?)\);'
            child_entry = f'\t\t\t\t{file_uuid} /* {filename} */,'
            # 在最后一个 children 后添加
            content = re.sub(group_pattern, r'\1\n\t\t\t\t' + child_entry + '\n\t\t\t', content, count=1)
    
    # 4. 添加到 PBXSourcesBuildPhase
    sources_pattern = r'(\*\* PBXSourcesBuildPhase \*\* \*\/[^/]*?/\* Sources \*/ = \{[^}]*?files = \(\n)'
    for filename, folder in NEW_FILES:
        build_uuid = build_uuids[filename]
        entry = f'\t\t\t\t{build_uuid} /* {filename} in Sources */,'
        content = re.sub(sources_pattern, r'\1' + entry + '\n', content, count=1)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Successfully added files to project.pbxproj")

if __name__ == '__main__':
    add_files_to_pbxproj('Legado.xcodeproj/project.pbxproj')
