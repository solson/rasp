module Rasp
  class Runtime
    attr_accessor :top_level, :user_scope

    def initialize
      @top_level = Scope.new(self)
      @user_scope = Scope.new(@top_level)

      Runtime.define_builtins(@top_level)
    end

    def self.define_builtins(scope)
      scope['true'] = true
      scope['false'] = false
      scope['nil'] = nil

      # This is the Ruby const_get function. Important for Ruby interop.
      scope.defspecial('::') do |scope, params|
        if name = params[1]
          context = Rasp.evaluate(params[0], scope)
        else
          name = params[0]
          context = Object
        end

        context.const_get(name.to_s)
      end

      # This is the Ruby 'send' function. Very important for Ruby interop.
      scope.defspecial('.') do |scope, params|
        reciever = Rasp.evaluate(params[0], scope)
        method = params[1][0].to_s
        args = params[1][1..-1].map{|arg| Rasp.evaluate(arg, scope)}

        reciever.__send__(method, *args)
      end

      scope.defspecial('quote') do |scope, params|
        params[0]
      end

      scope.defn('list') do |*params|
        params
      end

      scope.defspecial('if') do |scope, params|
        if(Rasp.evaluate(params[0], scope))
          Rasp.evaluate(params[1], scope)
        else
          Rasp.evaluate(params[2], scope) if params[2]
        end
      end

      scope.defspecial('def') do |scope, params|
        scope[params[0]] = Rasp.evaluate(params[1], scope)
      end

      scope.defspecial('fn') do |scope, params|
        Function.new(scope, params[0], params[1..-1])
      end

      scope.defspecial('macro') do |scope, params|
        Macro.new(scope, params[0], params[1..-1])
      end

#      scope.defmacro('apply') do |func, *args, argSeq|
#        [func, *args, *argSeq]
#      end

#        (def apply (fn (f & args)
#          (if (. (. args (last)) (is_a? (:: Enumerable))))
#              (. f (apply (. (. args (last)) (+ (. args (slice (range 0 -1)))))))
#              (. f (apply args))))

      scope.eval('
        (def range (macro (min max)
          (list (quote .) (quote (:: Range)) (list (quote new) min max))))

        (def isa? (fn (obj class)
          (. obj (is_a? class))))

        (def first (fn (ary) (. ary (first))))

        (def last (fn (ary) (. ary (last))))

        (def pop (fn (ary) (. ary (pop))))

        (def concat (fn (ary1 ary2) (. ary1 (concat ary2))))

        (def apply (macro (f & args)
          (if (isa? (last args) (:: Enumerable))
              (concat args (. (pop args) (to_a))))
          (. (list f) (+ args))))

        (def defn (macro (name args & forms)
          (list (quote def) name (list (quote apply) (quote fn) args forms))))

        (defn + (& args)
          (. args (reduce 0 "+")))

        (defn * (& args)
          (. args (reduce 1 "*")))
      ')
    end
  end
end
