module Rasp
  class Runtime
    class Scope
      attr_accessor :symbols

      def initialize(parent)
        @symbols = {}
        @parent = parent
      end

      def include?(name)
        @symbols.include?(name) || @parent.include?(name)
      end

      def find_scope_with(name)
        return self if @symbols.include?(name)
        @parent.find_scope_with(name)
      end

      def [](name)
        name = name.to_s
        scope = find_scope_with(name)
        if scope
          scope.symbols[name]
        else
          raise "Unable to resolve symbol '#{name}'."
        end
      end

      # def [](name)
      #   name = name.to_s

      #   if @symbols.include?(name)
      #     @symbols[name]
      #   elsif @parent.is_a?(Scope)
      #     @parent[name]
      #   else
      #     raise "Unable to resolve symbol '#{name}'."
      #   end
      # end

      def []=(name, value)
        name = name.to_s
        @symbols[name] = value
        value.name ||= name if value.is_a? Function
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
