Pod::Spec.new do |s|
  s.name         = "ObjScheme"
  s.version      = "0.5.1"
  s.summary      = "A Stupid but Simple Scheme implementation in Obj-C."
  s.homepage     = "https://github.com/gamechanger/objscheme"
  s.author       = { "Kiril Savino" => "kiril@gamechanger.io" }
  s.source       = { :git => "https://github.com/gamechanger/objscheme.git", :tag => "0.5.1" }
  s.ios.deployment_target = '6.0'
  s.license      = 'tbd'
  s.source_files = 'ObjScheme'
end
