require 'date'

require 'mallard/watcher/file/lister'

module Mallard; module Watcher; module File; class Target
    @@cnt   = 0
    def initialize (opts = {})
        @log    = opts[:logger]
        @@cnt   = @@cnt + 1
        @id     = @@cnt
    end

    def self.reset
        @@cnt = 0
    end

    def parse (key, val)
        case key
        when 'age'      then @age       = Target.seconds(val)
        when 'pattern'  then @lister    = Mallard::Watcher::File::Lister.new('pattern', { 'pattern' => val })
        when 'find'     then @lister    = Mallard::Watcher::File::Lister.new('find', val )
        else self.instance_variable_set(('@'+key).to_sym, val)
        end
    end

    def self.seconds (age)
        raise 'Age must be in the format \\d+[smhdw]' unless (match = age.match(/(\d+)([smhdw])/))
        num = match[1].to_i
        typ = match[2]

        case typ
        when 's' then return (num).to_i
        when 'm' then return (num * 60).to_i
        when 'h' then return (num * 60 * 60).to_i
        when 'd' then return (num * 60 * 60 * 24).to_i
        when 'w' then return (num * 60 * 60 * 24 * 7).to_i
        end

        raise 'Somebody messed with the code in seconds and broke it'
    end


    def verify
        %w{age tag execute lister}.each do |elem|
            raise "#{elem} not specified for target" unless instance_variable_get(('@'+elem).to_sym)
        end
    end

    def getList
        now = Time.now
        return @lister.list.find_all { |f| test(?e, f) && (now - File.stat(f).mtime > @age) }
    end

    def self.fields
        return %w{age pattern find execute tag}
    end

    def checkTarget
        if self.running?
            @log.debug 'already processing targets, skipping check for new targets'
            return
        end

        list    = self.getList
        return if list.length == 0
        @log.debug list.to_s
        @file = "/tmp/MallardWatcher.#{@tag}.#{$$}.#{@id}"
        fp = File.open(@file, 'w')
        fp.puts list
        fp.close
        self.launch
    end

    def running?
        @thread && @thread.status
    end

    def launch
        @thread = Thread.new { system("#{@execute} #{@file}") }
        @thread.run
    end

    def halt
        @thread && @thread.join
    end
end; end; end; end
