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
        args = params[1][1..-1]
        block = nil

        if i = args.find_index{|arg| arg.to_s == '&' }
          block = Rasp.evaluate(args[i + 1], scope)
          args = args[0...i]
        end

        args.map!{|arg| Rasp.evaluate(arg, scope)}

        reciever.__send__(method, *args, &block)
      end

      scope.defspecial('quote') do |scope, params|
        params[0]
      end

      scope.defspecial('eval') do |scope, params|
        Rasp.evaluate(Rasp.evaluate(params[0], scope), scope)
      end

      scope.defspecial('do') do |scope, params|
        val = nil

        params.each do |param|
          val = Rasp.evaluate(param, scope)
        end

        val
      end

      scope.defspecial('if') do |scope, params|
        if(Rasp.evaluate(params[0], scope))
          Rasp.evaluate(params[1], scope)
        else
          Rasp.evaluate(params[2], scope) if params[2]
        end
      end

      scope.defspecial('or') do |scope, params|
        val = nil

        # return nil if there are no params
        if params.count > 0
          params.each do |param|
            if val = Rasp.evaluate(param, scope)
              # return if it evalutes to logical true
              break
            end
          end
        end

        val
      end

      scope.defspecial('and') do |scope, params|
        val = true

        # return true if there are no params
        if params.count > 0
          params.each do |param|
            if not val = Rasp.evaluate(param, scope)
              # return if it evalutes to logical false
              break
            end
          end
        end

        val
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
        (def list (fn (& args) args))

        (def apply (fn (f & args)
          (. args (concat (. (. args (pop)) (to_a))))
          (eval (. (list f) (+ args)))))

        (def defn (macro (name args & forms)
          (list (quote def) name (apply fn args forms))))

        (def defmacro (macro (name args & forms)
          (list (quote def) name (apply macro args forms))))

        (defn map (f ary)
          (. ary (map & f)))

        (defn concat (& args)
          (. args (reduce () "+")))

        (defmacro import (& classes)
          (concat (list (quote do))
                  (map (fn (class)
                         (list (quote def) class (list (quote ::) class)))
                       classes)))

        (import Kernel Object Module Class Range String Array)

        (defmacro comment (& forms))

        (defn isa? (obj class)
          (. obj (is_a? class)))

        (defn method (obj name)
          (. obj (method name)))

        (defn new (class & args)
          (apply (method class "new") args))

        (defn range (min max)
          (new Range min max))

        (defn join (ary sep)
          (. ary (join sep)))

        (defn print (& args)
          (. (:: Kernel) (print (join args " "))))

        (defn println (& args)
          (apply print args)
          (print "\n"))

        (defn pr (& args)
          (. (:: Kernel) (print (join (map (fn (arg) (. arg (inspect))) args) " "))))

        (defn prn (& args)
          (apply pr args)
          (print "\n"))

        (defn each (ary fn)
          (. ary (each & fn)))

        (defn push (ary)
          (. ary (push)))

        (defn first (ary)
          (. ary (first)))

        (defn rest (ary)
          (. ary (slice (range 1 -1))))

        (defn last (ary)
          (. ary (last)))

        (defn pop (ary)
          (. ary (pop)))

        (defn aconcat (ary1 ary2)
          (. ary1 (concat ary2)))

        (defn + (& args)
          (. args (reduce 0 "+")))

        (defn * (& args)
          (. args (reduce 1 "*")))
      ')
    end
  end
end
