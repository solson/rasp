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
      scope.defmacro('::') do |scope, context, name|
        if name
          context = Rasp.evaluate(context, scope)
        else
          name = context
          context = Object
        end

        context.const_get(name.to_s)
      end

      # This is the Ruby 'send' function. Very important for Ruby interop.
      scope.defmacro('.') do |scope, reciever, args|
        reciever = Rasp.evaluate(reciever, scope)
        method = args[0].to_s
        args = args[1..-1].map{|arg| Rasp.evaluate(arg, scope)}

        reciever.__send__(method, *args)
      end

      scope.defmacro('def') do |scope, name, value|
        scope[name] = Rasp.evaluate(value, scope)
      end

      scope.defmacro('fn') do |scope, args, *forms|
        Function.new(scope, args, forms)
      end

      scope.defmacro('macro') do |scope, args, *forms|
        Macro.new(scope, args, forms)
      end
    end
  end
end
