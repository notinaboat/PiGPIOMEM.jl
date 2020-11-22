# References:
# [1] BCM2835-ARM-Peripherals.pdf
# https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
# [2] BCM2835 GPIO memory device driver
# https://github.com/raspberrypi/linux/blob/rpi-5.4.y/
#                    drivers/char/broadcom/bcm2835-gpiomem.c


module PiGPIOMEM


export GPIOPin
export set, clear
export set_input_mode, set_output_mode, is_input, is_output
export set_highz, set_pullup, set_pulldown

using Mmap


# BCM2835 GPIO Registers.

const gpiomem = Ref{Vector{UInt32}}()

struct Register
    address::Ptr{UInt32}
    function Register(offset)
        @assert 1 + offset in 1:length(gpiomem[])
        if !isassigned(gpiomem)
            gpiomem[] = Mmap.mmap("/dev/gpiomem",
                                  Vector{UInt32}, 40; # [1, 6.1, p91]
                                  grow=false)
        end
        new(pointer(gpiomem[], 1 + offset))
    end
end

gpfsel(n)   = register(n÷10)   # 0x 7E20 0000 [1, 6.1, p90]
gpset0()    = register(0x1C÷4) # 0x 7E20 001C [1, 6.1, p90]
gpclr0()    = register(0x28÷4) # 0x 7E20 0028 [1, 6.1, p90]
gplev0()    = register(0x34÷4) # 0x 7E20 0034 [1, 6.1, p90]
gppud()     = register(0x94÷4) # 0x 7E20 0094 [1, 6.1, p91]
gppudclk0() = register(0x98÷4) # 0x 7E20 0098 [1, 6.1, p91]

Base.getindex(r::Register) = unsafe_load(r.address)
Base.setindex!(r::Register, v) = unsafe_store!(r.address, v)


"""
    GPIOPin(n)

Raspberry Pi (BCM2835) General Purpose Input Output pin `n`.

Query pin: `x = pin[]`.

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
"""
struct GPIOPin

    sel_bit::UInt32 # [1, Table 6-2, p92]
    gpfsel::Register

    pin_bit::UInt32
    gpset::Register # [1, Table 6-9,  p95]
    gpclr::Register # [1, Table 6-10, p95]
    gplev::Register # [1, Table 6-12, p96]

    function GPIOPin(n; output=false)
        @assert n in 0:27
        pin = new(1 << (3*(n%10)), gpfsel(n), 
                  1 << n, gpset0(), gpclr0(), gplev0())
        reset_mode(pin)
        if output
            set_output_mode(pin)
        end
        pin
    end
end

sel_index(p::GPIOPin) = trailing_zeros(p.selpit)
pin_index(p::GPIOPin) = trailing_zeros(p.binpit)


# Set/Get pin state.

Base.setindex!(p::GPIOPin, v::Bool) = v ? set(p) : clear(p)
Base.setindex!(p::GPIOPin, v) = setindex(p, !iszero(v))
Base.getindex(p::GPIOPin) = !iszero(level(p))

  set(p::GPIOPin) = p.gpset[] = p.pin_bit                 # [1, Table 6-9,  p95]
clear(p::GPIOPin) = p.gpclr[] = p.pin_bit                 # [1, Table 6-10, p95]
level(p::GPIOPin) = p.gplev[] & p.pin_bit                 # [1, Table 6-12, p96]


# Input/Output mode.                                         [1, Table 6-2, p92]

reset_mode(p::GPIOPin) = p.gpfsel[] &= ~(0b111 << sel_index(p))

set_input_mode(p::GPIOPin) = p.gpfsel[] &= ~p.sel_bit
set_output_mode(p::GPIOPin) = p.gpfsel[] |= p.sel_bit
is_input(p::GPIOPin) = iszero(p.gpfsel[] & p.sel_bit)
is_output(p::GPIOPin) = !is_input(p::GPIOPin)



# Operations on multiple pins.

bits(pins...) = reduce(|, p.pin_bit for p in pins)

  set(pins::GPIOPin...) = first(pins).gpset[] = bits(pins)
clear(pins::GPIOPin...) = first(pins).gpclr[] = bits(pins)
level(pins::GPIOPin...) = first(pins).gplev[] & bits(pins)


# Pull-up/down.                                            [1, Table 6-28, p101]

set_highz(p::GPIOPin) = set_pud(p, 0)
set_pulldown(p::GPIOPin) = set_pud(p, 1)
set_pullup(p::GPIOPin) = set_pud(p, 2)

function set_pud(p::GPIOPin, mode)
    gppud()[] = mode
    yeild() # FIXME [1, p101] Wait 150 cycles
    gppudclk0()[] = p.pin_bit
    yeild() # FIXME [1, p101] Wait 150 cycles
    gppud()[] = 0
    gppudclk()[] = 0
end



end # module
