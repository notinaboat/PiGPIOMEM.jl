"""
# module PiGPIOMEM

Julia interface for `/dev/gpiomem` on Raspberry Pi [1].
`/dev/gpiomem` maps the BCM2835 GPIO registers at `0x7E200000` [2, p89].

This module can:
 * Query and set GPIO pins.
 * Configure input/output mode and pullups/pulldowns.

## Interface Summary

Create a `GPIOPin` object:
 * `pin = GPIOPin(7)`

Query pin state:
 * `x = pin[]` (`Bool`)

Set pin state:
 * `pin[] = true` -- logic high
 * `pin[] = false` -- logic low
 * `set(pin)` -- logic high
 * `clear(pin)` -- logic low

Configure input/output:
 * `set_input_mode(pin)` (default)
 * `set_output_mode(pin)`
 * `is_input(pin)::Bool`
 * `is_output(pin)::Bool`

Configure pullup/pulldown:
 * `set_highz(pin)` (default)
 * `set_pulldown(pin)`
 * `set_pullup(pin)`

Set/Get multiple pins:
 * `PiGPIOMEM.set(::GPIOPin...)`
 * `PiGPIOMEM.clear(::GPIOPin...)`
 * `PiGPIOMEM.level(::GPIOPin...)`

## References

 [1] BCM2835-ARM-Peripherals.pdf
     https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf

 [2] BCM2835 GPIO memory device driver
     https://github.com/raspberrypi/linux/blob/rpi-5.4.y/
                        drivers/char/broadcom/bcm2835-gpiomem.c
"""
module PiGPIOMEM


export GPIOPin
export set, clear
export set_input_mode, set_output_mode, is_input, is_output
export set_highz, set_pullup, set_pulldown

using Mmap


# BCM2835 GPIO Registers.

"Memory map of the BCM2835 GPIO registers (`0x7E200000`)"
const gpiomem = Ref{Vector{UInt32}}()
const gpiomem_length = 40                                        # [1, 6.1, p91]


"""
    Register(offset)

Wraps a pointer to one of the BCM2835 GPIO registers.
Provides efficient access to register content using direct load/store
instructions via the `getindex/setindex!` interface.
The offset is bounds checked once at construction time.
The `/dev/gpiomem` map is loaded on demand.
"""
struct Register
    address::Ptr{UInt32}
    function Register(offset)
        @assert 1 + offset in 1:gpiomem_length
        if !isassigned(gpiomem)
            gpiomem[] = Mmap.mmap("/dev/gpiomem",
                                  Vector{UInt32}, gpiomem_length;
                                  grow=false)
        end
        new(pointer(gpiomem[], 1 + offset))
    end
end

Base.getindex(r::Register) = unsafe_load(r.address)
Base.setindex!(r::Register, v) = unsafe_store!(r.address, v)

gpfsel(n)   = Register(n÷10)                        # 0x 7E20 0000 [1, 6.1, p90]
gpset0()    = Register(0x1C÷4)                      # 0x 7E20 001C [1, 6.1, p90]
gpclr0()    = Register(0x28÷4)                      # 0x 7E20 0028 [1, 6.1, p90]
gplev0()    = Register(0x34÷4)                      # 0x 7E20 0034 [1, 6.1, p90]
gppud()     = Register(0x94÷4)                      # 0x 7E20 0094 [1, 6.1, p91]
gppudclk0() = Register(0x98÷4)                      # 0x 7E20 0098 [1, 6.1, p91]


