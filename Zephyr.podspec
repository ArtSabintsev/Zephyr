Pod::Spec.new do |s|
  s.name          = "Zephyr"
  s.version       = "2.2.4"
  s.summary       = "Effortlessly synchronize UserDefaults over iCloud"
  s.swift_version = "4.1"

  s.description  = <<-DESC
  Effortlessly synchronize UserDefaults over iCloud.
  DESC

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '3.0'

  s.homepage     = "https://github.com/ArtSabintsev/Zephyr"
  s.license      = "MIT"
  s.authors      = { "Arthur Ariel Sabintsev" => "arthur@sabintsev.com"}
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/ArtSabintsev/Zephyr.git", :tag => s.version.to_s }
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
end
