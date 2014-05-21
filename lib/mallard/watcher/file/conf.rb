require 'yaml'
require 'digest/md5'
require 'mallard/watcher/file/target'

module Mallard; module Watcher; module File; class Conf
    def initialize (conf, log)
        @conf   = conf
        @log    = log
        @md5    = Digest::MD5.file(@conf)
        self.read
    end

    def clear
        @sleep      = nil
        @targets    = Array.new
        @stagger    = nil
        @tg         = Hash.new
        Mallard::Watcher::File::Target.reset
    end

    def read
        self.clear
        @log.info('reading config file')
        hash    = YAML.load_file @conf

        @sleep  = Mallard::Watcher::File::Target.seconds(hash['main'][0]['sleep_interval'])
        hash['targ'].each do |targ|
            @targets.push self.parse(targ)
        end

        raise "Invalid config file" unless (@sleep && @targets)
        @stagger    = hash['main'][0]['stagger_interval']
        if @stagger.nil?
            @stagger    = @sleep
            @grouping   = 1
        elsif @stagger == 'auto'
            cnt = @targets.size
            if cnt > @sleep
                @stagger    = 1
                @grouping   = @sleep
            else
                while @sleep % cnt != 0
                    cnt += 1
                end
                @stagger    = @sleep / cnt
                @grouping   = cnt
            end
        else
            val = Mallard::Watcher::File::Target.seconds(@stagger)
            if val > @sleep
                @stagger    = @sleep
                @grouping   = 1
            else
                while @sleep % val != 0
                    val -= 1
                end
                @stagger    = val
                @grouping   = @sleep / val
            end
        end

        (0..(@targets.size - 1)).each do |i|
            group = i % @grouping
            @tg[group] = Array.new unless @tg[group]
            @tg[group].push @targets[i]
        end
        @current    = 0
        @log.info("sleep        = #{@sleep}")
        @log.info("stagger      = #{@stagger}")
        @log.info("grouping     = #{@grouping}")
        @log.info("target count = #{@targets.size}")
        @log.info("group count  = #{@tg.size}")
    end

    def parse (hash)
        target  = Mallard::Watcher::File::Target.new(:logger => @log)

        Mallard::Watcher::File::Target.fields.each do |elem|
            next unless hash[elem]
            target.parse(elem, hash[elem])
        end

        target.verify
        return target
    end

    def sleep
        Kernel.sleep @stagger
    end

    def exec
        md5     = Digest::MD5.file(@conf)
        if md5 != @md5
            self.halt
            self.read
            @md5 = md5
        end

        if @tg.has_key? @current
            @tg[@current].each do |target|
                target.checkTarget
            end
        end

        @current = (@current + 1) % @grouping
    end

    def halt
        @targets.each do |target|
            target.halt
        end
    end
end; end; end; end
