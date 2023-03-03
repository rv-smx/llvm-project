//===-- RISCVFinalizeSMXBranch.cpp - Expand atomic pseudo instrs. ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a pass that finalises SMX branch pseudo instructions into
// target instructions. This pass should be run after the register allocation.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"

#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

using namespace llvm;

#define RISCV_FINALIZE_SMX_BRANCH_NAME                                         \
  "RISCV SMX branch instruction finalization pass"

namespace {

class RISCVFinalizeSMXBranch : public MachineFunctionPass {
public:
  static char ID;

  RISCVFinalizeSMXBranch() : MachineFunctionPass(ID) {
    initializeRISCVFinalizeSMXBranchPass(*PassRegistry::getPassRegistry());
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override {
    return RISCV_FINALIZE_SMX_BRANCH_NAME;
  }

private:
  bool finalizeMBB(MachineBasicBlock &MBB);
  void fuseRead(MachineBasicBlock &MBB, MachineInstr &Read, MachineInstr &Br);
  void fuseStep(MachineBasicBlock &MBB, MachineInstr &Step, MachineInstr &Br);
  void replaceBranch(MachineBasicBlock &MBB, MachineInstr &Br);

  const RISCVInstrInfo *TII;
};

char RISCVFinalizeSMXBranch::ID = 0;

bool RISCVFinalizeSMXBranch::runOnMachineFunction(MachineFunction &MF) {
  TII = static_cast<const RISCVInstrInfo *>(MF.getSubtarget().getInstrInfo());
  bool Modified = false;
  for (auto &MBB : MF)
    Modified |= finalizeMBB(MBB);
  return Modified;
}

bool RISCVFinalizeSMXBranch::finalizeMBB(MachineBasicBlock &MBB) {
  // Scan for all pseudo branches.
  MachineInstr *FusedOp = nullptr, *FusedBr = nullptr, *Br = nullptr;
  for (auto &MI : MBB) {
    switch (MI.getOpcode()) {
    case RISCV::SMX_FUSE_READ:
    case RISCV::SMX_FUSE_STEP:
      assert(!FusedOp && "There can be only one fused SMX op in an MBB");
      FusedOp = &MI;
      break;
    case RISCV::SMX_FUSE_BL:
    case RISCV::SMX_FUSE_BNL:
    case RISCV::SMX_FUSE_J:
      assert(!FusedBr && !Br && "There can be only one SMX branch in an MBB");
      FusedBr = &MI;
      break;
    case RISCV::SMX_STEP_ZBL:
    case RISCV::SMX_STEP_ZBNL:
    case RISCV::SMX_STEP_ZJ:
    case RISCV::SMX_ZBL:
    case RISCV::SMX_ZBNL:
      assert(!FusedBr && !Br && "There can be only one SMX branch in an MBB");
      Br = &MI;
      break;
    default:;
    }
  }

  // Quit if nothing found.
  if (!FusedOp && !FusedBr && !Br)
    return false;

  // Sanity check.
  assert(((FusedOp && FusedBr) || (!FusedOp && !FusedBr)) &&
         "Fused SMX op and branch are not a pair");
  assert((!FusedOp ||
          (FusedOp->getOpcode() == RISCV::SMX_FUSE_READ &&
           (FusedBr->getOpcode() == RISCV::SMX_FUSE_BL ||
            FusedBr->getOpcode() == RISCV::SMX_FUSE_BNL)) ||
          (FusedOp->getOpcode() == RISCV::SMX_FUSE_STEP &&
           (FusedBr->getOpcode() == RISCV::SMX_FUSE_BL ||
            FusedBr->getOpcode() == RISCV::SMX_FUSE_BNL ||
            FusedBr->getOpcode() == RISCV::SMX_FUSE_J))) &&
         "Fused SMX op can not be paired with the fused branch");
  assert(
      (!FusedOp ||
       FusedOp->getOperand(1).getImm() == FusedBr->getOperand(0).getImm()) &&
      "The stream ID of a fused SMX op is different from the fused branch's");

  // Fuse or replace.
  if (FusedOp) {
    if (FusedOp->getOpcode() == RISCV::SMX_FUSE_READ)
      fuseRead(MBB, *FusedOp, *FusedBr);
    else
      fuseStep(MBB, *FusedOp, *FusedBr);
  } else {
    replaceBranch(MBB, *Br);
  }
  return true;
}

void RISCVFinalizeSMXBranch::fuseRead(MachineBasicBlock &MBB,
                                      MachineInstr &Read, MachineInstr &Br) {
  // Get debug location and operands.
  auto DL = Br.getDebugLoc();
  auto Dest = Read.getOperand(0).getReg();
  auto Stream = Read.getOperand(1);
  auto Target = Br.getOperand(1);

  // Determine opcode.
  unsigned Opcode;
  if (Br.getOpcode() == RISCV::SMX_FUSE_BL) {
    Opcode = RISCV::SMX_BL;
  } else {
    Opcode = RISCV::SMX_BNL;
  }

  // Insert SMX branch.
  BuildMI(MBB, Br, DL, TII->get(Opcode), Dest).add(Stream).add(Target);

  // Remove pseudo instructions.
  Read.eraseFromParent();
  Br.eraseFromParent();
}

void RISCVFinalizeSMXBranch::fuseStep(MachineBasicBlock &MBB,
                                      MachineInstr &Step, MachineInstr &Br) {
  // Get debug location and operands.
  auto DL = Br.getDebugLoc();
  auto Dest = Step.getOperand(0).getReg();
  auto Stream = Step.getOperand(1);
  auto Target = Br.getOperand(1);

  // Determine opcode.
  unsigned Opcode;
  if (Br.getOpcode() == RISCV::SMX_FUSE_BL) {
    Opcode = RISCV::SMX_STEP_BL;
  } else if (Br.getOpcode() == RISCV::SMX_FUSE_BNL) {
    Opcode = RISCV::SMX_STEP_BNL;
  } else {
    Opcode = RISCV::SMX_STEP_J;
  }

  // Insert SMX branch.
  BuildMI(MBB, Br, DL, TII->get(Opcode), Dest).add(Stream).add(Target);

  // Remove pseudo instructions.
  Step.eraseFromParent();
  Br.eraseFromParent();
}

void RISCVFinalizeSMXBranch::replaceBranch(MachineBasicBlock &MBB,
                                           MachineInstr &Br) {
  // Get debug location and operands.
  auto DL = Br.getDebugLoc();
  auto Stream = Br.getOperand(0);
  auto Target = Br.getOperand(1);

  // Determine opcode.
  unsigned Opcode;
  switch (Br.getOpcode()) {
  default:
    llvm_unreachable("Invalid SMX branch opcode");
  case RISCV::SMX_STEP_ZBL:
    Opcode = RISCV::SMX_STEP_BL;
    break;
  case RISCV::SMX_STEP_ZBNL:
    Opcode = RISCV::SMX_STEP_BNL;
    break;
  case RISCV::SMX_STEP_ZJ:
    Opcode = RISCV::SMX_STEP_J;
    break;
  case RISCV::SMX_ZBL:
    Opcode = RISCV::SMX_BL;
    break;
  case RISCV::SMX_ZBNL:
    Opcode = RISCV::SMX_BNL;
    break;
  }

  // Insert SMX branch.
  BuildMI(MBB, Br, DL, TII->get(Opcode), RISCV::X0).add(Stream).add(Target);

  // Remove pseudo instructions.
  Br.eraseFromParent();
}

} // end of anonymous namespace

INITIALIZE_PASS(RISCVFinalizeSMXBranch, "riscv-finalize-smx-branch",
                RISCV_FINALIZE_SMX_BRANCH_NAME, false, false)

namespace llvm {

FunctionPass *createRISCVFinalizeSMXBranchPass() {
  return new RISCVFinalizeSMXBranch();
}

} // end of namespace llvm
