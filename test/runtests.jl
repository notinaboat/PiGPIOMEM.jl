using PiGPIOMEM
using LLVM
#using BaremetalPi

nop() = LLVM.Interop.@asmcall("nop")
spin_ns(n) = for i in 1:n nop() end

function test(pin)

    for i in 1:10_000_000
        clear(pin)
        spin_ns(80)
        set(pin)
        spin_ns(80)
    end
end

#function test2()
#    init_gpio()
#    gpio_set_mode(18, :out)
#
#    while true
#        gpio_clear(18)
#        spin_ns(100)
#        gpio_set(18)
#        spin_ns(100)
#    end
#end


#@time spin_ns(100000 / 3)
#@time spin_ns(10000 / 3)
#@time spin_ns(1000 / 3)

test(GPIOPin(18, output=true))

#using InteractiveUtils
#code_native(test, [GPIOPin], debuginfo=:none)

"""
2 * (spin( 80) + d) =  520ns
2 * (spin(100) + d) =  632ns
2 * (spin(150) + d) =  936ns
2 * (spin(200) + d) = 1240ns

ns = 3 x 2 * spin + 34

2 * spin(100): 632ns
2 * spin(100): 632-34 = 598ns
spin(100): 598 / 2 = 300 ns
spin = 3ns
"""

# 2.1MHz
#test2()
