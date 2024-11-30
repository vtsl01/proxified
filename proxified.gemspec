# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'proxified/version'

Gem::Specification.new do |spec|
  spec.name          = 'proxified'
  spec.version       = Proxified::VERSION
  spec.authors       = ['Valerio Licata']
  spec.email         = ['valerio.licata.dev@gmail.com']

  spec.summary       = 'Proxify any object with a few lines of code.'
  spec.description   =
    'A simple way to put a proxy in front of any object, at any time.'
  spec.homepage      = 'https://github.com/vtsl01/proxified'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the
  # 'allowed_push_host' to allow pushing to a single host or delete this
  # section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata["allowed_push_host"] = "Set to 'http://mygemserver.com'"
  #
  #   spec.metadata["homepage_uri"] = spec.homepage
  #   spec.metadata["source_code_uri"] = "Put your gem's public repo URL here."
  #   spec.metadata["changelog_uri"] = "Put your gem's CHANGELOG.md URL here."
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 3.3'

  spec.add_development_dependency 'bundler', '~> 2.5'
  spec.add_development_dependency 'guard', '~> 2.15'
  spec.add_development_dependency 'guard-bundler', '~> 2.2', '>= 2.2.1'
  spec.add_development_dependency 'guard-rspec', '~> 4.7', '>= 4.7.3'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.8'

  spec.add_dependency 'activesupport', '~> 6.1.7.3'
end
