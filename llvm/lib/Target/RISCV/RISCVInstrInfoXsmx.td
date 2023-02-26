//===-- RISCVInstrInfoXsmx.td - RISC-V SMX instructions ----*- tablegen -*-===//
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
// RISC-V specific DAG nodes
//===----------------------------------------------------------------------===//

def SDT_RISCVSMXExtLoad : SDTypeProfile<1, 2, [SDTCisVT<0, XLenVT>,
                                               SDTCisVT<1, XLenVT>,
                                               SDTCisVT<2, XLenVT>]>;

def SDT_RISCVSMXTruncStore : SDTypeProfile<0, 3, [SDTCisVT<0, XLenVT>,
                                                  SDTCisVT<1, XLenVT>,
                                                  SDTCisVT<2, XLenVT>]>;

def SDT_RISCVSMXBranch : SDTypeProfile<1, 2, [SDTCisVT<0, XLenVT>,
                                              SDTCisVT<1, XLenVT>,
                                              SDTCisVT<2, OtherVT>]>;

multiclass RISCVSMXExtLoad<string ext, int len> {
  defvar node_name = "smx_" # NAME # "_load_i" # len;
  def node_name : SDNode<"RISCVISD::SMX_" # ext # "_LOAD_I" # len,
                         SDT_RISCVSMXExtLoad, [SDNPHasChain, SDNPMayLoad]>;
  def smx_ # NAME # loadi # len
      : PatFrag<(ops node:$stream, node:$sel),
                (!cast<SDNode>(node_name) node:$stream, node:$sel)>;
}

multiclass RISCVSMXTruncStore<int len> {
  defvar node_name = "smx_trunc_store_i" # len;
  def node_name : SDNode<"RISCVISD::SMX_TRUNC_STORE_I" # len,
                         SDT_RISCVSMXTruncStore, [SDNPHasChain, SDNPMayStore]>;
  def smx_truncstorei # len
      : PatFrag<(ops node:$stream, node:$sel, node:$val),
                (!cast<SDNode>(node_name) node:$stream, node:$sel, node:$val)>;
}

foreach l = [8, 16, 32] in {
  defm ext : RISCVSMXExtLoad<"EXT", l>;
  defm sext : RISCVSMXExtLoad<"SEXT", l>;
  defm zext : RISCVSMXExtLoad<"ZEXT", l>;
  defm "" : RISCVSMXTruncStore<l>;
}

def smx_step_bl : SDNode<"RISCVISD::SMX_STEP_BL", SDT_RISCVSMXBranch,
                         [SDNPHasChain]>;
def smx_step_j  : SDNode<"RISCVISD::SMX_STEP_J", SDT_RISCVSMXBranch,
                         [SDNPHasChain]>;
def smx_bnl     : SDNode<"RISCVISD::SMX_BNL", SDT_RISCVSMXBranch,
                         [SDNPHasChain]>;

//===----------------------------------------------------------------------===//
// Operand definitions
//===----------------------------------------------------------------------===//

def SMXStopConditionArg : AsmOperandClass {
  let Name = "SMXStopConditionArg";
  let RenderMethod = "addSMXStopConditionArgOperands";
  let DiagnosticType = "InvalidSMXStopConditionArg";
}

def smx_stop_cond_arg : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<4>(Imm);}]> {
  let ParserMatchClass = SMXStopConditionArg;
  let PrintMethod = "printSMXStopConditionArg";
  let DecoderMethod = "decodeUImmOperand<4>";
  let OperandType = "OPERAND_UIMM4";
  let OperandNamespace = "RISCVOp";
}

def SMXFactorKindArg : AsmOperandClass {
  let Name = "SMXFactorKindArg";
  let RenderMethod = "addSMXFactorKindArgOperands";
  let DiagnosticType = "InvalidSMXFactorKindArg";
}

def smx_fact_kind_arg : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<1>(Imm);}]> {
  let ParserMatchClass = SMXFactorKindArg;
  let PrintMethod = "printSMXFactorKindArg";
  let DecoderMethod = "decodeUImmOperand<1>";
  let OperandType = "OPERAND_UIMM1";
  let OperandNamespace = "RISCVOp";
}

