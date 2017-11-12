Pod::Spec.new do |s|
  s.name = 'Pancake'
  s.version = '0.1.0'
  s.license = 'MIT'
  s.summary = 'Flat cache built in Swift'
  s.homepage = 'https://github.com/zradke/Pancake'
  s.author = { 'Zach Radke' => 'zach.radke@gmail.com' }
  s.source = { :git => 'https://github.com/zradke/Pancake.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'Pancake/*.swift'
end
