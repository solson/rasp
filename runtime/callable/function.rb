module Rasp
  class Runtime
    class Function < Macro
      def call(scope, params)
        params = params.map do |cell|
          Rasp.evaluate(cell, scope)
        end
        return @body.call(*params) if primitive?
        apply(params)
      end

      def to_s
        "#<Function:#{@name}>"
      end
      alias inspect to_s
    end
  end
end
