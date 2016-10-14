Gem::Specification.new do |s|
  s.name = "ruby-band"
  s.version = "0.2.0"

  s.authors = ["arrigonialberto86"]
  s.date = "2016-10-14" # oct 14
  s.description = "Data mining and machine learning algorithms for JRuby "
  s.email = "arrigonialberto86@gmail.com"
  s.executables = ["ruby-band"]
  s.extensions = ["ext/mkrf_conf.rb"]
  s.extra_rdoc_files = [
      "LICENSE.txt",
      "README.md",
      "README.rdoc"
  ]
  s.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.homepage = "http://github.com/arrigonialberto86/ruby-band"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.summary = "Data mining algorithms for JRuby"

  s.add_runtime_dependency 'activesupport', '>= 3.2.13', '~> 3'
  s.add_dependency("rack", "~>1")

  s.add_dependency("atomic", ">=0")
  s.add_dependency("i18n", ">= 0.6.1")
  s.add_dependency("rake")
  s.add_dependency("bio", ">= 1.4.2")
  s.add_dependency("jbundler", "0.4.3")
  s.add_dependency("ruport")
  s.add_dependency("json")
  s.add_dependency("multi_json")
  s.add_dependency("gherkin")
  s.add_dependency("git")
  s.add_dependency("shoulda", ">= 0")
  s.add_dependency("test-unit", ">= 0")
  s.add_dependency("rdoc", ">= 3.12")
  s.add_dependency("bundler", ">= 1.3.5")
  s.add_dependency("jeweler", "~> 1.8.4")
  s.add_dependency("simplecov", ">= 0")
  s.add_dependency("cucumber")
  s.add_dependency("rspec")

end
