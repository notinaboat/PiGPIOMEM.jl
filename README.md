# PiGPIOMEM.jl

Julia interface for Raspberry Pi GPIO using [`/dev/gpiomem`](https://github.com/raspberrypi/linux/blob/rpi-5.4.y/drivers/char/broadcom/bcm2835-gpiomem.c).

`/dev/gpiomem` provides userspace access to the BCM2835 GPIO control registers
(see [BCM2835-ARM-Peripherals.pdf](https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf) p89).


## Installation

```julia
pkg> add https://github.com/notinaboat/PiGPIOMEM.jl
```


## Simple examples

```julia
julia> using PiGPIOMEM

julia> pin7 = GPIOPin(7)
GPIOPin(7)

julia> pin7[]
false

julia> set_pullup(pin7)

julia> pin7[]
true

julia> set_output_mode(pin7)

julia> pin7[] = false

julia> pin7[]
false

julia> set(pin7)

julia> pin7[]
true

julia> clear(pin7)

julia> pin7[]
false

julia> pin17 = GPIOPin(17; output=true)
GPIOPin(17, output=true)

julia> pin17[] = true

julia> clear(pin7, pin17)

julia> pin7[], pin17[]
(false, false)

julia> set(pin7, pin17)

julia> pin7[], pin17[]
(true, true)

```


## Full Documentation

See [`src/PiGPIOMEM.jl`](src/PiGPIOMEM.jl) or online help:


```julia
julia> using PiGPIOMEM
help?> PiGPIOMEM

```


## Implementation

The implementation aims to minimise pin access overhead.
The pin number is bounds checked only once at construction time and
register addresses and bit masks are pre-computed.

The resulting compiled pin access functions are very small:

```julia
julia> code_native(set, [GPIOPin]; debuginfo=:none)
	.text
	ldr	r1, [r0, #8]
	ldr	r0, [r0, #12]
	str	r1, [r0]
	bx	lr

julia> code_native(clear, [GPIOPin]; debuginfo=:none)
	.text
	ldr	r1, [r0, #8]
	ldr	r0, [r0, #16]
	str	r1, [r0]
	bx	lr

julia> code_native(getindex, [GPIOPin]; debuginfo=:none)
	.text
	ldr	r1, [r0, #8]
	ldr	r0, [r0, #20]
	ldr	r0, [r0]
	ands	r0, r1, r0
	movne	r0, #1
	bx	lr
```

The following test produces a 9.7MHz square wave on a Raspberry Pi Zero W.

```julia
julia> using LLVM

julia> @noinline nop() = LLVM.Interop.@asmcall("nop")

julia> toggle(pin) = while true
    clear(pin)
    nop()
    nop()
    set(pin)
    nop()
    nop()
end
toggle (generic function with 1 method)

julia> toggle(GPIOPin(21, output=true))
```


# Alternatives

* [JuliaBerry/PiGPIO.jl](https://github.com/JuliaBerry/PiGPIO.jl)
-- uses the [`pigpiod`](http://abyz.me.uk/rpi/pigpio/pigpiod.html)
daemon interface.

* [notinaboat/PiGPIOC.jl](https://github.com/notinaboat/PiGPIOC.jl)
-- `ccall` wrappers for the
[`pigpio` C Interface](http://abyz.me.uk/rpi/pigpio/cif.html).

* [ronisbr/BaremetalPi.jl](https://github.com/ronisbr/BaremetalPi.jl)
-- uses `/dev/gpiomem`, `/dev/spidevX.X`, `/dev/i2c-X` etc.
