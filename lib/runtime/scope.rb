module Rasp
  class Runtime
    class Scope
      attr_accessor :runtime

      def initialize(parent)
        @symbols = {}
        if parent.is_a? Runtime
          @parent = {}
          @runtime = parent
        else
          @parent = parent
          @runtime = parent.runtime
        end
      end

      def [](name)
        name = name.to_s

        if @symbols.include?(name)
          @symbols[name].tap{|x| puts "#{name}: #{x.inspect}" if $DEBUG}
        elsif @parent.is_a?(Scope)
          @parent[name]
        else
          raise "Unable to resolve symbol '#{name}'."
        end
      end

      def []=(name, value)
        @symbols[name.to_s] = value
        value.name = name if value.is_a? Function
        value
      end

      def keys
        @symbols.keys + @parent.keys
      end

      def defn(name, *args, &block)
        self[name] = Function.new(self, *args, &block)
      end

      def defspecial(name, &block)
        self[name] = Special.new(self, &block)
      end

      def defmacro(name, *args, &block)
        self[name] = Macro.new(self, *args, &block)
      end

      def eval(source)
        source = Rasp.parse(source)
        raise "The parser couldn't parse it." unless source
        source.eval(self)
      end
    end
  end
end
