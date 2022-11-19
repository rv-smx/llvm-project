//===-- RISCVInstrInfoZicbo.td - RISC-V SMX instructions ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the custom Stream-based
// Memory Access ISA extension (Xsmx).
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Operand definitions
//===----------------------------------------------------------------------===//

def SMXReadWriteArg : AsmOperandClass {
  let Name = "SMXReadWriteArg";
  let RenderMethod = "addSMXReadWriteArgOperands";
  let DiagnosticType = "InvalidSMXReadWriteArg";
}

def smx_rw_arg : Operand<XLenVT> {
  let ParserMatchClass = SMXReadWriteArg;
  let PrintMethod = "printSMXReadWriteArg";
  let DecoderMethod = "decodeUImmOperand<2>";
  let OperandType = "OPERAND_UIMM2";
  let OperandNamespace = "RISCVOp";
}

def SMXPatternArg : AsmOperandClass {
  let Name = "SMXPatternArg";
  let RenderMethod = "addSMXPatternArgOperands";
  let DiagnosticType = "InvalidSMXPatternArg";
}

def smx_pat_arg : Operand<XLenVT> {
  let ParserMatchClass = SMXPatternArg;
  let PrintMethod = "printSMXPatternArg";
  let DecoderMethod = "decodeUImmOperand<2>";
  let OperandType = "OPERAND_UIMM2";
  let OperandNamespace = "RISCVOp";
}

def uimm2_32 : ImmLeaf<i32, [{return isUInt<2>(Imm);}]>;
def uimm3_32 : ImmLeaf<i32, [{return isUInt<3>(Imm);}]>;
def uimm5_32 : ImmLeaf<i32, [{return isUInt<5>(Imm);}]>;
def uimm7_32 : ImmLeaf<i32, [{return isUInt<7>(Imm);}]>;
def uimm32_32 : ImmLeaf<i32, [{return isUInt<32>(Imm);}]>;

//===----------------------------------------------------------------------===//
// Instruction class templates
//===----------------------------------------------------------------------===//

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

  class SMXInstCfgIV<bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_0, (outs), (ins GPR:$rs2, simm12:$imm12),
                opcodestr, "$rs2, $imm12"> {
    let rs1 = 0;
  }

  class SMXInstCfgMS<bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_0, (outs),
                (ins GPR:$rs1, GPR:$rs2, uimm5:$dependent,
                 smx_rw_arg:$rw, smx_pat_arg:$pattern, uimm3:$width),
                opcodestr, "$rs1, $rs2, $dependent, $rw, $pattern, $width"> {
    bits<5> dependent;
    bits<2> rw;
    bits<2> pattern;
    bits<3> width;

    let imm12 = {width, pattern, rw, dependent};
  }

  class SMXInstHint<bits<7> funct7, bits<3> funct3, string opcodestr>
      : RVInstR<funct7, funct3, OPC_CUSTOM_0, (outs), (ins), opcodestr, ""> {
    let rs2 = 0;
    let rs1 = 0;
    let rd = 0;
  }

  class SMXInstStep<bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_0, (outs), (ins uimm5:$rs1, GPR:$rs2, simm12:$imm12),
                opcodestr, "$rs1, $rs2, $imm12">;

} // hasSideEffects = 1, mayLoad = 0, mayStore = 0

