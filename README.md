# PiGPIOMEM.jl

Julia interface for [`/dev/gpiomem'](https://github.com/raspberrypi/linux/blob/rpi-5.4.y/drivers/char/broadcom/bcm2835-gpiomem.c) on Raspberry Pi.

`/dev/gpiomem` provides access to the BCM2835 GPIO registers at `0x7E200000`
(See [BCM2835-ARM-Peripherals.pdf](https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf) p89.)

Simple examples:

```julia
using PiGPIOMEM

x = GPIOPin(7)
println("Pin state: ", x[])

set_output_mode(x)
clear(x)
set(x)
x[] = 0
x[] = 1
x[] = false
x[] = true

set_input_mode(x)
set_pullup(x)
println("Pin state: ", x[])

x = GPIOPin(8, output=true)
x[] = 1
```

Set pin: `pin[] = x`, `set(pin)`, `clear(pin)`.

Input/output: `set_input_mode(pin)` (default),
              `set_output_mode(pin)`,
              `is_input(pin)::Bool`,
              `is_output(pin)::Bool`.

Pullup/pulldown: `set_highz(pin)` (default),
                 `set_pulldown(pin)`
                 `set_pullup(pin)`

Set/Get multiple pins: `PiGPIOMEM.set(::GPIOPin...)`,
                       `PiGPIOMEM.clear(::GPIOPin...)`,
                       `PiGPIOMEM.level(::GPIOPin...)`.


Full documentation in [`src/PiGPIOMEM.jl`](src/PiGPIOMEM.jl) or:


```julia
julia> using PiGPIOMEM
help?> PiGPIOMEM
...

```



# Alternatives

* [JuliaBerry/PiGPIO.jl](https://github.com/JuliaBerry/PiGPIO.jl)
-- uses the [`pigpiod`](http://abyz.me.uk/rpi/pigpio/pigpiod.html)
daemon interface.

* [ronisbr/BaremetalPi.jl](https://github.com/ronisbr/BaremetalPi.jl)
-- uses `/dev/gpiomem`, `/dev/spidevX.X`, `/dev/i2c-X` etc.

* [notinaboat/PiGPIOC.jl](https://github.com/notinaboat/PiGPIOC.jl)
-- `ccall` wrappers for the
[`pigpio` C Interface](http://abyz.me.uk/rpi/pigpio/cif.html).
