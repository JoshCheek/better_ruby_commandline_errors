require 'pathname'
require 'error_to_communicate/version'
require 'error_to_communicate/theme'
require 'error_to_communicate/project'
require 'error_to_communicate/exception_info'

module ErrorToCommunicate
  autoload :FormatTerminal, 'error_to_communicate/format_terminal'

  class Config
    # If you wind up needing to modify this global list, let me know!
    # I figure there should be a way to add/remove heuristics on the Config instance,
    # but I can't quite tell what will be needed or what it should look like.
    # This implies we should provide a way to add/remove heuristics on the config itself.
    # So I'm intentionally leaving this array unfrozen, to allow modification,
    # so that anyone wanting to hack in their own heuristic isn't prevented,
    # but if that happens, tell me so I can figure out how to add that functionality correctly!
    require 'error_to_communicate/heuristic/wrong_number_of_arguments'
    require 'error_to_communicate/heuristic/no_method_error'
    require 'error_to_communicate/heuristic/load_error'
    require 'error_to_communicate/heuristic/syntax_error'
    require 'error_to_communicate/heuristic/exception'
    DEFAULT_HEURISTICS = [
      Heuristic::WrongNumberOfArguments,
      Heuristic::NoMethodError,
      Heuristic::LoadError,
      Heuristic::SyntaxError,
      Heuristic::Exception,
    ]

    # Should maybe also be an array, b/c there's no great way to add a proc to the blacklist,
    # right now, it would have to check it's thing and then call the next one
    DEFAULT_BLACKLIST = lambda do |einfo|
      einfo.classname == 'SystemExit'
    end

    def self.default
      @default ||= new
    end

    attr_accessor :heuristics, :blacklist, :theme, :format_with, :catchall_heuristic, :project

    def initialize(options={})
      self.heuristics  = options.fetch(:heuristics)      { DEFAULT_HEURISTICS }
      self.blacklist   = options.fetch(:blacklist)       { DEFAULT_BLACKLIST }
      self.theme       = options.fetch(:theme)           { Theme.new } # this is still really fkn rough
      self.format_with = options.fetch(:format_with)     { FormatTerminal }
      loaded_features  = options.fetch(:loaded_features) { $LOADED_FEATURES }
      root             = options.fetch(:root)            { File.expand_path Dir.pwd }
      self.project     = Project.new root: root, loaded_features: loaded_features
    end

    def accept?(exception, binding)
      return false unless ExceptionInfo.parseable? exception, binding
      einfo = ExceptionInfo.parse(exception, binding)
      !blacklist.call(einfo) && !!heuristics.find { |h| h.for? einfo }
    end

    def heuristic_for(exception, binding)
      accept?(exception, binding) || raise(ArgumentError, "Asked for a heuristic on an object we don't accept: #{exception.inspect}")
      einfo = ExceptionInfo.parse(exception, binding)
      heuristics.find { |heuristic| heuristic.for? einfo }
                .new(einfo: einfo, project: project)
    end

    def format(heuristic, cwd)
      format_with.call theme: theme, heuristic: heuristic, cwd: Pathname.new(cwd)
    end
  end
end
