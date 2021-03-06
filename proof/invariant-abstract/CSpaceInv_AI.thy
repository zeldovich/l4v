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
CSpace invariants
*)

theory CSpaceInv_AI
imports ArchAcc_AI
begin

lemma remove_rights_cap_valid[simp]:
  "s \<turnstile> c \<Longrightarrow> s \<turnstile> remove_rights S c"
  using valid_validate_vm_rights[simplified valid_vm_rights_def]
  by (cases c, simp_all add: remove_rights_def cap_rights_update_def
                   valid_cap_def cap_aligned_def acap_rights_update_def
                 split: arch_cap.splits)


lemma get_thread_state_inv [simp]:
  "\<lbrace> P \<rbrace> get_thread_state t \<lbrace> \<lambda>r. P \<rbrace>"
  apply (simp add: get_thread_state_def thread_get_def gets_the_def)
  apply wp
  apply simp
  done


lemma assert_get_tcb_sp:
  assumes "\<And>s. Q s \<Longrightarrow> valid_objs s"
  shows "\<lbrace> Q \<rbrace> gets_the (get_tcb thread) 
         \<lbrace>\<lambda>t. Q and ko_at (TCB t) thread and valid_tcb thread t \<rbrace>"
  apply wp
  apply (clarsimp dest!: assms)
  apply (clarsimp dest!: get_tcb_SomeD simp: obj_at_def)
  apply (erule(1) valid_objsE)
  apply (simp add: valid_obj_def)
  done


crunch inv[wp]: get_cap "P"
  (simp: crunch_simps)


declare resolve_address_bits'.simps [simp del]


lemma rab_inv[wp]:
  "\<lbrace>P\<rbrace> resolve_address_bits slot \<lbrace>\<lambda>rv. P\<rbrace>"