def smx_width_arg : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<3>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<3>;
  let DecoderMethod = "decodeUImmOperand<3>";
  let OperandType = "OPERAND_UIMM3";
  let OperandNamespace = "RISCVOp";
}

def smx_stream_arg : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<5>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<5>;
  let DecoderMethod = "decodeUImmOperand<5>";
  let OperandType = "OPERAND_UIMM5";
  let OperandNamespace = "RISCVOp";
}

def smx_sel_arg : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<7>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<7>;
  let DecoderMethod = "decodeUImmOperand<7>";
  let OperandType = "OPERAND_UIMM7";
  let OperandNamespace = "RISCVOp";
}

def uimm_xlen : ImmLeaf<XLenVT, [{}]>;

//===----------------------------------------------------------------------===//
// Instruction class templates
//===----------------------------------------------------------------------===//

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

  class SMXInstCfgIV<bit unsigned, bits<2> funct2, bits<3> funct3, string opcodestr>
      : RVInstR4<funct2, funct3, OPC_CUSTOM_0, (outs),
                 (ins GPR:$rs1, GPR:$rs2, GPR:$rs3, smx_stop_cond_arg:$cond),
                 opcodestr, "$rs1, $rs2, $rs3, $cond"> {
    bits<4> cond;

    let rd{4} = unsigned;
    let rd{3-0} = cond;
  }

  class SMXInstCfgMS<bit prefetch, bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_0, (outs),
                (ins GPR:$rs1, GPR:$rs2, smx_stream_arg:$dep,
                     smx_fact_kind_arg:$kind, smx_width_arg:$width),
                opcodestr, "$rs1, $rs2, $dep, $kind, $width"> {
    bits<3> width;
    bit kind;
    bits<5> dep;

    let imm12{11-10} = 0;
    let imm12{9-7} = width;
    let imm12{6} = prefetch;
    let imm12{5} = kind;
    let imm12{4-0} = dep;
  }

  class SMXInstCfgAddr<bits<3> funct3, string opcodestr>
      : RVInstS<funct3, OPC_CUSTOM_0, (outs),
                (ins GPR:$rs1, smx_stream_arg:$dep1, smx_fact_kind_arg:$kind1,
                     GPR:$rs2, smx_stream_arg:$dep2, smx_fact_kind_arg:$kind2),
                opcodestr, "$rs1, $dep1, $kind1, $rs2, $dep2, $kind2"> {
    bit kind2;
    bits<5> dep2;
    bit kind1;
    bits<5> dep1;

    let imm12{11} = kind2;
    let imm12{10-6} = dep2;
    let imm12{5} = kind1;
    let imm12{4-0} = dep1;
  }

  class SMXInstHint<bits<7> funct7, bits<3> funct3, string opcodestr>
      : RVInstR<funct7, funct3, OPC_CUSTOM_0, (outs), (ins), opcodestr, ""> {
    let rs2 = 0;
    let rs1 = 0;
    let rd = 0;
  }

  class SMXInstStep<bits<3> funct3, string opcodestr>
      : RVInstI<funct3, OPC_CUSTOM_1,
                (outs GPR:$rd), (ins smx_stream_arg:$rs1, simm12:$imm12),
                opcodestr, "$rd, $rs1, $imm12">;

  class SMXInstBranch<bits<3> funct3, string opcodestr>
      : RVInst<(outs GPR:$rd), (ins smx_stream_arg:$stream, simm13_lsb0:$imm12),
               opcodestr, "$rd, $stream, $imm12", [], InstFormatSMXB> {
    bits<12> imm12;
    bits<5> stream;
    bits<5> rd;

    let Inst{31-20} = imm12;
    let Inst{19-15} = stream;
    let Inst{14-12} = funct3;
    let Inst{11-7} = rd;
    let Opcode = OPC_CUSTOM_1.Value;
  }

} // hasSideEffects = 1, mayLoad = 0, mayStore = 0

