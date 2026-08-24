Pod::Spec.new do |s|
  s.name                  = 'WultraDigitalOnboarding'
  s.version               = '2.0.1'
  # Metadata
  s.license               = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary               = 'Wultra Digital Onboarding SDK'
  s.homepage              = 'https://wultra.com'
  s.author                = { 'Wultra s.r.o.' => 'support@wultra.com' }
  s.source                = { :git => 'https://github.com/wultra/digital-onboarding-apple.git', :tag => s.version }
  # Deployment targets
  s.swift_version         = '5.9'
  s.ios.deployment_target = '13.0'
  
  s.source_files          = 'Sources/**/*.swift'
  s.dependency 'WultraPowerAuthNetworking', '~> 1.5.0'

end