"""
    GPIOPin(n; [output=false])

Raspberry Pi (BCM2835) General Purpose Input Output pin `n`.

See `help?>` [PiGPIOMEM](@ref) for Interface Summary.

### Implementation Notes

The implementation aims to minimise pin access overhead.
The pin number is bounds checked only once at construction time and
register addresses and bit masks are pre-computed.

The GPIOPin object holds direct pointers to the BCM2835 Registers that
control a specific pin. Rather than storing the pin number, the GPIOPin object
stores bit masks for the register bits that control the pin. This allows
the `set` and `clear` functions to be as simple as possible
(`p.gpset[] = p.pin_bit` and `p.gpclr[] = p.pin_bit` respectively).

`sel_bit` is the Input/output mode bit for this pin in the GPFSELn register.

`pin_bit` is the bit that controls this pin in the GPSETn, GPCLRn and GPLEVn
egisters."
"""
struct GPIOPin

    sel_bit::UInt32                                       # [1, Table 6-2,  p92]
    gpfsel::Register                                      # [1,       6.1,  p90]

    pin_bit::UInt32
    gpset::Register                                       # [1, Table 6-9,  p95]
    gpclr::Register                                       # [1, Table 6-10, p95]
    gplev::Register                                       # [1, Table 6-12, p96]

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

sel_index(p::GPIOPin) = trailing_zeros(p.sel_bit)
pin_index(p::GPIOPin) = trailing_zeros(p.pin_bit)


# Set/Get pin state.

Base.setindex!(p::GPIOPin, v::Bool) = v ? set(p) : clear(p)
Base.setindex!(p::GPIOPin, v) = setindex!(p, !iszero(v))
Base.getindex(p::GPIOPin) = !iszero(level(p))

  set(p::GPIOPin) = (p.gpset[] = p.pin_bit; nothing)      # [1, Table 6-9,  p95]
clear(p::GPIOPin) = (p.gpclr[] = p.pin_bit; nothing)      # [1, Table 6-10, p95]
level(p::GPIOPin) =  p.gplev[] & p.pin_bit                # [1, Table 6-12, p96]


# Input/Output mode.                                         [1, Table 6-2, p92]

reset_mode(p::GPIOPin) = p.gpfsel[] &= ~(UInt32(0b111) << sel_index(p))

set_input_mode(p::GPIOPin) = (p.gpfsel[] &= ~p.sel_bit; nothing)
set_output_mode(p::GPIOPin) = (p.gpfsel[] |= p.sel_bit; nothing)
is_input(p::GPIOPin) = iszero(p.gpfsel[] & p.sel_bit)
is_output(p::GPIOPin) = !is_input(p::GPIOPin)


# Operations on multiple pins.

"Combine the `pin_bit`s for multiple `pins` into a single bit mask."
bits(pins...) = reduce(|, p.pin_bit for p in pins)

  set(pins::GPIOPin...) = (first(pins).gpset[] = bits(pins); nothing)
clear(pins::GPIOPin...) = (first(pins).gpclr[] = bits(pins); nothing)
level(pins::GPIOPin...) =  first(pins).gplev[] & bits(pins)


# Pull-up/down.                                            [1, Table 6-28, p101]

set_highz(p::GPIOPin)    = set_pud(p, 0)
set_pulldown(p::GPIOPin) = set_pud(p, 1)
set_pullup(p::GPIOPin)   = set_pud(p, 2)

using LLVM
@noinline nop() = LLVM.Interop.@asmcall("nop")
spin(n) = for i in 1:n nop() end                  # spin(50) ~= 1us on Pi Zero W

function set_pud(p::GPIOPin, mode)
    gppud()[] = mode
    spin(10)                                         # [1, p101] Wait 150 cycles
    gppudclk0()[] = p.pin_bit
    spin(10)                                         # [1, p101] Wait 150 cycles
    gppud()[] = 0
    gppudclk0()[] = 0
    nothing
end


# Pretty printing.

Base.show(io::IO, p::GPIOPin) =
    print(io, "GPIOPin(", pin_index(p), is_output(p) ? ", output=true)" : ")")

Base.show(io::IO, r::Register) =
    print(io, "BCM2835 Register: 0x7E20_",
              uppercase(string(r.address - pointer(gpiomem[]), base=16, pad=4)))



end # module
