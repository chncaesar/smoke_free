require 'xcodeproj'

project_path = 'SmokeFree/SmokeFree/SmokeFree.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'SmokeFree' }
raise 'app target not found' unless app_target

# Avoid duplicate
if project.targets.any? { |t| t.name == 'SmokeFreeTests' }
  puts 'SmokeFreeTests already exists; aborting'
  exit 0
end

test_target = project.new_target(:unit_test_bundle, 'SmokeFreeTests', :ios, '15.8', nil, :swift)

# Test files live at ../SmokeFreeTests relative to project dir (SmokeFree/SmokeFree)
tests_group = project.main_group.new_group('SmokeFreeTests', '../SmokeFreeTests')
test_files = Dir.glob(File.join(File.dirname(project_path), '..', 'SmokeFreeTests', '*.swift')).sort
test_files.each do |f|
  name = File.basename(f)
  ref = tests_group.new_reference(name)
  test_target.source_build_phase.add_file_reference(ref)
end

# Host the tests inside the app
test_target.add_dependency(app_target)

app_product = 'SmokeFree.app'
host = "$(BUILT_PRODUCTS_DIR)/#{app_product}/#{'SmokeFree'}"
test_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/#{app_product}/SmokeFree"
  bs['BUNDLE_LOADER'] = '$(TEST_HOST)'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.smoke-free.app.tests'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '15.8'
  bs['SWIFT_VERSION'] = '5.0'
  bs['DEVELOPMENT_TEAM'] = 'S394MV4B4G'
  bs['GENERATE_INFOPLIST_FILE'] = 'YES'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
end

# Record TestTargetID so Xcode links host app
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][test_target.uuid] = { 'TestTargetID' => app_target.uuid }

project.save
puts "Added SmokeFreeTests with #{test_files.size} files: #{test_files.map { |f| File.basename(f) }.join(', ')}"
