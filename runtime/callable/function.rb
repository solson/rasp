module Rasp
  class Runtime
    class Function
      attr_reader :body, :name

      def initialize(scope, formals = nil, body = nil, &block)
        if formals.is_a? Array
          @formals = formals.map{|id| id.to_s}
          if i = @formals.find_index('&')
            @rest = @formals[i + 1]
            @formals = @formals[0...i]
          end
        end

        @scope = scope
        @body = body || block
      end

      def name=(name)
        @name ||= name.to_s
      end

      def call(scope, params)
        params = params.map do |cell|
          Rasp.evaluate(cell, scope)
        end
        apply(params)
      end

      def apply(params)
        return @body.call(*params) if primitive?
        closure = Scope.new(@scope)
        index = 0

        @formals.each do |name|
          closure[name] = params[index]
          index += 1
        end

        closure[@rest] = params[index..-1] if @rest

        r = nil
        @body.each do |form|
          r = Rasp.evaluate(form, closure)
        end
        r
      end

      def primitive?
        @body.is_a? Proc
      end

      def to_s
        "#<Function:#{@name}>"
      end
      alias inspect to_s
    end
  end
end
