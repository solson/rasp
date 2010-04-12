module Rasp
  class Runtime
    class Scope
      attr_accessor :runtime

      def initialize(parent = {})
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
        value = @symbols[name.to_s]

        if !value && @parent.is_a?(Scope)
          value = @parent[name]
        end

        value
      end

      def []=(name, value)
        @symbols[name.to_s] = value
        value.name = name if value.is_a? Function
      end

      def define(name, *args, &block)
        self[name] = Function.new(self, *args, &block)
      end

      def syntax(name, &block)
        self[name] = Syntax.new(self, &block)
      end

      def eval(source)
        source = Rasp.parse(source)
        source.eval(self)
      end
    end
  end
end