let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class SMXInstLoad<RegisterClass rd, bits<2> width, bit unsigned,
                  bits<3> funct3, string opcodestr>
    : RVInstI<funct3, OPC_CUSTOM_0,
              (outs rd:$rd), (ins smx_stream_arg:$rs1, smx_sel_arg:$selector),
              opcodestr, "$rd, $rs1, $selector"> {
  bits<7> selector;

  let imm12 = {selector, 0b00, unsigned, width};
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class SMXInstStore<RegisterClass rs2, bits<2> width,
                   bits<3> funct3, string opcodestr>
    : RVInstS<funct3, OPC_CUSTOM_0, (outs),
              (ins smx_stream_arg:$rs1, rs2:$rs2, smx_sel_arg:$selector),
              opcodestr, "$rs1, $rs2, $selector"> {
  bits<7> selector;

  let imm12 = {selector, 0b000, width};
}

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasExtXsmx] in {
  def SMX_CFG_IV_B  : SMXInstCfgIV   <     0, 0b00, 0b000, "smx.cfg.iv.b">, Sched<[]>;
  def SMX_CFG_IV_BU : SMXInstCfgIV   <     1, 0b00, 0b000, "smx.cfg.iv.bu">, Sched<[]>;
  def SMX_CFG_IV_H  : SMXInstCfgIV   <     0, 0b01, 0b000, "smx.cfg.iv.h">, Sched<[]>;
  def SMX_CFG_IV_HU : SMXInstCfgIV   <     1, 0b01, 0b000, "smx.cfg.iv.hu">, Sched<[]>;
  def SMX_CFG_IV_W  : SMXInstCfgIV   <     0, 0b10, 0b000, "smx.cfg.iv.w">, Sched<[]>;
  def SMX_CFG_MS    : SMXInstCfgMS   <           0, 0b001, "smx.cfg.ms">, Sched<[]>;
  def SMX_CFG_MS_P  : SMXInstCfgMS   <           1, 0b001, "smx.cfg.ms.p">, Sched<[]>;
  def SMX_CFG_ADDR  : SMXInstCfgAddr <              0b010, "smx.cfg.addr">, Sched<[]>;
  def SMX_READY     : SMXInstHint    <   0b0000001, 0b011, "smx.ready">, Sched<[]>;
  def SMX_END       : SMXInstHint    <   0b0000010, 0b011, "smx.end">, Sched<[]>;
  def SMX_LB        : SMXInstLoad    <GPR, 0b00, 0, 0b100, "smx.lb">, Sched<[]>;
  def SMX_LBU       : SMXInstLoad    <GPR, 0b00, 1, 0b100, "smx.lbu">, Sched<[]>;
  def SMX_LH        : SMXInstLoad    <GPR, 0b01, 0, 0b100, "smx.lh">, Sched<[]>;
  def SMX_LHU       : SMXInstLoad    <GPR, 0b01, 1, 0b100, "smx.lhu">, Sched<[]>;
  def SMX_LW        : SMXInstLoad    <GPR, 0b10, 0, 0b100, "smx.lw">, Sched<[]>;
  def SMX_SB        : SMXInstStore   <GPR, 0b00,    0b101, "smx.sb">, Sched<[]>;
  def SMX_SH        : SMXInstStore   <GPR, 0b01,    0b101, "smx.sh">, Sched<[]>;
  def SMX_SW        : SMXInstStore   <GPR, 0b10,    0b101, "smx.sw">, Sched<[]>;
  def SMX_STEP      : SMXInstStep    <              0b000, "smx.step">, Sched<[]>;
  def SMX_STEP_BL   : SMXInstBranch  <              0b001, "smx.step.bl">, Sched<[]>;
  def SMX_STEP_J    : SMXInstBranch  <              0b010, "smx.step.j">, Sched<[]>;
  def SMX_BNL       : SMXInstBranch  <              0b011, "smx.bnl">, Sched<[]>;
} // Predicates = [HasExtXsmx]

let Predicates = [HasExtXsmx, IsRV64] in {
  def SMX_CFG_IV_WU : SMXInstCfgIV <     1, 0b10, 0b000, "smx.cfg.iv.wu">, Sched<[]>;
  def SMX_CFG_IV_D  : SMXInstCfgIV <     0, 0b11, 0b000, "smx.cfg.iv.d">, Sched<[]>;
  def SMX_LWU       : SMXInstLoad  <GPR, 0b10, 1, 0b100, "smx.lwu">, Sched<[]>;
  def SMX_LD        : SMXInstLoad  <GPR, 0b11, 0, 0b100, "smx.ld">, Sched<[]>;
  def SMX_SD        : SMXInstStore <GPR, 0b11,    0b101, "smx.sd">, Sched<[]>;
} // Predicates = [HasExtXsmx, IsRV64]

