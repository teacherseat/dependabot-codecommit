$:.push File.expand_path("../lib", __FILE__)

require 'dependabot_codecommit/version'

Gem::Specification.new do |s|
  s.name          = 'dependabot-codecommit'
  s.version       = DependabotCodecommit::VERSION
  s.authors       = ['Andrew Brown']
  s.email         = ['andew@teacherseat.com']
  s.summary       = 'Dependabot CodeCommit'
  s.description   = 'Dependabot CodeCommit'
  s.homepage      = 'https://github.com/teacherseat/dependabot-codecommit'
  s.license       = 'MIT'

  s.files         = Dir["{lib}/**/*", "README.md"]
  s.test_files    = Dir["spec/**/*"]
  s.executables   = ['dependabot-codecommit']
  s.require_paths = ['lib']
  s.bindir        = 'bin'

  s.required_ruby_version = '>= 2.7'
  s.add_dependency "dependabot-common", "~> 0.133.6"
  s.add_dependency "dependabot-omnibus", "~> 0.133.6"
  s.add_dependency "aws-sdk-codecommit"
end

