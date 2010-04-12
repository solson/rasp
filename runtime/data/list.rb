module Rasp
  class Runtime
    class List < ::Array
      include Expression
      def eval(scope)
        Rasp.evaluate(self.first, scope).call(scope, self[1..-1])
      end
    end
  end
end
