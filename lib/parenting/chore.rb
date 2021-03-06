module Parenting
  class Chore
    attr_accessor :on_start, :on_success, :on_failure, :on_stderr, :exit_status
    attr_accessor :command, :stdin, :stdout, :stderr
    attr_accessor :cost, :thread, :result
    attr_accessor :deps, :name, :completed

    def initialize(opts)
      [:on_start, :on_success, :on_failure, :on_stderr].each do |cb|
        if opts.key?(cb)
          self.send :"#{cb}=", opts.fetch(cb).dup
        else
          # no-op
          self.send :"#{cb}=", lambda {|o|}
        end
      end

      self.name = opts[:name] || nil
      self.deps = opts[:deps] || []
      self.completed = Queue.new

      self.command = opts.fetch(:command).dup
      self.command = [self.command] unless self.command.is_a? Array
      self.cost    = opts[:cost] || nil
      self.stdin   = opts[:stdin] || nil
      self.stdout  = nil
      self.stderr  = Queue.new
      self.result  = :working
    end

    def satisfied?(completed)
      self.deps.empty? || self.deps.all?{|d| completed.include?(d)}
    end

    def run!
      self.on_start.call(self)

      self.thread = Thread.new do
        cmd = [self.command].flatten
        Open3.popen3(* cmd) do |i, o, e, t|
          i.write(self.stdin); i.close

          e.each_line do |line|
            self.stderr << line
          end
          e.close

          self.stdout = o.read
          o.close

          result = t.value
          self.exit_status = result.exitstatus

          if result.success?
            self.result = :success
          else
            self.result = :failure
          end
        end
      end
    end

    def complete?
      self.result == :success || self.result == :failure
    end

    def done_with(name)
      self.completed << name
    end

    def handle_completion
      if self.result == :success
        self.on_success.call(self)
      elsif self.result == :failure
        self.on_failure.call(self)
      else
        raise "This should not happen"
      end
    end

    def failed?
      self.result == :failure
    end
  end
end
