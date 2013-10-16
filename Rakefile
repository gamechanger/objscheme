
task :test do |t|
  sh "killall \"iPhone Simulator\" || true"
  sh "xcodebuild -workspace ObjScheme.xcworkspace -scheme ObjScheme -sdk iphonesimulator clean build"
  sh "xcodebuild -workspace ObjScheme.xcworkspace -scheme ObjSchemeTests -sdk iphonesimulator test -destination OS=7.0,name=iPad 2>&1 | ocunit2junit"
end