let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in {

  class SMXInstLoad<RegisterClass rd, bits<2> width, bit unsigned,
                    bits<3> funct3, string opcodestr>
      : RVInstI<funct3, OPC_CUSTOM_1,
                (outs rd:$rd), (ins uimm5:$rs1, uimm7:$selector),
                opcodestr, "$rd, $rs1, $selector"> {
    bits<7> selector;

    let imm12 = {selector, 0b00, unsigned, width};
  }

  class SMXInstRead<bits<3> funct3, string opcodestr>
      : RVInstI<funct3, OPC_CUSTOM_1,
                (outs GPR:$rd), (ins uimm5:$rs1, simm12:$imm12),
                opcodestr, "$rd, $rs1, $imm12">;

} // hasSideEffects = 0, mayLoad = 1, mayStore = 0

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in {

  class SMXInstStore<RegisterClass rs2, bits<2> width,
                     bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_1,
                (outs), (ins uimm5:$rs1, rs2:$rs2, uimm7:$selector),
                opcodestr, "$rs1, $rs2, $selector"> {
    bits<7> selector;

    let imm12 = {selector, 0b000, width};
  }

  class SMXInstWrite<bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_1,
                (outs), (ins uimm5:$rs1, GPR:$rs2, simm12:$imm12),
                opcodestr, "$rs1, $rs2, $imm12">;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 1

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasExtXsmx] in {
  def SMX_CFG_IV : SMXInstCfgIV <              0b000, "smx.cfg.iv">, Sched<[]>;
  def SMX_CFG_MS : SMXInstCfgMS <              0b001, "smx.cfg.ms">, Sched<[]>;
  def SMX_READY  : SMXInstHint  <   0b0000000, 0b010, "smx.ready">, Sched<[]>;
  def SMX_END    : SMXInstHint  <   0b0000001, 0b010, "smx.end">, Sched<[]>;
  def SMX_STEP   : SMXInstStep  <              0b011, "smx.step">, Sched<[]>;
  def SMX_LB     : SMXInstLoad  <GPR, 0b00, 0, 0b000, "smx.lb">, Sched<[]>;
  def SMX_LBU    : SMXInstLoad  <GPR, 0b00, 1, 0b000, "smx.lbu">, Sched<[]>;
  def SMX_LH     : SMXInstLoad  <GPR, 0b01, 0, 0b000, "smx.lh">, Sched<[]>;
  def SMX_LHU    : SMXInstLoad  <GPR, 0b01, 1, 0b000, "smx.lhu">, Sched<[]>;
  def SMX_LW     : SMXInstLoad  <GPR, 0b10, 0, 0b000, "smx.lw">, Sched<[]>;
  def SMX_LWU    : SMXInstLoad  <GPR, 0b10, 1, 0b000, "smx.lwu">, Sched<[]>;
  def SMX_LD     : SMXInstLoad  <GPR, 0b11, 0, 0b000, "smx.ld">, Sched<[]>;
  def SMX_SB     : SMXInstStore <GPR, 0b00,    0b001, "smx.sb">, Sched<[]>;
  def SMX_SH     : SMXInstStore <GPR, 0b01,    0b001, "smx.sh">, Sched<[]>;
  def SMX_SW     : SMXInstStore <GPR, 0b10,    0b001, "smx.sw">, Sched<[]>;
  def SMX_SD     : SMXInstStore <GPR, 0b11,    0b001, "smx.sd">, Sched<[]>;
  def SMX_RD_IV  : SMXInstRead  <              0b010, "smx.rd.iv">, Sched<[]>;
  def SMX_WR_IV  : SMXInstWrite <              0b011, "smx.wr.iv">, Sched<[]>;
} // Predicates = [HasExtXsmx]

let Predicates = [HasExtXsmx, HasStdExtF] in {
  def SMX_FLW : SMXInstLoad  <FPR32, 0b10, 0, 0b100, "smx.flw">, Sched<[]>;
  def SMX_FLD : SMXInstLoad  <FPR64, 0b11, 0, 0b100, "smx.fld">, Sched<[]>;
  def SMX_FSW : SMXInstStore <FPR32, 0b10,    0b101, "smx.fsw">, Sched<[]>;
  def SMX_FSD : SMXInstStore <FPR64, 0b11,    0b101, "smx.fsd">, Sched<[]>;
} // Predicates = [HasExtXsmx, HasStdExtF]

//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//

class SMXLoadPat<SMXInstLoad load, ValueType vt>
    : Pat<(vt (int_riscv_smx_load uimm5_32:$rs1, uimm7_32:$selector)),
          (load uimm5:$rs1, uimm7:$selector)>;

