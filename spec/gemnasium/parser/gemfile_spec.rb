require "spec_helper"


RSpec::Matchers.define :have_a_dependency_with_name do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.name == expected}
  end
end

RSpec::Matchers.define :have_a_runtime_dependency do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.type == :runtime}
  end
end

RSpec::Matchers.define :have_a_development_dependency do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.type == :development}
  end
end

RSpec::Matchers.define :have_a_dependency_with_requirement do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.requirement.to_s == expected }
  end
end

RSpec::Matchers.define :have_a_dependency_with_list_of_requirements do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.requirement.as_list == expected }
  end
end

RSpec::Matchers.define :be_in_the_default_group do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.groups.include? :default}
  end
end

RSpec::Matchers.define :have_dependency_in_groups do |expected|
  match do |actual|
    actual.dependencies.detect {|d| d.groups == expected}
  end
end

RSpec::Matchers.define :have_dependencies_in_groups do |expected|
  match do |actual|
    actual.dependencies.collect {|d| d.groups }.flatten.uniq == expected
  end
end

describe Gemnasium::Parser::Gemfile do

  subject(:gemfile) {Gemnasium::Parser::Gemfile.new(@content)}
  def content(string)
    @content ||= begin
      indent = string.scan(/^[ \t]*(?=\S)/)
      n = indent ? indent.size : 0
      string.gsub(/^[ \t]{#{n}}/, "")
    end
  end

  def dependencies
    @dependencies ||= gemfile.dependencies
  end

  def dependency
    dependencies.size.should == 1
    dependencies.first
  end

  def reset
    @content = @gemfile = @dependencies = nil
  end

  context "given a gem call" do
    context "with double quotes" do
      before { content(%(gem "rake", ">= 0.8.7")) }
      it {should have_a_dependency_with_name "rake"}
      it {should have_a_dependency_with_requirement ">= 0.8.7"}
      it {should_not be_gemspec}
      it {should have_a_runtime_dependency}
      it {should be_in_the_default_group}
      its(:gemspec) {should be_nil}
    end

    context "with single quotes" do
      before { content(%(gem 'rake', '>= 0.8.7')) }
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_requirement ">= 0.8.7"}
    end

    context "with mixed quotes" do
      before {content(%(gem "rake', ">= 0.8.7"))}
      it 'ignores the line' do
        gemfile.dependencies.should be_empty
      end
    end

    context "with a period in the gem name" do
      before { content(%(gem "pygment.rb", ">= 0.8.7")) }
      it {should have_a_dependency_with_name "pygment.rb"}
      it {should have_a_dependency_with_requirement ">= 0.8.7"}
    end

    context "without a requirement" do
      before {content(%(gem "rake"))}
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_requirement ">= 0"}
    end

    context "with multiple requirements" do
      before {content(%(gem "rake", ">= 0.8.7", "<= 0.9.2"))}
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_list_of_requirements ["<= 0.9.2", ">= 0.8.7"]}
    end

    context "with options" do
      before { content(%(gem "rake", ">= 0.8.7", :require => false)) }
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_requirement ">= 0.8.7" }
    end

    context "with a :development type option" do
      before { content(%(gem "rake", :group => :development)) }
      it { should have_a_development_dependency}
    end

    context "with a parantheses" do
      before {content(%(gem("rake", ">= 0.8.7")))}
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_requirement ">= 0.8.7" }
    end

    context "with inline comments" do
      before {content(%(gem "rake", ">= 0.8.7" # Comment))}
      it { should have_a_dependency_with_name "rake" }
      it { should have_a_dependency_with_requirement ">= 0.8.7" }
    end

    context "with a group specified" do
      before { content(%(gem "rake", :group => :development)) }
      it { should have_dependency_in_groups [:development]}
    end

    context "with multiple groups specified as a :group option" do
      before { content(%(gem "rake", :group => [:development, :test])) }
      it { should have_dependency_in_groups [:development, :test]}
    end

    context "with multiple groups specified as a :groups option" do
      before { content(%(gem "rake", :groups => [:development, :test])) }
      it { should have_dependency_in_groups [:development, :test]}
    end

    context "within a group call" do
      before do
        content(<<-EOF)
          gem "rake"
          group :production do
            gem "pg"
          end
          group :development do
            gem "sqlite3"
          end
        EOF
      end
      it { should have_dependency_in_groups [:default]}
      it { should have_dependency_in_groups [:development]}
      it { should have_dependency_in_groups [:production]}
    end

    context "within a group call with parentheses" do
      before do
        content(<<-EOF)
          group(:production) do
            gem "pg"
          end
        EOF
      end
      it { should have_dependency_in_groups [:production]}
    end

    context "within a multiple group call" do
      before do
        content(<<-EOF)
          group :development, :test do
            gem "sqlite3"
          end
        EOF
      end
      it { should have_dependency_in_groups [:development, :test]}
    end

    context "with a git option" do
      before {content(%(gem "rails", :git => "https://github.com/rails/rails.git"))}
      its(:dependencies) {should be_empty}
    end

    context "with a github option" do
      before {content(%(gem "rails", :git => "https://github.com/rails/rails.git"))}
      its(:dependencies) {should be_empty}
    end

    context "with a path option" do
      before {content(%(gem "rails", :github => "rails/rails"))}
      its(:dependencies) {should be_empty}
    end

    context "within a git block" do
      before do
        content(<<-EOF)
          git "https://github.com/rails/rails.git" do
            gem "rails"
          end
        EOF
      end
      its(:dependencies) {should be_empty}
    end

    context "within a git block with parentheses" do
      before do
        content(<<-EOF)
          git("https://github.com/rails/rails.git") do
            gem "rails"
          end
        EOF
      end
      its(:dependencies) {should be_empty}
    end

    context "within a path block" do
      before do
        content(<<-EOF)
          path "vendor/rails" do
            gem "rails"
          end
        EOF
      end
      its(:dependencies) {should be_empty}
    end

    context "with a path block with parentheses" do
      before do
        content(<<-EOF)
          path("vendor/rails") do
            gem "rails"
          end
        EOF
      end
      its(:dependencies) {should be_empty}
    end
  end

  context 'given a gemspec call' do

    context 'with no options' do
      before {content(%(gemspec))}
      it {should be_gemspec}
      its(:gemspec) {should == "*.gemspec"}
    end

    context "with a name option" do
      before {content(%(gemspec :name => "gemnasium-parser"))}
      its(:gemspec) {should == "gemnasium-parser.gemspec"}
    end

    context "with a path option" do
      before {content(%(gemspec :path => "lib/gemnasium"))}
      its(:gemspec) {should == "lib/gemnasium/*.gemspec" }
    end

    context "with both name and path options" do
      before {content(%(gemspec :name => "parser", :path => "lib/gemnasium"))}
      its(:gemspec) {should == "lib/gemnasium/parser.gemspec" }
    end

    context "with parentheses" do
      before {content(%(gemspec(:name => "gemnasium-parser")))}
      it {should be_gemspec}
    end
  end

  context "given multiple gems in a group" do
    before do
      content(<<-EOF)
        group :development do
          gem "rake"
          gem "sqlite3"
        end
      EOF
    end
    it {should have(2).dependencies}
    it {should have_dependencies_in_groups [:development]}
  end

  context "given multiple gems in multiple groups" do
    before do
      content(<<-EOF)
        group :development, :test do
          gem "rake"
          gem "sqlite3"
        end
      EOF
    end

    it {should have(2).dependencies}
    it {should have_dependencies_in_groups [:development, :test]}
  end

  # This should be treated as an integration test, but we can leave it here for now.
  it "ignores h4x" do
    path = File.expand_path("../h4x.txt", __FILE__)
    content(%(gem "h4x", :require => "\#{`touch #{path}`}"))
    dependencies.size.should == 0
    begin
      File.should_not exist(path)
    ensure
      FileUtils.rm_f(path)
    end
  end


  it "records dependency line numbers" do
    content(<<-EOF)
      gem "rake"

      gem "rails"
    EOF
    dependencies[0].instance_variable_get(:@line).should == 1
    dependencies[1].instance_variable_get(:@line).should == 3
  end

  it "maps groups to types" do
    content(<<-EOF)
      gem "rake"
      gem "pg", :group => :production
      gem "mysql2", :group => :staging
      gem "sqlite3", :group => :development
    EOF
    dependencies[0].type.should == :runtime
    dependencies[1].type.should == :runtime
    dependencies[2].type.should == :development
    dependencies[3].type.should == :development
  end

  context "when a custom runtime group is specified" do
    it "maps groups to types" do
    Gemnasium::Parser.runtime_groups << :staging
    content(<<-EOF)
      gem "rake"
      gem "pg", :group => :production
      gem "mysql2", :group => :staging
      gem "sqlite3", :group => :development
    EOF
    dependencies[0].type.should == :runtime
    dependencies[1].type.should == :runtime
    dependencies[2].type.should == :runtime
    dependencies[3].type.should == :development
    end
  end




  it "parses oddly quoted gems" do
    content(%(gem %q<rake>))
    dependency.name.should == "rake"
  end

end