unfolding resolve_address_bits_def
proof (induct slot rule: resolve_address_bits'.induct) 
  case (1 z cap cref) 
  show ?case
  apply (clarsimp simp add: valid_def)
  apply (subst (asm) resolve_address_bits'.simps)
  apply (cases cap)
            apply (auto simp: in_monad)[5]
       defer
       apply (auto simp: in_monad)[6]
  apply (rename_tac obj_ref nat list)
  apply (simp only: cap.simps)
  apply (case_tac "nat + length list = 0")
   apply (simp add: fail_def)
  apply (simp only: if_False)
  apply (case_tac a)
   apply (simp only: K_bind_def)
   apply (drule in_bindE_L, elim disjE conjE exE)+
       apply (simp only: split: split_if_asm)
        apply (simp add: returnOk_def return_def)
       apply (drule in_bindE_L, elim disjE conjE exE)+
        apply (simp only: split: split_if_asm)
         prefer 2
         apply (clarsimp simp: in_monad)
        apply (drule (8) 1)
        apply (clarsimp simp: in_monad)
        apply (drule in_inv_by_hoareD [OF get_cap_inv])
        apply (auto simp: in_monad valid_def)[1]
       apply (clarsimp simp: in_monad)
      apply (clarsimp simp: in_monad)
     apply (clarsimp simp: in_monad)
    apply (clarsimp simp: in_monad)
   apply (clarsimp simp: in_monad)
  apply (simp only: K_bind_def in_bindE_R)
  apply (elim conjE exE)
  apply (simp only: split: split_if_asm)
   apply (simp add: in_monad split: split_if_asm)
  apply (simp only: K_bind_def in_bindE_R)
  apply (elim conjE exE)
  apply (simp only: split: split_if_asm)
   prefer 2
   apply (clarsimp simp: in_monad)
   apply (drule in_inv_by_hoareD [OF get_cap_inv])
   apply simp
  apply (drule (8) "1")
  apply (clarsimp simp: in_monad valid_def)
  apply (drule in_inv_by_hoareD [OF get_cap_inv])
  apply (auto simp: in_monad)
  done
qed

crunch inv [wp]: lookup_slot_for_thread P


crunch inv [wp]: lookup_cap P


lemma cte_at_tcb_update:
  "tcb_at t s \<Longrightarrow> cte_at slot (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>) = cte_at slot s"
  by (clarsimp simp add: cte_at_cases obj_at_def is_tcb)


lemma valid_cap_tcb_update [simp]:
  "tcb_at t s \<Longrightarrow> (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>) \<turnstile> cap = s \<turnstile> cap"
  apply (clarsimp simp: is_tcb elim!: obj_atE)
  apply (subgoal_tac "a_type (TCB tcba) = a_type (TCB tcb)")
   apply (rule iffI)
    apply (drule(1) valid_cap_same_type[where p=t])
     apply simp
    apply (simp add: fun_upd_idem)
   apply (erule(2) valid_cap_same_type[OF _ sym])
  apply (simp add: a_type_def)
  done


lemma obj_at_tcb_update:
  "\<lbrakk> tcb_at t s; \<And>x y. P (TCB x) = P (TCB y)\<rbrakk> \<Longrightarrow> 
  obj_at P t' (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>) = obj_at P t' s"
  apply (simp add: obj_at_def is_tcb_def)
  apply clarsimp
  apply (case_tac ko)
  apply simp_all
  done


lemma valid_thread_state_tcb_update:
  "\<lbrakk> tcb_at t s \<rbrakk> \<Longrightarrow>
  valid_tcb_state ts (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>) = valid_tcb_state ts s"
  apply (unfold valid_tcb_state_def)
  apply (case_tac ts)
  apply (simp_all add: obj_at_tcb_update is_ep_def is_tcb_def is_aep_def)
  done


lemma valid_objs_tcb_update:
  "\<lbrakk>tcb_at t s; valid_tcb t tcb s; valid_objs s \<rbrakk>
  \<Longrightarrow> valid_objs (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>)"
  apply (clarsimp simp: valid_objs_def dom_def
                 elim!: obj_atE)
  apply (intro conjI impI) 
   apply (rule valid_obj_same_type)
      apply (simp add: valid_obj_def)+
   apply (clarsimp simp: a_type_def is_tcb)
  apply clarsimp
  apply (rule valid_obj_same_type)
     apply (drule_tac x=ptr in spec, simp)
    apply (simp add: valid_obj_def)
   apply assumption
  apply (clarsimp simp add: a_type_def is_tcb)
  done


lemma obj_at_update:
  "obj_at P t' (s \<lparr>kheap := kheap s (t \<mapsto> v)\<rparr>) = 
  (if t = t' then P v else obj_at P t' s)"
  by (simp add: obj_at_def)


lemma iflive_tcb_update:
  "\<lbrakk> if_live_then_nonz_cap s; live (TCB tcb) \<longrightarrow> ex_nonz_cap_to t s;
           obj_at (same_caps (TCB tcb)) t s \<rbrakk>
  \<Longrightarrow> if_live_then_nonz_cap (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>)"
  unfolding fun_upd_def
  apply (simp add: if_live_then_nonz_cap_def, erule allEI)
  apply safe
   apply (clarsimp simp add: obj_at_def elim!: ex_cap_to_after_update
                   split: split_if_asm | (erule notE, erule ex_cap_to_after_update))+
  done


lemma ifunsafe_tcb_update:
  "\<lbrakk> if_unsafe_then_cap s; obj_at (same_caps (TCB tcb)) t s \<rbrakk>
  \<Longrightarrow> if_unsafe_then_cap (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>)"
  apply (simp add: if_unsafe_then_cap_def, elim allEI)
  apply (clarsimp dest!: caps_of_state_cteD
                   simp: cte_wp_at_after_update fun_upd_def)
  apply (clarsimp simp: cte_wp_at_caps_of_state
                        ex_cte_cap_to_after_update)
  done


lemma zombies_tcb_update:
  "\<lbrakk> zombies_final s; obj_at (same_caps (TCB tcb)) t s \<rbrakk>
   \<Longrightarrow> zombies_final (s\<lparr>kheap := kheap s(t \<mapsto> TCB tcb)\<rparr>)"
  apply (simp add: zombies_final_def is_final_cap'_def2, elim allEI)
  apply (clarsimp simp: cte_wp_at_after_update fun_upd_def)
  done


lemma tcb_state_same_refs:
  "\<lbrakk> ko_at (TCB t) p s; tcb_state t = tcb_state t' \<rbrakk>
     \<Longrightarrow> state_refs_of (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = state_refs_of s"
  by (clarsimp simp add: state_refs_of_def obj_at_def
                 intro!: ext)


lemma valid_idle_tcb_update:
  "\<lbrakk>valid_idle s; ko_at (TCB t) p s; tcb_state t = tcb_state t';
    valid_tcb p t' s \<rbrakk>
   \<Longrightarrow> valid_idle (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  by (clarsimp simp: valid_idle_def st_tcb_at_def obj_at_def)


lemma valid_reply_caps_tcb_update:
  "\<lbrakk>valid_reply_caps s; ko_at (TCB t) p s; tcb_state t = tcb_state t';
    same_caps (TCB t) (TCB t') \<rbrakk>
   \<Longrightarrow> valid_reply_caps (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  apply (frule_tac P'="same_caps (TCB t')" in obj_at_weakenE, simp)
  apply (fastforce simp: valid_reply_caps_def has_reply_cap_def
                        st_tcb_at_def obj_at_def fun_upd_def
                        cte_wp_at_after_update caps_of_state_after_update)
  done


lemma valid_reply_masters_tcb_update:
  "\<lbrakk>valid_reply_masters s; ko_at (TCB t) p s; tcb_state t = tcb_state t';
    same_caps (TCB t) (TCB t') \<rbrakk>
   \<Longrightarrow> valid_reply_masters (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  by (clarsimp simp: valid_reply_masters_def fun_upd_def is_tcb 
                     cte_wp_at_after_update obj_at_def)


lemma valid_arch_obj_tcb_update':
  "\<lbrakk> valid_arch_obj obj s; kheap s p = Some (TCB t) \<rbrakk>
   \<Longrightarrow> valid_arch_obj obj (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  apply (cases obj)
     apply (fastforce elim: typ_at_same_type [rotated -1])
    apply clarsimp
    apply (rename_tac "fun" x)
    apply (erule_tac x=x in allE)
    apply (case_tac "fun x", (clarsimp simp: obj_at_def)+)[1]
   apply clarsimp
   apply (rename_tac "fun" x)
   apply (erule_tac x=x in ballE)
   apply (case_tac "fun x", (clarsimp simp: obj_at_def)+)[1]
   apply (fastforce elim: typ_at_same_type [rotated -1])
  apply simp
  done


lemma valid_arch_obj_tcb_update:
  "kheap s p = Some (TCB t)
   \<Longrightarrow> valid_arch_obj obj (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = valid_arch_obj obj s"
  apply (rule iffI)
   apply (drule valid_arch_obj_tcb_update'[where p=p and t'=t], simp)
   apply (simp add: fun_upd_idem)
  apply (erule(1) valid_arch_obj_tcb_update')
  done


lemma valid_arch_objs_tcb_update:
  "\<lbrakk> valid_arch_objs s; kheap s p = Some (TCB t)\<rbrakk>
    \<Longrightarrow> valid_arch_objs (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  apply (erule valid_arch_objs_stateI)
    apply (clarsimp simp: obj_at_def vs_refs_def split: split_if_asm)
   apply simp
  apply (clarsimp simp: obj_at_def valid_arch_obj_tcb_update split: split_if_asm)
  done


lemma vs_lookup1_tcb_update:
  "kheap s p = Some (TCB t)
      \<Longrightarrow> vs_lookup1 (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = vs_lookup1 s"
  by (clarsimp simp add: vs_lookup1_def obj_at_def vs_refs_def intro!: set_eqI)


lemma vs_lookup_tcb_update:
  "kheap s p = Some (TCB t)
      \<Longrightarrow> vs_lookup (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = vs_lookup s"
  by (clarsimp simp add: vs_lookup_def vs_lookup1_tcb_update)


lemma only_idle_tcb_update:
  "\<lbrakk>only_idle s; ko_at (TCB t) p s; tcb_state t = tcb_state t' \<or> \<not>idle (tcb_state t') \<rbrakk>
    \<Longrightarrow> only_idle (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  by (clarsimp simp: only_idle_def st_tcb_at_def obj_at_def)


lemma tcb_update_global_pd_mappings:
  "\<lbrakk> valid_global_pd_mappings s; ko_at (TCB t) p s \<rbrakk>
       \<Longrightarrow> valid_global_pd_mappings (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)"
  apply (erule valid_global_pd_mappings_pres)
     apply (clarsimp simp: obj_at_def)+
  done


lemma tcb_state_same_cte_wp_at:
  "\<lbrakk> ko_at (TCB t) p s; \<forall>(getF, v) \<in> ran tcb_cap_cases. getF t = getF t' \<rbrakk>
     \<Longrightarrow> \<forall>P p'. cte_wp_at P p' (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>)
             = cte_wp_at P p' s"
  apply (clarsimp simp add: cte_wp_at_cases obj_at_def)
  apply (case_tac "tcb_cap_cases b")
   apply simp
  apply (drule bspec, erule ranI)
  apply clarsimp
  done


lemma valid_tcb_state_update:
  "\<lbrakk> valid_tcb p t s; valid_tcb_state st s;
     case st of 
                Structures_A.Inactive \<Rightarrow> True
              | Structures_A.BlockedOnReceive e d \<Rightarrow>
                     tcb_caller t = cap.NullCap
                   \<and> is_master_reply_cap (tcb_reply t)
                   \<and> obj_ref_of (tcb_reply t) = p
              | _ \<Rightarrow> is_master_reply_cap (tcb_reply t)
                   \<and> obj_ref_of (tcb_reply t) = p  \<rbrakk> \<Longrightarrow>
   valid_tcb p (t\<lparr>tcb_state := st\<rparr>) s"
  by (simp add: valid_tcb_def valid_tcb_state_def ran_tcb_cap_cases
         split: Structures_A.thread_state.splits)


lemma valid_tcb_if_valid_state:
  assumes vs: "valid_state s"
  assumes somet: "get_tcb thread s = Some y"
  shows "valid_tcb thread y s"
proof -
  from somet have inran: "kheap s thread = Some (TCB y)"
    by (clarsimp simp: get_tcb_def
                split: option.splits Structures_A.kernel_object.splits)
  from vs have "(\<forall>ptr\<in>dom (kheap s). \<exists>obj. kheap s ptr = Some obj \<and> valid_obj ptr obj s)"
    by (simp add: valid_state_def valid_pspace_def valid_objs_def)
  with inran have "valid_obj thread (TCB y) s" by (fastforce simp: dom_def)
  thus ?thesis by (simp add: valid_tcb_def valid_obj_def)
qed


lemma assert_get_tcb_ko:
  shows "\<lbrace> P \<rbrace> gets_the (get_tcb thread) \<lbrace>\<lambda>t. ko_at (TCB t) thread \<rbrace>"
  by (clarsimp simp: valid_def in_monad gets_the_def get_tcb_def 
                     obj_at_def
               split: option.splits Structures_A.kernel_object.splits)


lemma gts_st_tcb_at: "\<lbrace>st_tcb_at P t\<rbrace> get_thread_state t \<lbrace>\<lambda>rv s. P rv\<rbrace>"
  apply (simp add: get_thread_state_def thread_get_def)
  apply wp
  apply (clarsimp simp: st_tcb_at_def obj_at_def get_tcb_def is_tcb)
  done


lemma gts_st_tcb:
  "\<lbrace>\<top>\<rbrace> get_thread_state t \<lbrace>\<lambda>rv. st_tcb_at (\<lambda>st. rv = st) t\<rbrace>"
  apply (simp add: get_thread_state_def thread_get_def)
  apply wp
  apply (clarsimp simp: st_tcb_at_def)
  done


lemma allActiveTCBs_valid_state:
  "\<lbrace>valid_state\<rbrace> allActiveTCBs \<lbrace>\<lambda>R s. valid_state s \<and> (\<forall>t \<in> R. st_tcb_at runnable t s) \<rbrace>"
  apply (simp add: allActiveTCBs_def, wp)
  apply (simp add: getActiveTCB_def st_tcb_at_def obj_at_def get_tcb_def
              split: option.splits split_if_asm Structures_A.kernel_object.splits)
  done


definition
  cap_master_cap :: "cap \<Rightarrow> cap"
where
 "cap_master_cap cap \<equiv> case cap of
   cap.EndpointCap ref bdg rghts \<Rightarrow> cap.EndpointCap ref 0 UNIV
 | cap.AsyncEndpointCap ref bdg rghts \<Rightarrow> cap.AsyncEndpointCap ref 0 UNIV
 | cap.CNodeCap ref bits gd \<Rightarrow> cap.CNodeCap ref bits []
 | cap.ThreadCap ref \<Rightarrow> cap.ThreadCap ref
 | cap.DomainCap \<Rightarrow> cap.DomainCap
 | cap.ReplyCap ref master \<Rightarrow> cap.ReplyCap ref True
 | cap.UntypedCap ref n f \<Rightarrow> cap.UntypedCap ref n 0
 | cap.ArchObjectCap acap \<Rightarrow> cap.ArchObjectCap (case acap of
      arch_cap.PageCap ref rghts sz mapdata \<Rightarrow>
         arch_cap.PageCap ref UNIV sz None
    | arch_cap.ASIDPoolCap pool asid \<Rightarrow>
         arch_cap.ASIDPoolCap pool 0
    | arch_cap.PageTableCap ptr data \<Rightarrow>
         arch_cap.PageTableCap ptr None
    | arch_cap.PageDirectoryCap ptr data \<Rightarrow>
         arch_cap.PageDirectoryCap ptr None
       | _ \<Rightarrow> acap)
 | _ \<Rightarrow> cap"


lemma cap_master_cap_eqDs1:
  "cap_master_cap cap = cap.EndpointCap ref bdg rghts
     \<Longrightarrow> bdg = 0 \<and> rghts = UNIV
          \<and> (\<exists>bdg rghts. cap = cap.EndpointCap ref bdg rghts)"
  "cap_master_cap cap = cap.AsyncEndpointCap ref bdg rghts
     \<Longrightarrow> bdg = 0 \<and> rghts = UNIV
          \<and> (\<exists>bdg rghts. cap = cap.AsyncEndpointCap ref bdg rghts)"
  "cap_master_cap cap = cap.CNodeCap ref bits gd
     \<Longrightarrow> gd = [] \<and> (\<exists>gd. cap = cap.CNodeCap ref bits gd)"
  "cap_master_cap cap = cap.ThreadCap ref
     \<Longrightarrow> cap = cap.ThreadCap ref"
  "cap_master_cap cap = cap.DomainCap
     \<Longrightarrow> cap = cap.DomainCap"
  "cap_master_cap cap = cap.NullCap
     \<Longrightarrow> cap = cap.NullCap"
  "cap_master_cap cap = cap.IRQControlCap
     \<Longrightarrow> cap = cap.IRQControlCap"
  "cap_master_cap cap = cap.IRQHandlerCap irq
     \<Longrightarrow> cap = cap.IRQHandlerCap irq"
  "cap_master_cap cap = cap.Zombie ref tp n
     \<Longrightarrow> cap = cap.Zombie ref tp n"
  "cap_master_cap cap = cap.UntypedCap ref bits 0
     \<Longrightarrow> \<exists>f. cap = cap.UntypedCap ref bits f"
  "cap_master_cap cap = cap.ReplyCap ref master
     \<Longrightarrow> master = True
          \<and> (\<exists>master. cap = cap.ReplyCap ref master)"
  "cap_master_cap cap = cap.ArchObjectCap (arch_cap.PageCap ref rghts sz mapdata)
     \<Longrightarrow> rghts = UNIV \<and> mapdata = None
          \<and> (\<exists>rghts mapdata. cap = cap.ArchObjectCap (arch_cap.PageCap ref rghts sz mapdata))"
  "cap_master_cap cap = cap.ArchObjectCap arch_cap.ASIDControlCap
     \<Longrightarrow> cap = cap.ArchObjectCap arch_cap.ASIDControlCap"
  "cap_master_cap cap = cap.ArchObjectCap (arch_cap.ASIDPoolCap pool asid)
     \<Longrightarrow> asid = 0 \<and> (\<exists>asid. cap = cap.ArchObjectCap (arch_cap.ASIDPoolCap pool asid))"
  "cap_master_cap cap = cap.ArchObjectCap (arch_cap.PageTableCap ptr data)
     \<Longrightarrow> data = None \<and> (\<exists>data. cap = cap.ArchObjectCap (arch_cap.PageTableCap ptr data))"
  "cap_master_cap cap = cap.ArchObjectCap (arch_cap.PageDirectoryCap ptr data2)
     \<Longrightarrow> data2 = None \<and> (\<exists>data2. cap = cap.ArchObjectCap (arch_cap.PageDirectoryCap ptr data2))"
  by (clarsimp simp: cap_master_cap_def
              split: cap.split_asm arch_cap.split_asm)+


lemmas cap_master_cap_eqDs = cap_master_cap_eqDs1 cap_master_cap_eqDs1 [OF sym]


definition
  cap_badge :: "cap \<rightharpoonup> badge"
where
 "cap_badge cap \<equiv> case cap of
    cap.EndpointCap r badge rights \<Rightarrow> Some badge
  | cap.AsyncEndpointCap r badge rights \<Rightarrow> Some badge
  | _ \<Rightarrow> None"

lemma cap_badge_simps [simp]:
 "cap_badge (cap.EndpointCap r badge rights)       = Some badge"
 "cap_badge (cap.AsyncEndpointCap r badge rights)  = Some badge"
 "cap_badge (cap.UntypedCap p n f)                 = None"
 "cap_badge (cap.NullCap)                          = None"
 "cap_badge (cap.DomainCap)                        = None"
 "cap_badge (cap.CNodeCap r bits guard)            = None"
 "cap_badge (cap.ThreadCap r)                      = None"
 "cap_badge (cap.DomainCap)                        = None"
 "cap_badge (cap.ReplyCap r master)                = None"
 "cap_badge (cap.IRQControlCap)                    = None"
 "cap_badge (cap.IRQHandlerCap irq)                = None"
 "cap_badge (cap.Zombie r b n)                     = None"
 "cap_badge (cap.ArchObjectCap cap)                = None"
  by (auto simp: cap_badge_def)

(* FIXME: move to somewhere sensible *)
lemma pageBitsForSize_simps[simp]:
  "pageBitsForSize ARMSmallPage    = 12"
  "pageBitsForSize ARMLargePage    = 16"
  "pageBitsForSize ARMSection      = 20"
  "pageBitsForSize ARMSuperSection = 24"
  by (simp add: pageBitsForSize_def)+


lemma cdt_parent_of_def:
  "m \<turnstile> p cdt_parent_of c \<equiv> m c = Some p"
  by (simp add: cdt_parent_rel_def is_cdt_parent_def)


lemmas cdt_parent_defs = cdt_parent_of_def is_cdt_parent_def cdt_parent_rel_def
 

lemma valid_mdb_no_null:
  "\<lbrakk> valid_mdb s; caps_of_state s p = Some cap.NullCap \<rbrakk> \<Longrightarrow> 
  \<not> cdt s \<Turnstile> p \<rightarrow> p' \<and> \<not> cdt s \<Turnstile> p' \<rightarrow> p"
  apply (simp add: valid_mdb_def mdb_cte_at_def cte_wp_at_caps_of_state)
  apply (cases p, cases p')
  apply (rule conjI)
   apply (fastforce dest!: tranclD simp: cdt_parent_defs)
  apply (fastforce dest!: tranclD2 simp: cdt_parent_defs)
  done


lemma x_sym: "(s = t) = r \<Longrightarrow> (t = s) = r" by auto

lemma set_inter_not_emptyD1: "\<lbrakk>A \<inter> B = {}; A \<noteq> {}; B \<noteq> {}\<rbrakk> \<Longrightarrow> \<not> B \<subseteq> A"
  by blast


lemma set_inter_not_emptyD2: "\<lbrakk>A \<inter> B = {}; A \<noteq> {}; B \<noteq> {}\<rbrakk> \<Longrightarrow> \<not> A \<subseteq> B"
  by blast


lemma set_inter_not_emptyD3: "\<lbrakk>A \<inter> B = {}; A \<noteq> {}; B \<noteq> {}\<rbrakk> \<Longrightarrow> A \<noteq> B"
  by blast


lemma untyped_range_in_cap_range: "untyped_range x \<subseteq> cap_range x"
  by(simp add:cap_range_def)


lemma set_object_cte_wp_at:  
  "\<lbrace>\<lambda>s. cte_wp_at P p (kheap_update (\<lambda>ps. (kheap s)(ptr \<mapsto> ko)) s)\<rbrace>
  set_object ptr ko 
  \<lbrace>\<lambda>uu. cte_wp_at P p\<rbrace>"
  unfolding set_object_def
  apply simp
  apply wp
  done


lemma set_cap_caps_of_state[wp]:
  "\<lbrace>\<lambda>s. P ((caps_of_state s) (ptr \<mapsto> cap))\<rbrace> set_cap cap ptr \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (cases ptr)
  apply (clarsimp simp add: set_cap_def split_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all add: set_object_def
                          split del: split_if cong: if_cong bind_cong)
   apply (rule hoare_pre, wp)
   apply (clarsimp elim!: rsubst[where P=P]
                    simp: caps_of_state_cte_wp_at cte_wp_at_cases
                          fun_upd_def[symmetric] wf_cs_upd obj_at_def
                  intro!: ext)
   apply auto[1]
  apply (rule hoare_pre, wp)
  apply (clarsimp simp: obj_at_def)
  apply (safe elim!: rsubst[where P=P] intro!: ext)
      apply (auto simp: caps_of_state_cte_wp_at cte_wp_at_cases,
             auto simp: tcb_cap_cases_def split: split_if_asm)
  done


lemma set_cap_cte_wp_at: 
  "\<lbrace>(\<lambda>s. if p = ptr then P cap else cte_wp_at P p s) and cte_at ptr\<rbrace> 
  set_cap cap ptr
  \<lbrace>\<lambda>uu s. cte_wp_at P p s\<rbrace>"
  apply (simp add: cte_wp_at_caps_of_state)
  apply (wpx set_cap_caps_of_state)
  apply clarsimp
  done


lemma set_cap_cte_wp_at': 
  "\<lbrace>\<lambda>s. if p = ptr then (P cap \<and> cte_at ptr s) else cte_wp_at P p s\<rbrace> 
  set_cap cap ptr
  \<lbrace>\<lambda>uu s. cte_wp_at P p s\<rbrace>"
  apply (simp add: cte_wp_at_caps_of_state)
  apply (wpx set_cap_caps_of_state)
  apply clarsimp
  done


lemma set_cap_typ_at:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace>
   set_cap cap p'
   \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all)
   prefer 2
   apply (auto simp: valid_def in_monad obj_at_def a_type_def)[1]
  apply (clarsimp simp add: valid_def in_monad obj_at_def a_type_def)
  apply (clarsimp simp: wf_cs_upd)
  done


lemma set_cap_a_type_inv:
  "((), t) \<in> fst (set_cap cap slot s) \<Longrightarrow> typ_at T p t = typ_at T p s"
  apply (subgoal_tac "EX x. typ_at T p s = x")
   apply (elim exE)
   apply (cut_tac P="op= x" in set_cap_typ_at[of _ T p cap slot])
   apply (fastforce simp: valid_def)
  apply fastforce
  done


crunch arch[wp]: set_cap "\<lambda>s. P (arch_state s)" (simp: split_def)


lemma set_cap_arch_state [wp]:
  "\<lbrace>valid_arch_state\<rbrace> set_cap cap p \<lbrace>\<lambda>_. valid_arch_state\<rbrace>"
  by (wp valid_arch_state_lift set_cap_typ_at)


lemma set_cap_tcb:
  "\<lbrace>tcb_at p'\<rbrace> set_cap cap  p \<lbrace>\<lambda>rv. tcb_at p'\<rbrace>"
  by (clarsimp simp: tcb_at_typ intro!: set_cap_typ_at)


lemma set_cap_sets:
  "\<lbrace>\<top>\<rbrace> set_cap cap p \<lbrace>\<lambda>rv s. cte_wp_at (\<lambda>c. c = cap) p s\<rbrace>"
  apply (simp add: cte_wp_at_caps_of_state)
  apply (wpx set_cap_caps_of_state)
  apply clarsimp
  done


lemma set_cap_valid_cap:
  "\<lbrace>valid_cap c\<rbrace> set_cap x p \<lbrace>\<lambda>_. valid_cap c\<rbrace>"
  by (simp add: valid_cap_typ set_cap_typ_at)


lemma set_cap_cte_at:
  "\<lbrace>cte_at p'\<rbrace> set_cap x p \<lbrace>\<lambda>_. cte_at p'\<rbrace>"
  by (simp add: valid_cte_at_typ set_cap_typ_at [where P="\<lambda>x. x"])


lemma set_cap_valid_objs:
  "\<lbrace>valid_objs and valid_cap x
        and tcb_cap_valid x p\<rbrace>
      set_cap x p \<lbrace>\<lambda>_. valid_objs\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all split del: split_if)
   apply clarsimp
   apply (wp set_object_valid_objs)
   apply (clarsimp simp: obj_at_def a_type_def wf_cs_upd)
   apply (erule(1) valid_objsE)
   apply (clarsimp simp: valid_obj_def valid_cs_def
                         valid_cs_size_def wf_cs_upd)
   apply (clarsimp simp: ran_def split: split_if_asm)
   apply blast
  apply (rule hoare_pre, wp set_object_valid_objs)
  apply (clarsimp simp: obj_at_def a_type_def tcb_cap_valid_def
                        is_tcb_def)
  apply (erule(1) valid_objsE)
  apply (clarsimp simp: valid_obj_def valid_tcb_def
                        ran_tcb_cap_cases)
  apply (intro conjI impI, simp_all add: st_tcb_at_def obj_at_def)
  done


lemma set_cap_aligned [wp]:
 "\<lbrace>pspace_aligned\<rbrace>
  set_cap c p
  \<lbrace>\<lambda>rv. pspace_aligned\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (wp set_object_aligned)
  apply (case_tac obj, simp_all split del: split_if)
   apply clarsimp
   apply wp
   apply (clarsimp simp: a_type_def obj_at_def wf_cs_upd
                         fun_upd_def[symmetric])
  apply (rule hoare_pre, wp)
  apply (simp add: obj_at_def a_type_def)
  done


lemma set_cap_refs_of [wp]:
 "\<lbrace>\<lambda>s. P (state_refs_of s)\<rbrace>
  set_cap cp p
  \<lbrace>\<lambda>rv s. P (state_refs_of s)\<rbrace>"
  apply (simp add: set_cap_def set_object_def split_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all split del: split_if)
   apply wp
   apply (rule hoare_pre, wp)
   apply (clarsimp elim!: rsubst[where P=P]
                    simp: state_refs_of_def obj_at_def
                  intro!: ext)
  apply (rule hoare_pre, wp)
  apply (clarsimp simp: state_refs_of_def obj_at_def)
  apply (clarsimp elim!: rsubst[where P=P] intro!: ext | rule conjI)+
  done


lemma set_cap_distinct [wp]:
 "\<lbrace>pspace_distinct\<rbrace> set_cap c p \<lbrace>\<lambda>rv. pspace_distinct\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (wp set_object_distinct)
  apply (case_tac obj, simp_all split del: split_if)
   apply clarsimp
   apply wpx
   apply (clarsimp simp: a_type_def obj_at_def wf_cs_upd
                         fun_upd_def[symmetric])
  apply (rule hoare_pre, wp)
  apply (simp add: obj_at_def a_type_def)
  done


lemma set_cap_cur [wp]:
 "\<lbrace>cur_tcb\<rbrace> set_cap c p \<lbrace>\<lambda>rv. cur_tcb\<rbrace>"
  apply (simp add: set_cap_def set_object_def split_def)
  apply (wp)
   prefer 2
   apply (rule get_object_sp)  
  apply (case_tac obj, simp_all split del: split_if)
   apply clarsimp
   apply wp
   apply (clarsimp simp: cur_tcb_def obj_at_def is_tcb)
  apply (rule hoare_pre, wp)
  apply (clarsimp simp add: cur_tcb_def obj_at_def is_tcb)
  done


lemma set_cap_st_tcb [wp]:
 "\<lbrace>st_tcb_at P t\<rbrace> set_cap c p \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (simp add: set_cap_def set_object_def split_def)
  apply (wp)
   prefer 2
   apply (rule get_object_sp)  
  apply (case_tac obj)
    apply (simp_all del: fun_upd_apply)
   apply (clarsimp simp: st_tcb_at_def obj_at_def|rule conjI|wp)+
  done


lemma set_cap_live[wp]:
  "\<lbrace>\<lambda>s. P (obj_at live p' s)\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. P (obj_at live p' s)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all split del: split_if)
   apply (rule hoare_pre, wp)
   apply (clarsimp simp: obj_at_def)
  apply (rule hoare_pre, wp)
  apply (clarsimp simp: obj_at_def)
  done


lemma set_cap_cap_to:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap'. p'\<notin>(zobj_refs cap' - zobj_refs cap)) p s
         \<and> ex_nonz_cap_to p' s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. ex_nonz_cap_to p'\<rbrace>"
  apply (simp add: ex_nonz_cap_to_def cte_wp_at_caps_of_state)
  apply wp
  apply simp
  apply (elim conjE exE)
  apply (case_tac "(a, b) = p")
   apply fastforce
  apply fastforce
  done


crunch irq_node[wp]: set_cap "\<lambda>s. P (interrupt_irq_node s)"
  (simp: crunch_simps)


lemma set_cap_cte_cap_wp_to:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap'. p' \<in> cte_refs cap' (interrupt_irq_node s) \<and> P cap'
                           \<longrightarrow> p' \<in> cte_refs cap (interrupt_irq_node s) \<and> P cap) p s
        \<and> ex_cte_cap_wp_to P p' s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P p'\<rbrace>"
  apply (simp add: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply wpx
  apply (intro impI, elim conjE exE)
  apply (case_tac "(a, b) = p")
   apply fastforce
  apply fastforce
  done


lemma set_cap_iflive:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap'. \<forall>p'\<in>(zobj_refs cap' - zobj_refs cap). obj_at (Not \<circ> live) p' s) p s
        \<and> if_live_then_nonz_cap s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv s. if_live_then_nonz_cap s\<rbrace>"
  apply (simp add: if_live_then_nonz_cap_def)
  apply (simp only: imp_conv_disj)
  apply (rule hoare_pre, wp hoare_vcg_all_lift hoare_vcg_disj_lift set_cap_cap_to)
  apply (clarsimp simp: cte_wp_at_def)
  apply (rule ccontr)
  apply (drule bspec)
   apply simp
  apply (clarsimp simp: obj_at_def)
  done


lemma update_cap_iflive:
  "\<lbrace>cte_wp_at (\<lambda>cap'. zobj_refs cap' = zobj_refs cap) p
      and if_live_then_nonz_cap\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. if_live_then_nonz_cap s\<rbrace>"
  apply (wpx set_cap_iflive)
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done


lemma set_cap_ifunsafe:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap'. \<forall>p'. p' \<in> cte_refs cap' (interrupt_irq_node s)
                            \<and> (p' \<notin> cte_refs cap (interrupt_irq_node s)
                                   \<or> (\<exists>cp. appropriate_cte_cap cp cap'
                                            \<and> \<not> appropriate_cte_cap cp cap))
                            \<longrightarrow>
                             (p' \<noteq> p \<longrightarrow> cte_wp_at (op = cap.NullCap) p' s)
                           \<and> (p' = p \<longrightarrow> cap = cap.NullCap)) p s
        \<and> if_unsafe_then_cap s
        \<and> (cap \<noteq> cap.NullCap \<longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s)\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. if_unsafe_then_cap s\<rbrace>"
  apply (simp add: if_unsafe_then_cap_def)
  apply (wpx set_cap_cte_cap_wp_to)
  apply clarsimp
  apply (rule conjI)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (rule ccontr, clarsimp)
   apply (drule spec, drule spec, drule(1) mp [OF _ conjI])
    apply auto[2]
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (fastforce simp: Ball_def)
  done


lemma update_cap_ifunsafe:
  "\<lbrace>cte_wp_at (\<lambda>cap'. cte_refs cap' = cte_refs cap
                      \<and> (\<forall>cp. appropriate_cte_cap cp cap'
                                 = appropriate_cte_cap cp cap)) p
      and if_unsafe_then_cap
      and (\<lambda>s. cap \<noteq> cap.NullCap \<longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s)\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. if_unsafe_then_cap s\<rbrace>"
  apply (wpx set_cap_ifunsafe)
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done


crunch it[wp]: set_cap "\<lambda>s. P (idle_thread s)"
  (wp: crunch_wps simp: crunch_simps) 


lemma set_cap_refs [wp]:
  "\<lbrace>\<lambda>x. P (global_refs x)\<rbrace> set_cap cap p \<lbrace>\<lambda>_ x. P (global_refs x)\<rbrace>"
  apply (simp add: global_refs_def)
  apply wpx
  done


lemma set_cap_globals [wp]:
  "\<lbrace>valid_global_refs and (\<lambda>s. global_refs s \<inter> cap_range cap = {})\<rbrace>
  set_cap cap p 
  \<lbrace>\<lambda>_. valid_global_refs\<rbrace>"
  apply (simp add: valid_global_refs_def valid_refs_def2)
  apply (wpx set_cap_caps_of_state)
  apply (clarsimp simp: ran_def)
  apply blast
  done


lemma set_cap_pspace:
  assumes x: "\<And>s f'. f (kheap_update f' s) = f s"
  shows      "\<lbrace>\<lambda>s. P (f s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. P (f s)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all split del: split_if cong: if_cong)
   apply (rule hoare_pre, wp)
   apply (simp add: x)
  apply (rule hoare_pre, wp)
  apply (simp add: x)
  done


lemma set_cap_rvk_cdt_ct_ms[wp]:
  "\<lbrace>\<lambda>s. P (is_original_cap s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. P (is_original_cap s)\<rbrace>"
  "\<lbrace>\<lambda>s. Q (cur_thread s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. Q (cur_thread s)\<rbrace>"
  "\<lbrace>\<lambda>s. R (machine_state s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. R (machine_state s)\<rbrace>"
  "\<lbrace>\<lambda>s. S (cdt s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. S (cdt s)\<rbrace>"
  "\<lbrace>\<lambda>s. T (idle_thread s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. T (idle_thread s)\<rbrace>"
  "\<lbrace>\<lambda>s. U (arch_state s)\<rbrace> set_cap p cap \<lbrace>\<lambda>rv s. U (arch_state s)\<rbrace>"
  by (rule set_cap_pspace | simp)+


lemma obvious:
  "\<lbrakk> S = {a}; x \<noteq> y; x \<in> S; y \<in> S \<rbrakk> \<Longrightarrow> P"
  by blast


lemma obvious2:
  "\<lbrakk> x \<in> S; \<And>y. y \<noteq> x \<Longrightarrow> y \<notin> S \<rbrakk> \<Longrightarrow> \<exists>x. S = {x}"
  by blast


lemma is_final_cap'_def3:
  "is_final_cap' cap = (\<lambda>s. \<exists>cref. cte_wp_at (\<lambda>c. obj_irq_refs cap \<inter> obj_irq_refs c \<noteq> {}) cref s
                                \<and> (\<forall>cref'. (cte_at cref' s \<and> cref' \<noteq> cref)
                                      \<longrightarrow> cte_wp_at (\<lambda>c. obj_irq_refs cap \<inter> obj_irq_refs c = {}) cref' s))"
  apply (clarsimp simp: is_final_cap'_def2
                intro!: ext arg_cong[where f=Ex])
  apply (subst iff_conv_conj_imp)
  apply (clarsimp simp: all_conj_distrib conj_comms)
  apply (rule rev_conj_cong[OF _ refl])
  apply (rule arg_cong[where f=All] ext)+
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply fastforce
  done


lemma final_cap_at_eq:
  "cte_wp_at (\<lambda>c. is_final_cap' c s) p s =
    (\<exists>cp. cte_wp_at (\<lambda>c. c = cp) p s \<and> (obj_irq_refs cp \<noteq> {})
       \<and> (\<forall>p'. (cte_at p' s \<and> p' \<noteq> p) \<longrightarrow>
                   cte_wp_at (\<lambda>c. obj_irq_refs cp \<inter> obj_irq_refs c = {}) p' s))"
  apply (clarsimp simp: is_final_cap'_def3 cte_wp_at_caps_of_state
                  simp del: split_paired_Ex split_paired_All)
  apply (rule iffI)
   apply (clarsimp simp del: split_paired_Ex split_paired_All)
   apply (rule conjI)
    apply clarsimp
   apply (subgoal_tac "(a, b) = p")
    apply (erule allEI)
    apply clarsimp
   apply (erule_tac x=p in allE)
   apply fastforce
  apply (clarsimp simp del: split_paired_Ex split_paired_All)
  apply (rule_tac x=p in exI)
  apply (clarsimp simp del: split_paired_Ex split_paired_All)
  done


lemma zombie_has_refs:
  "is_zombie cap \<Longrightarrow> obj_irq_refs cap \<noteq> {}"
  by (clarsimp simp: is_cap_simps cap_irqs_def cap_irq_opt_def
                     obj_irq_refs_def
              split: sum.split_asm)


lemma zombie_cap_irqs:
  "is_zombie cap \<Longrightarrow> cap_irqs cap = {}"
  by (clarsimp simp: is_cap_simps)


lemma zombies_final_def2:
  "zombies_final = (\<lambda>s. \<forall>p p' cap cap'. (cte_wp_at (op = cap) p s \<and> cte_wp_at (op = cap') p' s
                                          \<and> (obj_refs cap \<inter> obj_refs cap' \<noteq> {}) \<and> p \<noteq> p')
                                      \<longrightarrow> (\<not> is_zombie cap \<and> \<not> is_zombie cap'))"
  unfolding zombies_final_def
  apply (rule ext)
  apply (rule iffI)
   apply (intro allI impI conjI notI)
    apply (elim conjE)
    apply (simp only: simp_thms conj_commute final_cap_at_eq cte_wp_at_def)
    apply (elim allE, drule mp, rule exI, erule(1) conjI)
    apply (elim exE conjE)
    apply (drule spec, drule mp, rule conjI, erule not_sym)
     apply simp
    apply (clarsimp simp: obj_irq_refs_Int)
   apply (elim conjE)
   apply (simp only: simp_thms conj_commute final_cap_at_eq cte_wp_at_def)
   apply (elim allE, drule mp, rule exI, erule(1) conjI)
   apply (elim exE conjE)
   apply (drule spec, drule mp, erule conjI)
    apply simp
   apply (clarsimp simp: Int_commute obj_irq_refs_Int)
  apply (clarsimp simp: final_cap_at_eq cte_wp_at_def
                        zombie_has_refs obj_irq_refs_Int
                        zombie_cap_irqs
                  simp del: split_paired_Ex)
  apply (rule ccontr)
  apply (elim allE, erule impE, (erule conjI)+)
   apply (clarsimp simp: is_cap_simps)
  apply clarsimp
  done


lemma zombies_finalD2:
  "\<lbrakk> fst (get_cap p s) = {(cap, s)}; fst (get_cap p' s) = {(cap', s)};
     p \<noteq> p'; zombies_final s; obj_refs cap \<inter> obj_refs cap' \<noteq> {} \<rbrakk>
     \<Longrightarrow> \<not> is_zombie cap \<and> \<not> is_zombie cap'"
  by (simp only: zombies_final_def2 cte_wp_at_def simp_thms conj_comms)

lemma zombies_finalD3:
  "\<lbrakk> cte_wp_at P p s; cte_wp_at P' p' s; p \<noteq> p'; zombies_final s;
     \<And>cap cap'. \<lbrakk> P cap; P' cap' \<rbrakk> \<Longrightarrow> obj_refs cap \<inter> obj_refs cap' \<noteq> {} \<rbrakk>
     \<Longrightarrow> cte_wp_at (Not \<circ> is_zombie) p s \<and> cte_wp_at (Not \<circ> is_zombie) p' s"
  apply (clarsimp simp: cte_wp_at_def)
  apply (erule(3) zombies_finalD2)
  apply simp
  done


lemma set_cap_final_cap_at:
  "\<lbrace>\<lambda>s. is_final_cap' cap' s \<and>
     cte_wp_at (\<lambda>cap''. (obj_irq_refs cap'' \<inter> obj_irq_refs cap' \<noteq> {})
                            = (obj_irq_refs cap \<inter> obj_irq_refs cap' \<noteq> {})) p s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. is_final_cap' cap'\<rbrace>"
  apply (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state)
  apply wp
  apply (elim conjE exEI allEI)
  apply (clarsimp simp: Int_commute)
  done


lemma set_cap_zombies':
  "\<lbrace>\<lambda>s. zombies_final s
         \<and> cte_wp_at (\<lambda>cap'. \<forall>p' cap''. (cte_wp_at (op = cap'') p' s \<and> p \<noteq> p'
                            \<and> (obj_refs cap \<inter> obj_refs cap'' \<noteq> {})
                             \<longrightarrow> (\<not> is_zombie cap \<and> \<not> is_zombie cap''))) p s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (simp add: zombies_final_def2 cte_wp_at_caps_of_state)
  apply (rule hoare_pre, wp)
  apply clarsimp
  apply (metis Int_commute Pair_eq)
  done

fun ex_zombie_refs :: "(cap \<times> cap) \<Rightarrow> obj_ref set"
where
  "ex_zombie_refs (c1, c2) =
     (case c1 of
       cap.Zombie p b n \<Rightarrow>
         (case c2 of
           cap.Zombie p' b' n' \<Rightarrow>
             (obj_refs (cap.Zombie p b n) - obj_refs (cap.Zombie p' b' n'))
           | _ \<Rightarrow>
             obj_refs (cap.Zombie p b n))
       | _ \<Rightarrow> obj_refs c1 - obj_refs c2)"

declare ex_zombie_refs.simps [simp del]

lemmas ex_zombie_refs_simps [simp]
    = ex_zombie_refs.simps[split_simps cap.split, simplified]

lemma ex_zombie_refs_def2:
 "ex_zombie_refs (cap, cap') =
    (if is_zombie cap
     then if is_zombie cap'
       then obj_refs cap - obj_refs cap'
       else obj_refs cap
     else obj_refs cap - obj_refs cap')"
  by (simp add: is_zombie_def split: cap.splits split del: split_if)

lemma set_cap_zombies:
  "\<lbrace>\<lambda>s. zombies_final s
         \<and> cte_wp_at (\<lambda>cap'. \<forall>r\<in>ex_zombie_refs (cap, cap'). \<forall>p'.
                              (p \<noteq> p' \<and> cte_wp_at (\<lambda>cap''. r \<in> obj_refs cap'') p' s)
                                \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap)) p s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (wp set_cap_zombies')
  apply (clarsimp simp: cte_wp_at_def elim!: nonemptyE)
  apply (subgoal_tac "x \<in> obj_refs capa \<longrightarrow> \<not> is_zombie cap'' \<and> \<not> is_zombie capa")
   prefer 2
   apply (rule impI)
   apply (drule(3) zombies_finalD2)
    apply clarsimp
    apply blast
   apply simp
  apply (simp only: ex_zombie_refs_def2 split: split_if_asm)
    apply simp
    apply (drule bspec, simp)
    apply (elim allE, erule disjE, erule(1) notE)
    apply simp
   apply simp
   apply (drule(1) bspec, elim allE, erule disjE, erule(1) notE)
   apply simp
  apply simp
  apply (erule impCE)
   apply (drule bspec, simp)
   apply (elim allE, erule impE, erule conjI)
    apply simp
   apply simp
  apply simp
  done


lemma set_cap_obj_at_other:
  "\<lbrace>\<lambda>s. P (obj_at P' p s) \<and> p \<noteq> fst p'\<rbrace> set_cap cap p' \<lbrace>\<lambda>rv s. P (obj_at P' p s)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_inv])
  apply (case_tac obj, simp_all split del: split_if)
   apply (rule hoare_pre, wp)
   apply (clarsimp simp: obj_at_def)
  apply (rule hoare_pre, wp)
  apply (clarsimp simp: obj_at_def)
  done


lemma new_cap_iflive:
  "\<lbrace>cte_wp_at (op = cap.NullCap) p
      and if_live_then_nonz_cap\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. if_live_then_nonz_cap s\<rbrace>"
  by (wp set_cap_iflive, clarsimp elim!: cte_wp_at_weakenE)


lemma new_cap_ifunsafe:
  "\<lbrace>cte_wp_at (op = cap.NullCap) p
      and if_unsafe_then_cap and ex_cte_cap_wp_to (appropriate_cte_cap cap) p\<rbrace>
     set_cap cap p \<lbrace>\<lambda>rv s. if_unsafe_then_cap s\<rbrace>"
  by (wp set_cap_ifunsafe, clarsimp elim!: cte_wp_at_weakenE)


lemma ex_zombie_refs_Null[simp]:
  "ex_zombie_refs (c, cap.NullCap) = obj_refs c"
  by (simp add: ex_zombie_refs_def2)


lemma new_cap_zombies:
  "\<lbrace>\<lambda>s. cte_wp_at (op = cap.NullCap) p s \<and>
        (\<forall>r\<in>obj_refs cap. \<forall>p'. p \<noteq> p' \<and> cte_wp_at (\<lambda>cap'. r \<in> obj_refs cap') p' s
                                   \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))
        \<and> zombies_final s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (wp set_cap_zombies)
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done


lemma new_cap_valid_pspace:
  "\<lbrace>cte_wp_at (op = cap.NullCap) p and valid_cap cap
      and tcb_cap_valid cap p and valid_pspace
      and (\<lambda>s. \<forall>r\<in>obj_refs cap. \<forall>p'. p \<noteq> p' \<and> cte_wp_at (\<lambda>cap'. r \<in> obj_refs cap') p' s
                                     \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (simp add: valid_pspace_def)
  apply (wpx set_cap_valid_objs new_cap_iflive new_cap_ifunsafe new_cap_zombies)
  apply (auto simp: cte_wp_at_caps_of_state)
  done


lemma obj_irq_refs_inD:
  "x \<in> obj_irq_refs cap \<Longrightarrow> obj_irq_refs cap = {x}"
  apply (case_tac cap, simp_all add: obj_irq_refs_def cap_irqs_def
                                     cap_irq_opt_def split: sum.split_asm)
  apply clarsimp
  done


lemma objirqrefs_distinct_or_equal:
  "\<lbrakk> obj_irq_refs cap \<inter> obj_irq_refs cap' \<noteq> {} \<rbrakk> 
     \<Longrightarrow> obj_irq_refs cap = obj_irq_refs cap'"
  by (clarsimp elim!: nonemptyE dest!: obj_irq_refs_inD)


lemma objirqrefs_distinct_or_equal_corl:
  "\<lbrakk> x \<in> obj_irq_refs cap; x \<in> obj_irq_refs cap' \<rbrakk>
     \<Longrightarrow> obj_irq_refs cap = obj_irq_refs cap'"
  by (blast intro!: objirqrefs_distinct_or_equal)


lemma obj_refs_cap_irqs_not_both:
  "obj_refs cap \<noteq> {} \<longrightarrow> cap_irqs cap = {}"
  by (clarsimp simp: cap_irqs_def cap_irq_opt_def split: cap.split sum.split_asm)


lemmas obj_irq_refs_Int_not =
    arg_cong [where f=Not, OF obj_irq_refs_Int, simplified, symmetric]


lemma not_final_another':
  "\<lbrakk> \<not> is_final_cap' cap s; fst (get_cap p s) = {(cap, s)};
       obj_irq_refs cap \<noteq> {} \<rbrakk>
      \<Longrightarrow> \<exists>p' cap'. p' \<noteq> p \<and> fst (get_cap p' s) = {(cap', s)}
                         \<and> obj_irq_refs cap' = obj_irq_refs cap
                         \<and> \<not> is_final_cap' cap' s"
  apply (simp add: is_final_cap'_def obj_irq_refs_Int_not cong: conj_cong
              del: split_paired_Ex split_paired_All)
  apply (erule not_singleton_oneE[where p=p])
   apply simp
  apply (rule_tac x=p' in exI)
  apply clarsimp
  apply (drule objirqrefs_distinct_or_equal)
  apply simp
  done


lemma not_final_another:
  "\<lbrakk> \<not> is_final_cap' cap s; fst (get_cap p s) = {(cap, s)};
       r \<in> obj_irq_refs cap \<rbrakk>
      \<Longrightarrow> \<exists>p' cap'. p' \<noteq> p \<and> fst (get_cap p' s) = {(cap', s)}
                         \<and> obj_irq_refs cap' = obj_irq_refs cap
                         \<and> \<not> is_final_cap' cap' s"
  apply (erule(1) not_final_another')
  apply clarsimp
  done


lemma delete_no_untyped:
  "\<lbrakk> ((), s') \<in> fst (set_cap cap.NullCap p s);
     \<not> (\<exists>cref. cte_wp_at (\<lambda>c. p' \<in> untyped_range c) cref s) \<rbrakk> \<Longrightarrow>
     \<not> (\<exists>cref. cte_wp_at (\<lambda>c. p' \<in> untyped_range c) cref s')"
  apply (simp only: cte_wp_at_caps_of_state)
  apply (erule use_valid, wp)
  apply clarsimp
  done


lemma get_cap_caps_of_state:
  "(fst (get_cap p s) = {(cap, s)}) = (Some cap = caps_of_state s p)"
  by (clarsimp simp: caps_of_state_def eq_commute)


definition
  no_cap_to_obj_with_diff_ref :: "cap \<Rightarrow> cslot_ptr set \<Rightarrow> 'z::state_ext state \<Rightarrow> bool"
where
 "no_cap_to_obj_with_diff_ref cap S \<equiv>
  \<lambda>s. \<forall>p \<in> UNIV - S. \<not> cte_wp_at (\<lambda>c. obj_refs c = obj_refs cap \<and>
                                       \<not> (table_cap_ref c = table_cap_ref cap)) p s"


lemma obj_ref_none_no_asid:
  "{} = obj_refs new_cap \<longrightarrow> None = table_cap_ref new_cap"
  "obj_refs new_cap = {} \<longrightarrow> table_cap_ref new_cap = None"
  by (simp add: table_cap_ref_def split: cap.split arch_cap.split)+


lemma no_cap_to_obj_with_diff_ref_Null:
  "no_cap_to_obj_with_diff_ref cap.NullCap S = \<top>"
  by (rule ext, simp add: no_cap_to_obj_with_diff_ref_def
                          cte_wp_at_caps_of_state obj_ref_none_no_asid)


definition
  "is_ap_cap cap \<equiv> case cap of cap.ArchObjectCap (arch_cap.ASIDPoolCap ap asid) \<Rightarrow> True | _ \<Rightarrow> False"


lemmas is_ap_cap_simps [simp] = is_ap_cap_def [split_simps cap.split arch_cap.split]


definition
  "reachable_pg_cap cap \<equiv> \<lambda>s.
   is_pg_cap cap \<and>
   (\<exists>vref. vs_cap_ref cap = Some vref \<and> (vref \<unrhd> obj_ref_of cap) s)"


definition
  replaceable :: "'z::state_ext state \<Rightarrow> cslot_ptr \<Rightarrow> cap \<Rightarrow> cap \<Rightarrow> bool"
where
 "replaceable s sl newcap \<equiv> \<lambda>cap.
    (cap = newcap)
  \<or> (\<not> is_final_cap' cap s \<and> newcap = cap.NullCap \<and> \<not> reachable_pg_cap cap s)
  \<or> (is_final_cap' cap s
      \<and> (\<forall>p\<in>zobj_refs cap - zobj_refs newcap.
              obj_at (Not \<circ> live) p s)
      \<and> (\<forall>p'. p' \<in> cte_refs cap (interrupt_irq_node s)
               \<and> (p' \<notin> cte_refs newcap (interrupt_irq_node s)
                    \<or> (\<exists>cp. appropriate_cte_cap cp cap
                             \<and> \<not> appropriate_cte_cap cp newcap))
             \<longrightarrow>
                 (p' \<noteq> sl \<longrightarrow> cte_wp_at (op = cap.NullCap) p' s)
               \<and> (p' = sl \<longrightarrow> newcap = cap.NullCap))
      \<and> (obj_irq_refs newcap \<subseteq> obj_irq_refs cap)
      \<and> (newcap \<noteq> cap.NullCap \<longrightarrow> cap_range newcap = cap_range cap)
      \<and> (is_master_reply_cap cap \<longrightarrow> newcap = cap.NullCap)
      \<and> (is_reply_cap cap \<longrightarrow> newcap = cap.NullCap)
      \<and> (\<not> is_master_reply_cap cap \<longrightarrow>
         tcb_cap_valid cap sl s \<longrightarrow> tcb_cap_valid newcap sl s)
      \<and> \<not> is_untyped_cap newcap \<and> \<not> is_master_reply_cap newcap
      \<and> \<not> is_reply_cap newcap
      \<and> newcap \<noteq> cap.IRQControlCap
      \<and> (newcap \<noteq> cap.NullCap \<longrightarrow> cap_class newcap = cap_class cap)
      \<and> (\<forall>vref. vs_cap_ref cap = Some vref
                \<longrightarrow> (vs_cap_ref newcap = Some vref
                       \<and> obj_refs newcap = obj_refs cap)
                 \<or> (\<forall>oref \<in> obj_refs cap. \<not> (vref \<unrhd> oref) s))
      \<and> no_cap_to_obj_with_diff_ref newcap {sl} s
      \<and> ((is_pt_cap newcap \<or> is_pd_cap newcap) \<longrightarrow> cap_asid newcap = None
          \<longrightarrow> (\<forall>r \<in> obj_refs newcap. obj_at (empty_table (set (arm_global_pts (arch_state s)))) r s))
      \<and> ((is_pt_cap newcap \<or> is_pd_cap newcap)
             \<longrightarrow> ((is_pt_cap newcap \<and> is_pt_cap cap \<or> is_pd_cap newcap \<and> is_pd_cap cap)
                      \<longrightarrow> (cap_asid newcap = None \<longrightarrow> cap_asid cap = None)
                      \<longrightarrow> obj_refs cap \<noteq> obj_refs newcap)
             \<longrightarrow> (\<forall>sl'. cte_wp_at (\<lambda>cap'. obj_refs cap' = obj_refs newcap
                                           \<and> (is_pd_cap newcap \<and> is_pd_cap cap' \<or> is_pt_cap newcap \<and> is_pt_cap cap')
                                           \<and> (cap_asid newcap = None \<or> cap_asid cap' = None)) sl' s \<longrightarrow> sl' = sl))
      \<and> \<not>is_ap_cap newcap)"


lemma range_not_empty_is_physical:
  "valid_cap cap s \<Longrightarrow> (cap_class cap = PhysicalClass) = (cap_range cap \<noteq> {})"
  apply (case_tac cap)
   apply (simp_all add:cap_range_def valid_cap_simps cap_aligned_def is_aligned_no_overflow)
  apply (rename_tac arch_cap)
  apply (case_tac arch_cap)
   apply (simp_all add:cap_range_def aobj_ref_def)
  done


lemma zombies_finalE:
  "\<lbrakk> \<not> is_final_cap' cap s; is_zombie cap; zombies_final s;
     cte_wp_at (op = cap) p s \<rbrakk>
     \<Longrightarrow> P"
  apply (frule(1) zombies_finalD)
   apply simp
  apply (clarsimp simp: cte_wp_at_def)
  done


lemma obj_ref_is_obj_irq_ref:
  "x \<in> obj_refs cap \<Longrightarrow> Inl x \<in> obj_irq_refs cap"
  by (simp add: obj_irq_refs_def)


lemma obj_irq_refs_eq:
  "(obj_irq_refs cap = obj_irq_refs cap')
      = (obj_refs cap = obj_refs cap' \<and> cap_irqs cap = cap_irqs cap')"
  apply (simp add: obj_irq_refs_def)
  apply (subgoal_tac "\<forall>x y. Inl x \<noteq> Inr y")
   apply blast
  apply simp
  done


lemma delete_duplicate_iflive:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap. \<not> is_final_cap' cap s) p s
      \<and> if_live_then_nonz_cap s \<and> zombies_final s\<rbrace>
     set_cap cap.NullCap p \<lbrace>\<lambda>rv s. if_live_then_nonz_cap s\<rbrace>"
  apply (clarsimp simp: if_live_then_nonz_cap_def ex_nonz_cap_to_def)
  apply (simp only: imp_conv_disj)
  apply (rule hoare_pre,
         wp hoare_vcg_all_lift hoare_vcg_disj_lift hoare_vcg_ex_lift
            set_cap_cte_wp_at)
  apply (clarsimp simp: cte_wp_at_def)
  apply (drule spec, drule(1) mp)
  apply clarsimp
  apply (case_tac "(a, b) = p")
   apply (clarsimp simp: zobj_refs_to_obj_refs)
   apply (drule(2) not_final_another[OF _ _ obj_ref_is_obj_irq_ref])
   apply (simp, elim exEI, clarsimp simp: obj_irq_refs_eq)
   apply (erule(2) zombies_finalE)
   apply (simp add: cte_wp_at_def)
  apply (intro exI, erule conjI, clarsimp)
  done


lemma non_unsafe_set_cap:
  "\<lbrace>\<lambda>s. \<not> cte_wp_at (op \<noteq> cap.NullCap) p' s\<rbrace>
     set_cap cap.NullCap p''
   \<lbrace>\<lambda>rv s. \<not> cte_wp_at (op \<noteq> cap.NullCap) p' s\<rbrace>"
  by (simp add: cte_wp_at_caps_of_state | wp)+


lemma cte_refs_obj_refs_elem:
  "x \<in> cte_refs cap y \<Longrightarrow> fst x \<in> obj_refs cap
                            \<or> (\<exists>irq. cap = cap.IRQHandlerCap irq)"
  by (cases cap, simp_all split: sum.split, fastforce+)


lemma get_cap_valid_objs_valid_cap:
  "\<lbrakk> fst (get_cap p s) = {(cap, s)}; valid_objs s \<rbrakk>
     \<Longrightarrow> valid_cap cap s"
  apply (rule cte_wp_at_valid_objs_valid_cap[where P="op = cap", simplified])
   apply (simp add: cte_wp_at_def)
  apply assumption
  done


lemma not_final_not_zombieD:
  "\<lbrakk> \<not> is_final_cap' cap s; fst (get_cap p s) = {(cap, s)};
     zombies_final s \<rbrakk> \<Longrightarrow> \<not> is_zombie cap"
  apply (rule notI)
  apply (erule(2) zombies_finalE)
  apply (simp add: cte_wp_at_def)
  done


lemma appropriate_cte_cap_irqs:
  "(\<forall>cp. appropriate_cte_cap cp cap = appropriate_cte_cap cp cap')
     = ((cap_irqs cap = {}) = (cap_irqs cap' = {}))"
  apply (rule iffI)
   apply (drule_tac x="cap.IRQControlCap" in spec)
   apply (simp add: appropriate_cte_cap_def)
  apply (simp add: appropriate_cte_cap_def split: cap.splits)
  done


lemma not_final_another_cte:
  "\<lbrakk> \<not> is_final_cap' cap s; fst (get_cap p s) = {(cap, s)};
       x \<in> cte_refs cap y; valid_objs s; zombies_final s \<rbrakk>
      \<Longrightarrow> \<exists>p' cap'. p' \<noteq> p \<and> fst (get_cap p' s) = {(cap', s)}
                         \<and> (\<forall>y. cte_refs cap' y = cte_refs cap y)
                         \<and> (\<forall>cp. appropriate_cte_cap cp cap'
                                     = appropriate_cte_cap cp cap)
                         \<and> \<not> is_final_cap' cap' s"
  apply (frule cte_refs_obj_refs_elem)
  apply (frule(1) not_final_another')
   apply (auto simp: obj_irq_refs_def cap_irqs_def cap_irq_opt_def)[1]
  apply (elim exEI, clarsimp)
  apply (drule(2) not_final_not_zombieD)+
  apply (drule(1) get_cap_valid_objs_valid_cap)+
  apply (clarsimp simp: is_zombie_def valid_cap_def obj_at_def is_obj_defs
                        a_type_def obj_irq_refs_eq
                        appropriate_cte_cap_irqs
                 split: cap.split_asm arch_cap.split_asm split_if_asm)
  done


lemma delete_duplicate_ifunsafe:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap. \<not> is_final_cap' cap s) p s
      \<and> if_unsafe_then_cap s \<and> valid_objs s \<and> zombies_final s\<rbrace>
     set_cap cap.NullCap p \<lbrace>\<lambda>rv s. if_unsafe_then_cap s\<rbrace>"
  apply (clarsimp simp: if_unsafe_then_cap_def ex_cte_cap_wp_to_def)
  apply (simp only: imp_conv_disj)
  apply (rule hoare_pre,
         wp hoare_vcg_all_lift hoare_vcg_disj_lift 
            hoare_vcg_ex_lift)
   apply (rule hoare_use_eq [where f=interrupt_irq_node])
    apply (wp set_cap_cte_wp_at)
  apply simp
  apply (elim conjE allEI)
  apply (clarsimp del: disjCI intro!: disjCI2)
  apply (case_tac "(a, b) = p")
   apply (simp cong: conj_cong add: cte_wp_at_weakenE [OF _ TrueI])
   apply (simp add: cte_wp_at_def | elim exE conjE)+
   apply (frule(4) not_final_another_cte)
   apply (simp, elim exEI, clarsimp)
  apply (fastforce elim!: cte_wp_at_weakenE)
  done


lemma cte_wp_at_conj:
  "cte_wp_at (\<lambda>c. P c \<and> Q c) p s = (cte_wp_at P p s \<and> cte_wp_at Q p s)"
  by (fastforce simp: cte_wp_at_def)


lemma cte_wp_at_disj:
  "cte_wp_at (\<lambda>c. P c \<or> Q c) p s = (cte_wp_at P p s \<or> cte_wp_at Q p s)"
  by (fastforce simp: cte_wp_at_def)


lemma obj_irq_refs_Null[simp]:
  "obj_irq_refs cap.NullCap = {}"
  by (simp add: obj_irq_refs_def)


lemma delete_duplicate_valid_pspace:
  "\<lbrace>\<lambda>s. valid_pspace s \<and> cte_wp_at (\<lambda>cap. \<not> is_final_cap' cap s) p s \<and>
        tcb_cap_valid cap.NullCap p s\<rbrace>
  set_cap cap.NullCap p
  \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (simp add: valid_pspace_def)
  apply (wpx set_cap_valid_objs delete_duplicate_iflive delete_duplicate_ifunsafe
            set_cap_zombies, auto elim!: cte_wp_at_weakenE)
  done


lemma set_cap_valid_pspace:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>cap'. (\<forall>p'\<in>zobj_refs cap' - zobj_refs cap. obj_at (Not \<circ> live) p' s)
                        \<and> (\<forall>r\<in>ex_zombie_refs (cap, cap'). \<forall>p'.
                              p \<noteq> p' \<and> cte_wp_at (\<lambda>cap''. r \<in> obj_refs cap'') p' s
                                \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))) p s
     \<and> valid_cap cap s \<and> tcb_cap_valid cap p s \<and> valid_pspace s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (simp add: valid_pspace_def)
  apply (wpx set_cap_valid_objs set_cap_iflive set_cap_zombies)
  apply (clarsimp elim!: cte_wp_at_weakenE | rule conjI)+
  done


lemma set_object_idle [wp]:
  "\<lbrace>valid_idle and
     (\<lambda>s. ko_at ko p s \<and> (\<not>is_tcb ko \<or> 
                   (ko = (TCB t) \<and> ko' = (TCB t') \<and>
                    tcb_state t = tcb_state t')))\<rbrace>
   set_object p ko'
   \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  apply (simp add: set_object_def)
  apply wpx
  apply (fastforce simp: valid_idle_def st_tcb_at_def obj_at_def is_tcb_def)
  done


lemma set_cap_idle:
  "\<lbrace>\<lambda>s. valid_idle s\<rbrace>
   set_cap cap p 
  \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  apply (simp add: valid_idle_def)
  apply (simp add: set_cap_def set_object_def split_def)
  apply wp
   prefer 2
   apply (rule get_object_sp)
  apply (case_tac obj, simp_all split del: split_if)
  apply ((clarsimp simp: st_tcb_at_def obj_at_def is_tcb_def|rule conjI|wp)+)[2]
  done


lemma set_cap_cte_at_neg:
  "\<lbrace>\<lambda>s. \<not> cte_at sl s\<rbrace> set_cap cap sl' \<lbrace>\<lambda>rv s. \<not> cte_at sl s\<rbrace>"
  apply (simp add: cte_at_typ)
  apply (wpx set_cap_typ_at)
  done


lemma set_cap_cte_wp_at_neg:
  "\<lbrace>\<lambda>s. cte_at sl' s \<and> (if sl = sl' then \<not> P cap else \<not> cte_wp_at P sl s)\<rbrace> set_cap cap sl' \<lbrace>\<lambda>rv s. \<not> cte_wp_at P sl s\<rbrace>"
  apply (simp add: cte_wp_at_caps_of_state)
  apply wp
  apply simp
  done


lemma set_cap_reply [wp]:
  "\<lbrace>valid_reply_caps and cte_at dest and
      (\<lambda>s. \<forall>t. cap = cap.ReplyCap t False \<longrightarrow>
               st_tcb_at awaiting_reply t s \<and>
               (\<not> has_reply_cap t s \<or>
                cte_wp_at (op = (cap.ReplyCap t False)) dest s))\<rbrace>
   set_cap cap dest \<lbrace>\<lambda>_. valid_reply_caps\<rbrace>"
  apply (simp add: valid_reply_caps_def has_reply_cap_def)
  apply (rule hoare_pre)
   apply (subst imp_conv_disj)
   apply (wp hoare_vcg_disj_lift hoare_vcg_all_lift set_cap_cte_wp_at_neg
        | simp)+
  apply (fastforce simp: unique_reply_caps_def is_cap_simps
                        cte_wp_at_caps_of_state) 
  done


lemma set_cap_reply_masters [wp]:
  "\<lbrace>valid_reply_masters and cte_at ptr and
       (\<lambda>s. \<forall>x. cap = cap.ReplyCap x True \<longrightarrow>
                fst ptr = x \<and> snd ptr = tcb_cnode_index 2) \<rbrace>
   set_cap cap ptr \<lbrace>\<lambda>_. valid_reply_masters\<rbrace>"
  apply (simp add: valid_reply_masters_def cte_wp_at_caps_of_state)
  apply wpx
  apply clarsimp
  done

crunch interrupt_states[wp]: cap_insert "\<lambda>s. P (interrupt_states s)"
  (wp: crunch_wps simp: crunch_simps)

crunch interrupt_states[wp]: cap_insert "\<lambda>s. P (interrupt_states s)"
  (wp: crunch_wps simp: crunch_simps)

lemma set_cap_irq_handlers:
 "\<lbrace>\<lambda>s. valid_irq_handlers s
      \<and> cte_wp_at (\<lambda>cap'. \<forall>irq \<in> cap_irqs cap - cap_irqs cap'. irq_issued irq s) ptr s\<rbrace>
    set_cap cap ptr
  \<lbrace>\<lambda>rv. valid_irq_handlers\<rbrace>"
  apply (simp add: valid_irq_handlers_def irq_issued_def)
  apply wpx
  apply (clarsimp simp: cte_wp_at_caps_of_state elim!: ranE split: split_if_asm)
   apply auto
  done


lemma wf_cs_ran_nonempty:
  "well_formed_cnode_n sz cs \<Longrightarrow> ran cs \<noteq> {}"
  apply (clarsimp simp: well_formed_cnode_n_def)
  apply (drule_tac f="\<lambda>S. replicate sz False \<in> S" in arg_cong)
  apply auto
  done


lemma set_cap_obj_at_impossible:
  "\<lbrace>\<lambda>s. P (obj_at P' p s) \<and> (\<forall>ko. P' ko \<longrightarrow> caps_of ko = {})\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv s. P (obj_at P' p s)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (wp get_object_wp | wpc)+
  apply (clarsimp simp: obj_at_def)
  apply (subgoal_tac "\<forall>sz cs. well_formed_cnode_n sz cs \<longrightarrow> \<not> P' (CNode sz cs)")
   apply (subgoal_tac "\<forall>tcb. \<not> P' (TCB tcb)")
    apply (clarsimp simp: fun_upd_def[symmetric] wf_cs_insert dom_def)
    apply auto[1]
   apply (auto simp:caps_of_def cap_of_def ran_tcb_cnode_map wf_cs_ran_nonempty)
  done


lemma empty_table_caps_of:
  "empty_table S ko \<Longrightarrow> caps_of ko = {}"
  by (cases ko, simp_all add: empty_table_def caps_of_def cap_of_def)


lemma not_final_another_caps:
  "\<lbrakk> \<not> is_final_cap' cap s; caps_of_state s p = Some cap;
       r \<in> obj_irq_refs cap \<rbrakk>
      \<Longrightarrow> \<exists>p' cap'. p' \<noteq> p \<and> caps_of_state s p' = Some cap'
                         \<and> obj_irq_refs cap' = obj_irq_refs cap
                         \<and> \<not> is_final_cap' cap' s"
  apply (clarsimp dest!: caps_of_state_cteD
                   simp: cte_wp_at_def)
  apply (drule(1) not_final_another')
   apply clarsimp
  apply clarsimp
  apply (subgoal_tac "cte_wp_at (op = cap') (a, b) s")
   apply (fastforce simp: cte_wp_at_caps_of_state)
  apply (simp add: cte_wp_at_def)
  done


lemma unique_table_refsD:
  "\<lbrakk> unique_table_refs cps; cps p = Some cap; cps p' = Some cap';
     obj_refs cap = obj_refs cap'\<rbrakk>
     \<Longrightarrow> table_cap_ref cap = table_cap_ref cap'"
  unfolding unique_table_refs_def
  by blast


lemma table_cap_ref_vs_cap_ref_Some:
  "table_cap_ref x = Some y \<Longrightarrow> vs_cap_ref x = Some y"
  by (clarsimp simp: table_cap_ref_def vs_cap_ref_def 
              split: Structures_A.cap.splits ARM_Structs_A.arch_cap.splits)


lemma set_cap_valid_vs_lookup:
  "\<lbrace>\<lambda>s. valid_vs_lookup s
      \<and> (\<forall>vref cap'. cte_wp_at (op = cap') ptr s
                \<longrightarrow> vs_cap_ref cap' = Some vref
                \<longrightarrow> (vs_cap_ref cap = Some vref \<and> obj_refs cap = obj_refs cap')
                 \<or> (\<not> is_final_cap' cap' s \<and> \<not> reachable_pg_cap cap' s)
                 \<or> (\<forall>oref \<in> obj_refs cap'. \<not> (vref \<unrhd> oref) s))
      \<and> unique_table_refs (caps_of_state s)\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv. valid_vs_lookup\<rbrace>"
  apply (simp add: valid_vs_lookup_def
              del: split_paired_All split_paired_Ex)
  apply (rule hoare_pre)
   apply (wp hoare_vcg_all_lift hoare_convert_imp[OF set_cap_vs_lookup_pages]
             hoare_vcg_disj_lift)
  apply (elim conjE allEI, rule impI, drule(1) mp)
  apply (simp only: simp_thms)
  apply (elim exE conjE)
  apply (case_tac "p' = ptr")
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (elim disjE impCE)
     apply fastforce
    apply clarsimp
    apply (drule (1) not_final_another_caps)
     apply (erule obj_ref_is_obj_irq_ref)
    apply (simp, elim exEI, clarsimp simp: obj_irq_refs_eq)
    apply (rule conjI, clarsimp)
    apply (drule(3) unique_table_refsD)
    apply (clarsimp simp: reachable_pg_cap_def is_pg_cap_def)
    apply (case_tac cap, simp_all add: vs_cap_ref_simps)[1]
    apply (rename_tac arch_cap)
    apply (case_tac arch_cap,
           simp_all add: vs_cap_ref_simps table_cap_ref_simps)[1]
       apply (clarsimp dest!: table_cap_ref_vs_cap_ref_Some)
      apply fastforce
     apply (clarsimp dest!: table_cap_ref_vs_cap_ref_Some)+
  apply (auto simp: cte_wp_at_caps_of_state)[1]
  done


lemma set_cap_valid_table_caps:
  "\<lbrace>\<lambda>s. valid_table_caps s
         \<and> ((is_pt_cap cap \<or> is_pd_cap cap) \<longrightarrow> cap_asid cap = None
            \<longrightarrow> (\<forall>r \<in> obj_refs cap. obj_at (empty_table (set (arm_global_pts (arch_state s)))) r s))\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv. valid_table_caps\<rbrace>"
  apply (simp add: valid_table_caps_def)
  apply (wp hoare_vcg_all_lift
            hoare_vcg_disj_lift hoare_convert_imp[OF set_cap_caps_of_state]
            hoare_use_eq[OF set_cap_arch set_cap_obj_at_impossible])
  apply (simp add: empty_table_caps_of)
  done


lemma set_cap_unique_table_caps:
  "\<lbrace>\<lambda>s. unique_table_caps (caps_of_state s)
      \<and> ((is_pt_cap cap \<or> is_pd_cap cap)
             \<longrightarrow> (\<forall>oldcap. caps_of_state s ptr = Some oldcap \<longrightarrow>
                  (is_pt_cap cap \<and> is_pt_cap oldcap \<or> is_pd_cap cap \<and> is_pd_cap oldcap)
                    \<longrightarrow> (cap_asid cap = None \<longrightarrow> cap_asid oldcap = None)
                    \<longrightarrow> obj_refs oldcap \<noteq> obj_refs cap)
             \<longrightarrow> (\<forall>ptr'. cte_wp_at (\<lambda>cap'. obj_refs cap' = obj_refs cap
                                              \<and> (is_pd_cap cap \<and> is_pd_cap cap' \<or> is_pt_cap cap \<and> is_pt_cap cap')
                                              \<and> (cap_asid cap = None \<or> cap_asid cap' = None)) ptr' s \<longrightarrow> ptr' = ptr))\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv s. unique_table_caps (caps_of_state s)\<rbrace>"
  apply wp
  apply (simp only: unique_table_caps_def)
  apply (elim conjE)
  apply (erule impCE)
   apply clarsimp
  apply (erule impCE)
   prefer 2
   apply (simp del: imp_disjL)
   apply (thin_tac "\<forall>a b. P a b" for P)
   apply (auto simp: cte_wp_at_caps_of_state)[1]
  apply (clarsimp simp del: imp_disjL del: allI)
  apply (case_tac "cap_asid cap \<noteq> None")
   apply (clarsimp del: allI)
   apply (elim allEI | rule impI)+
   apply (auto simp: is_pt_cap_def is_pd_cap_def)[1]
  apply (elim allEI)
  apply (intro conjI impI)
   apply (elim allEI)
   apply (auto simp: is_pt_cap_def is_pd_cap_def)[1]
  apply (elim allEI)
  apply (auto simp: is_pt_cap_def is_pd_cap_def)[1]
  done


lemma set_cap_unique_table_refs:
  "\<lbrace>\<lambda>s. unique_table_refs (caps_of_state s)
      \<and> no_cap_to_obj_with_diff_ref cap {ptr} s\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv s. unique_table_refs (caps_of_state s)\<rbrace>"
  apply wp
  apply clarsimp
  apply (simp add: unique_table_refs_def
              split del: split_if del: split_paired_All)
  apply (erule allEI, erule allEI)
  apply (clarsimp split del: split_if)
  apply (clarsimp simp: no_cap_to_obj_with_diff_ref_def
                        cte_wp_at_caps_of_state
                 split: split_if_asm)
  done


lemma set_cap_valid_arch_caps:
  "\<lbrace>\<lambda>s. valid_arch_caps s
      \<and> (\<forall>vref cap'. cte_wp_at (op = cap') ptr s
                \<longrightarrow> vs_cap_ref cap' = Some vref
                \<longrightarrow> (vs_cap_ref cap = Some vref \<and> obj_refs cap = obj_refs cap')
                 \<or> (\<not> is_final_cap' cap' s \<and> \<not> reachable_pg_cap cap' s)
                 \<or> (\<forall>oref \<in> obj_refs cap'. \<not> (vref \<unrhd> oref) s))
      \<and> no_cap_to_obj_with_diff_ref cap {ptr} s
      \<and> ((is_pt_cap cap \<or> is_pd_cap cap) \<longrightarrow> cap_asid cap = None
            \<longrightarrow> (\<forall>r \<in> obj_refs cap. obj_at (empty_table (set (arm_global_pts (arch_state s)))) r s))
      \<and> ((is_pt_cap cap \<or> is_pd_cap cap)
             \<longrightarrow> (\<forall>oldcap. caps_of_state s ptr = Some oldcap \<longrightarrow>
                  (is_pt_cap cap \<and> is_pt_cap oldcap \<or> is_pd_cap cap \<and> is_pd_cap oldcap)
                    \<longrightarrow> (cap_asid cap = None \<longrightarrow> cap_asid oldcap = None)
                    \<longrightarrow> obj_refs oldcap \<noteq> obj_refs cap)
             \<longrightarrow> (\<forall>ptr'. cte_wp_at (\<lambda>cap'. obj_refs cap' = obj_refs cap
                                              \<and> (is_pd_cap cap \<and> is_pd_cap cap' \<or> is_pt_cap cap \<and> is_pt_cap cap')
                                              \<and> (cap_asid cap = None \<or> cap_asid cap' = None)) ptr' s \<longrightarrow> ptr' = ptr))\<rbrace>
     set_cap cap ptr
   \<lbrace>\<lambda>rv. valid_arch_caps\<rbrace>"
  apply (simp add: valid_arch_caps_def pred_conj_def)
  apply (wp set_cap_valid_vs_lookup set_cap_valid_table_caps
            set_cap_unique_table_caps set_cap_unique_table_refs)
  apply simp+
  done

lemma set_cap_valid_arch_objs[wp]:
  "\<lbrace>valid_arch_objs\<rbrace> set_cap cap ptr \<lbrace>\<lambda>rv. valid_arch_objs\<rbrace>"
  apply (wp valid_arch_objs_lift set_cap_typ_at set_cap_obj_at_impossible)
  apply (clarsimp simp: caps_of_def cap_of_def)
  done


lemma set_cap_valid_global_objs[wp]:
  "\<lbrace>valid_global_objs\<rbrace> set_cap ptr cap \<lbrace>\<lambda>rv. valid_global_objs\<rbrace>"
  apply (wp valid_global_objs_lift valid_ao_at_lift
            set_cap_typ_at set_cap_obj_at_impossible
                  | simp add: caps_of_def cap_of_def)+
  apply (clarsimp simp: empty_table_def
                 split: Structures_A.kernel_object.split_asm)
  done


lemma get_cap_det:
  "(r,s') \<in> fst (get_cap p s) \<Longrightarrow> get_cap p s = ({(r,s)}, False)"
  apply (cases p)
  apply (clarsimp simp add: in_monad get_cap_def get_object_def
                     split: Structures_A.kernel_object.split_asm)
   apply (clarsimp simp add: bind_def return_def assert_opt_def simpler_gets_def)
  apply (simp add: bind_def simpler_gets_def return_def assert_opt_def)
  done


lemma get_cap_wp:
  "\<lbrace>\<lambda>s. \<forall>cap. cte_wp_at (op = cap) p s \<longrightarrow> Q cap s\<rbrace> get_cap p \<lbrace>Q\<rbrace>"
  apply (clarsimp simp: valid_def cte_wp_at_def)
  apply (frule in_inv_by_hoareD [OF get_cap_inv])
  apply (drule get_cap_det)
  apply simp
  done

lemma cap_insert_irq_handlers[wp]:
 "\<lbrace>\<lambda>s. valid_irq_handlers s
      \<and> cte_wp_at (\<lambda>cap'. \<forall>irq \<in> cap_irqs cap - cap_irqs cap'. irq_issued irq s) src s\<rbrace>
    cap_insert cap src dest
  \<lbrace>\<lambda>rv. valid_irq_handlers\<rbrace>"
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def update_cdt_def set_cdt_def set_original_def)
  apply (wp | simp split del: split_if)+
      apply (wp set_cap_irq_handlers get_cap_wp)
      apply (clarsimp simp:is_cap_simps )
      apply (wp set_cap_cte_wp_at get_cap_wp)
  apply (clarsimp simp: cte_wp_at_caps_of_state valid_irq_handlers_def)
  apply (auto simp:is_cap_simps free_index_update_def)
  done


lemma final_cap_duplicate:
  "\<lbrakk> fst (get_cap p s) = {(cap', s)};
     fst (get_cap p' s) = {(cap'', s)};
     p \<noteq> p'; is_final_cap' cap s; r \<in> obj_irq_refs cap;
     r \<in> obj_irq_refs cap'; r \<in> obj_irq_refs cap'' \<rbrakk>
     \<Longrightarrow> P"
  apply (clarsimp simp add: is_final_cap'_def
                            obj_irq_refs_Int_not)
  apply (erule(1) obvious)
   apply simp
   apply blast
  apply simp
  apply blast
  done


lemma obj_irq_refs_subset:
  "(obj_irq_refs cap \<subseteq> obj_irq_refs cap')
       = (obj_refs cap \<subseteq> obj_refs cap'
             \<and> cap_irqs cap \<subseteq> cap_irqs cap')"
  apply (simp add: obj_irq_refs_def)
  apply (subgoal_tac "\<forall>x y. Inl x \<noteq> Inr y")
   apply blast
  apply simp
  done


lemma set_cap_same_valid_pspace:
  "\<lbrace>cte_wp_at (\<lambda>c. c = cap) p and valid_pspace\<rbrace> set_cap cap p \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (wp set_cap_valid_pspace)
  apply (clarsimp simp: cte_wp_at_caps_of_state ex_zombie_refs_def2)
  apply (clarsimp simp: caps_of_state_valid_cap valid_pspace_def
                        cte_wp_tcb_cap_valid [OF caps_of_state_cteD])
  done


lemma replace_cap_valid_pspace:
  "\<lbrace>\<lambda>s. valid_pspace s \<and> cte_wp_at (replaceable s p cap) p s
          \<and> s \<turnstile> cap \<and> tcb_cap_valid cap p s\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (simp only: replaceable_def cte_wp_at_disj
                    conj_disj_distribL conj_disj_distribR)
  apply (rule hoare_strengthen_post)
   apply (rule hoare_vcg_disj_lift)
    apply (rule hoare_pre, rule set_cap_same_valid_pspace)
    apply simp
   apply (rule hoare_vcg_disj_lift)
    apply (cases "cap = cap.NullCap")
     apply simp
     apply (rule hoare_pre, rule delete_duplicate_valid_pspace)
     apply (fastforce simp: cte_wp_at_caps_of_state)
    apply (simp add: cte_wp_at_caps_of_state)
   apply (rule hoare_pre, rule set_cap_valid_pspace)
   apply (clarsimp simp: cte_wp_at_def)
   apply (clarsimp simp: ex_zombie_refs_def2 split: split_if_asm)
     apply (erule(3) final_cap_duplicate,
            erule subsetD, erule obj_ref_is_obj_irq_ref,
            erule subsetD, erule obj_ref_is_obj_irq_ref,
            erule obj_ref_is_obj_irq_ref)+
  apply simp
  done


lemma replace_cap_ifunsafe:
  "\<lbrace>\<lambda>s. cte_wp_at (replaceable s p cap) p s
       \<and> if_unsafe_then_cap s \<and> valid_objs s \<and> zombies_final s
       \<and> (cap \<noteq> cap.NullCap \<longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s)\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp only: replaceable_def cte_wp_at_disj conj_disj_distribR)
  apply (rule hoare_strengthen_post)
   apply (rule hoare_vcg_disj_lift)
    apply (rule hoare_pre, rule set_cap_ifunsafe)
    apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (rule hoare_vcg_disj_lift)
    apply (cases "cap = cap.NullCap")
     apply simp
     apply (rule hoare_pre, rule delete_duplicate_ifunsafe)
     apply (clarsimp simp: cte_wp_at_caps_of_state)
    apply (simp add: cte_wp_at_caps_of_state)
   apply (wp set_cap_ifunsafe)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply simp
  done


lemma thread_set_mdb:
  assumes c: "\<And>t getF v. (getF, v) \<in> ran tcb_cap_cases
                    \<Longrightarrow> getF (f t) = getF t"
  shows "\<lbrace>valid_mdb\<rbrace> thread_set f p \<lbrace>\<lambda>r. valid_mdb\<rbrace>"
  apply (simp add: thread_set_def set_object_def)
  apply (rule valid_mdb_lift)
    apply wp
    apply clarsimp
    apply (subst caps_of_state_after_update)
     apply (clarsimp simp: c)
    apply simp
   apply (wp | simp)+
  done


lemma set_cap_caps_of_state2:
  "\<lbrace>\<lambda>s. P (caps_of_state s (p \<mapsto> cap)) (cdt s) (is_original_cap s)\<rbrace> 
  set_cap cap p 
  \<lbrace>\<lambda>rv s. P (caps_of_state s) (cdt s) (is_original_cap s)\<rbrace>"
  apply (rule_tac Q="\<lambda>rv s. \<exists>m mr. P (caps_of_state s) m mr
                                  \<and> (cdt s = m) \<and> (is_original_cap s = mr)"
           in hoare_post_imp)
   apply simp
  apply (wp hoare_vcg_ex_lift)
  apply (rule_tac x="cdt s" in exI)
  apply (rule_tac x="is_original_cap s" in exI)
  apply (simp add: fun_upd_def)
  done


lemma obj_irq_refs_empty:
  "(obj_irq_refs cap = {}) = (cap_irqs cap = {} \<and> obj_refs cap = {})"
  by (simp add: obj_irq_refs_def conj_comms)


lemma final_NullCap:
  "is_final_cap' cap.NullCap = \<bottom>"
  by (rule ext, simp add: is_final_cap'_def)


lemma valid_table_capsD:
  "\<lbrakk> cte_wp_at (op = cap) ptr s; valid_table_caps s;
        is_pt_cap cap | is_pd_cap cap; cap_asid cap = None \<rbrakk>
        \<Longrightarrow> \<forall>r \<in> obj_refs cap. obj_at (empty_table (set (arm_global_pts (arch_state s)))) r s"
  apply (clarsimp simp: cte_wp_at_caps_of_state valid_table_caps_def)
  apply (cases ptr, fastforce)
  done


lemma unique_table_capsD:
  "\<lbrakk> unique_table_caps cps; cps ptr = Some cap; cps ptr' = Some cap';
     obj_refs cap = obj_refs cap'; cap_asid cap = None \<or> cap_asid cap' = None;
     (is_pd_cap cap \<and> is_pd_cap cap') \<or> (is_pt_cap cap \<and> is_pt_cap cap') \<rbrakk>
     \<Longrightarrow> ptr = ptr'"
  unfolding unique_table_caps_def
  by blast


(* FIXME: move *)
lemma valid_capsD:
  "\<lbrakk>caps_of_state s p = Some cap; valid_caps (caps_of_state s) s\<rbrakk>
   \<Longrightarrow> valid_cap cap s"
  by (cases p, simp add: valid_caps_def)


lemma unique_table_refs_no_cap_asidE:
  "\<lbrakk>caps_of_state s p = Some cap;
    unique_table_refs (caps_of_state s)\<rbrakk>
   \<Longrightarrow> no_cap_to_obj_with_diff_ref cap S s"
  apply (clarsimp simp: no_cap_to_obj_with_diff_ref_def
                        cte_wp_at_caps_of_state)
  apply (unfold unique_table_refs_def)
  apply (drule_tac x=p in spec, drule_tac x="(a,b)" in spec)
  apply (drule spec)+
  apply (erule impE, assumption)+
  apply (clarsimp simp: is_cap_simps)
  done


lemmas unique_table_refs_no_cap_asidD
     = unique_table_refs_no_cap_asidE[where S="{}"]


lemma set_cap_valid_kernel_mappings[wp]:
  "\<lbrace>valid_kernel_mappings\<rbrace> set_cap cap p \<lbrace>\<lambda>rv. valid_kernel_mappings\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (wp set_object_v_ker_map get_object_wp | wpc)+
  apply (clarsimp)
  done


lemma set_cap_equal_kernel_mappings[wp]:
  "\<lbrace>equal_kernel_mappings\<rbrace> set_cap cap p \<lbrace>\<lambda>rv. equal_kernel_mappings\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (wp set_object_equal_mappings get_object_wp | wpc)+
  apply (clarsimp)
  done


lemma set_cap_only_idle [wp]:
  "\<lbrace>only_idle\<rbrace> set_cap cap p \<lbrace>\<lambda>_. only_idle\<rbrace>" 
  by (wp only_idle_lift set_cap_typ_at)


lemma set_cap_global_pd_mappings[wp]:
  "\<lbrace>valid_global_pd_mappings\<rbrace>
       set_cap cap p \<lbrace>\<lambda>rv. valid_global_pd_mappings\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (wp set_object_global_pd_mappings get_object_wp | wpc)+
  apply (clarsimp simp: obj_at_def a_type_def)
  done


lemma set_cap_kernel_window[wp]:
  "\<lbrace>pspace_in_kernel_window\<rbrace> set_cap cap p \<lbrace>\<lambda>rv. pspace_in_kernel_window\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (wp set_object_pspace_in_kernel_window get_object_wp | wpc)+
  apply (clarsimp simp: obj_at_def)
  apply (clarsimp simp: fun_upd_def[symmetric]
                        a_type_def wf_cs_upd)
  done

lemma set_cap_cap_refs_in_kernel_window[wp]:
  "\<lbrace>cap_refs_in_kernel_window
         and (\<lambda>s. \<forall>ref \<in> cap_range cap. arm_kernel_vspace (arch_state s) ref
                         = ArmVSpaceKernelWindow)\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv. cap_refs_in_kernel_window\<rbrace>"
  apply (simp add: cap_refs_in_kernel_window_def valid_refs_def2
                   pred_conj_def)
  apply (rule hoare_lift_Pf2[where f=arch_state])
   apply wp
   apply (fastforce elim!: ranE split: split_if_asm)
  apply wp
  done

lemma cap_refs_in_kernel_windowD:
  "\<lbrakk> caps_of_state s ptr = Some cap; cap_refs_in_kernel_window s \<rbrakk>
   \<Longrightarrow> \<forall>ref \<in> cap_range cap.
         arm_kernel_vspace (arch_state s) ref = ArmVSpaceKernelWindow"
  apply (clarsimp simp: cap_refs_in_kernel_window_def valid_refs_def
                        cte_wp_at_caps_of_state)
  apply (cases ptr, fastforce)
  done


lemma set_cap_valid_ioc[wp]:
  "\<lbrace>valid_ioc and (\<lambda>s. p = cap.NullCap \<longrightarrow> \<not> is_original_cap s pt)\<rbrace>
   set_cap p pt
   \<lbrace>\<lambda>_. valid_ioc\<rbrace>"
  apply (simp add: set_cap_def split_def)
  apply (wp set_object_valid_ioc_caps get_object_sp)
   prefer 2
   apply (rule get_object_sp)
  apply (rule hoare_conjI)
   apply (clarsimp simp: valid_def return_def fail_def split_def
                         a_type_simps obj_at_def valid_ioc_def
                  split: Structures_A.kernel_object.splits)
  apply (rule hoare_conjI)
   apply (clarsimp simp: valid_def return_def fail_def split_def
                         a_type_simps obj_at_def valid_ioc_def
                  split: Structures_A.kernel_object.splits)
   apply (auto simp: wf_unique wf_cs_upd)[1]
  apply (clarsimp simp: valid_def return_def fail_def split_def
                        null_filter_def cap_of_def tcb_cnode_map_tcb_cap_cases
                        obj_at_def valid_ioc_def cte_wp_at_cases
                 split: Structures_A.kernel_object.splits)
  apply (intro conjI allI impI)
             apply fastforce+
           apply (rule ccontr, clarsimp)
           apply (drule spec, frule spec, erule impE, assumption)
           apply (drule_tac x="snd pt" in spec)
           apply (case_tac pt)
           apply (clarsimp simp: tcb_cap_cases_def  split: split_if_asm)
          apply fastforce
         apply (rule ccontr, clarsimp)
         apply (drule spec, frule spec, erule impE, assumption)
         apply (drule_tac x="snd pt" in spec)
         apply (case_tac pt)
         apply (clarsimp simp: tcb_cap_cases_def  split: split_if_asm)
        apply fastforce
       apply (rule ccontr, clarsimp)
       apply (drule spec, frule spec, erule impE, assumption)
       apply (drule_tac x="snd pt" in spec)
       apply (case_tac pt)
       apply (clarsimp simp: tcb_cap_cases_def  split: split_if_asm)
      apply fastforce
     apply (rule ccontr, clarsimp)
     apply (drule spec, frule spec, erule impE, assumption)
     apply (drule_tac x="snd pt" in spec)
     apply (case_tac pt)
     apply (clarsimp simp: tcb_cap_cases_def  split: split_if_asm)
    apply fastforce
   apply (rule ccontr, clarsimp)
   apply (drule spec, frule spec, erule impE, assumption)
   apply (drule_tac x="snd pt" in spec)
   apply (case_tac pt)
   apply (clarsimp simp: tcb_cap_cases_def  split: split_if_asm)
  apply fastforce
  done


lemma set_cap_vms[wp]:
  "\<lbrace>valid_machine_state\<rbrace> set_cap cap p \<lbrace>\<lambda>_. valid_machine_state\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (wp get_object_wp | wpc)+
  apply (intro allI impI conjI,
         simp_all add: valid_machine_state_def in_user_frame_def obj_at_def)
       apply (clarsimp simp: a_type_simps | drule_tac x=pa in spec |
              rule_tac x=sz in exI)+
  done


lemma descendants_inc_minor:
  "\<lbrakk>descendants_inc m cs; mdb_cte_at (\<lambda>p. \<exists>c. cs p = Some c \<and> cap.NullCap \<noteq> c) m;
   \<forall>x\<in> dom cs. cap_class (the (cs' x)) = cap_class (the (cs x)) \<and> cap_range (the (cs' x)) = cap_range (the (cs x))\<rbrakk>
  \<Longrightarrow> descendants_inc m cs'"
  apply (simp add:descendants_inc_def del:split_paired_All)
  apply (intro impI allI)
  apply (drule spec)+
  apply (erule(1) impE)
  apply (clarsimp simp:descendants_of_def)
  apply (frule tranclD)
  apply (drule tranclD2) 
  apply (simp add:cdt_parent_rel_def is_cdt_parent_def)
  apply (elim conjE exE)
  apply (drule(1) mdb_cte_atD)+
  apply (elim conjE exE)
  apply (drule_tac m1 = cs in bspec[OF _ domI,rotated],assumption)+
  apply simp
  done

lemma replace_cap_invs:
  "\<lbrace>\<lambda>s. invs s \<and> cte_wp_at (replaceable s p cap) p s
        \<and> cap \<noteq> cap.NullCap
        \<and> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s
        \<and> s \<turnstile> cap\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv s. invs s\<rbrace>"
  apply (simp add: invs_def valid_state_def valid_mdb_def2)
  apply (rule hoare_pre)
   apply (wp replace_cap_valid_pspace
             set_cap_caps_of_state2 set_cap_idle
             replace_cap_ifunsafe valid_irq_node_typ
             set_cap_typ_at set_cap_irq_handlers
             set_cap_valid_arch_caps set_cap_valid_arch_objs)
  apply (clarsimp simp: valid_pspace_def cte_wp_at_caps_of_state
                        replaceable_def)
  apply (rule conjI)
   apply (fastforce simp: tcb_cap_valid_def tcb_at_st_tcb_at
                  dest!: cte_wp_tcb_cap_valid [OF caps_of_state_cteD])
  apply (rule conjI)
   apply (erule_tac P="\<lambda>cps. mdb_cte_at cps (cdt s)" in rsubst)
   apply (rule ext)
   apply (safe del: disjE)[1]
    apply (simp add: obj_irq_refs_empty final_NullCap)+
  apply (rule conjI)
   apply (simp add: untyped_mdb_def is_cap_simps)
   apply (erule disjE)
    apply (clarsimp, rule conjI, clarsimp+)[1]
   apply (erule allEI, erule allEI)
   apply (drule_tac x="fst p" in spec, drule_tac x="snd p" in spec)
   apply (clarsimp simp: obj_irq_refs_subset)
   apply (drule(1) disjoint_subset, simp)
  apply (rule conjI)
   apply (erule descendants_inc_minor)
    apply simp
   apply (elim disjE)
    apply clarsimp
   apply clarsimp
  apply (rule conjI)
   apply (erule disjE)
    apply (simp add: fun_upd_def[symmetric] fun_upd_idem)
   apply (simp add: untyped_inc_def not_is_untyped_no_range)
  apply (rule conjI)
   apply (erule disjE)
    apply (simp add: fun_upd_def[symmetric] fun_upd_idem)
   apply (simp add: ut_revocable_def)
  apply (rule conjI)
   apply (erule disjE)
    apply (clarsimp simp: irq_revocable_def)
   apply clarsimp
   apply (clarsimp simp: irq_revocable_def)
  apply (rule conjI)
   apply (erule disjE)
    apply (simp add: fun_upd_def[symmetric] fun_upd_idem)
   apply (simp add: reply_master_revocable_def)
  apply (rule conjI)
   apply (erule disjE)
    apply (simp add: fun_upd_def[symmetric] fun_upd_idem)
   apply (clarsimp simp add: reply_mdb_def)
   apply (thin_tac "\<forall>a b. (a, b) \<in> cte_refs cp nd \<and> Q a b\<longrightarrow> R a b" for cp nd Q R)
   apply (thin_tac "is_pt_cap cap \<longrightarrow> P" for cap P)+ 
   apply (thin_tac "is_pd_cap cap \<longrightarrow> P" for cap P)+
   apply (rule conjI)
    apply (unfold reply_caps_mdb_def)[1]
    apply (erule allEI, erule allEI)
    apply (fastforce split: split_if_asm simp: is_cap_simps)
   apply (unfold reply_masters_mdb_def)[1]
   apply (erule allEI, erule allEI)
   apply (fastforce split: split_if_asm simp: is_cap_simps)
  apply (rule conjI)
   apply (erule disjE)
    apply (clarsimp)
    apply (drule caps_of_state_cteD)
    apply (erule(1) valid_reply_capsD [OF has_reply_cap_cte_wpD])
   apply (simp add: is_cap_simps)
  apply (frule(1) valid_global_refsD2)
  apply (frule(1) cap_refs_in_kernel_windowD)
  apply (rule conjI)
   apply (erule disjE)
    apply (clarsimp simp: valid_reply_masters_def cte_wp_at_caps_of_state)
    apply (cases p, fastforce)
   apply (simp add: is_cap_simps)
  apply (elim disjE)
   apply simp
   apply (clarsimp simp: valid_table_capsD[OF caps_of_state_cteD]
                    valid_arch_caps_def unique_table_refs_no_cap_asidE)
  apply simp
  apply (rule Ball_emptyI, simp add: obj_irq_refs_subset)
  done

crunch cte_wp_at: set_cdt "cte_wp_at P p"


lemma set_cdt_cdt_ct_ms_rvk[wp]:
  "\<lbrace>\<lambda>s. P m\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. P (cdt s)\<rbrace>"
  "\<lbrace>\<lambda>s. Q (is_original_cap s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. Q (is_original_cap s)\<rbrace>"
  "\<lbrace>\<lambda>s. R (cur_thread s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. R (cur_thread s)\<rbrace>"
  "\<lbrace>\<lambda>s. S (machine_state s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. S (machine_state s)\<rbrace>"
  "\<lbrace>\<lambda>s. T (idle_thread s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. T (idle_thread s)\<rbrace>"
  "\<lbrace>\<lambda>s. U (arch_state s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. U (arch_state s)\<rbrace>"
  by (simp add: set_cdt_def | wp)+


lemma set_original_wp[wp]:
  "\<lbrace>\<lambda>s. Q () (s \<lparr> is_original_cap := ((is_original_cap s) (p := v))\<rparr>)\<rbrace>
     set_original p v
   \<lbrace>Q\<rbrace>"
  by (simp add: set_original_def, wp)


lemma set_cdt_typ_at:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  apply (rule set_cdt_inv)
  apply (simp add: obj_at_def)
  done


lemma set_untyped_cap_as_full_typ_at[wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace>
   set_untyped_cap_as_full src_cap a b
   \<lbrace>\<lambda>ya s. P (typ_at T p s)\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (wp set_cap_typ_at hoare_drop_imps | simp split del:split_if)+
  done


lemma cap_insert_typ_at [wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace> cap_insert a b c \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  apply (simp add: cap_insert_def update_cdt_def)
  apply (wp set_cap_typ_at set_cdt_typ_at hoare_drop_imps
         |simp split del: split_if)+
  done

lemma cur_mdb [simp]:
  "cur_tcb (cdt_update f s) = cur_tcb s"
  by (simp add: cur_tcb_def)

lemma cur_tcb_more_update[iff]:
  "cur_tcb (trans_state f s) = cur_tcb s"
  by (simp add: cur_tcb_def)

crunch cur[wp]: cap_insert cur_tcb (wp: hoare_drop_imps)


lemma update_cdt_ifunsafe[wp]:
  "\<lbrace>if_unsafe_then_cap\<rbrace> update_cdt f \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp add: update_cdt_def set_cdt_def)
  apply wp
  apply (clarsimp elim!: ifunsafe_pspaceI)
  done


lemma ex_cap_revokable[simp]:
  "ex_nonz_cap_to p (s\<lparr>is_original_cap := m\<rparr>) = ex_nonz_cap_to p s"
  by (simp add: ex_nonz_cap_to_def)


lemma zombies_final_revokable[simp]:
  "zombies_final (is_original_cap_update f s) = zombies_final s"
  by (fastforce elim!: zombies_final_pspaceI)


lemma update_cdt_ex_cap[wp]:
  "\<lbrace>ex_nonz_cap_to p\<rbrace> update_cdt f \<lbrace>\<lambda>rv. ex_nonz_cap_to p\<rbrace>"
  apply (simp add: update_cdt_def set_cdt_def)
  apply wp
  apply (simp add: ex_nonz_cap_to_def)
  done


lemma update_cdt_iflive[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> update_cdt f \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (simp add: update_cdt_def set_cdt_def)
  apply wp
  apply (simp add: if_live_then_nonz_cap_def ex_nonz_cap_to_def)
  done


lemma update_cdt_zombies[wp]:
  "\<lbrace>zombies_final\<rbrace> update_cdt m \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (simp add: update_cdt_def set_cdt_def)
  apply wp
  apply (clarsimp elim!: zombies_final_pspaceI)
  done


lemma cap_insert_zombies:
  "\<lbrace>zombies_final and
    (\<lambda>s. (\<forall>r\<in>obj_refs cap. \<forall>p'.
           cte_wp_at (\<lambda>c. r \<in> obj_refs c) p' s
             \<longrightarrow> cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def)
  apply (wp| simp split del: split_if)+
      apply (wp new_cap_zombies get_cap_wp set_cap_cte_wp_at)
      apply (rule hoare_vcg_conj_lift)
       apply (clarsimp simp:is_cap_simps)
       apply (wp set_cap_zombies get_cap_wp set_cap_cte_wp_at hoare_allI)
  apply (clarsimp simp:is_cap_simps free_index_update_def cte_wp_at_caps_of_state | rule conjI)+
   apply (fastforce)
  apply (clarsimp simp:is_cap_simps free_index_update_def cte_wp_at_caps_of_state | rule conjI)+
  apply (fastforce)
  done

definition masked_as_full :: "cap \<Rightarrow> cap \<Rightarrow> cap" where
  "masked_as_full src_cap new_cap \<equiv>
   if is_untyped_cap src_cap \<and> is_untyped_cap new_cap \<and>
      obj_ref_of src_cap = obj_ref_of new_cap \<and>
      cap_bits_untyped src_cap = cap_bits_untyped new_cap 
   then (max_free_index_update src_cap) else src_cap"


lemma set_untyped_cap_as_full_cte_wp_at:
  "\<lbrace>\<lambda>s. (dest \<noteq> src \<and> cte_wp_at P dest s \<or>
         dest = src \<and> cte_wp_at (\<lambda>a. P (masked_as_full a cap)) src s) \<and>
        cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>ya s. (cte_wp_at P dest s)\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (intro impI conjI allI)
    apply (wp set_cap_cte_wp_at)
      apply (clarsimp simp:free_index_update_def cte_wp_at_caps_of_state is_cap_simps
        max_free_index_def masked_as_full_def)
    apply (intro conjI,elim disjE)
      apply clarsimp+
  apply wp
  apply (auto simp:is_cap_simps cte_wp_at_caps_of_state masked_as_full_def)
  done


lemma free_index_update_test_function_stuff[simp]:
  "cap_asid (src_cap\<lparr>free_index := a\<rparr>) = cap_asid src_cap"
  "obj_irq_refs (src_cap\<lparr>free_index := a\<rparr>) = obj_irq_refs src_cap"
  "vs_cap_ref (src_cap\<lparr>free_index := a\<rparr>) = vs_cap_ref src_cap"
  "untyped_range (cap \<lparr>free_index :=a \<rparr>) = untyped_range cap"
  "zobj_refs (c\<lparr>free_index:=a\<rparr>) =  zobj_refs c"
  "obj_refs (c\<lparr>free_index:=a\<rparr>) = obj_refs c"
  by (auto simp:cap_asid_def free_index_update_def  vs_cap_ref_def
    is_cap_simps obj_irq_refs_def split:cap.splits arch_cap.splits)


lemma valid_cap_free_index_update[simp]:
  "valid_cap cap s \<Longrightarrow> valid_cap (max_free_index_update cap) s"
  apply (case_tac cap)
  apply (simp_all add:free_index_update_def split:cap.splits arch_cap.splits)
  apply (clarsimp simp:valid_cap_def cap_aligned_def valid_untyped_def max_free_index_def)
  done


lemma ex_nonz_cap_to_more_update[iff]:
  "ex_nonz_cap_to w (trans_state f s) = ex_nonz_cap_to w s"
   by (simp add: ex_nonz_cap_to_def)

lemma cap_insert_ex_cap:
  "\<lbrace>ex_nonz_cap_to p\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. ex_nonz_cap_to p\<rbrace>"
  apply (simp add: cap_insert_def)
  apply (wp|simp split del: split_if)+
        apply (wp set_cap_cap_to get_cap_wp set_cap_cte_wp_at set_untyped_cap_as_full_cte_wp_at)
     apply (clarsimp simp:set_untyped_cap_as_full_def split del:if_splits)
     apply (wp set_cap_cap_to get_cap_wp)
  apply (clarsimp elim!: cte_wp_at_weakenE simp:is_cap_simps cte_wp_at_caps_of_state)
  apply (simp add:masked_as_full_def)
  done


lemma cap_insert_iflive:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def)
  apply (wp get_cap_wp set_cap_cte_wp_at | simp split del: split_if)+
      apply (rule new_cap_iflive)
     apply (wp set_cap_iflive set_cap_cte_wp_at get_cap_wp)
  apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)
  done


lemma untyped_cap_update_ex_cte_cap_wp_to:
  "\<lbrakk>if_unsafe_then_cap s; caps_of_state s src = Some src_cap;
    is_untyped_cap src_cap; is_untyped_cap cap\<rbrakk>
   \<Longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cap) src s"
  apply (case_tac src)
  apply (simp add:if_unsafe_then_cap_def)
  apply (drule spec)+
  apply (drule(1) mp)+
  apply (clarsimp simp: is_cap_simps)
  apply (erule ex_cte_cap_wp_to_weakenE)
  apply (clarsimp simp:appropriate_cte_cap_def)
  done

lemma ex_cte_cap_wo_to_more_update[simp]:
  "ex_cte_cap_wp_to P src (trans_state f s) = ex_cte_cap_wp_to P src s"
  by (simp add: ex_cte_cap_wp_to_def)

lemma if_unsafe_then_cap_more_update[iff]:
  "if_unsafe_then_cap (trans_state f s) = if_unsafe_then_cap s"
  by (simp add: if_unsafe_then_cap_def)

lemma cap_insert_ifunsafe:
  "\<lbrace>if_unsafe_then_cap and
    ex_cte_cap_wp_to (appropriate_cte_cap cap) dest\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp add: cap_insert_def)
  apply (wp get_cap_wp | simp split del: split_if)+
      apply (rule new_cap_ifunsafe)
     apply (simp add:set_untyped_cap_as_full_def split del:if_splits)
     apply (wp set_cap_cte_wp_at set_cap_ifunsafe set_cap_cte_cap_wp_to get_cap_wp)
  apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)
  apply (rule untyped_cap_update_ex_cte_cap_wp_to)
     apply (simp add:free_index_update_def)+
  done


lemma cap_insert_tcb:
 "\<lbrace>tcb_at t\<rbrace>
  cap_insert cap src dest 
  \<lbrace>\<lambda>rv. tcb_at t\<rbrace>" 
  by (simp add: cap_insert_typ_at [where P="\<lambda>x. x"] tcb_at_typ)


lemma set_cdt_caps_of_state:
  "\<lbrace>\<lambda>s. P (caps_of_state s)\<rbrace> set_cdt m \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (simp add: set_cdt_def)
  apply wp
  apply clarsimp
  done


crunch cos_ioc: set_cdt "\<lambda>s. P (caps_of_state s) (is_original_cap s)"


crunch irq_node[wp]: set_cdt "\<lambda>s. P (interrupt_irq_node s)"


lemmas set_cdt_caps_irq_node[wp]
  = hoare_use_eq[where f=interrupt_irq_node, OF set_cdt_irq_node, OF set_cdt_caps_of_state]

lemmas set_cap_caps_irq_node[wp]
  = hoare_use_eq[where f=interrupt_irq_node, OF set_cap_irq_node, OF set_cap_caps_of_state]


lemma cap_insert_cap_wp_to[wp]:
  "\<lbrace> K_bind(\<forall>x. P x = P (x\<lparr>free_index:=y\<rparr>)) and ex_cte_cap_wp_to P p\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P p\<rbrace>"
  apply (simp add: cap_insert_def ex_cte_cap_wp_to_def set_untyped_cap_as_full_def
                   cte_wp_at_caps_of_state update_cdt_def)
  apply (wp get_cap_wp | simp split del: split_if)+
  apply (rule allI)
  apply (clarsimp simp del:split_def,rule conjI)
    apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)
    apply (rule_tac x = a in exI)
    apply (rule_tac x = b in exI)
    apply (clarsimp simp:cte_wp_at_caps_of_state | rule conjI)+
  apply (rule_tac x = a in exI)
  apply (rule_tac x = b in exI)
  apply clarsimp
done


lemma ex_cte_cap_to_cnode_always_appropriate_strg:
  "ex_cte_cap_wp_to is_cnode_cap p s
    \<longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s"
  by (clarsimp elim!: ex_cte_cap_wp_to_weakenE
                simp: is_cap_simps appropriate_cte_cap_def
               split: cap.splits)


lemma update_cdt_refs_of[wp]:
  "\<lbrace>\<lambda>s. P (state_refs_of s)\<rbrace> update_cdt f \<lbrace>\<lambda>rv s. P (state_refs_of s)\<rbrace>"
  apply (simp add: update_cdt_def set_cdt_def)
  apply wp
  apply (clarsimp elim!: state_refs_of_pspaceI)
  done


lemma state_refs_of_revokable[simp]:
  "state_refs_of (s \<lparr> is_original_cap := m \<rparr>) = state_refs_of s"
  by (simp add: state_refs_of_def)


crunch state_refs_of[wp]: cap_insert "\<lambda>s. P (state_refs_of s)"
  (wp: crunch_wps)


crunch aligned[wp]: cap_insert pspace_aligned
  (wp: hoare_drop_imps)


crunch "distinct" [wp]: cap_insert pspace_distinct
  (wp: hoare_drop_imps)


lemma is_arch_cap_max_free_index[simp]:
  "is_arch_cap (x\<lparr>free_index:=y\<rparr>) = is_arch_cap x"
  by (auto simp:is_cap_simps free_index_update_def split:cap.splits)


lemma tcb_cap_valid_update_free_index[simp]:
  "tcb_cap_valid (cap\<lparr>free_index:=a\<rparr>) slot s = tcb_cap_valid cap slot s" 
  apply (rule iffI)
  apply (clarsimp simp:tcb_cap_valid_def)
  apply (intro conjI impI allI)
    apply (clarsimp simp:tcb_at_def st_tcb_at_def is_tcb_def obj_at_def 
      dest!:get_tcb_SomeD)
    apply (clarsimp simp:tcb_cap_cases_def free_index_update_def is_cap_simps
      split:if_splits cap.split_asm Structures_A.thread_state.split_asm)
    apply (clarsimp simp:st_tcb_at_def obj_at_def is_cap_simps free_index_update_def
      split:cap.split_asm)
  apply (clarsimp simp:tcb_cap_valid_def)
  apply (intro conjI impI allI)
    apply (clarsimp simp:tcb_at_def st_tcb_at_def is_tcb_def obj_at_def 
      dest!:get_tcb_SomeD)
    apply (clarsimp simp:tcb_cap_cases_def free_index_update_def is_cap_simps
      split:if_splits cap.split_asm Structures_A.thread_state.split_asm)
    apply (clarsimp simp:st_tcb_at_def obj_at_def is_cap_simps free_index_update_def
      valid_ipc_buffer_cap_def
      split:cap.split_asm)
    done


lemma set_untyped_cap_full_valid_objs:
  "\<lbrace>valid_objs and cte_wp_at (op = cap) slot\<rbrace>
   set_untyped_cap_as_full cap cap_new slot
   \<lbrace>\<lambda>r. valid_objs\<rbrace>"
  apply (simp add:set_untyped_cap_as_full_def split del:if_splits)
  apply (rule hoare_pre)
  apply (wp set_cap_valid_objs)
    apply (clarsimp simp:valid_cap_free_index_update tcb_cap_valid_caps_of_stateD
      cte_wp_at_caps_of_state caps_of_state_valid_cap)
  done


lemma set_untyped_cap_as_full_valid_cap:
  "\<lbrace>valid_cap cap\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>rv. valid_cap cap\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (rule hoare_pre)
  apply (wp set_cap_valid_cap,simp)
  done


lemma set_untyped_cap_as_full_tcb_cap_valid:
  "\<lbrace>tcb_cap_valid cap dest\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>rv s. tcb_cap_valid cap dest s\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def valid_def tcb_cap_valid_def)
  apply (intro conjI impI allI ballI)
    apply (case_tac "tcb_at (fst dest) s")
      apply clarsimp
      apply (intro conjI impI allI)
      apply (drule use_valid[OF _ set_cap_st_tcb],simp+)
        apply (clarsimp simp:valid_ipc_buffer_cap_def is_cap_simps)
    apply (clarsimp simp:tcb_at_typ)
    apply (drule use_valid[OF _ set_cap_typ_at])
      apply (assumption)
      apply simp
  apply (clarsimp simp:return_def)
  done


lemma cap_insert_objs [wp]:
 "\<lbrace>valid_objs and valid_cap cap and tcb_cap_valid cap dest\<rbrace>
  cap_insert cap src dest 
  \<lbrace>\<lambda>rv. valid_objs\<rbrace>"
  apply (simp add: cap_insert_def set_cdt_def update_cdt_def)
  apply (wp set_cap_valid_objs set_cap_valid_cap set_untyped_cap_as_full_valid_cap
    set_untyped_cap_full_valid_objs get_cap_wp set_untyped_cap_as_full_tcb_cap_valid
    | simp split del: split_if)+
  done


crunch st_tcb_at[wp]: cap_insert "st_tcb_at P t" 
  (wp: hoare_drop_imps)


crunch ct [wp]: cap_insert "\<lambda>s. P (cur_thread s)" 
  (wp: crunch_wps simp: crunch_simps)


lemma cap_insert_valid_cap[wp]:
  "\<lbrace>valid_cap c\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>rv. valid_cap c\<rbrace>"
  by (wp valid_cap_typ)


lemma cap_rights_update_idem [simp]:
  "cap_rights_update R (cap_rights_update R' cap) = cap_rights_update R cap"
  by (simp add: cap_rights_update_def acap_rights_update_def split: cap.splits arch_cap.splits)


lemma cap_master_cap_rights [simp]:
  "cap_master_cap (cap_rights_update R cap) = cap_master_cap cap"
  by (simp add: cap_master_cap_def cap_rights_update_def acap_rights_update_def 
           split: cap.splits arch_cap.splits)


lemma cap_insert_obj_at_other:
  "\<lbrace>\<lambda>s. P' (obj_at P p s) \<and> p \<noteq> fst src \<and> p \<noteq> fst dest\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>_ s. P' (obj_at P p s)\<rbrace>"
  apply (simp add: cap_insert_def update_cdt_def set_cdt_def set_untyped_cap_as_full_def)
  apply (rule hoare_pre)
   apply (wp set_cap_obj_at_other get_cap_wp|simp split del: split_if)+
  done


lemma as_user_only_idle :
  "\<lbrace>only_idle\<rbrace> as_user t m \<lbrace>\<lambda>_. only_idle\<rbrace>"
  apply (simp add: as_user_def set_object_def split_def)
  apply wp
  apply (clarsimp simp del: fun_upd_apply)
  apply (erule only_idle_tcb_update)
   apply (drule get_tcb_SomeD)
   apply (fastforce simp: obj_at_def)
  apply simp
  done


lemma valid_cap_imp_valid_vm_rights:
  "valid_cap (cap.ArchObjectCap (arch_cap.PageCap mw rs sz m)) s \<Longrightarrow>
   rs \<in> valid_vm_rights"
by (simp add: valid_cap_def valid_vm_rights_def)


lemma cap_rights_update_id [intro!, simp]:
  "valid_cap c s \<Longrightarrow> cap_rights_update (cap_rights c) c = c"
  unfolding cap_rights_update_def 
           acap_rights_update_def
  apply (cases c, simp_all)
   apply (simp add: valid_cap_def)
  apply (clarsimp simp: valid_cap_imp_valid_vm_rights  split: arch_cap.splits)
  done


lemma diminished_is_update:
  "valid_cap c' s \<Longrightarrow> diminished c c' \<Longrightarrow> \<exists>R. c' = cap_rights_update R c"
  apply (clarsimp simp: diminished_def mask_cap_def)
  apply (rule exI)
  apply (rule sym)
  apply (frule (1) cap_rights_update_id)
  done


lemmas diminished_is_update' =
  diminished_is_update[OF caps_of_state_valid_cap[OF _ invs_valid_objs]]


end
