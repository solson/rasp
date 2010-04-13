module Rasp
  class Runtime
    attr_accessor :top_level, :user_scope

    def initialize
      @top_level = Scope.new(self)
      @user_scope = Scope.new(@top_level)

      Runtime.define_builtins(@top_level)
    end

    def self.define_builtins(scope)
      # This is the Ruby const_get function. Important for Ruby interop.
#      scope.defmacro('::') do |scope, context, name|
#        if name
#          context = Rasp.evaluate(context, scope)
#        else
#          name = context
#          context = Object
#        end

#        context.const_get(name.to_s)
#      end

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

      scope.defspecial('def') do |scope, params|
        scope[params[0]] = Rasp.evaluate(params[1], scope)
      end

      scope.defspecial('fn') do |scope, params|
        Function.new(scope, params[0], params[1..-1])
      end

      scope.defspecial('macro') do |scope, params|
        Macro.new(scope, params[0], params[1..-1])
      end

      scope.eval('
        (def + (fn (& args)
          (. args (reduce 0 "+"))))

        (def * (fn (& args)
          (. args (reduce 1 "*"))))
      ')
    end
  end
end
