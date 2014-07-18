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
  Refinement for handleEvent and syscalls
*)

theory Syscall_R
imports Tcb_R Arch_R Interrupt_R
begin

declare if_weak_cong [cong]

(*
syscall has 5 sections: m_fault h_fault m_error h_error m_finalise

run m_fault (faultable code) \<rightarrow> r_fault
  failure, i.e. Inr somefault \<rightarrow> \<lambda>somefault. h_fault; done

success, i.e. Inl a
  \<rightarrow> run \<lambda>a. m_error a (errable code) \<rightarrow> r_error
       failure, i.e. Inr someerror \<rightarrow> \<lambda>someerror. h_error e; done
       success, i.e. Inl b \<rightarrow> \<lambda>b. m_finalise b

One can clearly see this is simulating some kind of monadic Maybe sequence
trying to identify all possible errors before actually performing the syscall.
*)

lemma syscall_corres:
  assumes corres:
    "corres (fr \<oplus> r_flt_rel) P P' m_flt m_flt'" 
    "\<And>flt flt'. flt' = fault_map flt \<Longrightarrow> 
        corres r (P_flt flt) (P'_flt flt') (h_flt flt) (h_flt' flt')"
    "\<And>rv rv'. r_flt_rel rv rv' \<Longrightarrow> 
        corres (ser \<oplus> r_err_rel rv rv') 
               (P_no_flt rv) (P'_no_flt rv')
               (m_err rv) (m_err' rv')"
    "\<And>rv rv' err err'. \<lbrakk>r_flt_rel rv rv'; err' = syscall_error_map err \<rbrakk>
     \<Longrightarrow> corres r (P_err rv err) 
            (P'_err rv' err') (h_err err) (h_err' err')"
    "\<And>rvf rvf' rve rve'. \<lbrakk>r_flt_rel rvf rvf'; r_err_rel rvf rvf' rve rve'\<rbrakk>
     \<Longrightarrow> corres (intr \<oplus> r)
           (P_no_err rvf rve) (P'_no_err rvf' rve') 
           (m_fin rve) (m_fin' rve')"

  assumes wp:
    "\<And>rv.  \<lbrace>Q_no_flt rv\<rbrace>   m_err rv   \<lbrace>P_no_err rv\<rbrace>,  \<lbrace>P_err rv\<rbrace>"
    "\<And>rv'. \<lbrace>Q'_no_flt rv'\<rbrace> m_err' rv' \<lbrace>P'_no_err rv'\<rbrace>,\<lbrace>P'_err rv'\<rbrace>"
    "\<lbrace>Q\<rbrace> m_flt \<lbrace>\<lambda>rv. P_no_flt rv and Q_no_flt rv\<rbrace>, \<lbrace>P_flt\<rbrace>" 
    "\<lbrace>Q'\<rbrace> m_flt' \<lbrace>\<lambda>rv. P'_no_flt rv and Q'_no_flt rv\<rbrace>, \<lbrace>P'_flt\<rbrace>"

  shows "corres (intr \<oplus> r) (P and Q) (P' and Q')
           (Syscall_A.syscall m_flt  h_flt m_err h_err m_fin) 
           (Syscall_H.syscall m_flt' h_flt' m_err' h_err' m_fin')"
  apply (simp add: Syscall_A.syscall_def Syscall_H.syscall_def liftE_bindE)
  apply (rule corres_split_bind_sum_case)
      apply (rule corres_split_bind_sum_case | rule corres | rule wp | simp add: liftE_bindE)+
  done

lemma syscall_valid':
  assumes x:
             "\<And>ft. \<lbrace>P_flt ft\<rbrace> h_flt ft \<lbrace>Q\<rbrace>"
             "\<And>err. \<lbrace>P_err err\<rbrace> h_err err \<lbrace>Q\<rbrace>"
             "\<And>rv. \<lbrace>P_no_err rv\<rbrace> m_fin rv \<lbrace>Q\<rbrace>,\<lbrace>E\<rbrace>"
             "\<And>rv. \<lbrace>P_no_flt rv\<rbrace> m_err rv \<lbrace>P_no_err\<rbrace>, \<lbrace>P_err\<rbrace>"
             "\<lbrace>P\<rbrace> m_flt \<lbrace>P_no_flt\<rbrace>, \<lbrace>P_flt\<rbrace>"
  shows "\<lbrace>P\<rbrace> Syscall_H.syscall m_flt h_flt m_err h_err m_fin \<lbrace>Q\<rbrace>, \<lbrace>E\<rbrace>"
  apply (simp add: Syscall_H.syscall_def liftE_bindE
             cong: sum.case_cong)
  apply (rule hoare_split_bind_sum_caseE)
    apply (wp x)[1]
   apply (rule hoare_split_bind_sum_caseE)
     apply (wp x|simp)+
  done


text {* Completing the relationship between abstract/haskell invocations *}

primrec
  inv_relation :: "Invocations_A.invocation \<Rightarrow> Invocations_H.invocation \<Rightarrow> bool"
where
  "inv_relation (Invocations_A.InvokeUntyped i) x =
     (\<exists>i'. untypinv_relation i i' \<and> x = InvokeUntyped i')"
| "inv_relation (Invocations_A.InvokeEndpoint w w2 b) x =
     (x = InvokeEndpoint w w2 b)"
| "inv_relation (Invocations_A.InvokeAsyncEndpoint w w2 w3) x = 
     (x = InvokeAsyncEndpoint w w2 w3)"
| "inv_relation (Invocations_A.InvokeReply w ptr) x = 
     (x = InvokeReply w (cte_map ptr))"
| "inv_relation (Invocations_A.InvokeTCB i) x = 
     (\<exists>i'. tcbinv_relation i i' \<and> x = InvokeTCB i')"
| "inv_relation (Invocations_A.InvokeDomain tptr domain) x = 
     (x = InvokeDomain tptr domain)"
| "inv_relation (Invocations_A.InvokeIRQControl i) x = 
     (\<exists>i'. irq_control_inv_relation i i' \<and> x = InvokeIRQControl i')"
| "inv_relation (Invocations_A.InvokeIRQHandler i) x = 
     (\<exists>i'. irq_handler_inv_relation i i' \<and> x = InvokeIRQHandler i')"
| "inv_relation (Invocations_A.InvokeCNode i) x = 
     (\<exists>i'. cnodeinv_relation i i' \<and> x = InvokeCNode i')"
| "inv_relation (Invocations_A.InvokeArchObject i) x = 
     (\<exists>i'. archinv_relation i i' \<and> x = InvokeArchObject i')"

(* In order to assert conditions that must hold for the appropriate 
   handleInvocation and handle_invocation calls to succeed, we must have 
   some notion of what a valid invocation is.
   This function defines that.
   For example, a InvokeEndpoint requires an endpoint at its first 
   constructor argument. *)

primrec
  valid_invocation' :: "Invocations_H.invocation \<Rightarrow> kernel_state \<Rightarrow> bool"
where
  "valid_invocation' (Invocations_H.InvokeUntyped i) = valid_untyped_inv' i"
| "valid_invocation' (Invocations_H.InvokeEndpoint w w2 b) = (ep_at' w and ex_nonz_cap_to' w)"
| "valid_invocation' (Invocations_H.InvokeAsyncEndpoint w w2 w3) = (aep_at' w and ex_nonz_cap_to' w)"
| "valid_invocation' (Invocations_H.InvokeTCB i) = tcb_inv_wf' i"
| "valid_invocation' (Invocations_H.InvokeDomain thread domain) =
   (tcb_at' thread  and K (domain \<le> maxDomain))"
| "valid_invocation' (Invocations_H.InvokeReply thread slot) =
       (tcb_at' thread and cte_wp_at' (\<lambda>cte. cteCap cte = ReplyCap thread False) slot)"
| "valid_invocation' (Invocations_H.InvokeIRQControl i) = irq_control_inv_valid' i"
| "valid_invocation' (Invocations_H.InvokeIRQHandler i) = irq_handler_inv_valid' i"
| "valid_invocation' (Invocations_H.InvokeCNode i) = valid_cnode_inv' i" 
| "valid_invocation' (Invocations_H.InvokeArchObject i) = valid_arch_inv' i"


(* FIXME: sseefried: Clean up proof and move to Tcb_R.thy *)
lemma dec_domain_inv_corres:
  shows "\<lbrakk> list_all2 cap_relation (map fst cs) (map fst cs');
           list_all2 (\<lambda>p pa. snd pa = cte_map (snd p)) cs cs' \<rbrakk> \<Longrightarrow>
        corres (ser \<oplus> ((\<lambda>x. inv_relation x \<circ> uncurry Invocations_H.invocation.InvokeDomain) \<circ> (\<lambda>(x,y). Invocations_A.invocation.InvokeDomain x y))) \<top> \<top>
          (decode_domain_invocation label args cs)
          (decodeDomainInvocation label args cs')"
  apply (simp add: decode_domain_invocation_def decodeDomainInvocation_def)
  apply (rule whenE_throwError_corres_initial)
    apply (simp+)[2]
  apply (case_tac "args", simp_all)
  apply (rule corres_guard_imp)
    apply (rule_tac r'="\<lambda>domain domain'. domain = domain'" and R="\<lambda>_. \<top>" and R'="\<lambda>_. \<top>" in corres_splitEE)
       apply (rule whenE_throwError_corres_initial)
         apply simp
         apply (case_tac "cs")
         (* sseefried: There must be a better way to do this. This case_tac approach is inelegant*)
       apply ((case_tac "cs'", ((simp add: null_def)+)[2])+)[2]
        apply (subgoal_tac "cap_relation (fst (hd cs)) (fst (hd cs'))")
        apply (case_tac "fst (hd cs)")
          apply (case_tac "fst (hd cs')", simp+, rule corres_returnOkTT)
          apply (simp add: inv_relation_def o_def uncurry_def)
          apply (case_tac "fst (hd cs')", fastforce+)
          apply (case_tac "cs")
            apply (case_tac "cs'", ((simp add: list_all2_map2 list_all2_map1)+)[2])
            apply (case_tac "cs'", ((simp add: list_all2_map2 list_all2_map1)+)[2])
     apply (rule whenE_throwError_corres)
     apply (simp+)[2]
     apply (rule corres_returnOkTT)
     apply (wp | simp)+
done

lemma decode_invocation_corres:
  "\<lbrakk>cptr = to_bl cptr'; mi' = message_info_map mi;
    slot' = cte_map slot; cap_relation cap cap';
    args = args'; list_all2 cap_relation (map fst excaps) (map fst excaps');
    list_all2 (\<lambda>p pa. snd pa = cte_map (snd p)) excaps excaps' \<rbrakk>
    \<Longrightarrow>
    corres (ser \<oplus> inv_relation)
           (invs and valid_sched and valid_list
                 and valid_cap cap and cte_at slot and cte_wp_at (diminished cap) slot
                 and (\<lambda>s. \<forall>x\<in>set excaps. s \<turnstile> fst x \<and> cte_at (snd x) s)
                 and (\<lambda>s. length args < 2 ^ word_bits))
           (invs' and valid_cap' cap' and cte_at' slot'
            and (\<lambda>s. \<forall>x\<in>set excaps'. s \<turnstile>' fst x \<and> cte_at' (snd x) s)
            and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)))
      (decode_invocation (mi_label mi) args cptr slot cap excaps)
      (RetypeDecls_H.decodeInvocation (mi_label mi) args' cptr' slot' cap' excaps')"
  apply (rule corres_gen_asm)
  apply (unfold decode_invocation_def decodeInvocation_def)
  apply (case_tac cap, simp_all only: cap.cases)
   --"dammit, simp_all messes things up, must handle cases manually"
             -- "Null"
             apply (simp add: isCap_defs)
            -- "Untyped"
            apply (simp add: isCap_defs Let_def o_def split del: split_if)
            apply clarsimp
            apply (rule corres_guard_imp, rule dec_untyped_inv_corres)
              apply ((clarsimp simp:cte_wp_at_caps_of_state diminished_def)+)[3]
           -- "(Async)Endpoint"
           apply (simp add: isCap_defs returnOk_def)
          apply (simp add: isCap_defs)
          apply (clarsimp simp: returnOk_def neq_Nil_conv)
         -- "ReplyCap"
         apply (simp add: isCap_defs Let_def returnOk_def)
        -- "CNodeCap"
        apply (simp add: isCap_defs Let_def CanModify_def
                    split del: split_if cong: if_cong)
        apply (clarsimp simp add: o_def)
        apply (rule corres_guard_imp)
          apply (rule_tac F="length list \<le> 32" in corres_gen_asm)
          apply (rule dec_cnode_inv_corres, simp+)
         apply (simp add: valid_cap_def)
        apply simp
       -- "ThreadCap"
       apply (simp add: isCap_defs Let_def CanModify_def
                   split del: split_if cong: if_cong)
       apply (clarsimp simp add: o_def)
       apply (rule corres_guard_imp)
         apply (rule decode_tcb_inv_corres, rule refl,
                simp_all add: valid_cap_def valid_cap'_def)[3]
       apply (simp add: split_def)
       apply (rule list_all2_conj)
        apply (simp add: list_all2_map2 list_all2_map1)
       apply assumption
      -- "DomainCap"
      apply (simp add: isCap_defs)
      apply (rule corres_guard_imp)
      apply (rule dec_domain_inv_corres)
      apply (simp+)[4]
     -- "IRQControl"
     apply (simp add: isCap_defs o_def)
     apply (rule corres_guard_imp, rule decode_irq_control_corres, simp+)[1]
    -- "IRQHandler"
    apply (simp add: isCap_defs o_def)
    apply (rule corres_guard_imp, rule decode_irq_handler_corres, simp+)[1]
   -- "Zombie"
   apply (simp add: isCap_defs)
  -- "Arch"
  apply (clarsimp simp only: cap_relation.simps)
  apply (clarsimp simp add: isCap_defs Let_def o_def)
  apply (rule corres_guard_imp [OF dec_arch_inv_corres])
      apply (simp_all add: list_all2_map2 list_all2_map1)+
  apply (clarsimp simp: is_arch_diminished_def cte_wp_at_caps_of_state
                        is_cap_simps)
  done

(* Levity: added (20090126 19:32:38) *)
declare mapME_Nil [simp]

crunch inv' [wp]: lookupCapAndSlot P

(* See also load_word_offs_corres *)
lemma load_word_offs_word_corres:
  assumes y: "y < max_ipc_words"
  and    yv: "y' = y * 4"
  shows "corres op = \<top> (valid_ipc_buffer_ptr' a) (load_word_offs_word a y) (loadWordUser (a + y'))"
  unfolding loadWordUser_def yv using y
  apply -
  apply (rule corres_stateAssert_assume [rotated])
   apply (simp add: pointerInUserData_def)
   apply (erule valid_ipc_buffer_ptr'D2)
    apply (subst word_mult_less_iff)
       apply simp
      apply (unfold word_bits_len_of)
      apply (simp, subst mult_commute)
      apply (rule nat_less_power_trans [where k = 2, simplified])
       apply (rule unat_less_power)
        apply (simp add: word_bits_conv)
       apply (erule order_less_trans, simp add: max_ipc_words word_bits_conv)
      apply (simp add: word_bits_conv)
     apply (simp add: max_ipc_words word_bits_conv)
    apply assumption
   apply (rule is_aligned_mult_triv2 [where n = 2, simplified])
   apply (simp add: word_bits_conv)
  apply (rule corres_guard_imp)
    apply (simp add: load_word_offs_word_def word_size_def)
    apply (rule_tac F = "is_aligned a msg_align_bits" in corres_gen_asm2)
    apply (rule corres_machine_op)
    apply (rule corres_Id [OF refl refl])
    apply (rule no_fail_pre)
     apply wp
    apply (erule aligned_add_aligned)
      apply (rule is_aligned_mult_triv2 [where n = 2, simplified])
      apply (simp add: word_bits_conv msg_align_bits)+
  apply (simp add: valid_ipc_buffer_ptr'_def msg_align_bits)
  done

lemma hinv_corres_assist:
  "\<lbrakk> info' = message_info_map info \<rbrakk>
       \<Longrightarrow> corres (fr \<oplus> (\<lambda>(p, cap, extracaps, buffer) (p', capa, extracapsa, buffera).
        p' = cte_map p \<and> cap_relation cap capa \<and> buffer = buffera \<and>
        list_all2
         (\<lambda>x y. cap_relation (fst x) (fst y) \<and> snd y = cte_map (snd x))
         extracaps extracapsa))

           (invs and tcb_at thread and (\<lambda>_. valid_message_info info)) 
           (invs' and tcb_at' thread)
           (doE (cap, slot) \<leftarrow>
                cap_fault_on_failure cptr' False
                 (lookup_cap_and_slot thread (to_bl cptr'));
                do
                   buffer \<leftarrow> lookup_ipc_buffer False thread;
                   doE extracaps \<leftarrow> lookup_extra_caps thread buffer info;
                       returnOk (slot, cap, extracaps, buffer)
                   odE
                od
            odE)
           (doE (cap, slot) \<leftarrow> capFaultOnFailure cptr' False (lookupCapAndSlot thread cptr');
               do buffer \<leftarrow> VSpace_H.lookupIPCBuffer False thread;
                  doE extracaps \<leftarrow> lookupExtraCaps thread buffer info';
                      returnOk (slot, cap, extracaps, buffer)
                  odE
               od
            odE)"
  apply (clarsimp simp add: split_def)
  apply (rule corres_guard_imp)
    apply (rule corres_splitEE [OF _ corres_cap_fault])
       prefer 2
       -- "switched over to argument of corres_cap_fault"
       apply (rule lcs_corres, simp)
      apply (rule corres_split [OF _ lipcb_corres])
        apply (rule corres_splitEE [OF _ lec_corres])
            apply (rule corres_returnOkTT)
            apply simp+
         apply (wp | simp)+
   apply auto
  done

lemma msg_from_lookup_failure_map[simp]:
  "msgFromLookupFailure (lookup_failure_map f) = msg_from_lookup_failure f"
  apply (simp add: msgFromLookupFailure_def)
  apply (case_tac f, simp_all add: lookup_failure_map_def)
  done

lemma msg_from_syserr_map[simp]:
  "msgFromSyscallError (syscall_error_map err) = msg_from_syscall_error err"
  apply (simp add: msgFromSyscallError_def)
  apply (case_tac err,clarsimp+)
  done

(* FIXME futz move to TCB *)
lemma non_exst_same_timeSlice_upd[simp]:
  "non_exst_same tcb (tcbDomain_update f tcb)"
  by (cases tcb, simp add: non_exst_same_def)

lemma threadSet_tcbDomain_update_ct_idle_or_in_cur_domain':
  "\<lbrace>ct_idle_or_in_cur_domain' and (\<lambda>s. ksSchedulerAction s \<noteq> ResumeCurrentThread) \<rbrace>
     threadSet (tcbDomain_update (\<lambda>_. domain)) t
   \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain'\<rbrace>"
  apply (simp add: ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)
  apply (wp hoare_vcg_disj_lift hoare_vcg_imp_lift)
    apply (wp | wps)+
  apply (auto simp: obj_at'_def)
  done

lemma threadSet_tcbDomain_update_ct_not_inQ:
  "\<lbrace>ct_not_inQ \<rbrace> threadSet (tcbDomain_update (\<lambda>_. domain)) t \<lbrace>\<lambda>_. ct_not_inQ\<rbrace>"
  apply (simp add: threadSet_def ct_not_inQ_def)
  apply (wp)
   apply (rule hoare_convert_imp [OF setObject_nosch])
    apply (rule updateObject_tcb_inv)
   apply (wps setObject_ct_inv)
   apply (wp setObject_tcb_strongest getObject_tcb_wp)
  apply (case_tac "t = ksCurThread s")
   apply (clarsimp simp: obj_at'_def)+
  done

(* FIXME: sseefried: Move back to TcbAcc_R.thy *)
lemma setObject_F_ct_activatable':
  "\<lbrakk>\<And>tcb f. tcbState (F f tcb) = tcbState tcb \<rbrakk> \<Longrightarrow>  \<lbrace>ct_in_state' activatable' and obj_at' (op = tcb) t\<rbrace>
    setObject t (F f tcb)
   \<lbrace>\<lambda>_. ct_in_state' activatable'\<rbrace>"
  apply (clarsimp simp: ct_in_state'_def st_tcb_at'_def)
  apply (rule hoare_pre)
   apply (wps setObject_ct_inv)
   apply (wp setObject_tcb_strongest)
  apply (clarsimp simp: obj_at'_def)
  done

lemmas setObject_tcbDomain_update_ct_activatable'[wp] = setObject_F_ct_activatable'[where F="tcbDomain_update", simplified]

(* FIXME: sseefried: Move back to TcbAcc_R.thy *)
lemma setObject_F_st_tcb_at':
  "\<lbrakk>\<And>tcb f. tcbState (F f tcb) = tcbState tcb \<rbrakk> \<Longrightarrow> \<lbrace>st_tcb_at' P t' and obj_at' (op = tcb) t\<rbrace>
    setObject t (F f tcb)
   \<lbrace>\<lambda>_. st_tcb_at' P t'\<rbrace>"
  apply (simp add: st_tcb_at'_def)
  apply (rule hoare_pre)
  apply (wp setObject_tcb_strongest)
  apply (clarsimp simp: obj_at'_def)
  done

lemmas setObject_tcbDomain_update_st_tcb_at'[wp] = setObject_F_st_tcb_at'[where F="tcbDomain_update", simplified]

lemma threadSet_tcbDomain_update_sch_act_wf[wp]:
  "\<lbrace>\<lambda>s. sch_act_wf (ksSchedulerAction s) s \<and> sch_act_not t s\<rbrace>
    threadSet (tcbDomain_update (\<lambda>_. domain)) t
   \<lbrace>\<lambda>_ s. sch_act_wf (ksSchedulerAction s) s\<rbrace>"
  apply (simp add: sch_act_wf_cases
            split: scheduler_action.split)
  apply (wp hoare_vcg_conj_lift)
   apply (simp add: threadSet_def)
   apply wp
   apply (wps setObject_sa_unchanged)
   apply (wp static_imp_wp getObject_tcb_wp)+
   apply (clarsimp simp: obj_at'_def)
  apply (rule hoare_vcg_all_lift)
  apply (rule_tac Q="\<lambda>_ s. ksSchedulerAction s = SwitchToThread word \<longrightarrow> st_tcb_at' runnable' word s \<and> tcb_in_cur_domain' word s \<and> word \<noteq> t"
               in hoare_strengthen_post)
  apply (wp hoare_vcg_all_lift hoare_vcg_conj_lift hoare_imp_lift_something)+
    apply (simp add: threadSet_def)
    apply (wp_trace getObject_tcb_wp )
    apply (clarsimp simp: obj_at'_def)
    apply (wp threadSet_tcbDomain_triv')
  apply (auto)
  done

lemma threadSet_tcbDomain_update_invs':
  "\<lbrace>invs' and tcb_at' t and sch_act_simple
     and obj_at' (Not \<circ> tcbQueued) t 
     and (\<lambda>s. ksSchedulerAction s \<noteq> ResumeCurrentThread)
     and K (domain \<le> maxDomain)\<rbrace>
     threadSet (tcbDomain_update (\<lambda>_. domain)) t
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: invs'_def valid_state'_def split del: split_if)
  apply (rule hoare_pre)
  apply (wp_trace
               threadSet_valid_pspace'
               threadSet_valid_queues
               threadSet_valid_queues'
               threadSet_state_refs_of'T_P[where f'=id and P'=False and Q=\<bottom>]
               threadSet_iflive'T
               threadSet_ifunsafe'T
               threadSet_idle'T
               threadSet_global_refsT
               threadSet_cur
               irqs_masked_lift
               valid_irq_node_lift
               valid_irq_handlers_lift''
               threadSet_ctes_ofT
               threadSet_tcbDomain_update_ct_not_inQ
               threadSet_valid_dom_schedule'
               threadSet_tcbDomain_update_sch_act_wf
               threadSet_tcbDomain_update_ct_idle_or_in_cur_domain'
             | clarsimp simp: tcb_cte_cases_def)+
  apply (auto simp: inQ_def obj_at'_def)
done

(* FIXME: sseefried: Clean up proof *)
lemma set_domain_setDomain_corres:
  "corres dc
     (valid_etcbs and valid_sched and tcb_at tptr)
     (invs'  and sch_act_simple
             and tcb_at' tptr and (\<lambda>s. new_dom \<le> maxDomain))
     (set_domain tptr new_dom)
     (setDomain tptr new_dom)"
  apply (rule corres_gen_asm2)
  apply (simp add: set_domain_def setDomain_def thread_set_domain_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF _ gct_corres])
      apply (rule corres_split[OF _ tcbSchedDequeue_corres])
        apply (rule corres_split[OF _ ethread_set_corres])
                 apply (rule corres_split[OF _ gts_isRunnable_corres])
                   apply simp
                   apply (rule corres_split[OF corres_when[OF refl]])
                      apply (rule rescheduleRequired_corres)
                     apply clarsimp
                     apply (rule corres_when[OF refl])
                     apply (rule tcbSchedEnqueue_corres)
                    apply (wp hoare_drop_imps hoare_vcg_conj_lift | clarsimp| assumption)+
          apply (clarsimp simp: etcb_relation_def)
         apply ((wp_trace hoare_vcg_conj_lift hoare_vcg_disj_lift | clarsimp)+)[1]
        apply clarsimp
        apply (rule_tac Q="\<lambda>_. valid_objs' and valid_queues' and valid_queues and
          (\<lambda>s. sch_act_wf (ksSchedulerAction s) s) and tcb_at' tptr"
          in hoare_strengthen_post[rotated])
         apply (auto simp: invs'_def valid_state'_def sch_act_wf_weak st_tcb_at'_def o_def)[1]
        apply (wp threadSet_valid_objs' threadSet_valid_queues'_no_state
          threadSet_valid_queues_no_state
          threadSet_st_tcb_no_state | simp)+
      apply (rule_tac Q = "\<lambda>r s. invs' s \<and> (\<forall>p. tptr \<notin> set (ksReadyQueues s p)) \<and> sch_act_simple s
        \<and>  tcb_at' tptr s" in hoare_strengthen_post[rotated])
       apply (clarsimp simp:invs'_def valid_state'_def valid_pspace'_def sch_act_simple_def)
       apply (clarsimp simp:valid_tcb'_def)
       apply (drule(1) bspec)
       apply (clarsimp simp:tcb_cte_cases_def)
       apply fastforce
      apply (wp hoare_vcg_all_lift Tcb_R.tcbSchedDequeue_not_in_queue)
   apply clarsimp
   apply (frule tcb_at_is_etcb_at)
    apply simp+
   apply (auto elim: tcb_at_is_etcb_at valid_objs'_maxDomain valid_objs'_maxPriority st_tcb'_weakenE
               simp: valid_sched_def valid_sched_action_def)
done


(* FIXME end move *)
lemma pinv_corres:
  "\<lbrakk> inv_relation i i'; call \<longrightarrow> block \<rbrakk> \<Longrightarrow>
   corres (intr \<oplus> op=)
     (einvs and valid_invocation i
            and simple_sched_action
            and ct_active
            and (\<lambda>s. (\<exists>w w2 b. i = Invocations_A.InvokeEndpoint w w2 b) \<longrightarrow> st_tcb_at simple (cur_thread s) s))
     (invs' and sch_act_simple and valid_invocation' i' and ct_active' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)))
     (perform_invocation block call i) (performInvocation block call i')"
  apply (simp add: performInvocation_def)
  apply (case_tac i)
          apply (clarsimp simp: o_def liftE_bindE)
          apply (rule corres_guard_imp)
            apply (rule corres_split[OF corres_returnOkTT])
               apply simp
              apply (erule corres_guard_imp [OF inv_untyped_corres])
               apply assumption+
             apply wp
          apply simp+
         apply (rule corres_guard_imp)
           apply (rule corres_split [OF _ gct_corres])
             apply simp
             apply (rule corres_split [OF _ send_ipc_corres])
                apply (rule corres_trivial)
                apply simp
               apply simp
              apply wp
          apply (clarsimp simp: ct_in_state_def)
          apply (fastforce elim: st_tcb_ex_cap)
         apply (clarsimp simp: pred_conj_def invs'_def cur_tcb'_def simple_sane_strg
                               sch_act_simple_def)
        apply (rule corres_guard_imp)
          apply (simp add: liftE_bindE)
          apply (rule corres_split [OF _ send_async_ipc_corres])
            apply (rule corres_trivial)
            apply (simp add: returnOk_def)
           apply wp
         apply (simp+)[2]
       apply simp
       apply (rule corres_guard_imp)
         apply (rule corres_split_eqr [OF _ gct_corres])
           apply (rule corres_split_nor [OF _ do_reply_transfer_corres])
             apply (rule corres_trivial, simp)
            apply wp
        apply (clarsimp simp: tcb_at_invs)
        apply (clarsimp simp: invs_def valid_state_def valid_pspace_def)
       apply (clarsimp simp: tcb_at_invs')
       apply (fastforce elim!: cte_wp_at_weakenE')
      apply (clarsimp simp: liftME_def)
      apply (rule corres_guard_imp)
        apply (erule tcbinv_corres)
       apply (simp)+
      -- "domain cap"
      apply (clarsimp simp: invoke_domain_def)
      apply (rule corres_guard_imp)
      apply (rule corres_split [OF _ set_domain_setDomain_corres])
        apply (rule corres_trivial, simp)
       apply (wp)
       apply (clarsimp+)[2]
     -- "CNodes"
     apply clarsimp
     apply (rule corres_guard_imp)
       apply (rule corres_splitEE [OF _ inv_cnode_corres])
          apply (rule corres_trivial, simp add: returnOk_def)
         apply assumption
        apply wp
      apply (clarsimp+)[2]
    apply (clarsimp simp: liftME_def[symmetric] o_def dc_def[symmetric])
    apply (rule corres_guard_imp, rule invoke_irq_control_corres, simp+)
   apply (clarsimp simp: liftME_def[symmetric] o_def dc_def[symmetric])
   apply (rule corres_guard_imp, rule invoke_irq_handler_corres, simp+)
  apply clarsimp
  apply (rule corres_guard_imp)
    apply (rule inv_arch_corres, assumption)
   apply (clarsimp+)[2]
  done

lemma sendAsyncIPC_tcb_at'[wp]:
  "\<lbrace>tcb_at' t\<rbrace>
     sendAsyncIPC aepptr bdg val
   \<lbrace>\<lambda>rv. tcb_at' t\<rbrace>"
  apply (simp add: sendAsyncIPC_def doAsyncTransfer_def
              cong: list.case_cong async_endpoint.case_cong)
  apply (wp aep'_cases_weak_wp list_cases_weak_wp)
  apply simp
  done

lemmas checkCap_inv_typ_at'
  = checkCap_inv[where P="\<lambda>s. P (typ_at' T p s)", standard]

crunch typ_at'[wp]: restart "\<lambda>s. P (typ_at' T p s)"
crunch typ_at'[wp]: performTransfer "\<lambda>s. P (typ_at' T p s)"

lemma invokeTCB_typ_at'[wp]:
  "\<lbrace>\<lambda>s. P (typ_at' T p s)\<rbrace>
     invokeTCB tinv
   \<lbrace>\<lambda>rv s. P (typ_at' T p s)\<rbrace>"
  apply (cases tinv,
         simp_all add: invokeTCB_def
                       getThreadBufferSlot_def locateSlot_conv
            split del: split_if)
   apply (simp only: cases_simp if_cancel simp_thms conj_ac pred_conj_def
                     Let_def split_def getThreadVSpaceRoot
          | (simp split del: split_if cong: if_cong)
          | (wp mapM_x_wp[where S=UNIV, simplified]
                checkCap_inv_typ_at'
                option_cases_weak_wp)[1]
          | wpcw)+
  done

lemmas invokeTCB_typ_ats[wp] = typ_at_lifts [OF invokeTCB_typ_at']

crunch typ_at'[wp]: doReplyTransfer "\<lambda>s. P (typ_at' T p s)"
  (wp: hoare_drop_imps)
lemmas doReplyTransfer_typ_ats[wp] = typ_at_lifts [OF doReplyTransfer_typ_at']
crunch typ_at'[wp]: invokeIRQControl "\<lambda>s. P (typ_at' T p s)"
lemmas invokeIRQControl_typ_ats[wp] = typ_at_lifts [OF invokeIRQControl_typ_at']
crunch typ_at'[wp]: invokeIRQHandler "\<lambda>s. P (typ_at' T p s)"
lemmas invokeIRQHandler_typ_ats[wp] = typ_at_lifts [OF invokeIRQHandler_typ_at']

crunch tcb_at'[wp]: setDomain "tcb_at' tptr"
  (simp: crunch_simps)

lemma pinv_tcb'[wp]:
  "\<lbrace>invs' and st_tcb_at' active' tptr
          and valid_invocation' i and ct_active'\<rbrace>
     RetypeDecls_H.performInvocation block call i
   \<lbrace>\<lambda>rv. tcb_at' tptr\<rbrace>"
  apply (simp add: performInvocation_def)
  apply (case_tac i, simp_all)
          apply (wp invokeArch_tcb_at' | clarsimp simp: st_tcb_at')+
  done

lemma setQueue_cte_wp_at[wp]:
  "\<lbrace>cte_wp_at' P p\<rbrace> setQueue d prio queue \<lbrace>\<lambda>rv. cte_wp_at' P p\<rbrace>"
  apply (simp add: setQueue_def)
  apply wp
  apply (clarsimp elim!: cte_wp_at'_pspaceI)
  done

lemma sts_cte_at[wp]:
  "\<lbrace>cte_at' p\<rbrace> setThreadState st t \<lbrace>\<lambda>rv. cte_at' p\<rbrace>"
  apply (simp add: setThreadState_def)
  apply (wp|simp)+
  done

lemma sts_valid_inv'[wp]:
  "\<lbrace>valid_invocation' i\<rbrace> setThreadState st t \<lbrace>\<lambda>rv. valid_invocation' i\<rbrace>"
  apply (case_tac i, simp_all add: sts_valid_untyped_inv' sts_valid_arch_inv')
        apply (wp | simp)+
     apply (case_tac tcbinvocation,
            simp_all add: setThreadState_tcb',
            auto  intro!: hoare_vcg_conj_lift hoare_vcg_disj_lift
               simp only: imp_conv_disj simp_thms pred_conj_def,
            auto  intro!: hoare_vcg_prop
                          sts_cap_to' sts_cte_cap_to'
                          setThreadState_typ_ats
                   split: option.splits)[1]
    apply (case_tac cnode_invocation, simp_all add: cte_wp_at_ctes_of)
          apply (wp | simp)+
   apply (case_tac irqcontrol_invocation, simp_all)
   apply (wp | simp add: irq_issued'_def)+
  apply (case_tac irqhandler_invocation, simp_all)
  apply (wp hoare_vcg_ex_lift ex_cte_cap_to'_pres | simp)+
  done

(* FIXME futz move to TCB *)
crunch inv[wp]: decodeDomainInvocation P
  (wp: crunch_wps simp: crunch_simps)

lemma decode_inv_inv'[wp]:
  "\<lbrace>P\<rbrace> decodeInvocation label args cap_index slot cap excaps \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (simp add: decodeInvocation_def Let_def
              split del: split_if
              cong: if_cong)
  apply (rule hoare_pre)
   apply (wp decodeTCBInv_inv |
          simp only: o_def |
          clarsimp split: capability.split_asm simp: isCap_defs)+
  done

lemma diminished_IRQHandler' [simp]:
  "diminished' (IRQHandlerCap h) cap = (cap = IRQHandlerCap h)"
  apply (rule iffI)
   apply (drule diminished_capMaster)
   apply clarsimp
  apply (simp add: diminished'_def maskCapRights_def isCap_simps Let_def)
  done

lemma diminished_ReplyCap' [simp]:
  "diminished' (ReplyCap x y) cap = (cap = ReplyCap x y)"
  apply (rule iffI)
   apply (clarsimp simp: diminished'_def maskCapRights_def Let_def split del: split_if)
   apply (cases cap, simp_all add: isCap_simps)[1]
   apply (simp add: ArchRetype_H.maskCapRights_def split: arch_capability.splits)
  apply (simp add: diminished'_def maskCapRights_def isCap_simps Let_def)
  done

lemma diminished_IRQControlCap' [simp]:
  "diminished' IRQControlCap cap = (cap = IRQControlCap)"
  apply (rule iffI)
   apply (drule diminished_capMaster)
   apply clarsimp
  apply (simp add: diminished'_def maskCapRights_def isCap_simps Let_def)
  done

(* FIXME: sseefried:  futz strengthen precondition, move to TCB *)
lemma dec_dom_inv_wf[wp]:
  "\<lbrace>invs' and (\<lambda>s. \<forall>x \<in> set excaps. s \<turnstile>' fst x)\<rbrace>
  decodeDomainInvocation label args excaps 
  \<lbrace>\<lambda>x s. tcb_at' (fst x) s \<and> snd x \<le> maxDomain\<rbrace>, -"
  apply (simp add:decodeDomainInvocation_def)
  apply (wp whenE_throwError_wp | wpc |simp)+
  apply clarsimp
  apply (drule_tac x = "hd excaps" in bspec)
   apply (rule hd_in_set)
   apply (simp add:null_def)
  apply (simp add:valid_cap'_def)
  apply (simp add:not_le)
  apply (simp add:ucast_nat_def[symmetric])
  apply (rule word_of_nat_le)
  apply (simp add:numDomains_def maxDomain_def)
  done

lemma decode_inv_wf'[wp]:
  "\<lbrace>valid_cap' cap and invs' and sch_act_simple
          and cte_wp_at' (diminished' cap \<circ> cteCap) slot and real_cte_at' slot
          and (\<lambda>s. \<forall>r\<in>zobj_refs' cap. ex_nonz_cap_to' r s)
          and (\<lambda>s. \<forall>r\<in>cte_refs' cap (irq_node' s). ex_cte_cap_to' r s)
          and (\<lambda>s. \<forall>cap \<in> set excaps. \<forall>r\<in>cte_refs' (fst cap) (irq_node' s). ex_cte_cap_to' r s)
          and (\<lambda>s. \<forall>cap \<in> set excaps. \<forall>r\<in>zobj_refs' (fst cap). ex_nonz_cap_to' r s)
          and (\<lambda>s. \<forall>x \<in> set excaps. cte_wp_at' (diminished' (fst x) o cteCap) (snd x) s)
          and (\<lambda>s. \<forall>x \<in> set excaps. s \<turnstile>' fst x)
          and (\<lambda>s. \<forall>x \<in> set excaps. real_cte_at' (snd x) s)
          and (\<lambda>s. \<forall>x \<in> set excaps. ex_cte_cap_wp_to' isCNodeCap (snd x) s)
          and (\<lambda>s. \<forall>x \<in> set excaps. cte_wp_at' (badge_derived' (fst x) o cteCap) (snd x) s)
          and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
     decodeInvocation label args cap_index slot cap excaps
   \<lbrace>valid_invocation'\<rbrace>,-"
  apply (case_tac cap, simp_all add: decodeInvocation_def Let_def isCap_defs uncurry_def split_def
              split del: split_if
              cong: if_cong)
          apply ((rule hoare_pre,
                 ((wp_trace decodeTCBInv_wf | simp add: o_def)+)[1],
                 clarsimp simp: valid_cap'_def cte_wp_at_ctes_of
                   | (rule exI, rule exI, erule (1) conjI))+)
  done

lemma ct_active_imp_simple'[elim!]:
  "ct_active' s \<Longrightarrow> st_tcb_at' simple' (ksCurThread s) s"
  by (clarsimp simp: ct_in_state'_def
              elim!: st_tcb'_weakenE)

lemma ct_running_imp_simple'[elim!]:
  "ct_running' s \<Longrightarrow> st_tcb_at' simple' (ksCurThread s) s"
  by (clarsimp simp: ct_in_state'_def
              elim!: st_tcb'_weakenE)

lemma active_ex_cap'[elim]:
  "\<lbrakk> ct_active' s; if_live_then_nonz_cap' s \<rbrakk>
     \<Longrightarrow> ex_nonz_cap_to' (ksCurThread s) s"
  by (fastforce simp: ct_in_state'_def elim!: st_tcb_ex_cap'')

crunch st_tcb'[wp]: handleFaultReply "st_tcb_at' P t"
crunch it[wp]: handleFaultReply "\<lambda>s. P (ksIdleThread s)"

lemma handleFaultReply_invs[wp]:
  "\<lbrace>invs' and tcb_at' t\<rbrace> handleFaultReply x t label msg \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: handleFaultReply_def)
  apply (case_tac x, simp_all)
     apply (wp | simp)+
  done 

crunch sch_act_simple[wp]: handleFaultReply sch_act_simple
  (wp: crunch_wps)

lemma transferCaps_non_null_cte_wp_at':
  assumes PUC: "\<And>cap. P cap \<Longrightarrow> \<not> isUntypedCap cap"
  shows "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>
     transferCaps info caps ep rcvr rcvBuf dim
   \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>"
proof -
  have CTEF: "\<And>P p s. \<lbrakk> cte_wp_at' P p s; \<And>cte. P cte \<Longrightarrow> False \<rbrakk> \<Longrightarrow> False"
    by (erule cte_wp_atE', auto)
  show ?thesis
    unfolding transferCaps_def
    apply (wp | wpc)+
        apply (rule transferCapsToSlots_pres2)
         apply (rule hoare_weaken_pre [OF cteInsert_weak_cte_wp_at3])
         apply (rule PUC,simp)
         apply (clarsimp simp: cte_wp_at_ctes_of)
        apply (wp hoare_vcg_all_lift static_imp_wp | simp add:ball_conj_distrib)+
    done
qed

crunch cte_wp_at' [wp]: setMessageInfo "cte_wp_at' P p"

lemma copyMRs_cte_wp_at'[wp]:
  "\<lbrace>cte_wp_at' P ptr\<rbrace> copyMRs sender sendBuf receiver recvBuf n \<lbrace>\<lambda>_. cte_wp_at' P ptr\<rbrace>"
  unfolding copyMRs_def
  apply (wp mapM_wp | wpc | simp add: split_def | rule equalityD1)+
  done

lemma doNormalTransfer_non_null_cte_wp_at':
  assumes PUC: "\<And>cap. P cap \<Longrightarrow> \<not> isUntypedCap cap"
  shows
  "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>
   doNormalTransfer st send_buffer ep b gr rt recv_buffer dim
   \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>"
  unfolding doNormalTransfer_def
  apply (wp transferCaps_non_null_cte_wp_at' | simp add:PUC)+
  done

lemma setMRs_cte_wp_at'[wp]:
  "\<lbrace>cte_wp_at' P ptr\<rbrace> setMRs thread buffer messageData \<lbrace>\<lambda>_. cte_wp_at' P ptr\<rbrace>"
  by (simp add: setMRs_def zipWithM_x_mapM split_def, wp crunch_wps)

lemma doFaultTransfer_cte_wp_at'[wp]:
  "\<lbrace>cte_wp_at' P ptr\<rbrace>
   doFaultTransfer badge sender receiver receiverIPCBuffer
   \<lbrace>\<lambda>_. cte_wp_at' P ptr\<rbrace>"
  unfolding doFaultTransfer_def
  apply (wp | wpc | simp add: split_def)+
  done

lemma doIPCTransfer_non_null_cte_wp_at':
  assumes PUC: "\<And>cap. P cap \<Longrightarrow> \<not> isUntypedCap cap"
  shows
  "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>
   doIPCTransfer sender endpoint badge grant receiver dim
   \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> cteCap cte \<noteq> capability.NullCap) ptr\<rbrace>"
  unfolding doIPCTransfer_def
  apply (wp doNormalTransfer_non_null_cte_wp_at' hoare_drop_imp hoare_allI | wpc | clarsimp simp:PUC)+
  done

lemma doIPCTransfer_non_null_cte_wp_at2':
  fixes P
  assumes PNN: "\<And>cte. P (cteCap cte) \<Longrightarrow> cteCap cte \<noteq> capability.NullCap"
   and    PUC: "\<And>cap. P cap \<Longrightarrow> \<not> isUntypedCap cap"
  shows "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) ptr\<rbrace>
         doIPCTransfer sender endpoint badge grant receiver dim
         \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte)) ptr\<rbrace>"
  proof -
    have PimpQ: "\<And>P Q ptr s. \<lbrakk> cte_wp_at' (\<lambda>cte. P (cteCap cte)) ptr s;
                               \<And>cte. P (cteCap cte) \<Longrightarrow> Q (cteCap cte) \<rbrakk>
                             \<Longrightarrow> cte_wp_at' (\<lambda>cte. P (cteCap cte) \<and> Q (cteCap cte)) ptr s"
      by (erule cte_wp_at_weakenE', clarsimp)
    show ?thesis
      apply (rule hoare_chain [OF doIPCTransfer_non_null_cte_wp_at'])
       apply (erule PUC)
       apply (erule PimpQ)
       apply (drule PNN, clarsimp)
      apply (erule cte_wp_at_weakenE')
      apply (clarsimp)
      done
  qed

lemma st_tcb_at'_eqD:
  "\<lbrakk> st_tcb_at' (\<lambda>s. s = st) t s; st_tcb_at' (\<lambda>s. s = st') t s \<rbrakk> \<Longrightarrow> st = st'"
  by (clarsimp simp add: st_tcb_at'_def obj_at'_def)

lemma isReply_awaiting_reply':
  "isReply st = awaiting_reply' st"
  by (case_tac st, (clarsimp simp add: isReply_def)+)

lemma doReply_invs[wp]:
  "\<lbrace>tcb_at' t and tcb_at' t' and
    cte_wp_at' (\<lambda>cte. cteCap cte = ReplyCap t False) slot and
    invs' and sch_act_simple\<rbrace>
     doReplyTransfer t' t slot
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: doReplyTransfer_def liftM_def)
  apply (rule hoare_seq_ext [OF _ gts_sp'])
  apply (rule hoare_seq_ext [OF _ assert_sp])
  apply (rule hoare_seq_ext [OF _ getCTE_sp])
  apply (wp, wpc)
       apply (wp)
       apply (wp_once sts_invs_minor'')
       apply (simp)
       apply (wp_once sts_st_tcb')
       apply (wp)[1]
      apply (rule_tac Q="\<lambda>rv s. invs' s
                                 \<and> t \<noteq> ksIdleThread s
                                 \<and> st_tcb_at' awaiting_reply' t s"
               in hoare_post_imp)
       apply (clarsimp)
       apply (frule_tac t=t in invs'_not_runnable_not_queued)
        apply (erule st_tcb'_weakenE, case_tac st, clarsimp+)
       apply (rule conjI, erule st_tcb'_weakenE, case_tac st, clarsimp+)
       apply (rule conjI, rule impI, erule st_tcb'_weakenE, case_tac st)
               apply (clarsimp | drule(1) obj_at_conj')+
       apply (clarsimp simp: invs'_def valid_state'_def ct_in_state'_def)
       apply (drule(1) st_tcb_at_conj')
       apply (subgoal_tac "st_tcb_at' (\<lambda>_. False) (ksCurThread s) s")
        apply (clarsimp)
       apply (erule_tac P="\<lambda>st. awaiting_reply' st \<and> activatable' st"
                in st_tcb'_weakenE)
       apply (case_tac st, clarsimp+)
      apply (wp cteDeleteOne_reply_st_tcb_at)
     apply (clarsimp)
     apply (rule_tac Q="\<lambda>_. (\<lambda>s. t \<noteq> ksIdleThread s)
                        and cte_wp_at' (\<lambda>cte. cteCap cte = capability.ReplyCap t False) slot"
              in hoare_strengthen_post [rotated])
      apply clarsimp
      apply (erule cte_wp_at_weakenE', simp)
     apply (wp)
     apply (rule hoare_strengthen_post [OF doIPCTransfer_non_null_cte_wp_at'])
      apply (erule conjE)
      apply assumption
     apply (erule cte_wp_at_weakenE')
     apply (fastforce)
    apply (wp sts_invs_minor'' sts_st_tcb' static_imp_wp)
          apply (rule_tac Q="\<lambda>rv s. invs' s \<and> sch_act_simple s
                                 \<and> st_tcb_at' awaiting_reply' t s
                                 \<and> t \<noteq> ksIdleThread s"
                       in hoare_post_imp)
           apply (clarsimp)
           apply (frule_tac t=t in invs'_not_runnable_not_queued)
            apply (erule st_tcb'_weakenE, case_tac st, clarsimp+)
           apply (rule conjI, erule st_tcb'_weakenE, case_tac st, clarsimp+)
           apply (rule conjI, rule impI, erule st_tcb'_weakenE, case_tac st)
                   apply (clarsimp | drule(1) obj_at_conj')+
               apply (clarsimp simp: invs'_def valid_state'_def ct_in_state'_def)
               apply (drule(1) st_tcb_at_conj')
               apply (subgoal_tac "st_tcb_at' (\<lambda>_. False) (ksCurThread s) s")
                apply (clarsimp)
               apply (erule_tac P="\<lambda>st. awaiting_reply' st \<and> activatable' st"
                        in st_tcb'_weakenE)
               apply (case_tac st, clarsimp+)
              apply (wp threadSet_invs_trivial threadSet_st_tcb_at2 static_imp_wp
                      | clarsimp simp add: inQ_def)+
            apply (rule_tac Q="\<lambda>_. invs' and tcb_at' t
                                   and sch_act_simple and st_tcb_at' awaiting_reply' t"
                     in hoare_strengthen_post [rotated])
             apply (clarsimp)
             apply (rule conjI)
              apply (clarsimp simp add: invs'_def valid_state'_def valid_idle'_def)
              apply (rule conjI)
               apply clarsimp
              apply clarsimp
              apply (drule(1) st_tcb_at'_eqD, simp)
             apply clarsimp
             apply (rule conjI)
              apply (clarsimp simp add: invs'_def valid_state'_def valid_idle'_def)
              apply (erule st_tcb'_weakenE, clarsimp)
             apply (rule conjI)
              apply (clarsimp simp add: invs'_def valid_state'_def valid_idle'_def)
              apply (drule(1) st_tcb_at'_eqD, simp)
             apply (rule conjI)
              apply clarsimp
              apply (frule invs'_not_runnable_not_queued)
              apply (erule st_tcb'_weakenE, clarsimp)
              apply (frule (1) not_tcbQueued_not_ksQ)
              apply simp
             apply clarsimp
            apply (wp cteDeleteOne_reply_st_tcb_at hoare_drop_imp hoare_allI)
  apply (clarsimp simp add: isReply_awaiting_reply' cte_wp_at_ctes_of)
  apply (auto dest!: st_tcb_idle'[rotated] simp:isCap_simps)
  done

lemma ct_active_runnable' [simp]:
  "ct_active' s \<Longrightarrow> ct_in_state' runnable' s"
  by (fastforce simp: ct_in_state'_def elim!: st_tcb'_weakenE)

lemma valid_irq_node_tcbSchedEnqueue[wp]:
  "\<lbrace>\<lambda>s. valid_irq_node' (irq_node' s) s \<rbrace> tcbSchedEnqueue ptr 
  \<lbrace>\<lambda>rv s'. valid_irq_node' (irq_node' s') s'\<rbrace>"
  apply (rule hoare_pre)
  apply (simp add:valid_irq_node'_def )
  apply (wp hoare_unless_wp hoare_vcg_all_lift | wps)+
  apply (simp add:tcbSchedEnqueue_def)
  apply (wp hoare_unless_wp| simp)+
  apply (simp add:valid_irq_node'_def)
  done

lemma updateDomain_valid_pspace[wp]:
  "\<lbrace>\<lambda>s. valid_pspace' s \<and> ds \<le> maxDomain \<rbrace> threadSet (tcbDomain_update (\<lambda>_. ds)) thread 
  \<lbrace>\<lambda>r. valid_pspace'\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (wp threadSet_valid_pspace'T)
  apply (auto simp:tcb_cte_cases_def)
  done

lemma rescheduleRequired_valid_queues_but_ct_domain:
  "\<lbrace>\<lambda>s. Invariants_H.valid_queues s \<and> valid_objs' s 
     \<and> (\<forall>x. ksSchedulerAction s = SwitchToThread x \<longrightarrow> st_tcb_at' runnable' x s) \<rbrace>
    rescheduleRequired
   \<lbrace>\<lambda>_. Invariants_H.valid_queues\<rbrace>"
  apply (simp add: rescheduleRequired_def)
  apply (wp | wpc | simp)+
  done

lemma rescheduleRequired_valid_queues'_but_ct_domain:
  "\<lbrace>\<lambda>s. valid_queues' s 
     \<and> (\<forall>x. ksSchedulerAction s = SwitchToThread x \<longrightarrow> st_tcb_at' runnable' x s) 
   \<rbrace>
    rescheduleRequired
   \<lbrace>\<lambda>_. valid_queues'\<rbrace>"
  apply (simp add: rescheduleRequired_def)
  apply (wp | wpc | simp | fastforce simp: valid_queues'_def)+
  done

lemma tcbSchedEnqueue_valid_action:
  "\<lbrace>\<lambda>s. \<forall>x. ksSchedulerAction s = SwitchToThread x \<longrightarrow> st_tcb_at' runnable' x s\<rbrace>
  tcbSchedEnqueue ptr 
  \<lbrace>\<lambda>rv s. \<forall>x. ksSchedulerAction s = SwitchToThread x \<longrightarrow> st_tcb_at' runnable' x s\<rbrace>"
  apply (wp_trace hoare_vcg_all_lift hoare_vcg_imp_lift)
  apply clarsimp
  done

abbreviation (input) "all_invs_but_sch_extra \<equiv>
    \<lambda>s. valid_pspace' s \<and> Invariants_H.valid_queues s \<and>
    sym_refs (state_refs_of' s) \<and>
    if_live_then_nonz_cap' s \<and>
    if_unsafe_then_cap' s \<and>
    valid_idle' s \<and>
    valid_global_refs' s \<and>
    valid_arch_state' s \<and>
    valid_irq_node' (irq_node' s) s \<and>
    valid_irq_handlers' s \<and>
    valid_irq_states' s \<and>
    irqs_masked' s \<and>
    valid_machine_state' s \<and> 
    cur_tcb' s \<and>
    valid_queues' s \<and>
    valid_pde_mappings' s \<and> pspace_domain_valid s \<and>
    ksCurDomain s \<le> maxDomain \<and> valid_dom_schedule' s \<and> 
    (\<forall>x. ksSchedulerAction s = SwitchToThread x \<longrightarrow> st_tcb_at' runnable' x s)"


lemma rescheduleRequired_all_invs_but_extra:
  "\<lbrace>\<lambda>s. all_invs_but_sch_extra s\<rbrace>
    rescheduleRequired \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: invs'_def valid_state'_def)
  apply (rule hoare_pre)
  apply (wp add:rescheduleRequired_ct_not_inQ
    rescheduleRequired_sch_act' 
    rescheduleRequired_valid_queues_but_ct_domain
    rescheduleRequired_valid_queues'_but_ct_domain
    valid_irq_node_lift valid_irq_handlers_lift''
    irqs_masked_lift cur_tcb_lift
    del:rescheduleRequired_valid_queues')
  apply auto
  done

lemma threadSet_all_invs_but_sch_extra:
  shows      "\<lbrace> tcb_at' t and (\<lambda>s. (\<forall>p. t \<notin> set (ksReadyQueues s p))) and
                all_invs_but_sch_extra and sch_act_simple and 
                K (ds \<le> maxDomain) \<rbrace>
                threadSet (tcbDomain_update (\<lambda>_. ds)) t
              \<lbrace>\<lambda>rv. all_invs_but_sch_extra \<rbrace>"
  apply (rule hoare_gen_asm)
  apply (rule hoare_pre)
  apply (wp threadSet_valid_pspace'T_P[where P = False and Q = \<top>])
  apply (simp add:tcb_cte_cases_def)+
   apply (wp 
     threadSet_valid_pspace'T_P
     threadSet_state_refs_of'T_P[where f'=id and P'=False and Q=\<top>]
     threadSet_idle'T
     threadSet_global_refsT
     threadSet_cur
     irqs_masked_lift
     valid_irq_node_lift
     valid_irq_handlers_lift''
     threadSet_ctes_ofT
     threadSet_not_inQ
     threadSet_valid_queues'_no_state
     threadSet_tcbDomain_update_ct_idle_or_in_cur_domain'
     threadSet_valid_queues
     threadSet_valid_dom_schedule'
     
     threadSet_iflive'T
     threadSet_ifunsafe'T
     
     | simp add:tcb_cte_cases_def)+
   apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift threadSet_st_tcb_no_state | simp)+
  apply (clarsimp simp:sch_act_simple_def)
  apply (intro conjI)
   apply fastforce+
  done

lemma threadSet_not_curthread_ct_domain:
  "\<lbrace>\<lambda>s. ptr \<noteq> ksCurThread s \<and> ct_idle_or_in_cur_domain' s\<rbrace> threadSet f ptr \<lbrace>\<lambda>rv. ct_idle_or_in_cur_domain'\<rbrace>"
  apply (simp add:ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)
  apply (wp hoare_vcg_imp_lift hoare_vcg_disj_lift | wps)+
  apply clarsimp
  done

lemma setDomain_invs':
  "\<lbrace>invs' and sch_act_simple and ct_active' and
  (tcb_at' ptr and
  (\<lambda>s. sch_act_not ptr s) and
  (\<lambda>y. domain \<le> maxDomain))\<rbrace>
  setDomain ptr domain \<lbrace>\<lambda>y. invs'\<rbrace>"
  apply (simp add:setDomain_def )
  apply (wp_trace add: hoare_when_wp static_imp_wp static_imp_conj_wp rescheduleRequired_all_invs_but_extra
    tcbSchedEnqueue_valid_action hoare_vcg_if_lift2)
    apply (rule_tac Q = "\<lambda>r s. all_invs_but_sch_extra s \<and> curThread = ksCurThread s
      \<and> (ptr \<noteq> curThread \<longrightarrow> ct_not_inQ s \<and> sch_act_wf (ksSchedulerAction s) s \<and> ct_idle_or_in_cur_domain' s)"
      in hoare_strengthen_post[rotated])
     apply (clarsimp simp:invs'_def valid_state'_def st_tcb_at'_def[symmetric]
       valid_pspace'_def)
     apply (erule st_tcb_ex_cap'')
      apply simp
     apply (case_tac st,simp_all)[1]
    apply (rule hoare_strengthen_post[OF hoare_vcg_conj_lift])
      apply (rule threadSet_all_invs_but_sch_extra)
     prefer 2
     apply clarsimp
     apply assumption
   apply (wp static_imp_wp threadSet_st_tcb_no_state threadSet_not_curthread_ct_domain
     threadSet_tcbDomain_update_ct_not_inQ | simp)+
   apply (rule_tac Q = "\<lambda>r s. invs' s \<and> curThread = ksCurThread s \<and> sch_act_simple s
      \<and> domain \<le> maxDomain 
      \<and> (ptr \<noteq> curThread \<longrightarrow> ct_not_inQ s \<and> sch_act_not ptr s)"
      in hoare_strengthen_post[rotated])
    apply (clarsimp simp:invs'_def valid_state'_def)
   apply (wp hoare_vcg_imp_lift)
   apply (clarsimp simp:invs'_def valid_pspace'_def valid_state'_def)
   apply (rule conjI)
    apply (erule(1) valid_objs_valid_tcbE,simp add:valid_tcb'_def)+
  apply simp
  done

lemma performInv_invs'[wp]:
  "\<lbrace>invs' and sch_act_simple
          and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))
          and ct_active' and valid_invocation' i\<rbrace>
     RetypeDecls_H.performInvocation block call i \<lbrace>\<lambda>rv. invs'\<rbrace>"
  unfolding performInvocation_def
  apply (cases i)
  apply ((clarsimp simp: simple_sane_strg sch_act_simple_def
                         ct_not_ksQ sch_act_sane_def
                  | wp tcbinv_invs' arch_performInvocation_invs'
                       setDomain_invs'
                  | rule conjI | erule active_ex_cap')+)
  done

lemma getSlotCap_to_refs[wp]:
  "\<lbrace>\<top>\<rbrace> getSlotCap ref \<lbrace>\<lambda>rv s. \<forall>r\<in>zobj_refs' rv. ex_nonz_cap_to' r s\<rbrace>"
  by (simp add: getSlotCap_def | wp)+

lemma lcs_valid' [wp]:
  "\<lbrace>invs'\<rbrace> lookupCapAndSlot t xs \<lbrace>\<lambda>x s. s \<turnstile>' fst x\<rbrace>, -"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp|clarsimp simp: split_def)+
  done

lemma lcs_ex_cap_to' [wp]:
  "\<lbrace>invs'\<rbrace> lookupCapAndSlot t xs \<lbrace>\<lambda>x s. \<forall>r\<in>cte_refs' (fst x) (irq_node' s). ex_cte_cap_to' r s\<rbrace>, -"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp | simp add: split_def)+
  done
 
lemma lcs_ex_nonz_cap_to' [wp]:
  "\<lbrace>invs'\<rbrace> lookupCapAndSlot t xs \<lbrace>\<lambda>x s. \<forall>r\<in>zobj_refs' (fst x). ex_nonz_cap_to' r s\<rbrace>, -"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp | simp add: split_def)+
  done
 
lemma lcs_cte_at' [wp]:
  "\<lbrace>valid_objs'\<rbrace> lookupCapAndSlot t xs \<lbrace>\<lambda>rv s. cte_at' (snd rv) s\<rbrace>,-"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp|simp)+
  done
 
lemma lcs_eq [wp]:
  "\<lbrace>valid_objs'\<rbrace> lookupCapAndSlot t xs \<lbrace>\<lambda>rv s. cte_wp_at' (\<lambda>cte. cteCap cte = fst rv) (snd rv) s\<rbrace>,-"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp getSlotCap_cte_wp_at_rv | simp)+
  done

lemma lec_ex_cap_to' [wp]:
  "\<lbrace>invs'\<rbrace>
  lookupExtraCaps t xa mi 
  \<lbrace>\<lambda>rv s. (\<forall>cap \<in> set rv. \<forall>r\<in>cte_refs' (fst cap) (irq_node' s). ex_cte_cap_to' r s)\<rbrace>, -"
  unfolding lookupExtraCaps_def
  apply (cases "msgExtraCaps mi = 0")
   apply simp
   apply (wp mapME_set | simp)+
  done

lemma lec_ex_nonz_cap_to' [wp]:
  "\<lbrace>invs'\<rbrace>
  lookupExtraCaps t xa mi 
  \<lbrace>\<lambda>rv s. (\<forall>cap \<in> set rv. \<forall>r\<in>zobj_refs' (fst cap). ex_nonz_cap_to' r s)\<rbrace>, -"
  unfolding lookupExtraCaps_def
  apply (cases "msgExtraCaps mi = 0")
   apply simp
   apply (wp mapME_set | simp)+
  done

(* FIXME: move / generalize lemma in GenericLib *)
(* FIXME: move to CSpace_R *)
lemma getSlotCap_diminished' [wp]:
  "\<lbrace>\<top>\<rbrace> getSlotCap slot
  \<lbrace>\<lambda>cap. cte_wp_at' (diminished' cap \<circ> cteCap) slot\<rbrace>"
  apply (simp add: getSlotCap_def)
  apply (wp getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

lemma lcs_diminished' [wp]:
  "\<lbrace>\<top>\<rbrace> lookupCapAndSlot t cptr \<lbrace>\<lambda>rv. cte_wp_at' (diminished' (fst rv) o cteCap) (snd rv)\<rbrace>,-"
  unfolding lookupCapAndSlot_def
  apply (rule hoare_pre)
   apply (wp | simp add: split_def)+
  done


(* FIXME: could prove most (all?) of the other lec stuff in terms of this *) 
lemma lec_dimished'[wp]:
  "\<lbrace>\<top>\<rbrace>
     lookupExtraCaps t buffer info 
   \<lbrace>\<lambda>rv s. (\<forall>x\<in>set rv. cte_wp_at' (diminished' (fst x) o cteCap) (snd x) s)\<rbrace>,-"
  apply (simp add: lookupExtraCaps_def split del: split_if)
  apply (rule hoare_pre)
   apply (wp mapME_set|simp)+
  done

lemma lookupExtras_real_ctes[wp]:
  "\<lbrace>valid_objs'\<rbrace> lookupExtraCaps t xs info \<lbrace>\<lambda>rv s. \<forall>x \<in> set rv. real_cte_at' (snd x) s\<rbrace>,-"
  apply (simp add: lookupExtraCaps_def Let_def split del: split_if cong: if_cong)
  apply (rule hoare_pre)
   apply (wp mapME_set)
      apply (simp add: lookupCapAndSlot_def split_def)
      apply (wp option_cases_weak_wp mapM_wp' lsft_real_cte | simp)+
  done

lemma lookupExtras_ctes[wp]:
  "\<lbrace>valid_objs'\<rbrace> lookupExtraCaps t xs info \<lbrace>\<lambda>rv s. \<forall>x \<in> set rv. cte_at' (snd x) s\<rbrace>,-"
  apply (rule hoare_post_imp_R)
   apply (rule lookupExtras_real_ctes)
  apply (simp add: real_cte_at')
  done

lemma lsft_ex_cte_cap_to':
  "\<lbrace>invs' and K (\<forall>cap. isCNodeCap cap \<longrightarrow> P cap)\<rbrace>
     lookupSlotForThread t cref
   \<lbrace>\<lambda>rv s. ex_cte_cap_wp_to' P rv s\<rbrace>,-"
  apply (simp add: lookupSlotForThread_def split_def)
  apply (wp rab_cte_cap_to' getSlotCap_cap_to2 | simp)+
  done

lemma lec_caps_to'[wp]:
  "\<lbrace>invs' and K (\<forall>cap. isCNodeCap cap \<longrightarrow> P cap)\<rbrace>
     lookupExtraCaps t buffer info 
   \<lbrace>\<lambda>rv s. (\<forall>x\<in>set rv. ex_cte_cap_wp_to' P (snd x) s)\<rbrace>,-"
  apply (simp add: lookupExtraCaps_def split del: split_if)
  apply (rule hoare_pre)
   apply (wp mapME_set)
      apply (simp add: lookupCapAndSlot_def split_def)
      apply (wp lsft_ex_cte_cap_to' mapM_wp'
                    | simp | wpc)+
  done

lemma getSlotCap_badge_derived[wp]:
  "\<lbrace>\<top>\<rbrace> getSlotCap p \<lbrace>\<lambda>cap. cte_wp_at' (badge_derived' cap \<circ> cteCap) p\<rbrace>"
  apply (simp add: getSlotCap_def)
  apply (wp getCTE_wp)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

lemma lec_derived'[wp]:
  "\<lbrace>invs'\<rbrace>
     lookupExtraCaps t buffer info 
   \<lbrace>\<lambda>rv s. (\<forall>x\<in>set rv. cte_wp_at' (badge_derived' (fst x) o cteCap) (snd x) s)\<rbrace>,-"
  apply (simp add: lookupExtraCaps_def split del: split_if)
  apply (rule hoare_pre)
   apply (wp mapME_set)
      apply (simp add: lookupCapAndSlot_def split_def)
      apply (wp | simp)+
  done

lemma get_mrs_length_rv[wp]:
  "\<lbrace>\<lambda>s. \<forall>n. n \<le> msg_max_length \<longrightarrow> P n\<rbrace> get_mrs thread buf mi \<lbrace>\<lambda>rv s. P (length rv)\<rbrace>"
  apply (simp add: get_mrs_def)
  apply (rule hoare_pre)
   apply (wp mapM_length | wpc | simp del: upt.simps)+
  apply (clarsimp simp: msgRegisters_unfold
                        msg_max_length_def)
  done

lemma st_tcb_at_idle_thread':
  "\<lbrakk> st_tcb_at' P (ksIdleThread s) s; valid_idle' s \<rbrakk>
        \<Longrightarrow> P IdleThreadState"
  by (clarsimp simp: valid_idle'_def st_tcb_at'_def obj_at'_def)

crunch tcb_at'[wp]: replyFromKernel "tcb_at' t"

lemma invs_weak_sch_act_wf_strg:
  "invs' s \<longrightarrow> weak_sch_act_wf (ksSchedulerAction s) s"
  by clarsimp

(* FIXME: move *)
lemma rct_sch_act_simple[simp]:
  "ksSchedulerAction s = ResumeCurrentThread \<Longrightarrow> sch_act_simple s"
  by (simp add: sch_act_simple_def)

(* FIXME: move *)
lemma rct_sch_act_sane[simp]:
  "ksSchedulerAction s = ResumeCurrentThread \<Longrightarrow> sch_act_sane s"
  by (simp add: sch_act_sane_def)

lemma lookupCapAndSlot_real_cte_at'[wp]:
  "\<lbrace>valid_objs'\<rbrace> lookupCapAndSlot thread ptr \<lbrace>\<lambda>rv. real_cte_at' (snd rv)\<rbrace>, -"
apply (simp add: lookupCapAndSlot_def lookupSlotForThread_def)
apply (wp resolveAddressBits_real_cte_at' | simp add: split_def)+
done

lemmas set_thread_state_active_valid_sched =
  set_thread_state_runnable_valid_sched[simplified runnable_eq_active]

lemma setTCB_valid_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setObject a (tcb::tcb) \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = tcb,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],simp+)+
  done

crunch valid_duplicates'[wp]: threadSet "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject wp: setObject_ksInterrupt updateObject_default_inv)

lemma tcbSchedEnqueue_valid_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  tcbSchedEnqueue a \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  by (simp add:tcbSchedEnqueue_def unless_def setQueue_def | wp | wpc)+

crunch valid_duplicates'[wp]: rescheduleRequired "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject wp: setObject_ksInterrupt updateObject_default_inv)

crunch valid_duplicates'[wp]: setThreadState "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (ignore: getObject setObject)

(*FIXME: move to NonDetMonadVCG.valid_validE_R *)
lemma hinv_corres:
  "c \<longrightarrow> b \<Longrightarrow>
   corres (intr \<oplus> dc) 
          (einvs and (\<lambda>s. scheduler_action s = resume_cur_thread) and ct_active)
          (invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
           (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread) and ct_active') 
          (handle_invocation c b)
          (handleInvocation c b)"
  apply (simp add: handle_invocation_def handleInvocation_def liftE_bindE)
  apply (rule corres_guard_imp)
    apply (rule corres_split_eqr [OF _ gct_corres])
      apply (rule corres_split [OF _ get_mi_corres])
        apply clarsimp
        apply (simp add: liftM_def cap_register_def capRegister_def)
        apply (rule corres_split_eqr [OF _ user_getreg_corres])
          apply (rule syscall_corres)
                  apply (rule hinv_corres_assist, simp)
                 apply (clarsimp simp add: when_def)
                 apply (rule hf_corres)
                 apply simp
                apply (simp add: split_def)
                apply (rule corres_split [OF _ get_mrs_corres])
                  apply (rule decode_invocation_corres, simp_all)[1]
                   apply (fastforce simp: list_all2_map2 list_all2_map1 elim:  list_all2_mono)
                  apply (fastforce simp: list_all2_map2 list_all2_map1 elim:  list_all2_mono)
                 apply wp[1]
                apply (drule sym[OF conjunct1])
                apply simp
                apply wp[1]
               apply (clarsimp simp: when_def)
               apply (rule rfk_corres)
              apply (rule corres_split [OF _ sts_corres])
                 apply (rule corres_splitEE [OF _ pinv_corres])
                     apply simp
                     apply (rule corres_split [OF _ gts_corres])
                       apply (rename_tac state state')
                       apply (case_tac state, simp_all)[1]
                       apply (fold dc_def)[1]
                       apply (rule corres_split [OF sts_corres])
                          apply simp
                         apply (rule corres_when [OF refl rfk_corres])
                        apply (simp add: when_def)
                        apply (rule conjI, rule impI)
                         apply (rule reply_from_kernel_tcb_at)
                        apply (rule impI, wp)
                    apply (simp)+
                  apply (wp hoare_drop_imps)
                 apply (simp)
                 apply (wp)
                apply (simp)
               apply simp
               apply (rule_tac Q="\<lambda>rv. einvs and simple_sched_action and valid_invocation rve
                                   and (\<lambda>s. thread = cur_thread s)
                                   and st_tcb_at active thread"
                          in hoare_post_imp)
                apply (clarsimp simp: simple_from_active ct_in_state_def
                               elim!: st_tcb_weakenE)
               apply (wp sts_st_tcb_at' set_thread_state_simple_sched_action
                set_thread_state_active_valid_sched)
              apply (rule_tac Q="\<lambda>rv. invs' and valid_invocation' rve'
                                      and (\<lambda>s. thread = ksCurThread s)
                                      and st_tcb_at' active' thread
                                      and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)
                                      and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
                         in hoare_post_imp)
               apply (clarsimp simp: ct_in_state'_def)
               apply (frule(1) ct_not_ksQ)
               apply (clarsimp)
              apply (wp setThreadState_nonqueued_state_update
                        setThreadState_st_tcb setThreadState_rct)[1]
             apply (wp lec_caps_to get_cap_diminished lsft_ex_cte_cap_to
                     | simp add: split_def liftE_bindE[symmetric]
                                 ct_in_state'_def ball_conj_distrib
                     | rule hoare_vcg_E_elim)+
   apply (clarsimp simp: tcb_at_invs invs_valid_objs
                         valid_tcb_state_def ct_in_state_def
                         simple_from_active invs_mdb)
   apply (clarsimp simp: msg_max_length_def word_bits_def)
   apply (erule st_tcb_ex_cap, clarsimp+)
   apply fastforce
  apply (clarsimp)
  apply (frule tcb_at_invs')
  apply (clarsimp simp: invs'_def valid_state'_def
                        ct_in_state'_def ct_not_inQ_def)
  apply (frule(1) valid_queues_not_tcbQueued_not_ksQ)
  apply (frule st_tcb'_weakenE [where P=active' and P'=simple'], clarsimp)
  apply (frule(1) st_tcb_ex_cap'', fastforce)
  apply (clarsimp simp: valid_pspace'_def)
  apply (frule(1) st_tcb_at_idle_thread')
  apply (simp)
  done

lemma ts_Restart_case_helper':
  "(case ts of Structures_H.Restart \<Rightarrow> A | _ \<Rightarrow> B)
 = (if ts = Structures_H.Restart then A else B)"
  by (cases ts, simp_all)

lemma gts_imp':
  "\<lbrace>Q\<rbrace> getThreadState t \<lbrace>R\<rbrace> \<Longrightarrow>
   \<lbrace>\<lambda>s. st_tcb_at' P t s \<longrightarrow> Q s\<rbrace> getThreadState t \<lbrace>\<lambda>rv s. P rv \<longrightarrow> R rv s\<rbrace>"
  apply (simp only: imp_conv_disj)
  apply (erule hoare_vcg_disj_lift[rotated])
  apply (rule hoare_strengthen_post [OF gts_sp'])
  apply (clarsimp simp: st_tcb_at'_def obj_at'_def projectKOs)
  done

crunch st_tcb_at'[wp]: replyFromKernel "st_tcb_at' P t"
crunch cap_to'[wp]: replyFromKernel "ex_nonz_cap_to' p"
crunch it'[wp]: replyFromKernel "\<lambda>s. P (ksIdleThread s)"
crunch sch_act_simple[wp]: replyFromKernel sch_act_simple
  (lift: sch_act_simple_lift)

lemma rfk_ksQ[wp]:
  "\<lbrace>\<lambda>s. P (ksReadyQueues s p)\<rbrace> replyFromKernel t x1 \<lbrace>\<lambda>_ s. P (ksReadyQueues s p)\<rbrace>"
  apply (case_tac x1)
  apply (simp add: replyFromKernel_def)
  apply (wp)
  done

lemma hinv_invs'[wp]:
  "\<lbrace>invs' and ct_active' and
          (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
          (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)\<rbrace>
     handleInvocation calling blocking
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: handleInvocation_def split_def
                   ts_Restart_case_helper')
  apply (wp syscall_valid' setThreadState_nonqueued_state_update rfk_invs'
            hoare_vcg_all_lift static_imp_wp)
         apply simp
         apply (intro conjI impI)
          apply (wp gts_imp' | simp)+
        apply (rule_tac Q'="\<lambda>rv. invs'" in hoare_post_imp_R[rotated])
         apply clarsimp
         apply (subgoal_tac "thread \<noteq> ksIdleThread s", simp_all)[1]
          apply (fastforce elim!: st_tcb'_weakenE st_tcb_ex_cap'')
         apply (clarsimp simp: valid_idle'_def valid_state'_def
                               invs'_def st_tcb_at'_def obj_at'_def)
        apply wp
       apply (rule_tac Q="\<lambda>rv'. invs' and valid_invocation' rv
                                and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)
                                and (\<lambda>s. ksCurThread s = thread)
                                and st_tcb_at' active' thread"
                  in hoare_post_imp)
        apply (clarsimp simp: ct_in_state'_def)
        apply (frule(1) ct_not_ksQ)
        apply (clarsimp)
       apply (wp sts_invs_minor' setThreadState_st_tcb setThreadState_rct | simp)+
    apply (clarsimp)
    apply (frule(1) ct_not_ksQ)
    apply (fastforce simp add: tcb_at_invs' ct_in_state'_def 
                              simple_sane_strg
                              sch_act_simple_def
                       elim!: st_tcb'_weakenE st_tcb_ex_cap''
                        dest: st_tcb_at_idle_thread')+
  done

crunch typ_at'[wp]: handleFault "\<lambda>s. P (typ_at' T p s)" 

lemmas handleFault_typ_ats[wp] = typ_at_lifts [OF handleFault_typ_at']

lemma hinv_tcb'[wp]:
  "\<lbrace>st_tcb_at' active' t and invs' and ct_active' and sch_act_simple and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
     handleInvocation calling blocking
   \<lbrace>\<lambda>rv. tcb_at' t\<rbrace>"
  apply (simp add: handleInvocation_def split_def
                   ts_Restart_case_helper')
  apply (wp syscall_valid' setThreadState_nonqueued_state_update
            sts_st_tcb' ct_in_state'_set | simp split del: split_if)+
     apply (auto, auto simp: ct_in_state'_def dest: st_tcb_at_idle_thread')
  done

lemma hs_corres:
  "corres (intr \<oplus> dc)
          (einvs and (\<lambda>s. scheduler_action s = resume_cur_thread) and ct_active)
          (invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
           (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread) and ct_active')
          (handle_send blocking) (handleSend blocking)"
  by (simp add: handle_send_def handleSend_def hinv_corres)

lemma hs_invs'[wp]:
  "\<lbrace>invs' and ct_active' and
    (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
    (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)\<rbrace>
   handleSend blocking \<lbrace>\<lambda>r. invs'\<rbrace>"
  apply (rule validE_valid)
  apply (simp add: handleSend_def)
  apply (wp | simp)+
  done

lemma nullCapOnFailure_wp[wp]:
  assumes x: "\<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace>,\<lbrace>\<lambda>rv. Q NullCap\<rbrace>"
  shows      "\<lbrace>P\<rbrace> nullCapOnFailure f \<lbrace>Q\<rbrace>"
  unfolding nullCapOnFailure_def
  by (wp x)

lemma getThreadCallerSlot_map:
  "getThreadCallerSlot t = return (cte_map (t, tcb_cnode_index 3))"
  by (simp add: getThreadCallerSlot_def locateSlot_conv
                cte_map_def tcb_cnode_index_def tcbCallerSlot_def
                cte_level_bits_def)

lemma tcb_at_cte_at_map:
  "\<lbrakk> tcb_at' t s; offs \<in> dom tcb_cap_cases \<rbrakk> \<Longrightarrow> cte_at' (cte_map (t, offs)) s"
  apply (clarsimp simp: obj_at'_def projectKOs objBits_simps)
  apply (drule tcb_cases_related)
  apply (auto elim: cte_wp_at_tcbI')
  done

lemma delete_caller_cap_corres:
  "corres dc (einvs and tcb_at t) (invs' and tcb_at' t)
     (delete_caller_cap t)
     (deleteCallerCap t)" 
  apply (simp add: delete_caller_cap_def deleteCallerCap_def
                   getThreadCallerSlot_map)
  apply (rule corres_guard_imp)
    apply (rule cap_delete_one_corres)
   apply clarsimp
   apply (frule tcb_at_cte_at[where ref="tcb_cnode_index 3"])
    apply clarsimp
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (frule tcb_cap_valid_caps_of_stateD, clarsimp)
   apply (drule(1) tcb_cnode_index_3_reply_or_null)
   apply (auto simp: can_fast_finalise_def is_cap_simps
              intro: tcb_at_cte_at_map tcb_at_cte_at)
  done

lemma deleteCallerCap_invs[wp]:
  "\<lbrace>invs'\<rbrace> deleteCallerCap t \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: deleteCallerCap_def getThreadCallerSlot_def
                locateSlot_conv)
  apply (wp cteDeleteOne_invs)
  done

lemma deleteCallerCap_simple[wp]:
  "\<lbrace>st_tcb_at' simple' t\<rbrace> deleteCallerCap t' \<lbrace>\<lambda>rv. st_tcb_at' simple' t\<rbrace>"
  apply (simp add: deleteCallerCap_def getThreadCallerSlot_def
                   locateSlot_conv)
  apply (wp cteDeleteOne_st_tcb_at)
  apply simp
  done

lemma cteDeleteOne_st_tcb_at[wp]:
  assumes x[simp]: "\<And>st. simple' st \<longrightarrow> P st" shows
  "\<lbrace>st_tcb_at' P t\<rbrace> cteDeleteOne slot \<lbrace>\<lambda>rv. st_tcb_at' P t\<rbrace>"
  apply (subgoal_tac "\<exists>Q. P = (Q or simple')")
   apply (clarsimp simp: pred_disj_def)
   apply (rule cteDeleteOne_st_tcb_at_simplish)
  apply (rule_tac x=P in exI)
  apply (auto intro!: ext)
  done

lemma valid_cap_tcb_at_thread_or_zomb':
  "\<lbrakk> s \<turnstile>' cap; t \<in> zobj_refs' cap; tcb_at' t s \<rbrakk>
        \<Longrightarrow> isThreadCap cap \<or> isZombie cap"
  by (clarsimp simp: valid_cap'_def isCap_simps
                     obj_at'_def projectKOs
              split: capability.split_asm)

lemma deleteCallerCap_nonz_cap:
  "\<lbrace>ex_nonz_cap_to' p and tcb_at' p and valid_objs'\<rbrace>
      deleteCallerCap t
   \<lbrace>\<lambda>rv. ex_nonz_cap_to' p\<rbrace>"
  apply (simp add: deleteCallerCap_def getThreadCallerSlot_def
                   locateSlot_conv ex_nonz_cap_to'_def)
  apply (rule_tac P="\<lambda>s. \<exists>cref. cte_wp_at' (\<lambda>cte. isThreadCap (cteCap cte)
                                             \<and> p \<in> zobj_refs' (cteCap cte)) cref s"
                   in hoare_chain)
    apply (rule hoare_vcg_ex_lift, rule cteDeleteOne_cte_wp_at_preserved)
    apply (clarsimp simp: isCap_simps finaliseCap_def)
   apply (clarsimp simp: cte_wp_at_ctes_of)
   apply (rule_tac x=cref in exI)
   apply clarsimp
   apply (drule(1) ctes_of_valid')
   apply (drule(2) valid_cap_tcb_at_thread_or_zomb')
   apply (clarsimp simp: isCap_simps)
  apply (erule exEI)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

crunch sch_act_sane[wp]: cteDeleteOne sch_act_sane
  (wp: crunch_wps ss_sch_act_sane_weak
   simp: crunch_simps unless_def
   lift: sch_act_sane_lift)

crunch sch_act_sane[wp]: deleteCallerCap sch_act_sane

lemma hw_corres':
   "corres dc (einvs and ct_in_state active 
                    and (\<lambda>s. ex_nonz_cap_to (cur_thread s) s))
              (invs' and ct_in_state' simple'
                     and sch_act_sane
                     and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p)) 
                     and (\<lambda>s. ex_nonz_cap_to' (ksCurThread s) s))
                    handle_wait handleWait"
  apply (simp add: handle_wait_def handleWait_def liftM_bind Let_def
                   cap_register_def capRegister_def
             cong: if_cong cap.case_cong capability.case_cong bool.case_cong)
  apply (rule corres_guard_imp)
    apply (rule corres_split_eqr [OF _ gct_corres])
      apply (rule corres_split_nor [OF _ delete_caller_cap_corres])
        apply (rule corres_split_eqr [OF _ user_getreg_corres])
          apply (rule corres_split_catch)
             apply (erule hf_corres)
            apply (rule corres_cap_fault)
            apply (rule corres_splitEE [OF _ lc_corres])
              apply (clarsimp split: cap_relation_split_asm arch_cap.split_asm
                               simp: lookup_failure_map_def)
                (* evil, get us different preconds for the cases *)
               apply (rule corres_guard_imp[rotated], erule conjunct1, erule conjunct1)
               apply (rule receive_ipc_corres, simp+)[1]
              apply (rule corres_guard_imp[rotated], erule conjunct2, erule conjunct2)
              apply (rule receive_async_ipc_corres, simp+)
             apply (wp | wpcw | simp)+
           apply (rule hoare_vcg_E_elim)
            apply (simp add: lookup_cap_def lookup_slot_for_thread_def)
            apply wp
             apply (simp add: split_def)
             apply (wp resolve_address_bits_valid_fault2)
           apply (wp | wpcw | simp add: valid_fault_def)+
       apply (rule_tac Q="\<lambda>rv. einvs and st_tcb_at active thread
                                 and ex_nonz_cap_to thread
                                 and cte_wp_at (\<lambda>c. c = cap.NullCap)
                                                  (thread, tcb_cnode_index 3)"
                    in hoare_post_imp)
        apply (clarsimp simp: st_tcb_at_tcb_at invs_def valid_state_def
                              valid_pspace_def objs_valid_tcb_ctable)
       apply (wp delete_caller_cap_nonz_cap)
      apply (simp add: invs_valid_objs' invs_pspace_aligned'
                       invs_pspace_distinct' invs_cur'
                 cong: conj_cong)
      apply (simp add: invs_valid_objs' invs_pspace_aligned'
                       invs_pspace_distinct' invs_cur'
                 cong: rev_conj_cong)
      apply (rule_tac Q="\<lambda>rv. invs' and (\<lambda>s. thread = ksCurThread s)
                                    and sch_act_not thread
                                    and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))
                                    and st_tcb_at' simple' thread
                                    and ex_nonz_cap_to' thread"
               in hoare_post_imp, clarsimp)
      apply (wp deleteCallerCap_nonz_cap
                hoare_vcg_all_lift
                deleteCallerCap_ct_not_ksQ)
   apply (simp add: invs_valid_objs tcb_at_invs invs_psp_aligned invs_cur)
   apply (clarsimp simp add: ct_in_state_def conj_ac)
  apply (clarsimp simp add: ct_in_state'_def)
  apply (clarsimp simp: invs'_def valid_state'_def valid_pspace'_def
                        ct_in_state'_def sch_act_sane_not)
  done

lemma hw_corres:
  "corres dc (einvs and ct_active)
             (invs' and ct_active' and sch_act_sane and
                    (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p)))
            handle_wait handleWait"
  apply (rule corres_guard_imp)
    apply (rule hw_corres')
   apply (clarsimp simp: ct_in_state_def)
   apply (fastforce elim!: st_tcb_weakenE st_tcb_ex_cap)
  apply (clarsimp simp: ct_in_state'_def invs'_def valid_state'_def)
  apply (frule(1) st_tcb_ex_cap'')
  apply (auto elim: st_tcb'_weakenE)
  done

lemma lookupCap_refs[wp]:
  "\<lbrace>invs'\<rbrace> lookupCap t ref \<lbrace>\<lambda>rv s. \<forall>r\<in>zobj_refs' rv. ex_nonz_cap_to' r s\<rbrace>,-"
  by (simp add: lookupCap_def split_def | wp | simp add: o_def)+

lemma hw_invs'[wp]:
  "\<lbrace>invs' and ct_in_state' simple' and sch_act_sane
          and (\<lambda>s. ex_nonz_cap_to' (ksCurThread s) s)
          and (\<lambda>s. ksCurThread s \<noteq> ksIdleThread s)
          and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))\<rbrace>
   handleWait \<lbrace>\<lambda>r. invs'\<rbrace>"
  apply (simp add: handleWait_def cong: if_cong)
  apply (rule hoare_pre)
   apply ((wp | wpc | simp)+)[1]
      apply (rule validE_validE_R)
      apply (rule_tac Q="\<lambda>rv s. invs' s
                              \<and> sch_act_sane s
                              \<and> (\<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))
                              \<and> thread = ksCurThread s
                              \<and> ct_in_state' simple' s
                              \<and> ex_nonz_cap_to' thread s
                              \<and> thread \<noteq> ksIdleThread s
                              \<and> (\<forall>x \<in> zobj_refs' rv. ex_nonz_cap_to' x s)"
                  and E="\<lambda>_ _. True"
               in hoare_post_impErr[rotated])
        apply (clarsimp simp: isCap_simps ct_in_state'_def
                              sch_act_sane_not)
       apply (assumption)
      apply (wp)
    apply (rule_tac Q="\<lambda>rv s. invs' s
                            \<and> sch_act_sane s
                            \<and> (\<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))
                            \<and> thread = ksCurThread s
                            \<and> ct_in_state' simple' s
                            \<and> ex_nonz_cap_to' thread s
                            \<and> thread \<noteq> ksIdleThread s"
             in hoare_post_imp)
     apply (clarsimp simp: ct_in_state'_def)+
    apply (wp deleteCallerCap_nonz_cap
              hoare_vcg_all_lift
              deleteCallerCap_ct_not_ksQ
              hoare_lift_Pf2 [OF deleteCallerCap_simple
                                 deleteCallerCap_ct'])
  apply (clarsimp)
  apply (auto elim: st_tcb_ex_cap'' st_tcb'_weakenE 
             dest!: st_tcb_at_idle_thread'
              simp: ct_in_state'_def sch_act_sane_def)
  done

lemma hw_tcb'[wp]: "\<lbrace>tcb_at' t\<rbrace> handleWait \<lbrace>\<lambda>rv. tcb_at' t\<rbrace>"
  apply (simp add: handleWait_def cong: if_cong)
  apply (wp hoare_drop_imps
              | wpcw | simp)+
  done

lemma setSchedulerAction_obj_at'[wp]:
  "\<lbrace>obj_at' P p\<rbrace> setSchedulerAction sa \<lbrace>\<lambda>rv. obj_at' P p\<rbrace>"
  unfolding setSchedulerAction_def
  by (wp, clarsimp elim!: obj_at'_pspaceI)

lemma setSchedulerAction_st_tcb_at'[wp]:
  "\<lbrace>st_tcb_at' P t\<rbrace> setSchedulerAction sa \<lbrace>\<lambda>rv. st_tcb_at' P t\<rbrace>"
  unfolding st_tcb_at'_def
  by wp

crunch_ignore (add: null_cap_on_failure)

(*
lemma ct_idle_or_in_cur_domainD:
  "\<lbrakk>st_tcb_at' P (ksCurThread s) s; valid_idle' s;  
  \<not> P Structures_H.thread_state.IdleThreadState;
  ct_idle_or_in_cur_domain' s;tcb_at' (ksCurThread s) s\<rbrakk>
  \<Longrightarrow> obj_at' (\<lambda>tcb. ksCurDomain s = tcbDomain tcb) (ksCurThread s) s"
  apply (simp add:ct_idle_or_in_cur_domain'_def)
  apply (erule disjE)
   apply (clarsimp simp:valid_idle'_def st_tcb_at'_def obj_at'_def)
  apply (simp add:tcb_in_cur_domain'_def)
  done
*)



lemma hy_corres:
  "corres dc einvs (invs' and ct_active' and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)) handle_yield handleYield"
  apply (clarsimp simp: handle_yield_def handleYield_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF _ gct_corres])
      apply simp
      apply (rule corres_split[OF _ tcbSchedDequeue_corres])
        apply (rule corres_split[OF _ tcbSchedAppend_corres])
          apply (rule rescheduleRequired_corres)
         apply (wp weak_sch_act_wf_lift_linear | simp add: )+
   apply (simp add: invs_def valid_sched_def valid_sched_action_def
                cur_tcb_def tcb_at_is_etcb_at)
  apply clarsimp
  apply (frule ct_active_runnable')
  apply (clarsimp simp: invs'_def valid_state'_def ct_in_state'_def sch_act_wf_weak cur_tcb'_def
                        valid_pspace_valid_objs' valid_objs'_maxDomain tcb_in_cur_domain'_def)
  apply (erule(1) valid_objs_valid_tcbE[OF valid_pspace_valid_objs'])
  apply (simp add:valid_tcb'_def)
  done

lemma threadSet_invs_ct_active':
  "\<lbrace>invs' and ct_active' and tcb_at' thread\<rbrace>
  threadSet (tcbTimeSlice_update t) thread
  \<lbrace>\<lambda>r. invs' and ct_active'\<rbrace>"
proof -
  have ct_active'_def2:
    "ct_active' = (\<lambda>s. \<forall>t. t \<noteq> ksCurThread s \<or> st_tcb_at' active' t s)"
    apply (rule ext)
    apply (simp add: ct_in_state'_def)
    done
  show ?thesis
    apply (rule hoare_pre)
     apply (wp threadSet_invs_trivial, simp+)
     apply (simp only: ct_active'_def2)
     apply (rule hoare_vcg_all_lift)
     apply (rule hoare_vcg_disj_lift)
      apply (rule threadSet_ct)
     apply (rule threadSet_st_tcb_no_state)
     apply (case_tac tcb, simp)
    apply (clarsimp simp add: ct_active'_def2 inQ_def)
    done
qed

lemma hy_invs':
  "\<lbrace>invs' and ct_active'\<rbrace> handleYield \<lbrace>\<lambda>r. invs' and ct_active'\<rbrace>"
  apply (simp add: handleYield_def)
  apply (wp ct_in_state_thread_state_lift'
            rescheduleRequired_all_invs_but_ct_not_inQ
            tcbSchedAppend_invs_but_ct_not_inQ' | simp)+
  apply (clarsimp simp add: invs'_def valid_state'_def ct_in_state'_def sch_act_wf_weak cur_tcb'_def
                   valid_pspace_valid_objs' valid_objs'_maxDomain tcb_in_cur_domain'_def
                   )
  apply (simp add:ct_active_runnable'[unfolded ct_in_state'_def])
  done

lemma getDFSR_invs'[wp]:
  "valid invs' (doMachineOp getDFSR) (\<lambda>_. invs')"
  by (simp add: getDFSR_def doMachineOp_def split_def select_f_returns | wp)+

lemma getFAR_invs'[wp]:
  "valid invs' (doMachineOp getFAR) (\<lambda>_. invs')"
  by (simp add: getFAR_def doMachineOp_def split_def select_f_returns | wp)+

lemma getIFSR_invs'[wp]:
  "valid invs' (doMachineOp getIFSR) (\<lambda>_. invs')"
  by (simp add: getIFSR_def doMachineOp_def split_def select_f_returns | wp)+

lemma hv_invs'[wp]: "\<lbrace>invs' and tcb_at' t'\<rbrace> handleVMFault t' vptr \<lbrace>\<lambda>r. invs'\<rbrace>"
  apply (simp add: handleVMFault_def ArchVSpace_H.handleVMFault_def
             cong: vmfault_type.case_cong)
  apply (rule hoare_pre)
   apply (wp | wpcw | simp)+
  done

lemma hv_tcb'[wp]: "\<lbrace>tcb_at' t\<rbrace> handleVMFault t' vptr \<lbrace>\<lambda>r. tcb_at' t\<rbrace>"
  apply (simp add: handleVMFault_def ArchVSpace_H.handleVMFault_def
             cong: vmfault_type.case_cong)
  apply (rule hoare_pre)
   apply (wp | wpcw)+
  apply simp
  done

crunch nosch[wp]: handleVMFault "\<lambda>s. P (ksSchedulerAction s)"
  (ignore: getFAR getDFSR getIFSR)

lemma hv_inv_ex':
  "\<lbrace>P\<rbrace> handleVMFault t vp \<lbrace>\<lambda>_ _. True\<rbrace>, \<lbrace>\<lambda>_. P\<rbrace>"
  apply (simp add: handleVMFault_def ArchVSpace_H.handleVMFault_def
             cong: vmfault_type.case_cong)
  apply (rule hoare_pre)
   apply (wp dmo_inv' getDFSR_inv getFAR_inv getIFSR_inv getRestartPC_inv 
             det_getRestartPC asUser_inv
          | wpcw)+
  apply simp
  done

lemma active_from_running':
  "ct_running' s' \<Longrightarrow> ct_active' s'"
  by (clarsimp elim!: st_tcb'_weakenE
               simp: ct_in_state'_def)+

lemma simple_from_running':
  "ct_running' s' \<Longrightarrow> ct_in_state' simple' s'"
  by (clarsimp elim!: st_tcb'_weakenE
               simp: ct_in_state'_def)+

lemma hr_corres:
  "corres dc (einvs and ct_running) (invs' and sch_act_simple and ct_running')
         handle_reply handleReply"
  apply (simp add: handle_reply_def handleReply_def
                   getThreadCallerSlot_map
                   getSlotCap_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split_eqr [OF _ gct_corres])
      apply (rule corres_split [OF _ get_cap_corres])
        apply (rule_tac P="einvs and cte_wp_at (op = caller_cap) (thread, tcb_cnode_index 3)
                                and K (is_reply_cap caller_cap \<or> caller_cap = cap.NullCap)
                                and tcb_at thread and st_tcb_at active thread
                                and valid_cap caller_cap"
                    and P'="invs' and sch_act_simple and tcb_at' thread
                              and valid_cap' (cteCap rv')
                              and cte_at' (cte_map (thread, tcb_cnode_index 3))"
                    in corres_inst)
        apply (auto split: cap_relation_split_asm arch_cap.split_asm bool.split
                   intro!: corres_guard_imp [OF delete_caller_cap_corres]
                           corres_guard_imp [OF do_reply_transfer_corres]
                           corres_fail
                     simp: valid_cap_def valid_cap'_def is_cap_simps assert_def)[1]
        apply (fastforce simp: invs_def valid_state_def
                              cte_wp_at_caps_of_state st_tcb_def2
                        dest: valid_reply_caps_of_stateD)
       apply (wp get_cap_cte_wp_at get_cap_wp | simp add: cte_wp_at_eq_simp)+
   apply (intro conjI impI allI,
          (fastforce simp: invs_def valid_state_def
                   intro: tcb_at_cte_at)+)
      apply (clarsimp, frule tcb_at_invs)
      apply (fastforce dest: tcb_caller_cap simp: cte_wp_at_def)
     apply clarsimp
    apply (clarsimp simp: ct_in_state_def elim!: st_tcb_weakenE)
   apply (fastforce intro: cte_wp_valid_cap elim: cte_wp_at_weakenE)
  apply (fastforce intro: tcb_at_cte_at_map)
  done

lemma hr_invs'[wp]:
  "\<lbrace>invs' and sch_act_simple\<rbrace> handleReply \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: handleReply_def getSlotCap_def
                   getThreadCallerSlot_map getCurThread_def)
  apply (wp getCTE_wp | wpc | simp)+
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (drule ctes_of_valid', clarsimp+)
  apply (simp add: valid_cap'_def)
  apply (simp add: invs'_def cur_tcb'_def)
  done

crunch ksCurThread[wp]: cteDeleteOne "\<lambda>s. P (ksCurThread s)"
  (wp: crunch_wps setObject_ep_ct setObject_aep_ct
       simp: crunch_simps unless_def ignore: setObject)

crunch ksCurThread[wp]: handleReply "\<lambda>s. P (ksCurThread s)"
  (wp: crunch_wps transferCapsToSlots_pres1 setObject_ep_ct
       setObject_aep_ct
        simp: unless_def crunch_simps
      ignore: transferCapsToSlots setObject getObject)

lemmas cteDeleteOne_st_tcb_at_simple'[wp] =
    cteDeleteOne_st_tcb_at[where P=simple', simplified]

lemma simple_if_Restart_Inactive':
  "simple' (if P then Restart else Inactive)"
  by simp

crunch st_tcb_at_simple'[wp]: handleReply "st_tcb_at' simple' t'"
  (wp: hoare_post_taut crunch_wps sts_st_tcb_at'_cases
       threadSet_st_tcb_no_state
     ignore: setThreadState simp: simple_if_Restart_Inactive')

lemmas handleReply_ct_in_state_simple[wp] =
    ct_in_state_thread_state_lift' [OF handleReply_ksCurThread
                                     handleReply_st_tcb_at_simple']


(* FIXME: move *)
lemma doReplyTransfer_st_tcb_at_active: 
  "\<lbrace>st_tcb_at' active' t and tcb_at' t' and K (t \<noteq> t') and
    cte_wp_at' (\<lambda>cte. cteCap cte = (capability.ReplyCap t' False)) sl\<rbrace>
    doReplyTransfer t t' sl
   \<lbrace>\<lambda>rv. st_tcb_at' active' t\<rbrace>"
  apply (simp add: doReplyTransfer_def liftM_def)
  apply (wp setThreadState_st_tcb sts_st_tcb_neq' cteDeleteOne_reply_st_tcb_at
            hoare_drop_imps threadSet_st_tcb_no_state
            doIPCTransfer_non_null_cte_wp_at2' | wpc | clarsimp simp:isCap_simps)+
  apply (wp hoare_allI hoare_drop_imps)
  apply (fastforce)
  done

lemma hr_ct_active'[wp]:
  "\<lbrace>invs' and ct_active'\<rbrace> handleReply \<lbrace>\<lambda>rv. ct_active'\<rbrace>"
  apply (simp add: handleReply_def getSlotCap_def getCurThread_def
                   getThreadCallerSlot_def locateSlot_def)
  apply (rule hoare_seq_ext)
   apply (rule ct_in_state'_decomp)
    apply ((wp hoare_drop_imps | wpc | simp)+)[1]
   apply (subst haskell_assert_def)
   apply (wp hoare_vcg_all_lift getCTE_wp doReplyTransfer_st_tcb_at_active
        | wpc | simp)+
  apply (fastforce simp: ct_in_state'_def cte_wp_at_ctes_of valid_cap'_def
                  dest: ctes_of_valid')
  done

lemma hc_corres:
  "corres (intr \<oplus> dc) (einvs and (\<lambda>s. scheduler_action s = resume_cur_thread) and ct_active)
              (invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
                (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread) and
                ct_active')
         handle_call handleCall"
  by (simp add: handle_call_def handleCall_def liftE_bindE hinv_corres)

lemma hc_invs'[wp]:
  "\<lbrace>invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
      (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread) and
      ct_active'\<rbrace>
     handleCall
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: handleCall_def)
  apply (wp)
  apply (clarsimp)
  done

lemma sch_act_sane_ksMachineState [iff]:
  "sch_act_sane (s\<lparr>ksMachineState := b\<rparr>) = sch_act_sane s"
  by (simp add: sch_act_sane_def)

lemma cteInsert_sane[wp]:
  "\<lbrace>sch_act_sane\<rbrace> cteInsert newCap srcSlot destSlot \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  apply (simp add: sch_act_sane_def)
  apply (wp hoare_vcg_all_lift
            hoare_convert_imp [OF cteInsert_nosch cteInsert_ct])
  done

crunch sane [wp]: cteInsert sch_act_sane
  (wp: crunch_wps simp: crunch_simps)

crunch sane [wp]: setExtraBadge sch_act_sane

crunch sane [wp]: transferCaps "sch_act_sane"
  (wp: transferCapsToSlots_pres1 crunch_wps 
   simp: crunch_simps
   ignore: transferCapsToSlots)

lemma possibleSwitchTo_sane:
  "\<lbrace>\<lambda>s. sch_act_sane s \<and> t \<noteq> ksCurThread s\<rbrace> possibleSwitchTo t b \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  apply (simp add: possibleSwitchTo_def setSchedulerAction_def curDomain_def cong: if_cong)
  apply (wp hoare_drop_imps | wpc)+
  apply (simp add: sch_act_sane_def)
  done

lemmas attemptSwitchTo_sane
    = possibleSwitchTo_sane[where b=True, folded attemptSwitchTo_def]

crunch sane [wp]: handleFaultReply sch_act_sane
  (  wp: threadGet_inv hoare_drop_imps crunch_wps
   simp: crunch_simps
   ignore: setSchedulerAction)

crunch sane [wp]: doIPCTransfer sch_act_sane
  (  wp: threadGet_inv hoare_drop_imps crunch_wps
   simp: crunch_simps
   ignore: setSchedulerAction)

lemma doReplyTransfer_sane:
  "\<lbrace>\<lambda>s. sch_act_sane s \<and> t' \<noteq> ksCurThread s\<rbrace> 
  doReplyTransfer t t' callerSlot \<lbrace>\<lambda>rv. sch_act_sane\<rbrace>"
  apply (simp add: doReplyTransfer_def liftM_def)
  apply (wp attemptSwitchTo_sane hoare_drop_imps hoare_vcg_all_lift|wpc)+
  apply simp
  done

lemma handleReply_sane:
  "\<lbrace>sch_act_sane\<rbrace> handleReply \<lbrace>\<lambda>rv. sch_act_sane\<rbrace>"
  apply (simp add: handleReply_def getSlotCap_def getThreadCallerSlot_def locateSlot_def)
  apply (rule hoare_pre) 
   apply (wp haskell_assert_wp doReplyTransfer_sane getCTE_wp'| wpc)+
  apply (clarsimp simp: cte_wp_at_ctes_of) 
  done

lemma handleReply_nonz_cap_to_ct:
  "\<lbrace>ct_active' and invs' and sch_act_simple\<rbrace>
     handleReply
   \<lbrace>\<lambda>rv s. ex_nonz_cap_to' (ksCurThread s) s\<rbrace>"
  apply (rule_tac Q="\<lambda>rv. ct_active' and invs'"
               in hoare_post_imp)
   apply (auto simp: ct_in_state'_def elim: st_tcb_ex_cap'')[1]
  apply (wp | simp)+
  done

crunch ksQ[wp]: handleFaultReply "\<lambda>s. P (ksReadyQueues s p)"

lemma doReplyTransfer_ct_not_ksQ:
  "\<lbrace> invs' and sch_act_simple
           and tcb_at' thread and tcb_at' word
           and ct_in_state' simple'
           and (\<lambda>s. ksCurThread s \<noteq> word)
           and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set(ksReadyQueues s p))\<rbrace>
   doReplyTransfer thread word callerSlot
   \<lbrace>\<lambda>rv s. \<forall>p. ksCurThread s \<notin> set(ksReadyQueues s p)\<rbrace>"
proof -
  have astct: "\<And>t p.
       \<lbrace>(\<lambda>s. ksCurThread s \<notin> set(ksReadyQueues s p) \<and> sch_act_sane s)
             and (\<lambda>s. ksCurThread s \<noteq> t)\<rbrace>
       attemptSwitchTo t \<lbrace>\<lambda>rv s. ksCurThread s \<notin> set(ksReadyQueues s p)\<rbrace>"
    apply (rule hoare_weaken_pre)
     apply (wps attemptSwitchTo_ct')
     apply (wp attemptSwitchTo_ksQ)
    apply (clarsimp simp: sch_act_sane_def)
    done
  have stsct: "\<And>t st p.
       \<lbrace>(\<lambda>s. ksCurThread s \<notin> set(ksReadyQueues s p)) and sch_act_simple\<rbrace>
       setThreadState st t
       \<lbrace>\<lambda>rv s. ksCurThread s \<notin> set(ksReadyQueues s p)\<rbrace>"
    apply (rule hoare_weaken_pre)
     apply (wps setThreadState_ct')
     apply (wp hoare_vcg_all_lift sts_ksQ)
    apply (clarsimp)
    done
  show ?thesis
    apply (simp add: doReplyTransfer_def)
    apply (wp, wpc)
            apply (wp astct stsct hoare_vcg_all_lift
                      cteDeleteOne_ct_not_ksQ hoare_drop_imp
                      hoare_lift_Pf2 [OF cteDeleteOne_sch_act_not cteDeleteOne_ct']
                      hoare_lift_Pf2 [OF doIPCTransfer_st_tcb_at' doIPCTransfer_ct']
                      hoare_lift_Pf2 [OF doIPCTransfer_ksQ doIPCTransfer_ct']
                      hoare_lift_Pf2 [OF threadSet_ksQ threadSet_ct']
                      hoare_lift_Pf2 [OF handleFaultReply_ksQ handleFaultReply_ct']
                   | simp add: ct_in_state'_def)+
     apply (fastforce simp: sch_act_simple_def sch_act_sane_def ct_in_state'_def)+
    done
qed

lemma handleReply_ct_not_ksQ:
  "\<lbrace>invs' and sch_act_simple
           and ct_in_state' simple'
           and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))\<rbrace>
   handleReply
   \<lbrace>\<lambda>rv s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p)\<rbrace>"
  apply (simp add: handleReply_def del: split_paired_All)
  apply (subst haskell_assert_def)
  apply (wp | wpc)+
  apply (wp doReplyTransfer_ct_not_ksQ getThreadCallerSlot_inv)
    apply (rule_tac Q="\<lambda>cap.
                              (\<lambda>s. \<forall>p. ksCurThread s \<notin> set(ksReadyQueues s p))
                          and invs'
                          and sch_act_simple
                          and (\<lambda>s. thread = ksCurThread s)
                          and tcb_at' thread
                          and ct_in_state' simple'
                          and cte_wp_at' (\<lambda>c. cteCap c = cap) callerSlot"
             in hoare_post_imp)
     apply (clarsimp simp: invs'_def valid_state'_def valid_pspace'_def
                           cte_wp_at_ctes_of valid_cap'_def
                    dest!: ctes_of_valid')
    apply (wp getSlotCap_cte_wp_at getThreadCallerSlot_inv)
  apply (clarsimp)
  done

lemma hrw_corres:
  "corres dc (einvs and ct_running)
             (invs' and ct_running' and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread))
         (do x \<leftarrow> handle_reply; handle_wait od)
         (do x \<leftarrow> handleReply; handleWait od)"
  apply (rule corres_guard_imp)
    apply (rule corres_split_nor [OF _ hr_corres])
      apply (rule hw_corres')
     apply (wp handle_reply_nonz_cap_to_ct handleReply_sane
               handleReply_nonz_cap_to_ct handleReply_ct_not_ksQ handle_reply_valid_sched)
   apply (fastforce simp: ct_in_state_def ct_in_state'_def simple_sane_strg
                    elim!: st_tcb_weakenE st_tcb_ex_cap')
  apply (clarsimp simp: ct_in_state'_def)
  apply (frule(1) ct_not_ksQ)
  apply (fastforce elim: st_tcb'_weakenE)
  done


(* FIXME: move *) (* FIXME: should we add this to the simpset? *)
lemma he_corres: 
  "corres (intr \<oplus> dc) (einvs and (\<lambda>s. event \<noteq> Interrupt \<longrightarrow> ct_running s) and
                       (\<lambda>s. scheduler_action s = resume_cur_thread))
                      (invs' and (\<lambda>s. event \<noteq> Interrupt \<longrightarrow> ct_running' s) and
                       (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
                       (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread))
                      (handle_event event) (handleEvent event)"
  (is "?he_corres")
proof -
  have hw:
    "corres dc (einvs and ct_running and (\<lambda>s. scheduler_action s = resume_cur_thread))
               (invs' and ct_running'
                      and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread))
               handle_wait handleWait"
    apply (rule corres_guard_imp [OF hw_corres])
     apply (clarsimp simp: ct_in_state_def ct_in_state'_def
                     elim!: st_tcb_weakenE st_tcb'_weakenE
                     dest!: ct_not_ksQ)+
    done
    show ?thesis
      apply (case_tac event)
          apply (simp_all add: handleEvent_def)
          
          apply (case_tac syscall)
          apply (auto intro: corres_guard_imp[OF hs_corres]
                             corres_guard_imp[OF hw]
                             corres_guard_imp [OF hr_corres]
                             corres_guard_imp[OF hrw_corres]
                             corres_guard_imp[OF hc_corres]
                             corres_guard_imp[OF hy_corres]
                             active_from_running active_from_running'
                      simp: simple_sane_strg)[7]
         apply (rule corres_split')
            apply (rule corres_guard_imp[OF gct_corres], simp+)
           apply (rule hf_corres)
           apply simp
          apply (simp add: valid_fault_def)
          apply wp
          apply (fastforce elim!: st_tcb_ex_cap st_tcb_weakenE
                           simp: ct_in_state_def)
         apply wp
         apply (clarsimp)
         apply (frule(1) ct_not_ksQ)
         apply (auto simp: ct_in_state'_def sch_act_simple_def
                           sch_act_sane_def
                     elim: st_tcb'_weakenE st_tcb_ex_cap'')[1]
        apply (rule corres_split')
           apply (rule corres_guard_imp, rule gct_corres, simp+)
          apply (rule hf_corres)
          apply (simp add: valid_fault_def)
         apply wp
         apply (fastforce elim!: st_tcb_ex_cap st_tcb_weakenE
                          simp: ct_in_state_def valid_fault_def)
        apply wp
        apply clarsimp
        apply (frule(1) ct_not_ksQ)
        apply (auto simp: ct_in_state'_def sch_act_simple_def
                          sch_act_sane_def
                    elim: st_tcb'_weakenE st_tcb_ex_cap'')[1]
       apply (rule corres_guard_imp)
         apply (rule corres_split_eqr[where R="\<lambda>rv. invs and valid_sched"
                                      and R'="\<lambda>rv s. \<forall>x. rv = Some x \<longrightarrow> R'' x s",
                                      standard])
            apply (case_tac rv, simp_all add: doMachineOp_return)[1]
            apply (rule handle_interrupt_corres)
           apply (rule corres_machine_op)
           apply (rule corres_Id, simp+)
           apply (wp hoare_vcg_all_lift
                     doMachineOp_getActiveIRQ_IRQ_active'
                    | simp
                    | simp add: imp_conjR | wp_once hoare_drop_imps)+
        apply force
       apply simp
       apply (simp add: invs'_def valid_state'_def)
      apply (rule_tac corres_split')
         apply (rule corres_guard_imp, rule gct_corres, simp+)
        apply (rule corres_split_catch)
           apply (erule hf_corres)
          apply (rule hv_corres)
         apply (rule hoare_elim_pred_conjE2)
         apply (rule hoare_vcg_E_conj, rule validE_validE_E[OF hv_inv_ex])
         apply (wp handle_vm_fault_valid_fault)
        apply (rule hv_inv_ex')
       apply wp
       apply (clarsimp simp: simple_from_running tcb_at_invs)
       apply (fastforce elim!: st_tcb_ex_cap st_tcb_weakenE simp: ct_in_state_def) 
      apply wp
      apply (clarsimp)
      apply (frule(1) ct_not_ksQ)
      apply (auto simp: simple_sane_strg sch_act_simple_def ct_in_state'_def
                  elim: st_tcb_ex_cap'' st_tcb'_weakenE)
      done
  qed

crunch st_tcb_at'[wp]: handleVMFault "st_tcb_at' P t"
  (ignore: getFAR getDFSR getIFSR)
crunch cap_to'[wp]: handleVMFault "ex_nonz_cap_to' t"
  (ignore: getFAR getDFSR getIFSR)
crunch ksit[wp]: handleVMFault "\<lambda>s. P (ksIdleThread s)"
  (ignore: getFAR getDFSR getIFSR)

lemma hv_inv':
  "\<lbrace>P\<rbrace> handleVMFault p t \<lbrace>\<lambda>_. P\<rbrace>"
  apply (simp add: handleVMFault_def ArchVSpace_H.handleVMFault_def)
  apply (rule hoare_pre)
   apply (wp dmo_inv' getDFSR_inv getFAR_inv getIFSR_inv getRestartPC_inv 
             det_getRestartPC asUser_inv
          |wpc|simp add: throw_def)+
  done

lemma ct_not_idle':
  fixes s
  assumes vi:  "valid_idle' s"
      and cts: "ct_in_state' (\<lambda>tcb. \<not>idle' tcb) s"
  shows "ksCurThread s \<noteq> ksIdleThread s"
proof
  assume "ksCurThread s = ksIdleThread s"
  with vi have "ct_in_state' idle' s"
    unfolding ct_in_state'_def valid_idle'_def
    by (clarsimp elim!: st_tcb'_weakenE)
  
  with cts show False
    unfolding ct_in_state'_def
    by (fastforce dest: st_tcb_at_conj')
qed

lemma ct_running_not_idle'[simp]:
  "\<lbrakk>invs' s; ct_running' s\<rbrakk> \<Longrightarrow> ksCurThread s \<noteq> ksIdleThread s"
  apply (rule ct_not_idle')
   apply (fastforce simp: invs'_def valid_state'_def ct_in_state'_def
                   elim: st_tcb'_weakenE)+
  done

lemma ct_active_not_idle'[simp]:
  "\<lbrakk>invs' s; ct_active' s\<rbrakk> \<Longrightarrow> ksCurThread s \<noteq> ksIdleThread s"
  apply (rule ct_not_idle')
   apply (fastforce simp: invs'_def valid_state'_def ct_in_state'_def
                   elim: st_tcb'_weakenE)+
  done

lemma he_invs'[wp]:
  "\<lbrace>invs' and
      (\<lambda>s. event \<noteq> Interrupt \<longrightarrow> ct_running' s) and
      (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
      (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread)\<rbrace>
   handleEvent event
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
proof -
  have nidle: "\<And>s. invs' s \<and> ct_active' s \<longrightarrow> ksCurThread s \<noteq> ksIdleThread s"
    by (clarsimp)
  show ?thesis
    apply (case_tac event, simp_all add: handleEvent_def)
        apply (case_tac syscall,
               (wp handleReply_sane handleReply_nonz_cap_to_ct handleReply_ksCurThread
                   handleReply_ct_not_ksQ
                | clarsimp simp: active_from_running' simple_from_running' simple_sane_strg simp del: split_paired_All
                | rule conjI active_ex_cap'
                | drule ct_not_ksQ[rotated]
                | strengthen nidle)+)
        apply (rule hoare_strengthen_post,
               rule hoare_weaken_pre,
               rule hy_invs')
         apply (simp add: active_from_running')
        apply simp
       apply (wp hv_inv'
                 | rule conjI
                 | erule st_tcb'_weakenE st_tcb_ex_cap''
                 | clarsimp simp: tcb_at_invs ct_in_state'_def simple_sane_strg sch_act_simple_def
                 | drule st_tcb_at_idle_thread'
                 | drule ct_not_ksQ[rotated]
                 | wpc | wp_once hoare_drop_imps)+ 
  done
qed

lemma inv_irq_IRQInactive:
  "\<lbrace>\<top>\<rbrace> invokeIRQControl irqcontrol_invocation 
  -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: invokeIRQControl_def)
  apply (rule hoare_pre)
   apply (wpc|wp|simp add: invokeInterruptControl_def)+
  done

lemma inv_arch_IRQInactive:
  "\<lbrace>\<top>\<rbrace> ArchRetypeDecls_H.performInvocation invocation 
  -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: ArchRetype_H.performInvocation_def performARMMMUInvocation_def)
  apply wp
  done

lemma retype_pi_IRQInactive:
  "\<lbrace>valid_irq_states'\<rbrace> RetypeDecls_H.performInvocation blocking call v 
   -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: Retype_H.performInvocation_def)
  apply (rule hoare_pre)
   apply (wpc | 
          wp inv_tcb_IRQInactive inv_cnode_IRQInactive inv_irq_IRQInactive 
             inv_arch_IRQInactive |
          simp)+
  done

lemma hi_IRQInactive:
  "\<lbrace>valid_irq_states'\<rbrace> handleInvocation call blocking
    -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: handleInvocation_def split_def)
  apply (wp syscall_valid' retype_pi_IRQInactive)
    apply simp_all
  done

lemma handleSend_IRQInactive:
  "\<lbrace>invs'\<rbrace> handleSend blocking 
  -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: handleSend_def)
  apply (rule hoare_pre)
   apply (wp hi_IRQInactive)
  apply (simp add: invs'_def valid_state'_def)
  done

lemma handleCall_IRQInactive:
  "\<lbrace>invs'\<rbrace> handleCall 
  -, \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> irqstate.IRQInactive\<rbrace>"
  apply (simp add: handleCall_def)
  apply (rule hoare_pre)
   apply (wp hi_IRQInactive)
  apply (simp add: invs'_def valid_state'_def)
  done

lemma he_IRQInactive:
  "\<lbrace>invs'\<rbrace> handleEvent event -,
   \<lbrace>\<lambda>rv s. intStateIRQTable (ksInterruptState s) rv \<noteq> IRQInactive\<rbrace>"
  apply (simp add: handleEvent_def)
  apply (rule hoare_pre)
   apply (wp handleSend_IRQInactive handleCall_IRQInactive
           | wpc | simp)+
  done

end