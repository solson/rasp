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

#        raise "Unable to resolve symbol '#{name}'." unless value

        value
      end

      def []=(name, value)
        @symbols[name.to_s] = value
        value.name = name if value.is_a? Function
        value
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
        source.eval(self)
      end
    end
  end
end