let Predicates = [HasExtXsmx] in {

  def : Pat<(int_riscv_smx_cfg_iv GPR:$rs2), (SMX_CFG_IV GPR:$rs2, 0)>;
  def : Pat<(int_riscv_smx_cfg_iv simm12:$imm12), (SMX_CFG_IV X0, simm12:$imm12)>;
  def : Pat<(int_riscv_smx_cfg_iv (add GPR:$rs2, simm12:$imm12)),
            (SMX_CFG_IV GPR:$rs2, simm12:$imm12)>;

  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, uimm5_32:$dependent,
                                  0, 0, uimm2_32:$pattern, uimm3_32:$width),
            (SMX_CFG_MS GPR:$rs1, GPR:$rs2, uimm5:$dependent,
                        0b00, smx_pat_arg:$pattern, uimm3:$width)>;
  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, uimm5_32:$dependent,
                                  uimm32_32, 0, uimm2_32:$pattern, uimm3_32:$width),
            (SMX_CFG_MS GPR:$rs1, GPR:$rs2, uimm5:$dependent,
                        0b01, smx_pat_arg:$pattern, uimm3:$width)>;
  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, uimm5_32:$dependent,
                                  0, uimm32_32, uimm2_32:$pattern, uimm3_32:$width),
            (SMX_CFG_MS GPR:$rs1, GPR:$rs2, uimm5:$dependent,
                        0b10, smx_pat_arg:$pattern, uimm3:$width)>;
  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, uimm5_32:$dependent,
                                  uimm32_32, uimm32_32, uimm2_32:$pattern, uimm3_32:$width),
            (SMX_CFG_MS GPR:$rs1, GPR:$rs2, uimm5:$dependent,
                        0b11, smx_pat_arg:$pattern, uimm3:$width)>;

  def : Pat<(int_riscv_smx_ready), (SMX_READY)>;
  def : Pat<(int_riscv_smx_end), (SMX_END)>;

  // def : SMXLoadPat<SMX_LD, i8,  0b00>;
  // def : SMXLoadPat<SMX_LD, i16, 0b01>;
  def : SMXLoadPat<SMX_LW, i32>;

  def : Pat<(int_riscv_smx_store uimm5_32:$rs1, uimm7_32:$selector, GPR:$rs2),
            (SMX_SW uimm5:$rs1, GPR:$rs2, uimm7:$selector)>;

  def : Pat<(int_riscv_smx_read_iv uimm5_32:$rs1),
            (SMX_RD_IV uimm5:$rs1, 0)>;
  def : Pat<(add (int_riscv_smx_read_iv uimm5_32:$rs1), simm12:$imm12),
            (SMX_RD_IV uimm5:$rs1, simm12:$imm12)>;

  def : Pat<(int_riscv_smx_write_iv uimm5_32:$rs1, GPR:$rs2),
            (SMX_WR_IV uimm5:$rs1, GPR:$rs2, 0)>;
  def : Pat<(int_riscv_smx_write_iv uimm5_32:$rs1, simm12:$imm12),
            (SMX_WR_IV uimm5:$rs1, X0, simm12:$imm12)>;
  def : Pat<(int_riscv_smx_write_iv uimm5_32:$rs1, (add GPR:$rs2, simm12:$imm12)),
            (SMX_WR_IV uimm5:$rs1, GPR:$rs2, simm12:$imm12)>;

  def : Pat<(int_riscv_smx_step uimm5_32:$rs1, GPR:$rs2),
            (SMX_STEP uimm5:$rs1, GPR:$rs2, 0)>;
  def : Pat<(int_riscv_smx_step uimm5_32:$rs1, simm12:$imm12),
            (SMX_STEP uimm5:$rs1, X0, simm12:$imm12)>;
  def : Pat<(int_riscv_smx_step uimm5_32:$rs1, (add GPR:$rs2, simm12:$imm12)),
            (SMX_STEP uimm5:$rs1, GPR:$rs2, simm12:$imm12)>;

} // Predicates = [HasExtXsmx]

let Predicates = [HasExtXsmx, IsRV64] in {
  def : SMXLoadPat<SMX_LD, i64>;
} // Predicates = [HasExtXsmx, IsRV64]

let Predicates = [HasExtXsmx, HasStdExtF] in {
  def : SMXLoadPat<SMX_FLW, f32>;
  def : Pat<(int_riscv_smx_store uimm5_32:$rs1, uimm7_32:$selector, FPR32:$rs2),
            (SMX_FSW uimm5:$rs1, FPR32:$rs2, uimm7:$selector)>;
} // Predicates = [HasExtXsmx, HasStdExtF]

let Predicates = [HasExtXsmx, HasStdExtD] in {
  def : SMXLoadPat<SMX_FLD, f64>;
  def : Pat<(int_riscv_smx_store uimm5_32:$rs1, uimm7_32:$selector, FPR64:$rs2),
            (SMX_FSD uimm5:$rs1, FPR64:$rs2, uimm7:$selector)>;
} // Predicates = [HasExtXsmx, HasStdExtF]
