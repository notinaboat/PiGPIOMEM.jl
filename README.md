# PiGPIOMEM.jl

Julia interface for [`/dev/gpiomem'](https://github.com/raspberrypi/linux/blob/rpi-5.4.y/drivers/char/broadcom/bcm2835-gpiomem.c) on Raspberry Pi.

`/dev/gpiomem` provides access to the BCM2835 GPIO registers at `0x7E200000`
(See [BCM2835-ARM-Peripherals.pdf](https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf) p89.)


```julia
using PiGPIOMEM

x = GPIOPin(7)
println("Pin state: ", x[])

set_output_mode(x)
x[] = 0
x[] = 1
x[] = false
x[] = true
clear(x)
set(x)

set_input_mode(x)
set_pullup(x)
println("Pin state: ", x[])
```
