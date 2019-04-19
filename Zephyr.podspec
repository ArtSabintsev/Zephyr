Pod::Spec.new do |s|
  # Version
  s.version       = "3.4.0"
  s.swift_version = "5.0"

  # Meta
  s.name         = "Zephyr"
  s.summary      = "Effortlessly synchronize UserDefaults over iCloud."
  s.homepage     = "https://github.com/ArtSabintsev/Zephyr"
  s.license      = "MIT"
  s.authors      = { "Arthur Ariel Sabintsev" => "arthur@sabintsev.com"}
  s.description  = <<-DESC
  Effortlessly synchronize your UserDefaults over iCloud.
  DESC

  # Deployment
  s.ios.deployment_target      = '9.0'
  s.tvos.deployment_target     = '9.0'

  # Sources
  s.source       = { :git => "https://github.com/ArtSabintsev/Zephyr.git", :tag => s.version.to_s }
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
end
