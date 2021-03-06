(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

(* 
	Kernel state and kernel monads, imports everything that SEL4.Model needs.
*)

chapter "Kernel State and Monads"

theory KernelStateData_H
imports
  PSpaceStruct_H
  Structures_H
  "../machine/MachineOps"
  ArchStateData_H
begin

subsection "The Kernel State"

type_synonym ready_queue = "machine_word list"
translations
(type) "machine_word list" <= (type) "ready_queue"

text {* We pull a fast one on haskell here ... although Haskell expects
a KernelMonad which is a StateT monad in KernelData that wraps a MachineMonad,
we push the extra MachineMonad data into the KernelState. Fortunately the
update and accessor functions all still work. *}

record kernel_state =
  ksPSpace             :: pspace
  gsUserPages          :: "machine_word \<Rightarrow> vmpage_size option"
  gsCNodes             :: "machine_word \<Rightarrow> nat option"
  gsMaxObjectSize      :: nat
  ksDomScheduleIdx     :: nat
  ksDomSchedule        :: "(domain \<times> machine_word) list"
  ksCurDomain          :: domain
  ksDomainTime         :: machine_word
  ksReadyQueues        :: "domain \<times> priority \<Rightarrow> ready_queue"
  ksCurThread          :: machine_word
  ksIdleThread         :: machine_word
  ksSchedulerAction    :: scheduler_action
  ksInterruptState     :: interrupt_state
  ksWorkUnitsCompleted :: machine_word
  ksArchState          :: ArchStateData_H.kernel_state
  ksMachineState       :: machine_state

type_synonym 'a kernel = "(kernel_state, 'a) nondet_monad"

translations
  (type) "'c kernel" <= (type) "(kernel_state, 'c) nondet_monad"

subsection "Kernel Functions"

subsubsection "Initial Kernel State"

definition
  doMachineOp :: "(machine_state, 'a) nondet_monad  \<Rightarrow> 'a kernel"
where
 "doMachineOp mop \<equiv> do
    ms \<leftarrow> gets ksMachineState;
    (r, ms') \<leftarrow> select_f (mop ms);
    modify (\<lambda>ks. ks \<lparr> ksMachineState := ms' \<rparr>);
    return r
  od"

#INCLUDE_HASKELL SEL4/Model/StateData.lhs NOT doMachineOp KernelState ReadyQueue Kernel assert stateAssert findM funArray newKernelState capHasProperty
#INCLUDE_HASKELL SEL4/Model/StateData.lhs decls_only ONLY capHasProperty

end