let Predicates = [HasExtXsmx, HasStdExtF] in {
  def SMX_FLW : SMXInstLoad  <FPR32, 0b10, 0, 0b110, "smx.flw">, Sched<[]>;
  def SMX_FSW : SMXInstStore <FPR32, 0b10,    0b111, "smx.fsw">, Sched<[]>;
} // Predicates = [HasExtXsmx, HasStdExtF]

let Predicates = [HasExtXsmx, HasStdExtD] in {
  def SMX_FLD : SMXInstLoad  <FPR64, 0b11, 0, 0b110, "smx.fld">, Sched<[]>;
  def SMX_FSD : SMXInstStore <FPR64, 0b11,    0b111, "smx.fsd">, Sched<[]>;
} // Predicates = [HasExtXsmx, HasStdExtD]

//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//

def smx_load : PatFrag<(ops node:$stream, node:$sel),
                       (int_riscv_smx_load node:$stream, node:$sel)>;
def smx_store : PatFrag<(ops node:$stream, node:$sel, node:$val),
                        (int_riscv_smx_store node:$stream, node:$sel, node:$val)>;

class SMXLoadPat<PatFrag op, SMXInstLoad inst, ValueType vt = XLenVT>
    : Pat<(vt (op smx_stream_arg:$rs1, smx_sel_arg:$selector)),
          (inst smx_stream_arg:$rs1, smx_sel_arg:$selector)>;

class SMXStorePat<PatFrag op, SMXInstStore inst, RegisterClass reg = GPR,
                  ValueType vt = XLenVT>
    : Pat<(op smx_stream_arg:$rs1, smx_sel_arg:$selector, (vt reg:$rs2)),
          (inst smx_stream_arg:$rs1, reg:$rs2, smx_sel_arg:$selector)>;

let Predicates = [HasExtXsmx] in {

  /// Memory stream configurations

  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, smx_stream_arg:$dep,
                                  smx_fact_kind_arg:$kind, (XLenVT 0),
                                  smx_width_arg:$width),
            (SMX_CFG_MS GPR:$rs1, GPR:$rs2, smx_stream_arg:$dep,
                        smx_fact_kind_arg:$kind, smx_width_arg:$width)>;
  def : Pat<(int_riscv_smx_cfg_ms GPR:$rs1, GPR:$rs2, smx_stream_arg:$dep,
                                  smx_fact_kind_arg:$kind, uimm_xlen,
                                  smx_width_arg:$width),
            (SMX_CFG_MS_P GPR:$rs1, GPR:$rs2, smx_stream_arg:$dep,
                          smx_fact_kind_arg:$kind, smx_width_arg:$width)>;

  /// Address factor configurations

  def : Pat<(int_riscv_smx_cfg_addr GPR:$rs1, smx_stream_arg:$dep1, (XLenVT 0),
                                    GPR:$rs2, smx_stream_arg:$dep2, (XLenVT 0)),
            (SMX_CFG_ADDR GPR:$rs1, smx_stream_arg:$dep1, 0,
                          GPR:$rs2, smx_stream_arg:$dep2, 0)>;
  def : Pat<(int_riscv_smx_cfg_addr GPR:$rs1, smx_stream_arg:$dep1, uimm_xlen,
                                    GPR:$rs2, smx_stream_arg:$dep2, (XLenVT 0)),
            (SMX_CFG_ADDR GPR:$rs1, smx_stream_arg:$dep1, 1,
                          GPR:$rs2, smx_stream_arg:$dep2, 0)>;
  def : Pat<(int_riscv_smx_cfg_addr GPR:$rs1, smx_stream_arg:$dep1, (XLenVT 0),
                                    GPR:$rs2, smx_stream_arg:$dep2, uimm_xlen),
            (SMX_CFG_ADDR GPR:$rs1, smx_stream_arg:$dep1, 0,
                          GPR:$rs2, smx_stream_arg:$dep2, 1)>;
  def : Pat<(int_riscv_smx_cfg_addr GPR:$rs1, smx_stream_arg:$dep1, uimm_xlen,
                                    GPR:$rs2, smx_stream_arg:$dep2, uimm_xlen),
            (SMX_CFG_ADDR GPR:$rs1, smx_stream_arg:$dep1, 1,
                          GPR:$rs2, smx_stream_arg:$dep2, 1)>;

  /// Hint instructions

  def : Pat<(int_riscv_smx_ready), (SMX_READY)>;
  def : Pat<(int_riscv_smx_end), (SMX_END)>;

  /// Loads

  def : SMXLoadPat<smx_extloadi8, SMX_LB>;
  def : SMXLoadPat<smx_sextloadi8, SMX_LB>;
  def : SMXLoadPat<smx_zextloadi8, SMX_LBU>;
  def : SMXLoadPat<smx_extloadi16, SMX_LH>;
  def : SMXLoadPat<smx_sextloadi16, SMX_LH>;
  def : SMXLoadPat<smx_zextloadi16, SMX_LHU>;

  /// Stores

  def : SMXStorePat<smx_truncstorei8, SMX_SB>;
  def : SMXStorePat<smx_truncstorei16, SMX_SH>;

  /// Induction variable stream steps

  def : Pat<(int_riscv_smx_step smx_stream_arg:$rs1),
            (SMX_STEP smx_stream_arg:$rs1, 0)>;
  def : Pat<(add (int_riscv_smx_step smx_stream_arg:$rs1), simm12:$imm12),
            (SMX_STEP smx_stream_arg:$rs1, simm12:$imm12)>;

  /// Branch instructions

  def : Pat<(smx_step_bl smx_stream_arg:$stream, bb:$imm12),
            (SMX_STEP_BL smx_stream_arg:$stream, simm13_lsb0:$imm12)>;
  def : Pat<(smx_step_j smx_stream_arg:$stream, bb:$imm12),
            (SMX_STEP_J smx_stream_arg:$stream, simm13_lsb0:$imm12)>;
  def : Pat<(smx_bnl smx_stream_arg:$stream, bb:$imm12),
            (SMX_BNL smx_stream_arg:$stream, simm13_lsb0:$imm12)>;

} // Predicates = [HasExtXsmx]

