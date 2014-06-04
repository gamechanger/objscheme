require 'erubis'

template = File.read("ObjScheme.podspec.erb")
template = Erubis::Eruby.new(template)
puts template.result(:version => ARGV[0])

