
task :test do |t|
  sh "xctool -workspace ObjScheme.xcworkspace ONLY_ACTIVE_ARCH=NO -scheme ObjScheme -sdk iphonesimulator clean build"
  sh "xctool -workspace ObjScheme.xcworkspace ONLY_ACTIVE_ARCH=NO -scheme ObjScheme -sdk iphonesimulator test -freshSimulator -freshInstall -reporter pretty -reporter junit:test-reports/TEST-results.xml"
end
