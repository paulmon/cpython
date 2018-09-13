/* -----------------------------------------------------------------------
   sysv.S - Copyright (c) 1998, 2008, 2011 Red Hat, Inc.
        Copyright (c) 2011 Plausible Labs Cooperative, Inc.

   ARM Foreign Function Interface

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   ``Software''), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED ``AS IS'', WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
   ----------------------------------------------------------------------- */

#define LIBFFI_ASM
#include <fficonfig.h>
#include <ffi.h>
#include <ffi_cfi.h>
#include "internal.h"

/* Aid in defining a jump table with 8 bytes between entries.  */
/* ??? The clang assembler doesn't handle .if with symbolic expressions.  */
;#ifdef __clang__
;# define E(index)
;#else
;# define E(index)                      \
;    .if . - 0b - 8*index;              \
;    .error "type table out of sync";   \
;    .endif
;#endif

    AREA |.text|, CODE, THUMB, READONLY     ; .text

    ;@ r0:   stack
    ;@ r1:   frame
    ;@ r2:   fn
    ;@ r3:    vfp_used

    EXPORT |ffi_call_VFP|
|ffi_call_VFP| PROC
    cmp    r3, #3            ; load only d0 if possible
    vldrle d0, [r0]
    vldmgt r0, {d0-d7}
    add    r0, r0, #64        ; discard the vfp register args
    /* FALLTHRU */
    b ffi_call_SYSV     ; linux code doesn't need a branch.  Is this correct?
    ENDP

    EXPORT |ffi_call_SYSV|
|ffi_call_SYSV| PROC
    stm    r1, {fp, lr}
    mov    fp, r1

    mov    sp, r0        ; install the stack pointer
    mov    lr, r2        ; move the fn pointer out of the way
    ldr    ip, [fp, #16]    ; install the static chain
    ldmia    sp!, {r0-r3}    ; move first 4 parameters in registers.
    blx    lr        ; call fn

    ; Load r2 with the pointer to storage for the return value
    ; Load r3 with the return type code
    ldr    r2, [fp, #8]
    ldr    r3, [fp, #12]

    ; Deallocate the stack with the arguments.
    mov    sp, fp

return_vfp_s
    cmp r3, #ARM_TYPE_VFP_S
    bne return_vfp_d
    vstr s0, [r2]
    pop    {fp,pc}
return_vfp_d
    cmp r3, #ARM_TYPE_VFP_D
    bne return_vfp_n
    vstr d0, [r2]
    pop    {fp,pc}
return_vfp_n
    cmp r3, #ARM_TYPE_VFP_N
    bne return_int64
    vstm r2, {d0-d3}
    pop    {fp,pc}
return_int64
    cmp r3, #ARM_TYPE_INT64
    bne return_int
    str    r1, [r2, #4]
    str    r0, [r2]
    pop    {fp,pc}
return_int
    cmp r3, #ARM_TYPE_INT
    bne return_void
    str    r0, [r2]
    pop    {fp,pc}
return_void
    cmp r3, #ARM_TYPE_VOID
    bne return_struct
    pop    {fp,pc}
    nop
return_struct
    cmp r3, #ARM_TYPE_STRUCT
    pop    {fp,pc}
    ENDP


/*
    int ffi_closure_inner_* (cif, fun, user_data, frame)
*/

;    EXPORT |ffi_go_closure_SYSV|
;|ffi_go_closure_SYSV| PROC
;    stmdb    sp!, {r0-r3}            ; save argument regs
;    ldr    r0, [ip, #4]            ; load cif
;    ldr    r1, [ip, #8]            ; load fun
;    mov    r2, ip                ; load user_data
;    ;b    0f
;    b ffi_closure_SYSV_0
;    ENDP

    IMPORT |ffi_closure_inner_SYSV|
    EXPORT |ffi_closure_SYSV|
|ffi_closure_SYSV| PROC
    stmdb    sp!, {r0-r3}            ; save argument regs

    ldr    r0, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET]    ; load cif
    ldr    r1, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET+4]  ; load fun
    ldr    r2, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET+8]  ; load user_data
ffi_closure_SYSV_0
    add    ip, sp, #16            ; compute entry sp
    sub    sp, sp, #64+32            ; allocate frame
    stmdb    sp!, {ip,lr}

    add    r3, sp, #8            ; load frame
    bl    ffi_closure_inner_SYSV

    ; Load values returned in registers.
    add    r2, sp, #8+64            ; load result
    adr    r3, ffi_closure_ret
    add    pc, r3, r0, lsl #3
    ENDP

;    EXPORT |ffi_go_closure_VFP|
;|ffi_go_closure_VFP| PROC
;    stmdb    sp!, {r0-r3}            ; save argument regs
;    ldr    r0, [ip, #4]            ; load cif
;    ldr    r1, [ip, #8]            ; load fun
;    mov    r2, ip                ; load user_data
;;    b    ffi_go_closure_VFP_0
;    cfi_endproc
;    ENDP

    IMPORT |ffi_closure_inner_VFP|
    EXPORT |ffi_closure_VFP|
|ffi_closure_VFP| PROC
    stmdb    sp!, {r0-r3}            ; save argument regs

    ldr    r0, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET]    ; load cif
    ldr    r1, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET+4]  ; load fun
    ldr    r2, [ip, #FFI_TRAMPOLINE_CLOSURE_OFFSET+8]  ; load user_data
ffi_go_closure_VFP_0
    add    ip, sp, #16
    sub    sp, sp, #64+32            ; allocate frame
    vstm sp, {d0-d7}
    stmdb    sp!, {ip,lr}

    add    r3, sp, #8            ; load frame
    bl    ffi_closure_inner_VFP

    ; Load values returned in registers.
    add    r2, sp, #8+64            ; load result
    adr    r3, ffi_closure_ret
    add    pc, r3, r0, lsl #3
    ENDP

/* Load values returned in registers for both closure entry points.
   Note that we use LDM with SP in the register set.  This is deprecated
   by ARM, but not yet unpredictable.  */

    EXPORT |ffi_closure_ret|
|ffi_closure_ret| PROC
return_vfp_s_2
    cmp r2, #ARM_TYPE_VFP_S
    bne return_vfp_f_2
    vldr s0, [r2]
    beq call_epilogue
return_vfp_f_2
    cmp r2, #ARM_TYPE_VFP_D
    bne return_vfp_n_2
    vldr d0, [r2]
    beq call_epilogue
return_vfp_n_2
    cmp r2, #ARM_TYPE_VFP_N
    bne return_vfp_int64_2
    vldm r2, {d0-d3}
    beq call_epilogue
return_vfp_int64_2
    cmp r2, #ARM_TYPE_INT64
    bne return_vfp_int_2
    ldr    r1, [r2, #4]
    ldr    r0, [r2]
    beq call_epilogue
return_vfp_int_2
    cmp r2, #ARM_TYPE_INT
    bne return_vfp_void_2
    ldr    r0, [r2]
    beq call_epilogue
return_vfp_void_2
    cmp r2, #ARM_TYPE_VOID
    bne return_vfp_struct_2
    beq call_epilogue
return_vfp_struct_2
    cmp r2, #ARM_TYPE_STRUCT
    beq call_epilogue
call_epilogue
    ENDP


    EXPORT |ffi_arm_trampoline|
|ffi_arm_trampoline| PROC
thisproc    adr    ip, thisproc
            ldr    pc, =closure
closure     DCD    0
            ENDP

    END