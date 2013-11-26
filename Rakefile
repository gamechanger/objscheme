namespace :debug do
  task :cleanbuild do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjScheme -sdk iphonesimulator clean build"
  end
  task :build do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjScheme -sdk iphonesimulator build"
  end
end

namespace :tests do
  task :cleanbuild do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjSchemeTests -sdk iphonesimulator clean build"
  end
  task :build do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjSchemeTests -sdk iphonesimulator build"
  end
end

namespace :test do
  task :ci => ["debug:cleanbuild", "tests:cleanbuild"] do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjSchemeTests -sdk iphonesimulator -reporter plain -reporter junit:test-reports/TEST-results.xml test -freshInstall -freshSimulator"
  end

  task :default do |t|
    sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjSchemeTests -sdk iphonesimulator test -freshInstall -freshSimulator"
  end
end

task :analyze do
  sh "xctool -workspace ObjScheme.xcworkspace -scheme ObjScheme analyze"
end

task :test => "test:default"

