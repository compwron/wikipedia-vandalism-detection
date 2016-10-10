module A
  module B
    module C
      def foo
        p 1
      end
    end
  end
end

foo
C::foo

include A::B

C::foo
