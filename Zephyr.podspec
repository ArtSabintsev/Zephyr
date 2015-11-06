Pod::Spec.new do |s|
  s.name         = "Zephyr"
  s.version      = "1.1.2"
  s.summary      = "Effortlessly synchronize NSUserDefaults over iCloud"

  s.description  = <<-DESC Effortlessly synchronize NSUserDefaults over iCloud. DESC
  s.homepage     = "https://github.com/ArtSabintsev/Zephyr"
  s.license      = "MIT"
  s.authors      = { "Arthur Ariel Sabintsev" => "arthur@sabintsev.com"}
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/ArtSabintsev/Zephyr.git", :tag => s.version.to_s }
  s.source_files = 'Zephyr.swift'
  s.requires_arc = true
end
