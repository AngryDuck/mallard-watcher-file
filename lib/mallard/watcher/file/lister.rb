require 'find'

module Mallard; module Watcher; module File; class Lister
    @@listers   = { 'pattern' => 1, 'find' => 1 }
    def initialize (type, args)
        raise "Unknown lister #{type}" unless @@listers[type]
        @type   = type.to_sym
        @args   = args
    end

    def list
        send(@type).sort
    end

    def to_s
        "#{@type} --> #{@args}"
    end

    private

    def pattern
        Dir.glob(@args['pattern'].gsub(/~/, ENV['HOME']))
    end

    def find
        Find.find(@args['dir'].gsub(/~/, ENV['HOME'])).find_all { |f| File.fnmatch(@args['glob'], File.basename(f)) }
    end
end; end; end; end