let Predicates = [HasExtXsmx, IsRV32] in {

  /// Induction variable stream configurations

  def : Pat<(int_riscv_smx_cfg_iv GPR:$rs1, GPR:$rs2, GPR:$rs3,
                                  smx_stop_cond_arg:$cond),
            (SMX_CFG_IV_W GPR:$rs1, GPR:$rs2, GPR:$rs3, smx_stop_cond_arg:$cond)>;

  /// Loads

  def : SMXLoadPat<smx_load, SMX_LW>;

  /// Stores

  def : SMXStorePat<smx_store, SMX_SW>;

} // Predicates = [HasExtXsmx, IsRV32]

let Predicates = [HasExtXsmx, IsRV64] in {

  /// Induction variable stream configurations

  def : Pat<(int_riscv_smx_cfg_iv GPR:$rs1, GPR:$rs2, GPR:$rs3,
                                  smx_stop_cond_arg:$cond),
            (SMX_CFG_IV_D GPR:$rs1, GPR:$rs2, GPR:$rs3, smx_stop_cond_arg:$cond)>;

  /// Loads

  def : SMXLoadPat<smx_extloadi32, SMX_LW>;
  def : SMXLoadPat<smx_sextloadi32, SMX_LW>;
  def : SMXLoadPat<smx_zextloadi32, SMX_LWU>;
  def : SMXLoadPat<smx_load, SMX_LD>;

  /// Stores

  def : SMXStorePat<smx_truncstorei32, SMX_SW>;
  def : SMXStorePat<smx_store, SMX_SD>;

} // Predicates = [HasExtXsmx, IsRV64]

let Predicates = [HasExtXsmx, HasStdExtF] in {
  def : SMXLoadPat<smx_load, SMX_FLW, f32>;
  def : SMXStorePat<smx_store, SMX_FSW, FPR32, f32>;
} // Predicates = [HasExtXsmx, HasStdExtF]

let Predicates = [HasExtXsmx, HasStdExtD] in {
  def : SMXLoadPat<smx_load, SMX_FLD, f64>;
  def : SMXStorePat<smx_store, SMX_FSD, FPR64, f64>;
} // Predicates = [HasExtXsmx, HasStdExtF]
