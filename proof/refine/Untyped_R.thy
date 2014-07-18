(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

(* Proofs about untyped invocations. *)

theory Untyped_R
imports Detype_R Invocations_R
begin

primrec
  untypinv_relation :: "Invocations_A.untyped_invocation \<Rightarrow>
                        Invocations_H.untyped_invocation \<Rightarrow> bool"
where
  "untypinv_relation
     (Invocations_A.Retype c ob n ao n2 cl) x = (\<exists>ao'. x =
     (Invocations_H.Retype (cte_map c) ob n ao' n2
       (map cte_map cl))
           \<and> ao = APIType_map2 (Inr ao'))"

(* FIXME : needs adjustment. *)
primrec
  valid_untyped_inv' :: "Invocations_H.untyped_invocation \<Rightarrow> kernel_state \<Rightarrow> bool"
where
 "valid_untyped_inv' (Invocations_H.Retype slot ptr_base ptr ty us slots)
   = (\<lambda>s. \<exists>sz idx. (cte_wp_at' (\<lambda>cte. cteCap cte = UntypedCap ptr_base sz idx) slot s
          \<and> range_cover ptr sz (APIType_capBits ty us) (length slots)
          \<and> (idx \<le> unat (ptr - ptr_base) \<or> ptr = ptr_base ) \<and> (ptr && ~~ mask sz) = ptr_base)
          \<and> (ptr = ptr_base \<longrightarrow> descendants_range_in' {ptr_base..ptr_base + 2^sz - 1} slot (ctes_of s))
          \<and> distinct (slot # slots)
          \<and> (ty = APIObjectType ArchTypes_H.CapTableObject \<longrightarrow> us > 0)
          \<and> (ty = APIObjectType ArchTypes_H.Untyped \<longrightarrow> 4\<le> us \<and> us \<le> 30)
          \<and> (\<forall>slot \<in> set slots. cte_wp_at' (\<lambda>c. cteCap c = NullCap) slot s)
          \<and> (\<forall>slot \<in> set slots. ex_cte_cap_to' slot s)
          \<and> sch_act_simple s \<and> 0 < length slots)"

lemma whenE_rangeCheck_eq:
  "(rangeCheck (x :: 'a :: {linorder, integral}) y z) =
    (whenE (x < fromIntegral y \<or> fromIntegral z < x)
      (throwError (RangeError (fromIntegral y) (fromIntegral z))))"
  by (simp add: rangeCheck_def unlessE_whenE ucast_id linorder_not_le[symmetric])

declare of_nat_power [simp del]

lemma APIType_map2_CapTable[simp]:
  "(APIType_map2 ty = Structures_A.CapTableObject)
    = (ty = Inr (APIObjectType ArchTypes_H.CapTableObject))"
  by (simp add: APIType_map2_def
         split: sum.split ArchTypes_H.object_type.split
                ArchTypes_H.apiobject_type.split
                kernel_object.split arch_kernel_object.splits)

lemma alignUp_H[simp]:
  "Untyped_H.alignUp = WordSetup.alignUp"
  apply (rule ext)+
  apply (clarsimp simp:Untyped_H.alignUp_def WordSetup.alignUp_def mask_def)
  done

(* MOVE *)
lemma corres_compute_free_index:
  "corres (\<lambda>x y. x = y) (cte_at slot)
     (pspace_aligned' and pspace_distinct' and valid_mdb' and
      cte_wp_at' (\<lambda>_. True) (cte_map slot))
     (const_on_failure idx
        (doE y \<leftarrow> ensure_no_children slot;
             returnOk (0::nat)
         odE))
     (constOnFailure idx
        (doE y \<leftarrow> ensureNoChildren (cte_map slot);
             returnOk (0::nat)
         odE))"
  apply (clarsimp simp:const_on_failure_def constOnFailure_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split_catch[where E = dc and E'=dc])
      apply simp
     apply (rule corres_guard_imp[OF corres_splitEE])
         apply (rule corres_returnOkTT)
         apply simp
        apply (rule ensure_no_children_corres)
        apply simp
       apply wp
      apply simp+
     apply (clarsimp simp:dc_def,wp)+
   apply simp
  apply simp
  done

lemma dec_untyped_inv_corres:
  assumes cap_rel: "list_all2 cap_relation cs cs'"
  shows "corres
        (ser \<oplus> untypinv_relation)
        (invs and cte_wp_at (op = (cap.UntypedCap w n idx)) slot and (\<lambda>s. \<forall>x \<in> set cs. s \<turnstile> x))
        (invs'
          and (\<lambda>s. \<forall>x \<in> set cs'. s \<turnstile>' x))
        (decode_untyped_invocation label args slot (cap.UntypedCap w n idx) cs)
        (decodeUntypedInvocation label args (cte_map slot)
          (capability.UntypedCap w n idx) cs')"
proof (cases "6 \<le> length args \<and> cs \<noteq> []
                \<and> invocation_type label = UntypedRetype")
  case False
  show ?thesis using False cap_rel
    apply (clarsimp simp: decode_untyped_invocation_def
                          decodeUntypedInvocation_def
                          whenE_whenE_body unlessE_whenE
               split del: split_if cong: list.case_cong)
    apply (auto split: list.split)
    done
next
  case True
    have val_le_length_Cons: (* FIXME: clagged from Tcb_R *)
      "\<And>n xs. n \<noteq> 0 \<Longrightarrow> (n \<le> length xs) = (\<exists>y ys. xs = y # ys \<and> (n - 1) \<le> length ys)"
      apply (case_tac xs, simp_all)
      apply (case_tac n, simp_all)
      done

  obtain arg0 arg1 arg2 arg3 arg4 arg5 argsmore cap cap' csmore csmore'
    where args: "args = arg0 # arg1 # arg2 # arg3 # arg4 # arg5 # argsmore"
      and   cs: "cs = cap # csmore"
      and  cs': "cs' = cap' # csmore'"
      and crel: "cap_relation cap cap'"
    using True cap_rel
    apply (clarsimp simp: neq_Nil_conv list_all2_Cons1 val_le_length_Cons)
    apply fastforce
    done

  have il: "invocation_type label = UntypedRetype"
    using True by simp

  have word_unat_power2:
    "\<And>bits. \<lbrakk> bits < 32 \<or> bits < word_bits \<rbrakk> \<Longrightarrow> unat (2 ^ bits :: word32) = 2 ^ bits"
    by (simp add: word_bits_def unat_power_lower)
  have P: "\<And>P. corres (ser \<oplus> dc) \<top> \<top>
                  (whenE P (throwError ExceptionTypes_A.syscall_error.TruncatedMessage))
                  (whenE P (throwError Fault_H.syscall_error.TruncatedMessage))"
    by (simp add: whenE_def returnOk_def)
  have Q: "\<And>v. corres (ser \<oplus> (\<lambda>a b. APIType_map2 (Inr (toEnum (unat v))) = a)) \<top> \<top>
                  (data_to_obj_type v)
                  (whenE (fromEnum (maxBound :: ArchTypes_H.object_type) < unat v)
                       (throwError (Fault_H.syscall_error.InvalidArgument 0)))"
    apply (simp only: data_to_obj_type_def returnOk_bindE fun_app_def)
    apply (simp add: maxBound_def enum_apiobject_type
                     fromEnum_def whenE_def)
    apply (simp add: returnOk_def APIType_map2_def toEnum_def
                     enum_apiobject_type enum_object_type)
    apply (intro conjI impI)
     apply (subgoal_tac "unat v - 5 > 5")
      apply (simp add: arch_data_to_obj_type_def)
     apply simp
    apply (subgoal_tac "\<exists>n. unat v = n + 5")
     apply (clarsimp simp: arch_data_to_obj_type_def returnOk_def)
    apply (rule_tac x="unat v - 5" in exI)
    apply arith
    done
  have R: "\<And>cptr xs. mapM (\<lambda>x. locateSlot cptr x) xs = return (map (\<lambda>x. cptr + 2 ^ cte_level_bits * x) xs)"
    by (simp add: locateSlot_def mapM_return objBits_simps cte_level_bits_def)
  have S: "\<And>x (y :: ('g :: len) word) (z :: 'g word) bits. \<lbrakk> bits < len_of TYPE('g); x < 2 ^ bits \<rbrakk> \<Longrightarrow> toEnum x = (of_nat x :: 'g word)"
    apply (rule toEnum_of_nat)
    apply (erule order_less_trans)
    apply simp
    done
  obtain xs where xs: "xs = [unat arg4..<unat arg4 + unat arg5]"
    by simp
  have YUCK: "\<And>ref bits.
                  \<lbrakk> is_aligned ref bits;
                    Suc (unat arg4 + unat arg5 - Suc 0) \<le> 2 ^ bits;
                    bits < 32; 1 \<le> arg4 + arg5;
                    arg4 \<le> arg4 + arg5 \<rbrakk> \<Longrightarrow>
              (map (\<lambda>x. ref + 2 ^ cte_level_bits * x) [arg4 .e. arg4 + arg5 - 1])
              = map cte_map
               (map (Pair ref)
                 (map (nat_to_cref bits) xs))"
    apply (subgoal_tac "Suc (unat (arg4 + arg5 - 1)) = unat arg4 + unat arg5")
     apply (simp add: upto_enum_def xs del: upt.simps)
     apply (clarsimp simp: cte_map_def)
     apply (subst of_bl_nat_to_cref)
       apply simp
      apply simp
     apply (subst S)
       apply simp
      apply simp
     apply (simp add: cte_level_bits_def)
    apply unat_arith
    done
  have another:
    "\<And>bits a. \<lbrakk> (a::word32) \<le> 2 ^ bits; bits < word_bits\<rbrakk>
       \<Longrightarrow> 2 ^ bits - a = of_nat (2 ^ bits - unat a)"
    apply (subst of_nat_diff)
     apply (subst (asm) word_le_nat_alt)
     apply (simp add: word_unat_power2)
    apply simp
    done
   have ty_size:
   "\<And>x y. (obj_bits_api (APIType_map2 (Inr x)) y) = (Types_H.getObjectSize x y)"
      apply (clarsimp simp:obj_bits_api_def APIType_map2_def getObjectSize_def ArchTypes_H.getObjectSize_def)
      apply (case_tac x)
       apply (simp_all add:arch_kobj_size_def default_arch_object_def
         pageBits_def pdBits_def ptBits_def)
      apply (case_tac apiobject_type)
       apply (simp_all add:apiGetObjectSize_def tcbBlockSizeBits_def epSizeBits_def
         aepSizeBits_def slot_bits_def cteSizeBits_def)
      done
  note word_unat_power [symmetric, simp del]
  show ?thesis
    apply (rule corres_name_pre)
    apply clarsimp
    apply (subgoal_tac "cte_wp_at' (\<lambda>cte. cteCap cte = (capability.UntypedCap w n idx)) (cte_map slot) s'")
    prefer 2
     apply (drule state_relation_pspace_relation)
      apply (case_tac slot)
      apply simp
     apply (drule(1) pspace_relation_cte_wp_at)
      apply fastforce+
    apply (clarsimp simp:cte_wp_at_caps_of_state)
    apply (frule caps_of_state_valid_cap[unfolded valid_cap_def])
     apply fastforce
    apply (clarsimp simp:cap_aligned_def)
(* ugh yuck. who likes a word proof? furthermore, some more restriction of
   the returnOk_bindE stuff needs to be done in order to give you a single
   target to do the word proof against or else it needs repeating. ugh.
   maybe could seperate out the equality Isar-style? *)
    apply (simp add: decodeUntypedInvocation_def decode_untyped_invocation_def
                     args cs cs' xs[symmetric] il whenE_rangeCheck_eq
                     cap_case_CNodeCap unlessE_whenE bool_case_If
                     lookup_target_slot_def lookupTargetSlot_def
                split del: split_if cong: if_cong list.case_cong del: upt.simps)
    apply (rule corres_guard_imp)
      apply (rule corres_splitEE [OF _ Q])
        apply (rule whenE_throwError_corres)
          apply (simp add: word_bits_def word_size)
         apply (simp add: word_size word_bits_def fromIntegral_def
                          toInteger_nat fromInteger_nat linorder_not_less)
         apply fastforce
        apply (rule whenE_throwError_corres, simp)
         apply (clarsimp simp: fromAPIType_def ArchTypes_H.fromAPIType_def)
        apply (rule whenE_throwError_corres, simp)
         apply (clarsimp simp: fromAPIType_def ArchTypes_H.fromAPIType_def)
        apply (rule_tac r' = "\<lambda>cap cap'. cap_relation cap cap'" in corres_splitEE[OF _ corres_if])
             apply (rule_tac corres_split_norE)
                prefer 2
                apply (rule corres_if)
                  apply simp
                 apply (rule corres_returnOk,clarsimp)
                apply (rule corres_trivial)
                apply (clarsimp simp: fromAPIType_def lookup_failure_map_def)
               apply (rule_tac F="is_cnode_cap rva \<and> cap_aligned rva" in corres_gen_asm)
               apply (subgoal_tac "is_aligned (obj_ref_of rva) (bits_of rva) \<and> bits_of rva < 32")
                prefer 2
                apply (clarsimp simp: is_cap_simps bits_of_def cap_aligned_def word_bits_def
                                      is_aligned_weaken)
               apply (rule whenE_throwError_corres)
                 apply (clarsimp simp:retypeFanOutLimit_def is_cap_simps bits_of_def ucast_id)+
                apply (simp add: unat_arith_simps(2) unat_2p_sub_1 unat_power_lower word_bits_def)
               apply (rule whenE_throwError_corres)
                 apply (clarsimp simp:retypeFanOutLimit_def is_cap_simps bits_of_def ucast_id)+
                apply (simp add: unat_eq_0 word_less_nat_alt)
               apply (rule whenE_throwError_corres)
                 apply (clarsimp simp:retypeFanOutLimit_def is_cap_simps bits_of_def ucast_id)+
                apply (clarsimp simp:toInteger_word ucast_id unat_arith_simps(2) cap_aligned_def)
                apply (subst unat_sub)
                 apply (simp add: linorder_not_less word_le_nat_alt)
                apply (fold neq0_conv)
                apply (simp add: unat_eq_0 cap_aligned_def)
               apply (clarsimp simp:fromAPIType_def)
               apply (clarsimp simp:liftE_bindE R)
               apply (subgoal_tac "unat (arg4 + arg5) = unat arg4 + unat arg5")
                prefer 2
                apply (clarsimp simp:not_less)
                apply (subst unat_word_ariths(1))
                apply (rule mod_less)
                apply (unfold word_bits_len_of)[1]
                apply (subgoal_tac "2 ^ bits_of rva < (2 :: nat) ^ word_bits")
                 apply arith
                apply (rule power_strict_increasing, simp add: word_bits_conv)
                apply simp
               apply (frule_tac bits = "bits_of rva" in YUCK)
                   apply (simp)
                  apply (simp add: word_bits_conv)
                 apply (simp add: word_le_nat_alt)
                apply (simp add: word_le_nat_alt)
               apply (simp add:liftE_bindE[symmetric] free_index_of_def)
               apply (rule corres_split_norE)
                  apply (subst liftE_bindE)+
                  apply (rule corres_split[OF _ corres_compute_free_index])
                    apply (rule_tac F ="free_index \<le> 2 ^ n" in corres_gen_asm)
                    apply (rule whenE_throwError_corres)
                      apply (clarsimp simp:shiftL_nat word_less_nat_alt shiftr_div_2n')+
                     apply (simp add:word_of_nat_le unat_power_lower another)
                     apply (drule_tac x = freeIndex in unat_of_nat32[OF le_less_trans])
                      apply (simp add:ty_size shiftR_nat)+
                     apply (simp add:unat_of_nat32 le_less_trans[OF div_le_dividend]
                         le_less_trans[OF diff_le_self])
                    apply (rule corres_returnOkTT)
                    apply (clarsimp simp:ty_size getFreeRef_def get_free_ref_def is_cap_simps)
                   apply (rule hoare_strengthen_post[OF compute_free_index_wp])
                   apply simp
                  apply simp
                  apply wp
                 apply (clarsimp simp:is_cap_simps  simp del:ser_def)
                 apply (simp add: mapME_x_map_simp  del: ser_def)
                 apply (rule_tac P = "valid_cap (cap.CNodeCap r bits g) and invs" in corres_guard_imp [where P' = invs'])
                   apply (rule mapME_x_corres_inv [OF _ _ _ refl])
                     apply (simp del: ser_def)
                     apply (rule ensure_empty_corres)
                     apply (clarsimp simp: is_cap_simps)
                    apply (simp, wp)
                   apply (simp, wp)
                   apply clarsimp
                  apply (clarsimp simp add: xs is_cap_simps bits_of_def valid_cap_def)
                  apply (erule cap_table_at_cte_at)
                  apply (simp add: nat_to_cref_def word_bits_conv)
                 apply simp
                apply (wp mapME_x_inv_wp
                          validE_R_validE[OF valid_validE_R[OF ensure_empty_inv]]
                          validE_R_validE[OF valid_validE_R[OF ensureEmpty_inv]])
            apply simp
           apply (rule corres_returnOkTT)
           apply (rule crel)
          apply simp
          apply (rule corres_splitEE[OF _ lsfc_corres])
              apply simp
              apply (rule getSlotCap_corres,simp)
             apply (rule crel)
            apply simp
           apply (wp lookup_slot_for_cnode_op_inv
                     hoare_drop_impE_R hoare_vcg_all_lift_R
                | clarsimp)+
          apply (rule hoare_strengthen_post [where Q = "\<lambda>r. invs and valid_cap r and cte_at slot"])
           apply wp
          apply (clarsimp simp: is_cap_simps bits_of_def cap_aligned_def
                                valid_cap_def word_bits_def)
          apply (rule TrueI conjI impI)+
         apply wp
         apply (rule hoare_strengthen_post [where Q = "\<lambda>r. invs' and cte_at' (cte_map slot)"])
          apply wp
         apply (clarsimp simp:invs_pspace_aligned' invs_pspace_distinct' )
         apply auto[1]
      apply (wp whenE_throwError_wp | wp_once hoare_drop_imps)+
   apply (clarsimp simp: invs_valid_objs' invs_pspace_aligned' invs_pspace_distinct'
                         cte_wp_at_caps_of_state cte_wp_at_ctes_of )
   apply (clarsimp simp: invs_valid_objs invs_psp_aligned)
   apply (clarsimp simp: is_cap_simps valid_cap_def bits_of_def cap_aligned_def
                         cte_level_bits_def word_bits_conv)
  apply (clarsimp simp: invs_valid_objs' invs_pspace_aligned' invs_pspace_distinct'
                        cte_wp_at_caps_of_state cte_wp_at_ctes_of )
  done
qed

crunch inv[wp]: ensureEmptySlot "P"

lemma decodeUntyped_inv[wp]:
  "\<lbrace>P\<rbrace> decodeUntypedInvocation label args slot
       (UntypedCap w n idx) cs \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (simp add: decodeUntypedInvocation_def whenE_def
                   split_def unlessE_def Let_def
              split del: split_if cong: if_cong list.case_cong)
  apply (rule hoare_pre)
   apply (wp mapME_x_inv_wp hoare_drop_imps constOnFailure_wp
             mapM_wp'
               | wpcw
               | simp add: lookupTargetSlot_def)+
  done


(* Annotation added by Simon Winwood (Thu Jul  1 21:42:31 2010) using taint-mode *)
declare inj_Pair[simp]

declare upt_Suc[simp del]

lemma descendants_of_cte_at':
  "\<lbrakk>p \<in> descendants_of' x (ctes_of s); valid_mdb' s\<rbrakk>
   \<Longrightarrow> cte_wp_at' (\<lambda>_. True) p s"
  by (clarsimp simp:descendants_of'_def cte_wp_at_ctes_of
    dest!:subtree_target_Some)

lemma ctes_of_ko:
  "valid_cap' cap s \<Longrightarrow>
   isUntypedCap cap \<or>
   (\<forall>ptr\<in>capRange cap. \<exists>optr ko. ksPSpace s optr = Some ko \<and>
                                  ptr \<in> obj_range' optr ko)"
  apply (case_tac cap)
   -- "TCB case"
   apply (simp_all add:isCap_simps capRange_def)
   apply (clarsimp simp:valid_cap'_def obj_at'_def)
     apply (intro exI conjI,assumption)
     apply (clarsimp simp:projectKO_eq objBits_def obj_range'_def
       dest!:projectKO_opt_tcbD simp:objBitsKO_def)
   -- "AEP case"
   apply (clarsimp simp:valid_cap'_def obj_at'_def)
     apply (intro exI conjI,assumption)
     apply (clarsimp simp:projectKO_eq objBits_def
       obj_range'_def projectKO_aep objBitsKO_def)
   -- "EP case"
   apply (clarsimp simp:valid_cap'_def obj_at'_def)
     apply (intro exI conjI,assumption)
     apply (clarsimp simp:projectKO_eq objBits_def
       obj_range'_def projectKO_ep objBitsKO_def)
   -- "Zombie case"
    apply (case_tac zombie_type)
     apply (clarsimp simp: valid_cap'_def obj_at'_def)
     apply (intro exI conjI, assumption)
     apply (clarsimp simp: projectKO_eq objBits_def obj_range'_def dest!:projectKO_opt_tcbD simp: objBitsKO_def)
    apply (clarsimp simp: valid_cap'_def obj_at'_def capAligned_def
                           objBits_simps projectKOs)
    apply (frule_tac ptr=ptr and sz=4 in nasty_range
             [where 'a=32, folded word_bits_def]
           , simp+)
    apply clarsimp
    apply (drule_tac x=idx in spec)
    apply (clarsimp simp: less_mask_eq)
    apply (fastforce simp: obj_range'_def projectKOs objBits_simps field_simps)[1]
   -- "Arch cases"
    apply (case_tac arch_capability)
   -- "ASID case"
        apply (clarsimp simp: valid_cap'_def  typ_at'_def ko_wp_at'_def)
        apply (intro exI conjI, assumption)
         apply (clarsimp simp: obj_range'_def archObjSize_def objBitsKO_def)
         apply (case_tac ko,simp+)[1]
         apply (case_tac arch_kernel_object)
           apply (simp add:archObjSize_def asid_low_bits_def pageBits_def)+
   -- "Page case"
      apply (clarsimp simp: valid_cap'_def typ_at'_def ko_wp_at'_def capAligned_def)
      apply (frule_tac ptr = ptr and sz = "pageBits" in nasty_range
               [where 'a=32, folded word_bits_def])
          apply assumption
        apply (simp add: pbfs_atleast_pageBits)+
       apply (clarsimp)
      apply (drule_tac x = idx in spec)
      apply (clarsimp simp: objBitsT_koTypeOf [symmetric] objBitsT_simps)
      apply (intro exI conjI,assumption)
      apply (clarsimp simp:obj_range'_def)
      apply (case_tac ko,simp_all)
      apply (simp add:objBitsKO_def archObjSize_def field_simps shiftl_t2n)
       -- "PT case"
    apply (clarsimp simp: valid_cap'_def obj_at'_def pageBits_def
                          page_table_at'_def typ_at'_def ko_wp_at'_def ptBits_def)
    apply (frule_tac ptr=ptr and sz = 2
      in nasty_range[where 'a=32 and bz="ptBits", folded word_bits_def,
      simplified ptBits_def pageBits_def word_bits_def, simplified])
      apply simp
     apply simp
    apply clarsimp
    apply (drule_tac x=idx in spec)
    apply clarsimp
    apply (intro exI conjI,assumption)
    apply (clarsimp simp:obj_range'_def)
    apply (case_tac ko,simp_all)
    apply (case_tac arch_kernel_object,simp_all)
    apply (simp add:objBitsKO_def archObjSize_def field_simps shiftl_t2n)
     -- "PD case"
   apply (clarsimp simp: valid_cap'_def obj_at'_def pageBits_def pdBits_def
                         page_directory_at'_def typ_at'_def ko_wp_at'_def)
   apply (frule_tac ptr=ptr and sz=2
     in nasty_range[where 'a=32 and bz="pdBits", folded word_bits_def,
     simplified pdBits_def pageBits_def word_bits_def, simplified])
     apply simp
    apply simp
   apply clarsimp
   apply (drule_tac x="idx" in spec)
   apply clarsimp
   apply (intro exI conjI, assumption)
   apply (clarsimp simp: obj_range'_def objBitsKO_def field_simps)
   apply (case_tac ko, simp_all, case_tac arch_kernel_object, simp_all)
   apply (simp add: field_simps archObjSize_def shiftl_t2n)
  -- "CNode case"
  apply (clarsimp simp: valid_cap'_def obj_at'_def capAligned_def
                        objBits_simps projectKOs)
  apply (frule_tac ptr=ptr and sz=4 in nasty_range
    [where 'a=32, folded word_bits_def], simp+)
  apply clarsimp
  apply (drule_tac x=idx in spec)
  apply (clarsimp simp: less_mask_eq)
  apply (fastforce simp: obj_range'_def projectKOs objBits_simps field_simps)[1]
  done

lemma untypedCap_descendants_range':
  "\<lbrakk>valid_pspace' s; (ctes_of s) p = Some cte;
    isUntypedCap (cteCap cte);valid_mdb' s;
    q \<in> descendants_of' p (ctes_of s)\<rbrakk>
   \<Longrightarrow> cte_wp_at' (\<lambda>c. (capRange (cteCap c) \<inter>
                        usableUntypedRange (cteCap cte) = {})) q s"
   apply (clarsimp simp: valid_pspace'_def)
   apply (frule(1) descendants_of_cte_at')
   apply (clarsimp simp:cte_wp_at_ctes_of)
   apply (clarsimp simp:valid_mdb'_def)
   apply (frule valid_mdb_no_loops)
   apply (case_tac "isUntypedCap (cteCap ctea)")
   apply (case_tac ctea)
   apply (case_tac cte)
    apply clarsimp
    apply (frule(1) valid_capAligned[OF ctes_of_valid_cap'])
    apply (frule_tac c = capability in valid_capAligned[OF ctes_of_valid_cap'])
     apply (simp add:untypedCapRange)+
    apply (frule_tac c = capabilitya in aligned_untypedRange_non_empty)
     apply simp
    apply (frule_tac c = capability in aligned_untypedRange_non_empty)
     apply simp
    apply (clarsimp simp:valid_mdb'_def valid_mdb_ctes_def)
    apply (drule untyped_incD')
      apply simp+
    apply clarify
    apply (erule subset_splitE)
       apply simp
       apply (thin_tac "?P\<longrightarrow>?Q")+
       apply (elim conjE)
       apply (simp add:descendants_of'_def)
       apply (drule(1) subtree_trans)
       apply (simp add:no_loops_no_subtree)
      apply simp
     apply (clarsimp simp:descendants_of'_def | erule disjE)+
     apply (drule(1) subtree_trans)
     apply (simp add:no_loops_no_subtree)+
   apply (thin_tac "?P\<longrightarrow>?Q")+
   apply (erule(1) disjoint_subset2[OF usableRange_subseteq])
   apply (simp add:Int_ac)
  apply (case_tac ctea)
  apply (case_tac cte)
  apply clarsimp
  apply (drule(1) ctes_of_valid_cap')+
  apply (frule_tac cap = capability in ctes_of_ko)
  apply (elim disjE)
   apply clarsimp+
  apply (thin_tac "s \<turnstile>' capability")
  apply (clarsimp simp:valid_cap'_def isCap_simps valid_untyped'_def
             simp del:usableUntypedRange.simps untypedRange.simps)
  apply (thin_tac "\<forall>x y z. ?P x y z")
  apply (rule ccontr)
  apply (clarsimp dest!: WordLemmaBucket.int_not_emptyD simp del:usableUntypedRange.simps untypedRange.simps)
  apply (drule(1) bspec)
  apply (clarsimp simp:ko_wp_at'_def simp del:usableUntypedRange.simps untypedRange.simps)
  apply (drule_tac x = optr in spec)
  apply (clarsimp simp:ko_wp_at'_def simp del:usableUntypedRange.simps untypedRange.simps)
  apply (frule(1) pspace_alignedD')
  apply (frule(1) pspace_distinctD')
  apply (erule(1) impE)
  apply (clarsimp simp del:usableUntypedRange.simps untypedRange.simps)
  apply blast
  done

lemma cte_wp_at_caps_descendants_range_inI':
  "\<lbrakk>invs' s; cte_wp_at' (\<lambda>c. (cteCap c) = capability.UntypedCap
                                            (ptr && ~~ mask sz) sz idx) cref s;
    idx \<le> unat (ptr && mask sz); sz < word_bits\<rbrakk>
   \<Longrightarrow> descendants_range_in' {ptr .. (ptr && ~~ mask sz) + 2 ^ sz - 1}
         cref (ctes_of s)"
  apply (frule invs_mdb')
  apply (frule(1) le_mask_le_2p)
  apply (clarsimp simp:descendants_range_in'_def cte_wp_at_ctes_of)
  apply (drule untypedCap_descendants_range'[rotated])
    apply (simp add:isCap_simps)+
   apply (simp add:invs_valid_pspace')
  apply (clarsimp simp:cte_wp_at_ctes_of usable_untyped_range.simps)
  apply (erule disjoint_subset2[rotated])
  apply clarsimp
  apply (rule le_plus'[OF word_and_le2])
  apply simp
  apply (erule word_of_nat_le)
  done

lemma checkFreeIndex_wp:
  "\<lbrace>\<lambda>s. if descendants_of' slot (ctes_of s) = {} then Q 0 s else Q idx s\<rbrace>
   constOnFailure idx (doE y \<leftarrow> ensureNoChildren slot; returnOk (0::nat) odE)
   \<lbrace>Q\<rbrace>"
  apply (clarsimp simp:constOnFailure_def const_def)
  apply wp
  apply (simp add: ensureNoChildren_def whenE_def)
  apply (wp getCTE_wp')
  apply (intro allI impI conjI)
    apply simp_all
   apply (drule conjunct2)
   apply (erule impE)
   apply (clarsimp simp: cte_wp_at_ctes_of nullPointer_def descendants_of'_def)
   apply (rule_tac x = "(mdbNext (cteMDBNode cte))" in exI)
    apply (rule subtree.direct_parent)
      apply (simp add:mdb_next_rel_def mdb_next_def)
     apply simp
    apply (simp add:parentOf_def)+
   apply (drule conjunct1)
   apply (erule impE)
   apply (clarsimp simp: cte_wp_at_ctes_of nullPointer_def descendants_of'_def)
   apply (erule (4) subtree_no_parent)
  apply clarsimp
  apply (drule conjunct1)
  apply (clarsimp simp:nullPointer_def cte_wp_at_ctes_of descendants_of'_def)
  apply (erule(2) subtree_next_0)
  done

declare upt_Suc[simp]

lemma ensureNoChildren_sp:
  "\<lbrace>P\<rbrace> ensureNoChildren sl \<lbrace>\<lambda>rv s. P s \<and> descendants_of' sl (ctes_of s) = {}\<rbrace>,-"
  by (rule hoare_pre, wp ensureNoChildren_wp, simp)

declare isPDCap_PD [simp]

declare diminished_Untyped' [simp]

lemma dui_sp_helper':
  "\<lbrace>P\<rbrace> if Q then returnOk root_cap
       else doE slot \<leftarrow>
                  lookupTargetSlot root_cap cref dpth;
                  liftE (getSlotCap slot)
            odE \<lbrace>\<lambda>rv s. (rv = root_cap \<or> (\<exists>slot. cte_wp_at' (diminished' rv o cteCap) slot s)) \<and> P s\<rbrace>, -"
  apply (cases Q, simp_all add: lookupTargetSlot_def)
   apply (rule hoare_pre, wp, simp)
  apply (simp add: getSlotCap_def split_def)
  apply wp
   apply (rule hoare_strengthen_post [OF getCTE_sp[where P=P]])
   apply (clarsimp simp: cte_wp_at_ctes_of diminished'_def)
   apply (elim allE, drule(1) mp)
   apply (erule allE, subst(asm) maskCapRights_allRights)
   apply simp
  apply (rule hoare_pre, wp)
  apply simp
  done

lemma mapM_locate_eq:
  "mapM (locateSlot x) xs = return (map (\<lambda>y. x + y * 16) xs)"
  apply (induct xs)
   apply (simp add: mapM_def sequence_def)
  apply (simp add: mapM_Cons locateSlot_def objBits_simps mult_ac)
  done

lemma map_ensure_empty':
  "\<lbrace>\<lambda>s. (\<forall>slot \<in> set slots. cte_wp_at' (\<lambda>cte. cteCap cte = NullCap) slot s) \<longrightarrow> P s\<rbrace>
     mapME_x ensureEmptySlot slots
   \<lbrace>\<lambda>rv s. P s \<rbrace>,-"
  apply (induct slots arbitrary: P)
   apply (simp add: mapME_x_def sequenceE_x_def)
   apply wp
  apply (simp add: mapME_x_def sequenceE_x_def)
  apply (rule_tac Q="\<lambda>rv s. (\<forall>slot\<in>set slots. cte_wp_at' (\<lambda>cte. cteCap cte = capability.NullCap) slot s) \<longrightarrow> P s"
    in validE_R_sp)
   apply (simp add: ensureEmptySlot_def unlessE_def)
   apply (wp getCTE_wp')
   apply (clarsimp elim!: cte_wp_at_weakenE')
  apply (erule meta_allE)
  apply (erule hoare_post_imp_R)
  apply clarsimp
  done

lemma irq_nodes_global:
  "\<forall>irq :: word8. irq_node' s + (ucast irq) * 16 \<in> global_refs' s"
  by (simp add: global_refs'_def mult_ac)

lemma valid_global_refsD2':
  "\<lbrakk>ctes_of s p = Some cte; valid_global_refs' s\<rbrakk> \<Longrightarrow>
  global_refs' s \<inter> capRange (cteCap cte) = {}"
  by (blast dest: valid_global_refsD')


lemma cte_cap_in_untyped_range:
  "\<lbrakk> ptr \<le> x; x \<le> ptr + 2 ^ bits - 1; cte_wp_at' (\<lambda>cte. cteCap cte = UntypedCap ptr bits idx) cref s;
     descendants_of' cref (ctes_of s) = {}; invs' s;
     ex_cte_cap_to' x s; valid_global_refs' s \<rbrakk> \<Longrightarrow> False"
  apply (clarsimp simp: ex_cte_cap_to'_def cte_wp_at_ctes_of)
  apply (case_tac ctea, simp)
  apply (frule ctes_of_valid_cap', clarsimp)
  apply (case_tac "\<exists>irq. capability = IRQHandlerCap irq")
   apply (drule (1) equals0D[where a=x, OF valid_global_refsD2'[where p=cref]])
   apply (clarsimp simp: irq_nodes_global)
  apply (frule_tac p=crefa and p'=cref in caps_containedD', assumption)
     apply (clarsimp dest!: isCapDs)
    apply (rule_tac x=x in notemptyI)
    apply (simp add: subsetD [OF cte_refs_capRange])
   apply (clarsimp simp: invs'_def valid_state'_def valid_pspace'_def valid_mdb'_def
                         valid_mdb_ctes_def)
  apply (frule_tac p=cref and p'=crefa in untyped_mdbD', assumption)
      apply (simp_all add: isUntypedCap_def)
    apply (frule valid_capAligned)
    apply (frule capAligned_capUntypedPtr)
     apply (case_tac capability, simp_all)[1]
    apply blast
   apply (case_tac capability, simp_all)[1]
  apply (clarsimp simp: invs'_def valid_state'_def valid_pspace'_def valid_mdb'_def
                        valid_mdb_ctes_def)
  done

lemma cte_refs'_maskCapRights[simp]:
  "cte_refs' (maskCapRights msk cap) = cte_refs' cap"
  apply (rule master_eqI, rule cte_refs_Master)
  apply (simp add: capMasterCap_maskCapRights)
  done

lemma cap_case_CNodeCap_True_throw:
  "(case cap of CNodeCap a b c d \<Rightarrow> returnOk ()
         |  _ \<Rightarrow> throw $ e)
          = (whenE (\<not>isCNodeCap cap) (throwError e))"
  by (simp split: capability.split bool.split
             add: whenE_def isCNodeCap_def)


lemma  APIType_capBits[simp]: "Types_H.getObjectSize a b = APIType_capBits a b"
  apply (case_tac a)
   apply (clarsimp simp:getObjectSize_def APIType_capBits_def ArchTypes_H.getObjectSize_def
     split:ArchTypes_H.apiobject_type.splits simp:
    apiGetObjectSize_def tcbBlockSizeBits_def objBits_def objBitsKO_def pdBits_def
    epSizeBits_def aepSizeBits_def cteSizeBits_def ptBits_def pageBits_def)+
  done


lemma empty_descendants_range_in':
  "\<lbrakk>descendants_of' slot m = {}\<rbrakk> \<Longrightarrow> descendants_range_in' S slot m "
  by (clarsimp simp:descendants_range_in'_def)

lemma decodeUntyped_wf[wp]:
  "\<lbrace>invs' and cte_wp_at' (\<lambda>cte. cteCap cte = UntypedCap w sz idx) slot
          and sch_act_simple
          and (\<lambda>s. \<forall>x \<in> set cs. s \<turnstile>' x)
          and (\<lambda>s. \<forall>x \<in> set cs. \<forall>r \<in> cte_refs' x (irq_node' s). ex_cte_cap_to' r s)\<rbrace>
     decodeUntypedInvocation label args slot
       (UntypedCap w sz idx) cs
   \<lbrace>valid_untyped_inv'\<rbrace>,-"
  apply (simp add: decodeUntypedInvocation_def unlessE_def[symmetric]
                   unlessE_whenE rangeCheck_def whenE_def[symmetric]
                   mapM_locate_eq returnOk_liftE[symmetric] Let_def
                   cap_case_CNodeCap_True_throw
                split del: split_if cong: if_cong list.case_cong)
  apply (rule list_case_throw_validE_R)
   apply (clarsimp split del:if_splits split:list.splits)
   apply (intro conjI impI allI)
    apply ((rule hoare_pre,wp)+)[6]
   apply clarify
   apply (rule validE_R_sp[OF map_ensure_empty'] validE_R_sp[OF whenE_throwError_sp]
     validE_R_sp[OF dui_sp_helper'])+
   apply (rule hoare_pre)
   apply (wp validE_R_sp[OF map_ensure_empty'])+
   apply (wp whenE_throwError_wp validE_R_sp[OF map_ensure_empty'] checkFreeIndex_wp)
   apply (clarsimp simp:cte_wp_at_ctes_of not_less shiftL_nat)
   apply (rename_tac ty us b e srcNode list dimNode s cte)
   apply (case_tac cte)
   apply clarsimp
   apply (frule(1) valid_capAligned[OF ctes_of_valid_cap'[OF _ invs_valid_objs']])
   apply (clarsimp simp:capAligned_def)
   apply (subgoal_tac "idx \<le> 2^ sz")
    prefer 2
    apply (frule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
    apply (clarsimp simp:valid_cap'_def valid_untyped_def)
   apply (subgoal_tac "(2 ^ sz - idx) < 2^ word_bits")
    prefer 2
    apply (rule le_less_trans[where y = "2^sz"])
    apply simp+
   apply (subgoal_tac "of_nat (2 ^ sz - idx) = (2::word32)^sz - of_nat idx")
    prefer 2
    apply (simp add:word_of_nat_minus)
   apply (subgoal_tac "valid_cap' dimNode s")
    prefer 2
    apply (erule disjE)
     apply (fastforce dest: cte_wp_at_valid_objs_valid_cap')
    apply clarsimp
    apply (case_tac cte)
    apply clarsimp
    apply (drule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])+
    apply (drule diminished_valid')
    apply simp
  apply (clarsimp simp: toEnum_of_nat [OF less_Suc_unat_less_bound] ucast_id)
  apply (subgoal_tac "b \<le> 2 ^ capCNodeBits dimNode")
   prefer 2
   apply (clarsimp simp: isCap_simps)
   apply (subst (asm) le_m1_iff_lt[THEN iffD1])
    apply (clarsimp simp:valid_cap'_def isCap_simps p2_gt_0 capAligned_def word_bits_def)
   apply (erule less_imp_le)
  apply (subgoal_tac
    "distinct (map (\<lambda>y. capCNodePtr dimNode + y * 0x10) [b .e. b + e - 1])")
   prefer 2
   apply (simp add: distinct_map upto_enum_def del: upt_Suc)
   apply (rule comp_inj_on)
    apply (rule inj_onI)
    apply (clarsimp simp: toEnum_of_nat dest!: less_Suc_unat_less_bound)
    apply (erule word_unat.Abs_eqD)
     apply (simp add: unats_def)
    apply (simp add: unats_def)
   apply (rule inj_onI)
   apply (clarsimp simp: toEnum_of_nat[OF less_Suc_unat_less_bound]
                         ucast_id isCap_simps)
   apply (erule(2) inj_16)
   apply (subst Suc_unat_diff_1)
    apply (rule word_le_plus_either,simp)
    apply (subst olen_add_eqv)
    apply (subst add_commute)
    apply (erule(1) plus_minus_no_overflow_ab)
   apply (drule(1) le_plus)
   apply (rule unat_le_helper)
   apply (erule order_trans)
   apply (subst unat_power_lower32[symmetric], simp add: word_bits_def)
   apply (simp add: word_less_nat_alt[symmetric])
   apply (rule two_power_increasing)
    apply (clarsimp dest!:valid_capAligned
                     simp:capAligned_def objBits_def objBitsKO_def)
    apply (simp_all add: word_bits_def)[2]
  apply (clarsimp simp: Types_H.fromAPIType_def ArchTypes_H.fromAPIType_def)
  apply (subgoal_tac "Suc (unat (b + e - 1)) = unat b + unat e")
   prefer 2
   apply (subst Suc_unat_diff_1)
    apply (rule word_le_plus_either,simp)
    apply (subst olen_add_eqv)
    apply (subst add_commute)
    apply (erule(1) plus_minus_no_overflow_ab)
    apply (rule unat_plus_simple[THEN iffD1])
    apply (subst olen_add_eqv)
    apply (subst add_commute)
    apply (erule(1) plus_minus_no_overflow_ab)
  apply clarsimp
  apply (subgoal_tac "(\<forall>x. b \<le> x \<and> x \<le> b + e - 1 \<longrightarrow>
    ex_cte_cap_wp_to' (\<lambda>_. True) (capCNodePtr dimNode + x * 0x10) s)")
   prefer 2
   apply clarsimp
   apply (erule disjE)
   apply (erule bspec)
    apply (clarsimp simp:isCap_simps image_def)
    apply (rule_tac x = x in bexI,simp)
    apply simp
    apply (erule order_trans)
    apply (frule(1) le_plus)
    apply (rule word_l_diffs,simp+)
    apply (rule word_le_plus_either,simp)
    apply (subst olen_add_eqv)
    apply (subst add_commute)
    apply (erule(1) plus_minus_no_overflow_ab)
   apply (clarsimp simp:ex_cte_cap_wp_to'_def)
   apply (rule_tac x = nodeSlot in exI)
   apply (case_tac cte)
   apply (clarsimp simp:cte_wp_at_ctes_of diminished_cte_refs'[symmetric]
     isCap_simps image_def)
   apply (rule_tac x = x in bexI,simp)
   apply simp
   apply (erule order_trans)
   apply (frule(1) le_plus)
   apply (rule word_l_diffs,simp+)
   apply (rule word_le_plus_either,simp)
   apply (subst olen_add_eqv)
   apply (subst add_commute)
   apply (erule(1) plus_minus_no_overflow_ab)
  apply (intro conjI)
   apply (clarsimp simp:of_nat_shiftR fromIntegral_def toInteger_nat
     fromInteger_nat word_le_nat_alt of_nat_shiftR)
   apply (frule_tac n = "unat e" and bits = "(APIType_capBits (toEnum (unat ty)) (unat us))"
       in range_cover_stuff[where rv = 0,rotated -1])
         apply (simp add:unat_1_0)
        apply (erule le_trans[OF _ word_le_nat_alt[THEN iffD1],OF _ le_shiftr])
        apply (simp add:word_sub_le_iff word_of_nat_le)
       apply simp+
   apply (clarsimp simp:getFreeRef_def)
   apply (frule alignUp_idem[OF is_aligned_weaken,where a = w])
     apply (erule range_cover.sz)
    apply (simp add:range_cover_def)
   apply (simp add:empty_descendants_range_in')
   apply (clarsimp simp:image_def isCap_simps nullPointer_def word_size)
   apply (drule_tac x = x in spec)+
   apply simp
  apply (clarsimp simp:of_nat_shiftR fromIntegral_def toInteger_nat
     fromInteger_nat word_le_nat_alt of_nat_shiftR)
  apply (frule_tac n = "unat e" and bits = "(APIType_capBits (toEnum (unat ty)) (unat us))"
       in range_cover_stuff[rotated -1])
   apply (simp add:unat_1_0)+
  apply (clarsimp simp:getFreeRef_def)
  apply (intro conjI)
   apply clarsimp
    apply (drule cte_wp_at_caps_descendants_range_inI'
      [where ptr = w and sz = sz and idx = 0 and cref=slot])
       apply (clarsimp simp:cte_wp_at_ctes_of is_aligned_neg_mask_eq)
      apply simp
     apply (simp add:range_cover_def)
    apply (simp add:is_aligned_neg_mask_eq)
   apply (clarsimp simp:image_def isCap_simps)
   apply (drule_tac x = x in spec)+
  apply (simp add:nullPointer_def word_size)+
  done

lemma getCTE_known_cap:
  "\<lbrace>cte_wp_at' (\<lambda>c. cteCap c = cap) p\<rbrace> getCTE p \<lbrace>\<lambda>rv s. cteCap rv = cap\<rbrace>"
  apply (wp getCTE_wp)
  apply (clarsimp simp: cte_wp_at'_def)
  done

lemma getCTE_valid_cap2[wp]:
  "\<lbrace>valid_objs'\<rbrace> getCTE p \<lbrace>\<lambda>rv. valid_cap' (cteCap rv)\<rbrace>"
  apply (rule hoare_strengthen_post [OF getCTE_valid_cap])
  apply simp
  done

(* Annotation added by Simon Winwood (Mon Jul  5 15:50:07 2010) using taint-mode *)
declare is_aligned_0[simp]

lemma corres_list_all2_mapM_':
  assumes w: "suffixeq xs oxs" "suffixeq ys oys"
  assumes y: "\<And>x xs y ys. \<lbrakk> F x y; suffixeq (x # xs) oxs; suffixeq (y # ys) oys \<rbrakk>
               \<Longrightarrow> corres dc (P (x # xs)) (P' (y # ys)) (f x) (g y)"
  assumes z: "\<And>x y xs. \<lbrakk> F x y; suffixeq (x # xs) oxs \<rbrakk> \<Longrightarrow> \<lbrace>P (x # xs)\<rbrace> f x \<lbrace>\<lambda>rv. P xs\<rbrace>"
             "\<And>x y ys. \<lbrakk> F x y; suffixeq (y # ys) oys \<rbrakk> \<Longrightarrow> \<lbrace>P' (y # ys)\<rbrace> g y \<lbrace>\<lambda>rv. P' ys\<rbrace>"
  assumes x: "list_all2 F xs ys"
  shows "corres dc (P xs) (P' ys) (mapM_x f xs) (mapM_x g ys)"
  apply (insert x w)
  apply (induct xs arbitrary: ys)
   apply (simp add: mapM_x_def sequence_x_def)
  apply (case_tac ys)
   apply simp
  apply (clarsimp simp add: mapM_x_def sequence_x_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split [OF _ y])
         apply (clarsimp dest!: suffixeq_ConsD)
         apply (erule meta_allE, (drule(1) meta_mp)+)
         apply assumption
        apply assumption
       apply assumption
      apply assumption
     apply (erule(1) z)+
   apply simp+
  done

lemmas corres_list_all2_mapM_
     = corres_list_all2_mapM_' [OF suffixeq_refl suffixeq_refl]

(* Annotation added by Simon Winwood (Thu Jul  1 21:42:33 2010) using taint-mode *)
declare modify_map_id[simp]

lemma valid_mdbD3':
  "\<lbrakk> ctes_of s p = Some cte; valid_mdb' s \<rbrakk> \<Longrightarrow> p \<noteq> 0"
  by (clarsimp simp add: valid_mdb'_def valid_mdb_ctes_def no_0_def)

lemma capRange_sameRegionAs:
  "\<lbrakk> sameRegionAs x y; s \<turnstile>' y;
      capClass x = PhysicalClass \<or> capClass y = PhysicalClass \<rbrakk>
       \<Longrightarrow> capRange x \<inter> capRange y \<noteq> {}"
  apply (erule sameRegionAsE)
     apply (subgoal_tac "capClass x = capClass y \<and> capRange x = capRange y")
      apply simp
      apply (drule valid_capAligned)
      apply (drule(1) capAligned_capUntypedPtr)
      apply clarsimp
     apply (rule conjI)
      apply (rule master_eqI, rule capClass_Master, simp)
     apply (rule master_eqI, rule capRange_Master, simp)
    apply blast
   apply blast
  apply (clarsimp simp: isCap_simps)
  done

locale mdb_insert_again =
  mdb_ptr_parent: mdb_ptr m _ _ parent parent_cap parent_node +
  mdb_ptr_site: mdb_ptr m _ _ site site_cap site_node
    for m parent parent_cap parent_node site site_cap site_node +

  fixes c'

  assumes site_cap: "site_cap = NullCap"
  assumes site_prev: "mdbPrev site_node = 0"
  assumes site_next: "mdbNext site_node = 0"

  assumes is_untyped: "isUntypedCap parent_cap"
  assumes same_region: "sameRegionAs parent_cap c'"

  assumes range: "descendants_range' c' parent m"
  assumes phys: "capClass c' = PhysicalClass"

  fixes s
  assumes valid_capI': "m p = Some (CTE cap node) \<Longrightarrow> s \<turnstile>' cap"

  assumes ut_rev: "ut_revocable' m"

  fixes n
  defines "n \<equiv>
           (modify_map
             (\<lambda>x. if x = site
                  then Some (CTE c' (MDB (mdbNext parent_node) parent True True))
                  else m x)
             parent (cteMDBNode_update (mdbNext_update (\<lambda>x. site))))"

  assumes neq: "parent \<noteq> site"

context mdb_insert_again
begin

lemmas parent = mdb_ptr_parent.m_p
lemmas site = mdb_ptr_site.m_p

lemma next_wont_bite:
  "\<lbrakk> mdbNext parent_node \<noteq> 0; m (mdbNext parent_node) = Some cte \<rbrakk>
  \<Longrightarrow> \<not> sameRegionAs c' (cteCap cte)"
  using range ut_rev
  apply (cases cte)
  apply clarsimp
  apply (cases "m \<turnstile> parent \<rightarrow> mdbNext parent_node")
   apply (drule (2) descendants_rangeD')
   apply (drule capRange_sameRegionAs)
     apply (erule valid_capI')
    apply (simp add: phys)
   apply blast
  apply (erule notE, rule direct_parent)
    apply (clarsimp simp: mdb_next_unfold parent)
   apply assumption
  apply (simp add: parentOf_def parent)
  apply (insert is_untyped same_region)
  apply (clarsimp simp: isMDBParentOf_CTE)
  apply (rule conjI)
   apply (erule (1) sameRegionAs_trans)
  apply (simp add: ut_revocable'_def)
  apply (insert parent)
  apply simp
  apply (clarsimp simp: isCap_simps)
  done

lemma no_0_helper: "no_0 m \<Longrightarrow> no_0 n"
  by (simp add: n_def, simp add: no_0_def)

lemma no_0_n [intro!]: "no_0 n" by (auto intro: no_0_helper)

lemmas n_0_simps [iff] = no_0_simps [OF no_0_n]

lemmas neqs [simp] = neq neq [symmetric]

definition
  "new_site \<equiv> CTE c' (MDB (mdbNext parent_node) parent True True)"

definition
  "new_parent \<equiv> CTE parent_cap (mdbNext_update (\<lambda>a. site) parent_node)"

lemma n: "n = m (site \<mapsto> new_site, parent \<mapsto> new_parent)"
  using parent site
  by (simp add: n_def modify_map_apply new_site_def new_parent_def
                fun_upd_def[symmetric])

lemma site_no_parent [iff]:
  "m \<turnstile> site \<rightarrow> x = False" using site site_next
  by (auto dest: subtree_next_0)

lemma site_no_child [iff]:
  "m \<turnstile> x \<rightarrow> site = False" using site site_prev
  by (auto dest: subtree_prev_0)

lemma site_no_descendants: "descendants_of' site m = {}"
  by (simp add: descendants_of'_def)

lemma descendants_not_site: "site \<in> descendants_of' p m \<Longrightarrow> False"
  by (simp add: descendants_of'_def)

lemma parent_next: "m \<turnstile> parent \<leadsto> mdbNext parent_node"
  by (simp add: parent mdb_next_unfold)

lemma parent_next_rtrancl_conv [simp]:
  "m \<turnstile> mdbNext parent_node \<leadsto>\<^sup>* site = m \<turnstile> parent \<leadsto>\<^sup>+ site"
  apply (rule iffI)
   apply (insert parent_next)
   apply (fastforce dest: rtranclD)
  apply (drule tranclD)
  apply (clarsimp simp: mdb_next_unfold)
  done

lemma site_no_next [iff]:
  "m \<turnstile> x \<leadsto> site = False" using site site_prev dlist
  apply clarsimp
  apply (simp add: mdb_next_unfold)
  apply (elim exE conjE)
  apply (case_tac z)
  apply simp
  apply (rule dlistEn [where p=x], assumption)
   apply clarsimp
  apply clarsimp
  done

lemma site_no_next_trans [iff]:
  "m \<turnstile> x \<leadsto>\<^sup>+ site = False"
  by (clarsimp dest!: tranclD2)

lemma site_no_prev [iff]:
  "m \<turnstile> site \<leadsto> p = (p = 0)" using site site_next
  by (simp add: mdb_next_unfold)

lemma site_no_prev_trancl [iff]:
  "m \<turnstile> site \<leadsto>\<^sup>+ p = (p = 0)"
  apply (rule iffI)
   apply (drule tranclD)
   apply clarsimp
  apply simp
  apply (insert chain site)
  apply (simp add: mdb_chain_0_def)
  apply auto
  done

lemma chain_n:
  "mdb_chain_0 n"
proof -
  from chain
  have "m \<turnstile> mdbNext parent_node \<leadsto>\<^sup>* 0" using dlist parent
    apply (cases "mdbNext parent_node = 0")
     apply simp
    apply (erule dlistEn, simp)
    apply (auto simp: mdb_chain_0_def)
    done
  moreover
  have "\<not>m \<turnstile> mdbNext parent_node \<leadsto>\<^sup>* parent"
    using parent_next
    apply clarsimp
    apply (drule (1) rtrancl_into_trancl2)
    apply simp
    done
  moreover
  have "\<not> m \<turnstile> 0 \<leadsto>\<^sup>* site" using no_0 site
    by (auto elim!: next_rtrancl_tranclE dest!: no_0_lhs_trancl)
  moreover
  have "\<not> m \<turnstile> 0 \<leadsto>\<^sup>* parent" using no_0 parent
    by (auto elim!: next_rtrancl_tranclE dest!: no_0_lhs_trancl)
  moreover
  note chain
  ultimately show "mdb_chain_0 n" using no_0 parent site
    apply (simp add: n new_parent_def new_site_def)
    apply (auto intro!: mdb_chain_0_update no_0_update simp: next_update_lhs_rtrancl)
    done
qed

lemma no_loops_n: "no_loops n" using chain_n no_0_n
  by (rule mdb_chain_0_no_loops)

lemma irrefl_direct_simp_n [iff]:
  "n \<turnstile> x \<leadsto> x = False"
  using no_loops_n by (rule no_loops_direct_simp)

lemma irrefl_trancl_simp [iff]:
  "n \<turnstile> x \<leadsto>\<^sup>+ x = False"
  using no_loops_n by (rule no_loops_trancl_simp)

lemma n_direct_eq:
  "n \<turnstile> p \<leadsto> p' = (if p = parent then p' = site else
                 if p = site then m \<turnstile> parent \<leadsto> p'
                 else m \<turnstile> p \<leadsto> p')"
  using parent site site_prev
  by (auto simp: mdb_next_update n new_parent_def new_site_def
                 parent_next mdb_next_unfold)

lemma n_site:
  "n site = Some new_site"
  by (simp add: n)

lemma next_not_parent:
  "\<lbrakk> mdbNext parent_node \<noteq> 0; m (mdbNext parent_node) = Some cte \<rbrakk>
      \<Longrightarrow> \<not> isMDBParentOf new_site cte"
  apply (drule(1) next_wont_bite)
  apply (cases cte)
  apply (simp add: isMDBParentOf_def new_site_def)
  done

lemma parent_not_loop:
  "mdbNext parent_node \<noteq> parent"
  apply (insert no_loops)
  apply (simp add: no_loops_def)
  done

(* The newly inserted cap should never have children. *)
lemma site_no_parent_n:
  "n \<turnstile> site \<rightarrow> p = False" using parent valid_badges
  apply clarsimp
  apply (erule subtree.induct)
   prefer 2
   apply simp
  apply (clarsimp simp: parentOf_def mdb_next_unfold n_site new_site_def n)
  apply (cases "mdbNext parent_node = site")
   apply (subgoal_tac "m \<turnstile> parent \<leadsto> site")
    apply simp
   apply (subst mdb_next_unfold)
   apply (simp add: parent)
  apply clarsimp
  apply (erule notE[rotated], erule(1) next_not_parent[unfolded new_site_def])
  done

end

locale mdb_insert_again_child = mdb_insert_again +
  assumes child:
  "isMDBParentOf
   (CTE parent_cap parent_node)
   (CTE c' (MDB (mdbNext parent_node) parent True True))"

context mdb_insert_again_child
begin

lemma new_child [simp]:
  "isMDBParentOf new_parent new_site"
  by (simp add: new_parent_def new_site_def) (rule child)

lemma n_site_child:
  "n \<turnstile> parent \<rightarrow> site"
  apply (rule subtree.direct_parent)
    apply (simp add: n_direct_eq)
   apply simp
  apply (clarsimp simp: parentOf_def parent site n)
  done

lemma parent_m_n:
  assumes "m \<turnstile> p \<rightarrow> p'"
  shows "if p' = parent then n \<turnstile> p \<rightarrow> site \<and> n \<turnstile> p \<rightarrow> p' else n \<turnstile> p \<rightarrow> p'" using assms
proof induct
  case (direct_parent c)
  thus ?case
    apply (cases "p = parent")
     apply simp
     apply (rule conjI, clarsimp)
     apply clarsimp
     apply (rule subtree.trans_parent [where c'=site])
        apply (rule n_site_child)
       apply (simp add: n_direct_eq)
      apply simp
     apply (clarsimp simp: parentOf_def n)
     apply (clarsimp simp: new_parent_def parent)
    apply simp
    apply (subgoal_tac "n \<turnstile> p \<rightarrow> c")
     prefer 2
     apply (rule subtree.direct_parent)
       apply (clarsimp simp add: n_direct_eq)
      apply simp
     apply (clarsimp simp: parentOf_def n)
     apply (fastforce simp: new_parent_def parent)
    apply clarsimp
    apply (erule subtree_trans)
    apply (rule n_site_child)
    done
next
  case (trans_parent c d)
  thus ?case
    apply -
    apply (cases "c = site", simp)
    apply (cases "d = site", simp)
    apply (cases "c = parent")
     apply clarsimp
     apply (erule subtree.trans_parent [where c'=site])
       apply (clarsimp simp add: n_direct_eq)
      apply simp
     apply (clarsimp simp: parentOf_def n)
     apply (rule conjI, clarsimp)
     apply (clarsimp simp: new_parent_def parent)
    apply clarsimp
    apply (subgoal_tac "n \<turnstile> p \<rightarrow> d")
     apply clarsimp
     apply (erule subtree_trans, rule n_site_child)
    apply (erule subtree.trans_parent)
      apply (simp add: n_direct_eq)
     apply simp
    apply (clarsimp simp: parentOf_def n)
    apply (fastforce simp: parent new_parent_def)
    done
qed

lemma n_to_site [simp]:
  "n \<turnstile> p \<leadsto> site = (p = parent)"
  by (simp add: n_direct_eq)

lemma parent_n_m:
  assumes "n \<turnstile> p \<rightarrow> p'"
  shows "if p' = site then p \<noteq> parent \<longrightarrow> m \<turnstile> p \<rightarrow> parent else m \<turnstile> p \<rightarrow> p'"
proof -
  from assms have [simp]: "p \<noteq> site" by (clarsimp simp: site_no_parent_n)
  from assms
  show ?thesis
  proof induct
    case (direct_parent c)
    thus ?case
      apply simp
      apply (rule conjI)
       apply clarsimp
      apply clarsimp
      apply (rule subtree.direct_parent)
        apply (simp add: n_direct_eq split: split_if_asm)
       apply simp
      apply (clarsimp simp: parentOf_def n parent new_parent_def split: split_if_asm)
      done
  next
    case (trans_parent c d)
    thus ?case
      apply clarsimp
      apply (rule conjI, clarsimp)
      apply (clarsimp split: split_if_asm)
      apply (simp add: n_direct_eq)
      apply (cases "p=parent")
       apply simp
       apply (rule subtree.direct_parent, assumption, assumption)
       apply (clarsimp simp: parentOf_def n parent new_parent_def split: split_if_asm)
      apply clarsimp
      apply (erule subtree.trans_parent, assumption, assumption)
      apply (clarsimp simp: parentOf_def n parent new_parent_def split: split_if_asm)
     apply (erule subtree.trans_parent)
       apply (simp add: n_direct_eq split: split_if_asm)
      apply assumption
     apply (clarsimp simp: parentOf_def n parent new_parent_def split: split_if_asm)
     done
 qed
qed

lemma descendants:
  "descendants_of' p n =
   (if parent \<in> descendants_of' p m \<or> p = parent
   then descendants_of' p m \<union> {site} else descendants_of' p m)"
  apply (rule set_eqI)
  apply (simp add: descendants_of'_def)
  apply (fastforce dest!: parent_n_m dest: parent_m_n simp: n_site_child split: split_if_asm)
  done

end

lemma blarg_descendants_of':
  "descendants_of' x (modify_map m p (if P then id else cteMDBNode_update (mdbPrev_update f)))
     = descendants_of' x m"
  by (simp add: descendants_of'_def)

lemma bluhr_descendants_of':
  "mdb_insert_again_child (ctes_of s') parent parent_cap pmdb site site_cap site_node cap s
   \<Longrightarrow>
   descendants_of' x
           (modify_map
             (modify_map
               (\<lambda>c. if c = site
                    then Some (CTE cap (MDB (mdbNext pmdb) parent True True))
                    else ctes_of s' c)
               (mdbNext pmdb)
               (if mdbNext pmdb = 0 then id
                else cteMDBNode_update (mdbPrev_update (\<lambda>x. site))))
             parent (cteMDBNode_update (mdbNext_update (\<lambda>x. site))))
     = (if parent \<in> descendants_of' x (ctes_of s') \<or> x = parent
        then descendants_of' x (ctes_of s') \<union> {site}
        else descendants_of' x (ctes_of s'))"
  apply (subst modify_map_com)
  apply (case_tac x, case_tac mdbnode, clarsimp)
  apply (subst blarg_descendants_of')
  apply (erule mdb_insert_again_child.descendants)
  done

lemma cte_map_eq_subst:
  "\<lbrakk> cte_at p s; cte_at p' s; valid_objs s; pspace_aligned s; pspace_distinct s \<rbrakk>
     \<Longrightarrow> (cte_map p = cte_map p') = (p = p')"
  by (fastforce elim!: cte_map_inj_eq)

lemma mdb_relation_simp:
  "\<lbrakk> (s, s') \<in> state_relation; cte_at p s \<rbrakk>
    \<Longrightarrow> descendants_of' (cte_map p) (ctes_of s') = cte_map ` descendants_of p (cdt s)"
  by (cases p, clarsimp simp: state_relation_def cdt_relation_def)

lemma revokable_relation_simp:
  "\<lbrakk> (s, s') \<in> state_relation; null_filter (caps_of_state s) p = Some c; ctes_of s' (cte_map p) = Some (CTE cap node) \<rbrakk>
      \<Longrightarrow> mdbRevocable node = is_original_cap s p"
  apply (cases p, clarsimp simp: state_relation_def revokable_relation_def)
  apply (elim allE, erule impE, erule exI)
  apply (elim allE, erule (1) impE)
  apply simp
  done

lemma in_getCTE2:
  "((cte, s') \<in> fst (getCTE p s)) = (s' = s \<and> cte_wp_at' (op = cte) p s)"
  apply (safe dest!: in_getCTE)
  apply (clarsimp simp: cte_wp_at'_def getCTE_def)
  done


declare wrap_ext_op_det_ext_ext_def[simp]

lemma do_ext_op_update_cdt_list_symb_exec_l:
  "corres_underlying {(s :: det_ext state, s'). f (kheap s) s'} nf dc P P' (update_cdt_list g) (return x)"
  by (simp add: corres_underlying_def
  update_cdt_list_def set_cdt_list_def bind_def put_def get_def gets_def return_def)

lemma do_ext_op_update_cdt_list_symb_exec_l':
  "corres_underlying {(s::det_state, s'). f (kheap s) (ekheap s) s'} nf dc P P' (create_cap_ext p z a) (return x)"
  apply (simp add: corres_underlying_def create_cap_ext_def
  update_cdt_list_def set_cdt_list_def bind_def put_def get_def gets_def return_def)
  done

crunch it'[wp]: updateMDB "\<lambda>s. P (ksIdleThread s)"
crunch ups'[wp]: updateMDB "\<lambda>s. P (gsUserPages s)"
crunch cns'[wp]: updateMDB "\<lambda>s. P (gsCNodes s)"
crunch ksDomainTime[wp]: updateMDB "\<lambda>s. P (ksDomainTime s)"
crunch ksDomScheduleIdx[wp]: updateMDB "\<lambda>s. P (ksDomScheduleIdx s)"
crunch irq_node[wp]: update_cdt "\<lambda>s. P (interrupt_irq_node s)"
crunch ksWorkUnitsCompleted[wp]: updateMDB "\<lambda>s. P (ksWorkUnitsCompleted s)"

crunch exst[wp]: set_cdt "\<lambda>s. P (exst s)"

(*FIXME: Move to StateRelation*)
lemma state_relation_schact[elim!]: "(s,s') \<in> state_relation \<Longrightarrow> sched_act_relation (scheduler_action s) (ksSchedulerAction s')"
  apply (simp add: state_relation_def)
  done

lemma state_relation_queues[elim!]: "(s,s') \<in> state_relation \<Longrightarrow> ready_queues_relation (ready_queues s) (ksReadyQueues s')"
  apply (simp add: state_relation_def)
  done

lemma set_original_symb_exec_l:
  "corres_underlying {(s, s'). f (kheap s) (exst s) s'} nf dc P P' (set_original p b) (return x)"
  by (simp add: corres_underlying_def return_def set_original_def in_monad Bex_def)

lemma set_cdt_symb_exec_l:
  "corres_underlying {(s, s'). f (kheap s) (exst s) s'} nf dc P P' (set_cdt g) (return x)"
  by (simp add: corres_underlying_def return_def set_cdt_def in_monad Bex_def)

crunch domain_index[wp]: create_cap_ext "\<lambda>s. P (domain_index s)"
crunch domain_list[wp]: create_cap_ext "\<lambda>s. P (domain_list s)"
crunch domain_time[wp]: create_cap_ext "\<lambda>s. P (domain_time s)"
crunch work_units_completed[wp]: create_cap_ext "\<lambda>s. P (work_units_completed s)"

lemma create_cap_corres:
notes if_cong[cong del] if_weak_cong[cong]
shows
  "\<lbrakk> cref' = cte_map (fst tup)
     \<and> cap_relation (default_cap tp (snd tup) sz) cap \<rbrakk> \<Longrightarrow>
   corres dc
     (cte_wp_at (op = cap.NullCap) (fst tup) and pspace_aligned
        and pspace_distinct and valid_objs and valid_mdb and valid_list
        and cte_wp_at (op \<noteq> cap.NullCap) p)
     (cte_wp_at' (\<lambda>c. cteCap c = NullCap) cref' and
      cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and> sameRegionAs (cteCap cte) cap) (cte_map p)
       and valid_mdb' and pspace_aligned' and pspace_distinct' and valid_objs'
       and (\<lambda>s. descendants_range' cap (cte_map p) (ctes_of s)))
     (create_cap tp sz p tup)
     (insertNewCap (cte_map p) cref' cap)"
  apply (cases tup,
         clarsimp simp add: create_cap_def insertNewCap_def
                            liftM_def)
  apply (rule corres_symb_exec_r [OF _ getCTE_sp])+
      prefer 3
      apply (rule no_fail_pre, wp)
      apply (clarsimp elim!: cte_wp_at_weakenE')
     prefer 4
     apply (rule no_fail_pre, wp)
     apply (clarsimp elim!: cte_wp_at_weakenE')
    apply (rule corres_assert_assume)
     prefer 2
     apply (case_tac oldCTE)
     apply (clarsimp simp: cte_wp_at_ctes_of valid_mdb'_def valid_mdb_ctes_def
                           valid_nullcaps_def)
     apply (erule allE)+
     apply (erule (1) impE)
     apply (simp add: initMDBNode_def)
    apply clarsimp
    apply (rule_tac F="capClass cap = PhysicalClass" in corres_req)
     apply (clarsimp simp: cte_wp_at_ctes_of isCap_simps)
     apply (drule sameRegionAs_classes, simp)
    apply (rule corres_caps_decomposition)
                                    prefer 3
                                    apply wp+
                                       apply (rule hoare_post_imp, simp)
                                       apply wp
                                   defer
                                   apply ((wp | simp)+)[1]
                                  apply (simp add: create_cap_ext_def set_cdt_list_def update_cdt_list_def bind_assoc)
                                  apply ((wp | simp)+)[1]
                                 apply (wp updateMDB_ctes_of_cases
                                          getCTE_ctes_of_weakened
                                          | simp add: o_def split del: split_if)+
            apply (clarsimp simp: cdt_relation_def cte_wp_at_ctes_of
                     split del: split_if cong: if_cong simp del: id_apply)
            apply (subst if_not_P, erule(1) valid_mdbD3')
            apply (case_tac x, case_tac oldCTE)
            apply (subst bluhr_descendants_of')
             apply (rule mdb_insert_again_child.intro)
              apply (rule mdb_insert_again.intro)
                apply (rule mdb_ptr.intro)
                 apply (simp add: valid_mdb'_def vmdb_def)
                apply (rule mdb_ptr_axioms.intro)
                apply simp
               apply (rule mdb_ptr.intro)
                apply (simp add: valid_mdb'_def vmdb_def)
               apply (rule mdb_ptr_axioms.intro)
               apply fastforce
              apply (rule mdb_insert_again_axioms.intro)
                       apply (clarsimp simp: nullPointer_def)+
                apply (erule (1) ctes_of_valid_cap')
               apply (simp add: valid_mdb'_def valid_mdb_ctes_def)
              apply clarsimp
             apply (rule mdb_insert_again_child_axioms.intro)
             apply (clarsimp simp: isMDBParentOf_def)
             apply (clarsimp simp: isCap_simps)
             apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def
                                   ut_revocable'_def)
             apply (erule_tac x="cte_map p" in allE)
             apply (simp add: isCap_simps)
            apply (fold fun_upd_def)
            apply (subst descendants_of_insert_child')
               apply (erule(1) mdb_Null_descendants)
              apply (clarsimp simp: cte_wp_at_def)
             apply (erule(1) mdb_Null_None)
            apply (subgoal_tac "cte_at (aa, bb) s")
             prefer 2
             apply (drule not_sym, clarsimp simp: cte_wp_at_caps_of_state split: split_if_asm)
            apply (subst descendants_of_eq' [OF _ cte_wp_at_cte_at], assumption+)
                 apply (clarsimp simp: state_relation_def)
                apply assumption+
            apply (subst cte_map_eq_subst [OF _ cte_wp_at_cte_at], assumption+)
            apply (simp add: mdb_relation_simp)
           defer
           apply (clarsimp split del: split_if)+
         apply (clarsimp simp add: revokable_relation_def cte_wp_at_ctes_of
                        split del: split_if)
         apply simp
         apply (rule conjI)
          apply clarsimp
          apply (elim modify_map_casesE)
             apply ((clarsimp split: split_if_asm cong: conj_cong
                              simp: cte_map_eq_subst cte_wp_at_cte_at
                                    revokable_relation_simp)+)[4]
         apply clarsimp
         apply (subgoal_tac "null_filter (caps_of_state s) (aa, bb) \<noteq> None")
          prefer 2
          apply (clarsimp simp: null_filter_def cte_wp_at_caps_of_state split: split_if_asm)
         apply (subgoal_tac "cte_at (aa,bb) s")
          prefer 2
          apply clarsimp
          apply (drule null_filter_caps_of_stateD)
          apply (erule cte_wp_cte_at)
         apply (elim modify_map_casesE)
            apply (clarsimp split: split_if_asm cong: conj_cong
                             simp: cte_map_eq_subst cte_wp_at_cte_at
                                   revokable_relation_simp)+
        apply (clarsimp simp: state_relation_def ghost_relation_of_heap)+
     apply wp
   apply (rule corres_guard_imp)
     apply (rule corres_underlying_symb_exec_l [OF gets_symb_exec_l])
      apply (rule corres_underlying_symb_exec_l [OF gets_symb_exec_l])
       apply (rule corres_underlying_symb_exec_l [OF set_cdt_symb_exec_l])
        apply (rule corres_underlying_symb_exec_l [OF do_ext_op_update_cdt_list_symb_exec_l'])
         apply (rule corres_underlying_symb_exec_l [OF set_original_symb_exec_l])
          apply (rule corres_cong[OF refl refl _ refl refl, THEN iffD1])
           apply (rule bind_return[THEN fun_cong])
          apply (rule corres_split [OF _ set_cap_pspace_corres])
             apply (subst bind_return[symmetric],
                    rule corres_split)
                prefer 2
                apply (simp add: dc_def[symmetric])
                apply (rule updateMDB_symb_exec_r)
               apply (simp add: dc_def[symmetric])
               apply (rule updateMDB_symb_exec_r)
              apply (wp getCTE_wp set_cdt_valid_objs set_cdt_cte_at
                        hoare_weak_lift_imp | simp add: o_def)+
    apply (clarsimp simp: cte_wp_at_cte_at)
   apply (clarsimp simp: cte_wp_at_ctes_of no_0_def valid_mdb'_def
                         valid_mdb_ctes_def)
   apply (rule conjI, clarsimp)
   apply clarsimp
   apply (erule (2) valid_dlistEn)
   apply simp
  apply(simp only: cdt_list_relation_def valid_mdb_def2
              del: split_paired_All split_paired_Ex split del: split_if)
  apply(subgoal_tac "finite_depth (cdt s)")
   prefer 2
   apply(simp add: finite_depth valid_mdb_def2[symmetric])
  apply(intro impI allI)
  apply(subgoal_tac "mdb_insert_abs (cdt s) p (a, b)")
   prefer 2
   apply(clarsimp simp: cte_wp_at_caps_of_state)
   apply(rule mdb_insert_abs.intro)
     apply(clarsimp)
    apply(erule (1) mdb_cte_at_Null_None)
   apply (erule (1) mdb_cte_at_Null_descendants)
  apply(subgoal_tac "no_0 (ctes_of s')")
   prefer 2
   apply(simp add: valid_mdb_ctes_def valid_mdb'_def)
  apply simp
  apply (elim conjE)
  apply (case_tac "cdt s (a,b)")
   prefer 2
   apply (simp add: mdb_insert_abs_def)
  apply simp
  apply(case_tac x)
  apply(simp add: cte_wp_at_ctes_of)
  apply(simp add: mdb_insert_abs.next_slot split del: split_if)
  apply(case_tac "c=p")
   apply(simp)
   apply(clarsimp simp: modify_map_def)
   apply(case_tac z)
   apply(fastforce split: split_if_asm)
  apply(case_tac "c = (a, b)")
   apply(simp)
   apply(case_tac "next_slot p (cdt_list s) (cdt s)")
    apply(simp)
   apply(simp)
   apply(clarsimp simp: modify_map_def const_def)
   apply(clarsimp split: split_if_asm)
    apply(drule_tac p="cte_map p" in valid_mdbD1')
      apply(simp)
     apply(simp add: valid_mdb'_def valid_mdb_ctes_def)
    apply(clarsimp simp: nullPointer_def no_0_def)
    apply(clarsimp simp: state_relation_def)
    apply(clarsimp simp: cte_wp_at_caps_of_state)
    apply(drule_tac slot=p in pspace_relation_ctes_ofI)
       apply(simp add: cte_wp_at_caps_of_state)
      apply(simp)
     apply(simp)
    apply(simp)
   apply(clarsimp simp: state_relation_def cdt_list_relation_def)
   apply(erule_tac x="fst p" in allE, erule_tac x="snd p" in allE)
   apply(fastforce)
  apply(simp)
  apply(case_tac "next_slot c (cdt_list s) (cdt s)")
   apply(simp)
  apply(simp)
  apply(subgoal_tac "cte_at c s")
   prefer 2
   apply(rule cte_at_next_slot)
      apply(simp_all add: valid_mdb_def2)[4]
  apply(clarsimp simp: modify_map_def const_def)
  apply(simp split: split_if_asm)
       apply(simp add: valid_mdb'_def)
       apply(drule_tac ptr="cte_map p" in no_self_loop_next)
        apply(simp)
       apply(simp)
      apply(drule_tac p="(aa, bb)" in cte_map_inj)
           apply(simp_all add: cte_wp_at_caps_of_state)[5]
       apply(clarsimp)
      apply(simp)
     apply(clarsimp)
     apply(drule cte_map_inj_eq)
          apply(simp_all add: cte_wp_at_caps_of_state)[6]
    apply(clarsimp)
    apply(case_tac z)
    apply(clarsimp simp: state_relation_def cdt_list_relation_def)
    apply(erule_tac x=aa in allE, erule_tac x=bb in allE)
    apply(fastforce)
   apply(clarsimp)
   apply(drule cte_map_inj_eq)
        apply(simp_all add: cte_wp_at_caps_of_state)[6]
  apply(clarsimp simp: state_relation_def cdt_list_relation_def)
  apply(erule_tac x=aa in allE, erule_tac x=bb in allE, fastforce)
  done

lemma insertNewCap_mdbNext:
  "\<lbrace>\<lambda>s. \<not> sameRegionAs cap' cap \<and> parent \<noteq> slot \<and> valid_mdb' s
         \<and> parent \<noteq> 0 \<and> slot \<noteq> 0\<rbrace> insertNewCap parent slot cap
   \<lbrace>\<lambda>rv s. \<forall>next. cte_wp_at' (\<lambda>cte. mdbNext (cteMDBNode cte) = next) parent s \<and> next \<noteq> 0
                        \<longrightarrow> cte_wp_at' (\<lambda>cte. \<not> sameRegionAs cap' (cteCap cte)) next s\<rbrace>"
  apply (simp add: insertNewCap_def cte_wp_at_ctes_of)
  apply (wp getCTE_ctes_of updateMDB_ctes_of_cases | simp add: o_def split del: split_if)+
  apply (clarsimp split del: split_if simp: nullPointer_def)
  apply (erule modify_map_casesE, simp_all split del: split_if)
  apply (subst modify_map_other)
   apply assumption
  apply (subst modify_map_other)
   defer
   apply simp
  apply clarsimp
  apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def)
  apply (erule(2) valid_dlistE(1))
  apply simp
  done

lemma setCTE_cteCaps_of[wp]:
  "\<lbrace>\<lambda>s. P ((cteCaps_of s)(p \<mapsto> cteCap cte))\<rbrace>
      setCTE p cte
   \<lbrace>\<lambda>rv s. P (cteCaps_of s)\<rbrace>"
  apply (simp add: cteCaps_of_def)
  apply wp
  apply (clarsimp elim!: rsubst[where P=P] intro!: ext)
  done

lemma insertNewCap_wps[wp]:
  "\<lbrace>pspace_aligned'\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv. pspace_aligned'\<rbrace>"
  "\<lbrace>pspace_distinct'\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv. pspace_distinct'\<rbrace>"
  "\<lbrace>\<lambda>s. P ((cteCaps_of s)(slot \<mapsto> cap))\<rbrace>
      insertNewCap parent slot cap
   \<lbrace>\<lambda>rv s. P (cteCaps_of s)\<rbrace>"
  apply (simp_all add: insertNewCap_def)
   apply (wp hoare_drop_imps
            | simp add: o_def)+
  apply (clarsimp elim!: rsubst[where P=P] intro!: ext)
  done

definition apitype_of :: "cap \<Rightarrow> apiobject_type option"
where
  "apitype_of c \<equiv> case c of
    Structures_A.UntypedCap p b idx \<Rightarrow> Some ArchTypes_H.Untyped
  | Structures_A.EndpointCap r badge rights \<Rightarrow> Some EndpointObject
  | Structures_A.AsyncEndpointCap r badge rights \<Rightarrow> Some AsyncEndpointObject
  | Structures_A.CNodeCap r bits guard \<Rightarrow> Some ArchTypes_H.CapTableObject
  | Structures_A.ThreadCap r \<Rightarrow> Some TCBObject
  | _ \<Rightarrow> None"

lemma sameRegion_untyped_imp_subseteq:
  "\<lbrakk>RetypeDecls_H.sameRegionAs cap c; isUntypedCap cap\<rbrakk>
   \<Longrightarrow> capRange c \<subseteq> untypedRange cap"
   apply (simp add:sameRegionAs_def3)
   apply (elim disjE)
     apply (clarsimp simp:capRange_of_untyped isCap_simps)
     apply (drule(1) subsetD)
     apply simp
   apply (simp add:isCap_simps)
  done

lemma cteCaps_of_ran_Ball:
  "(\<forall>x \<in> ran (cteCaps_of s). P x) = (\<forall>x \<in> ran (ctes_of s). P (cteCap x))"
  apply (simp add: cteCaps_of_def ran_def)
  apply fastforce
  done

lemma cteCaps_of_ran_Ball_upd:
  "(\<forall>x \<in> ran (\<lambda>x. if x = p then None else cteCaps_of s x). P x)
     = (\<forall>x \<in> ran (\<lambda>x. if x = p then None else ctes_of s x). P (cteCap x))"
  apply (simp add: cteCaps_of_def ran_def)
  apply fastforce
  done

lemma cte_wp_at_cteCaps_of:
  "cte_wp_at' (\<lambda>cte. P (cteCap cte)) p s
    = (\<exists>cap. cteCaps_of s p = Some cap \<and> P cap)"
  apply (subst tree_cte_cteCap_eq[unfolded o_def])
  apply (clarsimp split: option.splits)
  done

lemma caps_contained_modify_mdb_helper[simp]:
  "(\<exists>n. modify_map m p (cteMDBNode_update f) x = Some (CTE c n))
    = (\<exists>n. m x = Some (CTE c n))"
  apply (cases "m p", simp_all add: modify_map_def)
  apply (case_tac a, simp_all)
  done

lemma caps_contained_modify_mdb[simp]:
  "caps_contained' (modify_map m p (cteMDBNode_update f))
    = caps_contained' m"
  by (simp add: caps_contained'_def)

lemma sameRegionAs_capRange_subset:
  "\<lbrakk> sameRegionAs c c'; capClass c = PhysicalClass \<rbrakk> \<Longrightarrow> capRange c' \<subseteq> capRange c"
  apply (erule sameRegionAsE)
     apply (rule equalityD1)
     apply (rule master_eqI, rule capRange_Master)
     apply simp
    apply assumption+
  apply (clarsimp simp: isCap_simps)
  done


definition
  is_end_chunk :: "cte_heap \<Rightarrow> capability \<Rightarrow> word32 \<Rightarrow> bool"
where
 "is_end_chunk ctes cap p \<equiv> \<exists>p'. ctes \<turnstile> p \<leadsto> p'
       \<and> (\<exists>cte. ctes p = Some cte \<and> sameRegionAs cap (cteCap cte))
       \<and> (\<forall>cte'. ctes p' = Some cte' \<longrightarrow> \<not> sameRegionAs cap (cteCap cte'))"

lemma chunk_end_chunk:
  "\<lbrakk> is_chunk ctes cap p p'; ctes \<turnstile> p \<leadsto>\<^sup>+ p'; is_end_chunk ctes cap p \<rbrakk>
     \<Longrightarrow> P"
  apply (clarsimp simp add: is_chunk_def is_end_chunk_def)
  apply (drule_tac x=p'a in spec)
  apply (drule mp)
   apply (erule trancl.intros)
  apply (drule mp)
   apply (drule tranclD, clarsimp)
   apply (simp add: mdb_next_unfold)
  apply clarsimp
  done

lemma end_chunk_site:
  "is_end_chunk ctes cap p
    \<Longrightarrow> \<exists>pcap pnode. ctes p = Some (CTE pcap pnode)
            \<and> sameRegionAs cap pcap"
  apply (clarsimp simp: is_end_chunk_def)
  apply (case_tac cte, simp)
  done

lemma chunk_region_trans:
  "\<lbrakk> sameRegionAs cap cap'; is_chunk ctes cap' p p' \<rbrakk>
      \<Longrightarrow> is_chunk ctes cap p p'"
  apply (simp add: is_chunk_def)
  apply (erule allEI)
  apply clarsimp
  apply (erule(1) sameRegionAs_trans)
  done

lemma sameRegionAs_refl:
  "sameRegionAs cap cap' \<Longrightarrow> sameRegionAs cap cap"
  apply (simp add: sameRegionAs_def3)
  apply (elim disjE exE)
    apply simp
   apply fastforce
  apply (clarsimp simp: isCap_simps)
  done

definition
  mdb_chunked2 :: "cte_heap \<Rightarrow> bool"
where
 "mdb_chunked2 ctes \<equiv> (\<forall>x p p' cte. ctes x = Some cte
         \<and> is_end_chunk ctes (cteCap cte) p \<and> is_end_chunk ctes (cteCap cte) p'
             \<longrightarrow> p = p')
      \<and> (\<forall>p p' cte cte'. ctes p = Some cte \<and> ctes p' = Some cte'
                 \<and> ctes \<turnstile> p \<leadsto> p' \<and> sameRegionAs (cteCap cte') (cteCap cte)
                      \<longrightarrow> sameRegionAs (cteCap cte) (cteCap cte'))"

lemma mdb_chunked2_endD:
  "\<lbrakk> is_end_chunk ctes cap p; is_end_chunk ctes cap p';
      mdb_chunked2 ctes; ctes x = Some (CTE cap node) \<rbrakk> \<Longrightarrow> p = p'"
  by (fastforce simp add: mdb_chunked2_def)

lemma mdb_chunked2_revD:
  "\<lbrakk> ctes p = Some cte; ctes p' = Some cte'; ctes \<turnstile> p \<leadsto> p';
      mdb_chunked2 ctes; sameRegionAs (cteCap cte') (cteCap cte) \<rbrakk>
       \<Longrightarrow> sameRegionAs (cteCap cte) (cteCap cte')"
  by (fastforce simp add: mdb_chunked2_def)

lemma valid_dlist_step_back:
  "\<lbrakk> ctes \<turnstile> p \<leadsto> p''; ctes \<turnstile> p' \<leadsto> p''; valid_dlist ctes; p'' \<noteq> 0 \<rbrakk>
      \<Longrightarrow> p = p'"
  apply (simp add: mdb_next_unfold valid_dlist_def)
  apply (frule_tac x=p in spec)
  apply (drule_tac x=p' in spec)
  apply (clarsimp simp: Let_def)
  done

lemma valid_dlist_step_back_trans:
  "\<lbrakk> valid_dlist ctes; ctes \<turnstile> p \<leadsto>\<^sup>+ p''; ctes \<turnstile> p' \<leadsto> p''; p'' \<noteq> 0 \<rbrakk>
      \<Longrightarrow> ctes \<turnstile> p \<leadsto>\<^sup>* p'"
  apply (erule tranclE)
   apply (drule(3) valid_dlist_step_back)
   apply simp
  apply (drule(3) valid_dlist_step_back)
  apply simp
  done

lemma chunk_sameRegionAs_step1:
  "\<lbrakk> ctes \<turnstile> p' \<leadsto>\<^sup>* p''; ctes p'' = Some cte;
      is_chunk ctes (cteCap cte) p p'';
      mdb_chunked2 ctes; valid_dlist ctes \<rbrakk> \<Longrightarrow>
     \<forall>cte'. ctes p' = Some cte'
     \<longrightarrow> ctes \<turnstile> p \<leadsto>\<^sup>+ p'
     \<longrightarrow> sameRegionAs (cteCap cte') (cteCap cte)"
  apply (erule converse_rtrancl_induct)
   apply (clarsimp simp: is_chunk_def)
   apply (drule_tac x=p'' in spec, clarsimp)
   apply (clarsimp simp: is_chunk_def)
  apply (frule_tac x=y in spec)
  apply (drule_tac x=z in spec)
  apply ((drule mp, erule(1) transitive_closure_trans)
              | clarsimp)+
  apply (rule sameRegionAs_trans[rotated], assumption)
  apply (drule(3) mdb_chunked2_revD)
   apply simp
   apply (erule(1) sameRegionAs_trans)
  apply simp
  done

lemma chunk_sameRegionAs:
  "\<lbrakk> ctes \<turnstile> p \<leadsto>\<^sup>+ p';
     ctes p = Some cte; ctes p' = Some cte';
     is_chunk ctes (cteCap cte') p p';
     mdb_chunked2 ctes; valid_dlist ctes;
     sameRegionAs (cteCap cte') (cteCap cte) \<rbrakk> \<Longrightarrow>
      sameRegionAs (cteCap cte) (cteCap cte')"
  apply (erule tranclE2)
   apply (erule(4) mdb_chunked2_revD)
  apply (frule(4) chunk_sameRegionAs_step1[OF trancl_into_rtrancl])
  apply (case_tac "ctes c")
   apply (erule tranclE2, (clarsimp simp: mdb_next_unfold)+)[1]
  apply (clarsimp simp: trancl.intros(1))
  apply (rule sameRegionAs_trans[rotated], assumption)
  apply (erule(3) mdb_chunked2_revD)
  apply (erule(1) sameRegionAs_trans)
  done

locale mdb_insert_again_all = mdb_insert_again_child +
  assumes valid_c': "s \<turnstile>' c'"

  fixes n'
  defines "n' \<equiv> modify_map n (mdbNext parent_node) (cteMDBNode_update (mdbPrev_update (\<lambda>a. site)))"
begin

lemma no_0_n' [simp]: "no_0 n'"
  using no_0_n by (simp add: n'_def)

lemma dom_n' [simp]: "dom n' = dom n"
  apply (simp add: n'_def)
  apply (simp add: modify_map_if dom_def)
  apply (rule set_eqI)
  apply simp
  apply (rule iffI)
   apply auto[1]
  apply clarsimp
  apply (case_tac y)
  apply (case_tac "mdbNext parent_node = x")
   apply auto
  done

lemma mdb_chain_0_n' [simp]: "mdb_chain_0 n'"
  using chain_n
  apply (simp add: mdb_chain_0_def)
  apply (simp add: n'_def  trancl_prev_update)
  done

lemma parency_n':
  "n' \<turnstile> p \<rightarrow> p' = (if m \<turnstile> p \<rightarrow> parent \<or> p = parent
                 then m \<turnstile> p \<rightarrow> p' \<or> p' = site
                  else m \<turnstile> p \<rightarrow> p')"
  using descendants [of p]
  unfolding descendants_of'_def
  by (auto simp add: set_eq_iff n'_def)

lemma n'_direct_eq:
  "n' \<turnstile> p \<leadsto> p' = (if p = parent then p' = site else
                  if p = site then m \<turnstile> parent \<leadsto> p'
                  else m \<turnstile> p \<leadsto> p')"
  by (simp add: n'_def n_direct_eq)

lemma n'_tranclD:
  "n' \<turnstile> p \<leadsto>\<^sup>+ p' \<Longrightarrow>
  (if p = site then m \<turnstile> parent \<leadsto>\<^sup>+ p'
   else if m \<turnstile> p \<leadsto>\<^sup>+ parent \<or> p = parent  then m \<turnstile> p \<leadsto>\<^sup>+ p' \<or> p' = site
   else m \<turnstile> p \<leadsto>\<^sup>+ p')"
  apply (erule trancl_induct)
   apply (fastforce simp: n'_direct_eq split: split_if_asm)
  apply (fastforce simp: n'_direct_eq split: split_if_asm elim: trancl_trans)
  done

lemma site_in_dom: "site \<in> dom n"
  by (simp add: n)

lemma m_tranclD:
  assumes m: "m \<turnstile> p \<leadsto>\<^sup>+ p'"
  shows "p' \<noteq> site \<and> n' \<turnstile> p \<leadsto>\<^sup>+ p'"
proof -
  from m have "p = site \<longrightarrow> p' = 0" by clarsimp
  with mdb_chain_0_n' m
  show ?thesis
  apply -
  apply (erule trancl_induct)
   apply (rule context_conjI)
    apply clarsimp
   apply (cases "p = site")
    apply (simp add: mdb_chain_0_def site_in_dom)
   apply (cases "p = parent")
    apply simp
    apply (rule trancl_trans)
     apply (rule r_into_trancl)
     apply (simp add: n'_direct_eq)
    apply (rule r_into_trancl)
    apply (simp add: n'_direct_eq)
   apply (rule r_into_trancl)
   apply (simp add: n'_direct_eq)
  apply (rule context_conjI)
   apply clarsimp
  apply clarsimp
  apply (erule trancl_trans)
  apply (case_tac "y = parent")
   apply simp
   apply (rule trancl_trans)
    apply (rule r_into_trancl)
    apply (simp add: n'_direct_eq)
   apply (rule r_into_trancl)
   apply (simp add: n'_direct_eq)
  apply (rule r_into_trancl)
  apply (simp add: n'_direct_eq)
  done
qed

lemma n'_trancl_eq:
  "n' \<turnstile> p \<leadsto>\<^sup>+ p' =
  (if p = site then m \<turnstile> parent \<leadsto>\<^sup>+ p'
   else if m \<turnstile> p \<leadsto>\<^sup>+ parent \<or> p = parent  then m \<turnstile> p \<leadsto>\<^sup>+ p' \<or> p' = site
   else m \<turnstile> p \<leadsto>\<^sup>+ p')"
  apply simp
  apply (intro conjI impI iffI)
           apply (drule n'_tranclD)
           apply simp
          apply simp
         apply (drule n'_tranclD)
         apply simp
        apply (erule disjE)
         apply (drule m_tranclD)+
         apply simp
        apply (drule m_tranclD)
        apply simp
        apply (erule trancl_trans)
        apply (rule r_into_trancl)
        apply (simp add: n'_direct_eq)
       apply (drule n'_tranclD, simp)
      apply (erule disjE)
       apply (drule m_tranclD)
       apply simp
      apply simp
      apply (rule r_into_trancl)
      apply (simp add: n'_direct_eq)
     apply (drule n'_tranclD, simp)
    apply simp
    apply (cases "p' = site", simp)
    apply (drule m_tranclD)
    apply clarsimp
    apply (drule tranclD)
    apply (clarsimp simp: n'_direct_eq)
    apply (simp add: rtrancl_eq_or_trancl)
   apply (drule n'_tranclD, simp)
  apply clarsimp
  apply (drule m_tranclD, simp)
  done

lemma n'_rtrancl_eq:
  "n' \<turnstile> p \<leadsto>\<^sup>* p' =
   (if p = site then p' \<noteq> site \<and> m \<turnstile> parent \<leadsto>\<^sup>+ p' \<or> p' = site
    else if m \<turnstile> p \<leadsto>\<^sup>* parent then m \<turnstile> p \<leadsto>\<^sup>* p' \<or> p' = site
    else m \<turnstile> p \<leadsto>\<^sup>* p')"
  by (auto simp: rtrancl_eq_or_trancl n'_trancl_eq split)

lemma mdbNext_parent_site [simp]:
  "mdbNext parent_node \<noteq> site"
proof
  assume "mdbNext parent_node = site"
  hence "m \<turnstile> parent \<leadsto> site"
    using parent
    by (unfold mdb_next_unfold) simp
  thus False by simp
qed

lemma mdbPrev_parent_site [simp]:
  "site \<noteq> mdbPrev parent_node"
proof
  assume "site = mdbPrev parent_node"
  with parent site
  have "m \<turnstile> site \<leadsto> parent"
    apply (unfold mdb_next_unfold)
    apply simp
    apply (erule dlistEp)
     apply clarsimp
    apply clarsimp
    done
  with p_0 show False by simp
qed

lemma parent_prev:
  "(m \<turnstile> parent \<leftarrow> p) = (p = mdbNext parent_node \<and> p \<noteq> 0)"
  apply (rule iffI)
   apply (frule dlist_prevD, rule parent)
   apply (simp add: mdb_next_unfold parent)
   apply (clarsimp simp: mdb_prev_def)
  apply clarsimp
  apply (rule dlist_nextD0)
   apply (rule parent_next)
  apply assumption
  done

lemma parent_next_prev:
  "(m \<turnstile> p \<leftarrow> mdbNext parent_node) = (p = parent \<and> mdbNext parent_node \<noteq> 0)"
  using parent
  apply -
  apply (rule iffI)
   apply (clarsimp simp add: mdb_prev_def)
   apply (rule conjI)
    apply (erule dlistEn)
     apply clarsimp
    apply simp
   apply clarsimp
  apply clarsimp
  apply (rule dlist_nextD0)
   apply (rule parent_next)
  apply assumption
  done


lemma n'_prev_eq:
  notes if_cong[cong del] if_weak_cong[cong]
  shows "n' \<turnstile> p \<leftarrow> p' = (if p' = site then p = parent
                         else if p = site then m \<turnstile> parent \<leftarrow> p'
                         else if p = parent then p' = site
                         else m \<turnstile> p \<leftarrow> p')"
  using parent site site_prev
  apply (simp add: n'_def n mdb_prev_def new_parent_def new_site_def split del: split_if)
  apply (clarsimp simp add: modify_map_if cong: if_cong split del: split_if)
  apply (cases "p' = site", simp)
  apply (simp cong: if_cong split del: split_if)
  apply (cases "p' = parent")
   apply clarsimp
   apply (rule conjI, clarsimp simp: mdb_prev_def)
   apply (clarsimp simp: mdb_prev_def)
  apply (simp cong: if_cong split del: split_if)
  apply (cases "p = site")
   apply (simp add: parent_prev)
   apply (cases "mdbNext parent_node = p'")
    apply simp
    apply (rule iffI)
     prefer 2
     apply clarsimp
     apply (erule dlistEn)
      apply simp
     apply clarsimp
     apply (case_tac cte')
     apply clarsimp
    apply clarsimp
   apply clarsimp
   apply (insert site_next)[1]
   apply (rule valid_dlistEp [OF dlist, where p=p'], assumption)
    apply clarsimp
   apply clarsimp
  apply (simp cong: if_cong split del: split_if)
  apply (cases "p = parent")
   apply clarsimp
   apply (insert site_next)
   apply (cases "mdbNext parent_node = p'", clarsimp)
   apply clarsimp
   apply (rule valid_dlistEp [OF dlist, where p=p'], assumption)
    apply clarsimp
   apply clarsimp
  apply simp
  apply (cases "mdbNext parent_node = p'")
   prefer 2
   apply (clarsimp simp: mdb_prev_def)
   apply (rule iffI, clarsimp)
   apply clarsimp
   apply (case_tac z)
   apply simp
  apply (rule iffI)
   apply (clarsimp simp: mdb_prev_def)
  apply (drule sym [where t=p'])
  apply (simp add: parent_next_prev)
  done

lemma dlist_n' [simp]:
  notes if_cong[cong del] if_weak_cong[cong]
  shows "valid_dlist n'"
  using no_0_n'
  by (clarsimp simp: valid_dlist_def2 n'_direct_eq
                     n'_prev_eq Invariants_H.valid_dlist_prevD [OF dlist])

lemma n'_cap:
  "n' p = Some (CTE c node) \<Longrightarrow>
  if p = site then c = c' \<and> m p = Some (CTE NullCap site_node)
  else \<exists>node'. m p = Some (CTE c node')"
  by (auto simp: n'_def n modify_map_if new_parent_def parent
                 new_site_def site site_cap split: split_if_asm)

lemma m_cap:
  "m p = Some (CTE c node) \<Longrightarrow>
  if p = site
  then \<exists>node'. n' site = Some (CTE c' node')
  else \<exists>node'. n' p = Some (CTE c node')"
  by (clarsimp simp: n n'_def new_parent_def new_site_def parent)

lemma n'_badged:
  "n' p = Some (CTE c node) \<Longrightarrow>
  if p = site then c = c' \<and> mdbFirstBadged node
  else \<exists>node'. m p = Some (CTE c node') \<and> mdbFirstBadged node = mdbFirstBadged node'"
  by (auto simp: n'_def n modify_map_if new_parent_def parent
                 new_site_def site site_cap split: split_if_asm)

lemma no_next_region:
  "\<lbrakk> m \<turnstile> parent \<leadsto> p'; m p' = Some (CTE cap' node) \<rbrakk> \<Longrightarrow> \<not>sameRegionAs c' cap'"
  apply (clarsimp simp: mdb_next_unfold parent)
  apply (frule next_wont_bite [rotated], clarsimp)
  apply simp
  done

lemma valid_badges_n' [simp]: "valid_badges n'"
  using valid_badges
  apply (clarsimp simp: valid_badges_def)
  apply (simp add: n'_direct_eq)
  apply (drule n'_badged)+
  apply (clarsimp split: split_if_asm)
   apply (drule (1) no_next_region)
   apply simp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply simp
  done

lemma c'_not_Null: "c' \<noteq> NullCap"
  using same_region by clarsimp

lemma valid_nullcaps_n' [simp]:
  "valid_nullcaps n'"
  using nullcaps is_untyped c'_not_Null
  apply (clarsimp simp: valid_nullcaps_def n'_def n modify_map_if new_site_def
                        new_parent_def isCap_simps)
  apply (erule allE)+
  apply (erule (1) impE)
  apply (simp add: nullMDBNode_def)
  apply (insert parent)
  apply (rule dlistEn, rule parent)
   apply clarsimp
  apply (clarsimp simp: nullPointer_def)
  done

lemma phys': "capClass parent_cap = PhysicalClass"
  using sameRegionAs_classes [OF same_region] phys
  by simp

lemma capRange_c': "capRange c' \<subseteq> capRange parent_cap"
  apply (rule sameRegionAs_capRange_subset)
   apply (rule same_region)
  apply (rule phys')
  done

lemma untypedRange_c':
  assumes ut: "isUntypedCap c'"
  shows "untypedRange c' \<subseteq> untypedRange parent_cap"
  using ut is_untyped capRange_c'
  by (auto simp: isCap_simps)

lemma sameRegion_parentI:
  "sameRegionAs c' cap \<Longrightarrow> sameRegionAs parent_cap cap"
  using same_region
  apply -
  apply (erule (1) sameRegionAs_trans)
  done

lemma no_loops_n': "no_loops n'"
  using mdb_chain_0_n' no_0_n'
  by (rule mdb_chain_0_no_loops)

lemmas no_loops_simps' [simp]=
  no_loops_trancl_simp [OF no_loops_n']
  no_loops_direct_simp [OF no_loops_n']

lemma rangeD:
  "\<lbrakk> m \<turnstile> parent \<rightarrow> p; m p = Some (CTE cap node) \<rbrakk> \<Longrightarrow>
  capRange cap \<inter> capRange c' = {}"
  using range by (rule descendants_rangeD')

lemma capAligned_c': "capAligned c'"
  using valid_c' by (rule valid_capAligned)

lemma capRange_ut:
  "capRange c' \<subseteq> untypedRange parent_cap"
  using capRange_c' is_untyped
  by (clarsimp simp: isCap_simps del: subsetI)

lemma untyped_mdb_n' [simp]: "untyped_mdb' n'"
  using untyped_mdb capRange_ut untyped_inc
  apply (clarsimp simp: untyped_mdb'_def descendants_of'_def)
  apply (drule n'_cap)+
  apply (simp add: parency_n')
  apply (simp split: split_if_asm)
    apply clarsimp
    apply (erule_tac x=parent in allE)
    apply (simp add: parent is_untyped)
    apply (erule_tac x=p' in allE)
    apply simp
    apply (frule untypedCapRange)
    apply (drule untypedRange_c')
    apply (erule impE, blast)
    apply (drule (1) rangeD)
    apply simp
   apply clarsimp
   apply (thin_tac "All ?P")
   apply (simp add: untyped_inc'_def)
   apply (erule_tac x=parent in allE)
   apply (erule_tac x=p in allE)
   apply (simp add: parent is_untyped)
   apply (clarsimp simp: descendants_of'_def)
   apply (case_tac "untypedRange parent_cap = untypedRange c")
    apply simp
    apply (elim disjE conjE)
     apply (drule (1) rangeD)
     apply (drule untypedCapRange)
     apply simp
     apply blast
    apply simp
   apply (erule disjE)
    apply clarsimp
   apply (erule disjE)
    apply (simp add: psubsetI)
    apply (elim conjE)
    apply (drule (1) rangeD)
    apply (drule untypedCapRange)
    apply simp
    apply blast
   apply blast
  apply clarsimp
  done

lemma site':
  "n' site = Some new_site"
  by (simp add: n n'_def modify_map_if new_site_def)

lemma loopE: "m \<turnstile> x \<leadsto>\<^sup>+ x \<Longrightarrow> P"
  by simp

lemma capRange_parent_inter:
  "capRange c' \<inter> untypedRange parent_cap \<noteq> {}"
  using capAligned_capUntypedPtr [OF valid_capAligned [OF valid_c'] phys] capRange_ut
  by blast

lemma n'_ex_cteCap:
  "(\<exists>cte. n' p = Some cte \<and> P (cteCap cte))
     = (if p = site then P c' else (\<exists>cte. m p = Some cte \<and> P (cteCap cte)))"
  apply (simp add: n'_def n_def modify_map_def)
  apply fastforce
  done

lemma n'_all_cteCap:
  "(\<forall>cte. n' p = Some cte \<longrightarrow> P (cteCap cte))
     = (if p = site then P c' else (\<forall>cte. m p = Some cte \<longrightarrow> P (cteCap cte)))"
  apply (simp add: n'_def n_def modify_map_def)
  apply fastforce
  done

lemma is_end_chunk_n':
  "is_end_chunk n' cap x
      = (if x = site \<and> sameRegionAs cap c' then
           is_end_chunk m cap parent
         else if x = parent \<and> sameRegionAs cap parent_cap then False
         else is_end_chunk m cap x)"
  apply (simp add: is_end_chunk_def n'_direct_eq site' new_site_def
                   mdb_ptr_parent.p_next
                   mdb_ptr_parent.m_p
             cong: conj_cong)
  apply (subst n'_all_cteCap n'_ex_cteCap)+
  apply simp
  oops

lemma m_loop_trancl_rtrancl:
  "m \<turnstile> y \<leadsto>\<^sup>* x \<Longrightarrow> \<not> m \<turnstile> x \<leadsto>\<^sup>+ y"
  apply clarsimp
  apply (drule(1) transitive_closure_trans)
  apply (erule loopE)
  done

lemma m_rtrancl_to_site:
  "m \<turnstile> p \<leadsto>\<^sup>* site = (p = site)"
  apply (rule iffI)
   apply (erule rtranclE)
    apply assumption
   apply simp
  apply simp
  done

lemma descendants_of'_D: "p' \<in> descendants_of' p ctes \<Longrightarrow> ctes \<turnstile> p \<rightarrow> p' "
  by (clarsimp simp:descendants_of'_def)

lemma untyped_inc_mdbD:
  "\<lbrakk> sameRegionAs cap cap'; isUntypedCap cap;
      ctes p = Some (CTE cap node); ctes p' = Some (CTE cap' node');
        untyped_inc' ctes; untyped_mdb' ctes; no_loops ctes \<rbrakk>
     \<Longrightarrow> ctes \<turnstile> p \<rightarrow> p' \<or> p = p' \<or>
          (isUntypedCap cap' \<and> untypedRange cap \<subseteq> untypedRange cap'
                  \<and> sameRegionAs cap' cap
                  \<and> ctes \<turnstile> p' \<rightarrow> p)"
  apply (subgoal_tac "untypedRange cap \<subseteq> untypedRange cap' \<longrightarrow> sameRegionAs cap' cap")
   apply (cases "isUntypedCap cap'")
    apply (drule(4) untyped_incD'[where p=p and p'=p'])
    apply (erule sameRegionAsE, simp_all add: untypedCapRange)[1]
      apply (cases "untypedRange cap = untypedRange cap'")
       apply simp
       apply (elim disjE conjE)
      apply (simp only: simp_thms descendants_of'_D)+
     apply (elim disjE conjE)
     apply (simp add: subset_iff_psubset_eq)
     apply (elim disjE)
      apply (simp add:descendants_of'_D)+
     apply (clarsimp simp:descendants_of'_def)
    apply (clarsimp simp: isCap_simps)
  apply clarsimp
  apply (erule sameRegionAsE)
      apply simp
     apply (drule(1) untyped_mdbD',simp)
         apply (simp add:untypedCapRange)
         apply blast
        apply simp
       apply assumption
      apply (simp add:descendants_of'_def)
     apply (clarsimp simp:isCap_simps)
    apply (simp add:isCap_simps)
  apply (clarsimp simp:sameRegionAs_def3)
  apply (erule disjE)
   apply (intro conjI)
     apply blast
    apply (simp add:untypedCapRange)
    apply (erule subset_trans[OF _ untypedRange_in_capRange])
   apply clarsimp
   apply (rule untypedRange_not_emptyD)
   apply (simp add:untypedCapRange)
    apply blast
  apply (clarsimp simp:isCap_simps)
done

lemma parent_chunk:
  "is_chunk n' parent_cap parent site"
  by (clarsimp simp: is_chunk_def
                     n'_trancl_eq n'_rtrancl_eq site' new_site_def same_region
                     m_loop_trancl_rtrancl m_rtrancl_to_site)

lemma mdb_chunked_n' [simp]:
  notes if_cong[cong del] if_weak_cong[cong]
  shows "mdb_chunked n'"
  using chunked untyped_mdb untyped_inc
  apply (clarsimp simp: mdb_chunked_def)
  apply (drule n'_cap)+
  apply (simp add: n'_trancl_eq split del: split_if)
  apply (simp split: split_if_asm)
    apply clarsimp
    apply (frule sameRegion_parentI)
    apply (frule(1) untyped_inc_mdbD [OF _ is_untyped _ _ untyped_inc untyped_mdb no_loops, OF _ parent])
    apply (elim disjE)
      apply (frule sameRegionAs_capRange_Int)
         apply (simp add: phys)
        apply (rule valid_capAligned [OF valid_c'])
       apply (rule valid_capAligned)
       apply (erule valid_capI')
      apply (erule notE, erule(1) descendants_rangeD' [OF range, rotated])
     apply (clarsimp simp: parent parent_chunk)
    apply clarsimp
    apply (frule subtree_mdb_next)
    apply (simp add: m_loop_trancl_rtrancl [OF trancl_into_rtrancl, where x=parent])
    apply (case_tac "p' = parent")
     apply (clarsimp simp: parent)
    apply (drule_tac x=p' in spec)
    apply (drule_tac x=parent in spec)
    apply (frule sameRegionAs_trans [OF _ same_region])
    apply (clarsimp simp: parent is_chunk_def n'_trancl_eq n'_rtrancl_eq
                          m_rtrancl_to_site site' new_site_def)
    apply (drule_tac x=p'' in spec)
    apply clarsimp
    apply (drule_tac p=p'' in m_cap, clarsimp)
   apply clarsimp
   apply (erule_tac x=p in allE)
   apply (erule_tac x=parent in allE)
   apply (insert parent is_untyped)[1]
   apply simp
   apply (case_tac "p = parent")
    apply (simp add: parent)
    apply (clarsimp simp add: is_chunk_def)
    apply (simp add: rtrancl_eq_or_trancl)
    apply (erule disjE)
     apply (clarsimp simp: site' new_site_def)
    apply clarsimp
    apply (drule tranclD)
    apply (clarsimp simp: n'_direct_eq)
    apply (drule (1) transitive_closure_trans)
    apply simp
   apply simp
   apply (case_tac "isUntypedCap cap")
    prefer 2
    apply (simp add: untyped_mdb'_def)
    apply (erule_tac x=parent in allE)
    apply simp
    apply (erule_tac x=p in allE)
    apply (simp add: descendants_of'_def)
    apply (drule mp[where P="S \<inter> T \<noteq> {}", standard])
     apply (frule sameRegionAs_capRange_Int, simp add: phys)
       apply (rule valid_capAligned, erule valid_capI')
      apply (rule valid_capAligned, rule valid_c')
     apply (insert capRange_ut)[1]
     apply blast
    apply (drule (1) rangeD)
    apply (drule capRange_sameRegionAs, rule valid_c')
     apply (simp add: phys)
    apply simp
   apply (case_tac "untypedRange parent_cap \<subseteq> untypedRange cap")
    apply (erule impE)
     apply (clarsimp simp only: isCap_simps untypedRange.simps)
     apply (subst (asm) range_subset_eq)
      apply (drule valid_capI')+
      apply (drule valid_capAligned)+
      apply (clarsimp simp: capAligned_def)
      apply (erule is_aligned_no_overflow)
     apply (simp(no_asm) add: sameRegionAs_def3 isCap_simps)
     apply (drule valid_capI')+
     apply (drule valid_capAligned)+
     apply (clarsimp simp: capAligned_def is_aligned_no_overflow interval_empty)
    apply clarsimp
    apply (erule disjE)
     apply simp
     apply (rule conjI)
      prefer 2
      apply clarsimp
      apply (drule (1) trancl_trans, erule loopE)
     apply (thin_tac "?P \<longrightarrow> ?Q")
     apply (clarsimp simp: is_chunk_def)
     apply (simp add: n'_trancl_eq n'_rtrancl_eq split: split_if_asm)
       apply (simp add: site' new_site_def)
      apply (erule_tac x=p'' in allE)
      apply clarsimp
      apply (drule_tac p=p'' in m_cap)
      apply clarsimp
     apply (simp add: rtrancl_eq_or_trancl)
    apply simp
    apply (rule conjI)
     apply clarsimp
     apply (drule (1) trancl_trans, erule loopE)
    apply clarsimp
    apply (clarsimp simp: is_chunk_def)
    apply (simp add: n'_trancl_eq n'_rtrancl_eq split: split_if_asm)
     apply (drule (1) transitive_closure_trans, erule loopE)
    apply (subgoal_tac "m \<turnstile> p \<rightarrow> parent")
     apply (drule subtree_mdb_next)
     apply (drule (1) trancl_trans, erule loopE)
    apply (thin_tac "All ?P")
    apply (drule_tac p=parent and p'=p in untyped_incD'[rotated], assumption+)
    apply simp
    apply (subgoal_tac "\<not> m \<turnstile> parent \<rightarrow> p")
     prefer 2
     apply clarsimp
     apply (drule (1) rangeD)
     apply (drule capRange_sameRegionAs, rule valid_c')
      apply (simp add: phys)
     apply simp
    apply (clarsimp simp: descendants_of'_def subset_iff_psubset_eq)
    apply (erule disjE,simp,simp)
   apply (drule_tac p=parent and p'=p in untyped_incD'[rotated], assumption+)
   apply (simp add:subset_iff_psubset_eq descendants_of'_def)
    apply (elim disjE conjE| simp )+
      apply (drule(1) rangeD)
      apply (drule capRange_sameRegionAs[OF _ valid_c'])
       apply (simp add:phys)+
   apply (insert capRange_c' is_untyped)[1]
   apply (simp add: untypedCapRange [symmetric])
   apply (drule(1) disjoint_subset)
   apply (drule capRange_sameRegionAs[OF _ valid_c'])
    apply (simp add:phys)
   apply (simp add:Int_ac)
  apply clarsimp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply clarsimp
  apply (erule disjE)
   apply simp
   apply (thin_tac "?P \<longrightarrow> ?Q")
   apply (subgoal_tac "is_chunk n' cap p p'")
    prefer 2
    apply (clarsimp simp: is_chunk_def)
    apply (simp add: n'_trancl_eq n'_rtrancl_eq split: split_if_asm)
        apply (erule disjE)
         apply (erule_tac x=parent in allE)
         apply clarsimp
         apply (erule impE, fastforce)
         apply (clarsimp simp: parent)
         apply (simp add: site' new_site_def)
         apply (erule sameRegionAs_trans, rule same_region)
        apply (clarsimp simp add: parent)
        apply (simp add: site' new_site_def)
        apply (rule same_region)
       apply (erule_tac x=p'' in allE)
       apply clarsimp
       apply (drule_tac p=p'' in m_cap)
       apply clarsimp
      apply (erule_tac x=p'' in allE)
      apply clarsimp
      apply (drule_tac p=p'' in m_cap)
      apply clarsimp
     apply (erule_tac x=p'' in allE)
     apply clarsimp
     apply (drule_tac p=p'' in m_cap)
     apply clarsimp
    apply (erule_tac x=p'' in allE)
    apply clarsimp
    apply (drule_tac p=p'' in m_cap)
    apply clarsimp
   apply simp
   apply (rule conjI)
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (drule (1) trancl_trans, erule loopE)
    apply (rule conjI, clarsimp)
     apply (drule (1) trancl_trans, erule loopE)
    apply clarsimp
    apply (drule (1) trancl_trans, erule loopE)
   apply (rule conjI)
    apply clarsimp
    apply (drule (1) trancl_trans, erule loopE)
   apply clarsimp
   apply (rule conjI)
    apply clarsimp
    apply (drule (1) trancl_trans, erule loopE)
   apply (rule conjI, clarsimp)
   apply clarsimp
   apply (drule (1) trancl_trans, erule loopE)
  apply simp
  apply (thin_tac "?P \<longrightarrow> ?Q")
  apply (subgoal_tac "is_chunk n' cap' p' p")
   prefer 2
   apply (clarsimp simp: is_chunk_def)
   apply (simp add: n'_trancl_eq n'_rtrancl_eq split: split_if_asm)
       apply (erule disjE)
        apply (erule_tac x=parent in allE)
        apply clarsimp
        apply (erule impE, fastforce)
        apply (clarsimp simp: parent)
        apply (simp add: site' new_site_def)
        apply (erule sameRegionAs_trans, rule same_region)
       apply (clarsimp simp add: parent)
       apply (simp add: site' new_site_def)
       apply (rule same_region)
      apply (erule_tac x=p'' in allE)
      apply clarsimp
      apply (drule_tac p=p'' in m_cap)
      apply clarsimp
     apply (erule_tac x=p'' in allE)
     apply clarsimp
     apply (drule_tac p=p'' in m_cap)
     apply clarsimp
    apply (erule_tac x=p'' in allE)
    apply clarsimp
    apply (drule_tac p=p'' in m_cap)
    apply clarsimp
   apply (erule_tac x=p'' in allE)
   apply clarsimp
   apply (drule_tac p=p'' in m_cap)
   apply clarsimp
  apply simp
  apply (rule conjI)
   apply clarsimp
   apply (rule conjI)
    apply clarsimp
    apply (drule (1) trancl_trans, erule loopE)
   apply (rule conjI, clarsimp)
    apply (drule (1) trancl_trans, erule loopE)
   apply clarsimp
   apply (drule (1) trancl_trans, erule loopE)
  apply (rule conjI)
   apply clarsimp
   apply (drule (1) trancl_trans, erule loopE)
  apply clarsimp
  apply (rule conjI)
   apply clarsimp
   apply (drule (1) trancl_trans, erule loopE)
  apply (rule conjI, clarsimp)
  apply clarsimp
  apply (drule (1) trancl_trans, erule loopE)
  done

lemma caps_contained_n' [simp]: "caps_contained' n'"
  using caps_contained untyped_mdb untyped_inc
  apply (clarsimp simp: caps_contained'_def)
  apply (drule n'_cap)+
  apply (clarsimp split: split_if_asm)
     apply (drule capRange_untyped)
     apply simp
    apply (frule capRange_untyped)
    apply (frule untypedRange_c')
    apply (erule_tac x=parent in allE)
    apply (erule_tac x=p' in allE)
    apply (simp add: parent)
    apply (erule impE, blast)
    apply (simp add: untyped_mdb'_def)
    apply (erule_tac x=parent in allE)
    apply (erule_tac x=p' in allE)
    apply (simp add: parent is_untyped descendants_of'_def)
    apply (erule impE)
     apply (thin_tac "m site = ?t")
     apply (drule valid_capI')
     apply (frule valid_capAligned)
     apply blast
    apply (drule (1) rangeD)
    apply (frule capRange_untyped)
    apply (drule untypedCapRange)
    apply simp
   apply (thin_tac "All ?P")
   apply (insert capRange_c')[1]
   apply (simp add: untypedCapRange is_untyped)
   apply (subgoal_tac "untypedRange parent_cap \<inter> untypedRange c \<noteq> {}")
    prefer 2
    apply blast
   apply (frule untyped_incD'[OF _ capRange_untyped _ is_untyped])
    apply (case_tac c)
      apply simp_all
    apply (simp add:isCap_simps)
    apply (rule parent)
   apply clarsimp
   apply (case_tac "untypedRange c = untypedRange parent_cap")
    apply blast
   apply simp
   apply (elim disjE)
      apply (drule_tac A = "untypedRange c" in psubsetI)
       apply simp+
      apply (thin_tac "?P\<longrightarrow>?Q")
      apply (elim conjE)
      apply (simp add:descendants_of'_def)
      apply (drule(1) rangeD)
      apply (frule capRange_untyped)
      apply (simp add:untypedCapRange Int_ac)
     apply blast
   apply (simp add:descendants_of'_def)
   apply blast
  apply blast
  done

lemma untyped_inc_n' [simp]: "untypedRange c' \<inter> usableUntypedRange parent_cap = {} \<Longrightarrow> untyped_inc' n'"
  using untyped_inc
  apply (clarsimp simp: untyped_inc'_def)
  apply (drule n'_cap)+
  apply (clarsimp simp: descendants_of'_def parency_n' split: split_if_asm)
    apply (frule untypedRange_c')
    apply (insert parent is_untyped)[1]
    apply (erule_tac x=parent in allE)
    apply (erule_tac x=p' in allE)
    apply clarsimp
    apply (case_tac "untypedRange parent_cap = untypedRange c'a")
     apply simp
     apply (intro conjI)
       apply (intro impI)
       apply (elim disjE conjE)
         apply (drule(1) subtree_trans,simp)
        apply (simp add:subset_not_psubset)
       apply simp
      apply (clarsimp simp:subset_not_psubset)
      apply (drule valid_capI')+
      apply (drule(2) disjoint_subset[OF usableRange_subseteq[OF valid_capAligned],rotated -1])
      apply simp
     apply (clarsimp)
     apply (rule int_not_emptyD)
       apply (drule(1) rangeD)
       apply (simp add:untypedCapRange Int_ac)
      apply (erule aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_c']])
     apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
    apply simp
    apply (erule subset_splitE)
       apply (simp|elim conjE)+
       apply (thin_tac "?P \<longrightarrow>?Q")+
       apply blast
      apply (simp|elim conjE)+
      apply (thin_tac "?P\<longrightarrow>?Q")+
      apply (intro conjI,intro impI,drule(1) subtree_trans,simp)
       apply clarsimp
      apply (intro impI)
      apply (drule(1) rangeD)
      apply (simp add:untypedCapRange Int_ac)
      apply (rule int_not_emptyD)
        apply (simp add:Int_ac)
       apply (erule aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_c']])
      apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
     apply simp
    apply (thin_tac "?P\<longrightarrow>?Q")+
    apply (drule(1) disjoint_subset[rotated])
    apply simp
    apply (drule_tac B = "untypedRange c'a" in int_not_emptyD)
      apply (erule aligned_untypedRange_non_empty[OF capAligned_c'])
     apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
    apply simp
   apply (frule untypedRange_c')
   apply (insert parent is_untyped)[1]
   apply (erule_tac x=p in allE)
   apply (erule_tac x=parent in allE)
   apply clarsimp
   apply (case_tac "untypedRange parent_cap = untypedRange c")
    apply simp
    apply (intro conjI)
      apply (intro impI)
      apply (elim disjE conjE)
        apply (clarsimp simp:subset_not_psubset )+
       apply (drule(1) subtree_trans,simp)
      apply simp
     apply (clarsimp simp:subset_not_psubset)
     apply (drule disjoint_subset[OF usableRange_subseteq[OF valid_capAligned[OF valid_capI']],rotated])
       apply simp
      apply assumption
     apply simp
    apply clarsimp
    apply (rule int_not_emptyD)
      apply (drule(1) rangeD)
      apply (simp add:untypedCapRange Int_ac)
     apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
    apply (erule aligned_untypedRange_non_empty[OF capAligned_c'])
   apply simp
   apply (erule subset_splitE)
      apply (simp|elim conjE)+
      apply (thin_tac "?P \<longrightarrow>?Q")+
      apply (intro conjI,intro impI,drule(1) subtree_trans,simp)
       apply clarsimp
      apply (intro impI)
      apply (drule(1) rangeD)
      apply (simp add:untypedCapRange Int_ac)
      apply (rule int_not_emptyD)
        apply (simp add:Int_ac)
       apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
      apply (erule aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_c']])
     apply simp
     apply (thin_tac "?P\<longrightarrow>?Q")+
     apply blast
    apply (thin_tac "?P\<longrightarrow>?Q")+
    apply simp
   apply (drule(1) disjoint_subset2[rotated])
   apply simp
   apply (drule_tac B = "untypedRange c'" in int_not_emptyD)
     apply (erule(1) aligned_untypedRange_non_empty[OF valid_capAligned[OF valid_capI']])
    apply (erule aligned_untypedRange_non_empty[OF capAligned_c'])
   apply simp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply simp
  apply blast
  done

lemma ut_rev_n' [simp]: "ut_revocable' n'"
  using ut_rev
  apply (clarsimp simp: ut_revocable'_def n'_def n_def)
  apply (clarsimp simp: modify_map_if split: split_if_asm)
  done

lemma class_links_m: "class_links m"
  using valid
  by (simp add: valid_mdb_ctes_def)

lemma parent_phys: "capClass parent_cap = PhysicalClass"
  using is_untyped
  by (clarsimp simp: isCap_simps)

lemma class_links [simp]: "class_links n'"
  using class_links_m
  apply (clarsimp simp add: class_links_def)
  apply (simp add: n'_direct_eq
            split: split_if_asm)
    apply (case_tac cte,
           clarsimp dest!: n'_cap simp: site' parent new_site_def phys parent_phys)
   apply (drule_tac x=parent in spec)
   apply (drule_tac x=p' in spec)
   apply (case_tac cte')
   apply (clarsimp simp: site' new_site_def parent parent_phys phys dest!: n'_cap
                  split: split_if_asm)
  apply (case_tac cte, case_tac cte')
  apply (clarsimp dest!: n'_cap split: split_if_asm)
  apply fastforce
  done

lemma irq_control_n' [simp]:
  "irq_control n'"
  using irq_control phys
  apply (clarsimp simp: irq_control_def)
  apply (clarsimp simp: n'_def n_def)
  apply (clarsimp simp: modify_map_if split: split_if_asm)
  done

lemma dist_z_m:
  "distinct_zombies m"
  using valid by auto

lemma dist_z [simp]:
  "distinct_zombies n'"
  using dist_z_m
  apply (simp add: n'_def distinct_zombies_nonCTE_modify_map)
  apply (simp add: n_def distinct_zombies_nonCTE_modify_map
                   fun_upd_def[symmetric])
  apply (erule distinct_zombies_seperateE, simp)
  apply (case_tac cte, clarsimp)
  apply (subgoal_tac "capRange capability \<inter> capRange c' \<noteq> {}")
   apply (frule untyped_mdbD' [OF _ _ _ _ _ untyped_mdb, OF parent])
      apply (simp add: is_untyped)
     apply (clarsimp simp add: untypedCapRange[OF is_untyped, symmetric])
     apply (drule disjoint_subset2 [OF capRange_c'])
     apply simp
    apply simp
   apply (simp add: descendants_of'_def)
   apply (drule(1) rangeD)
   apply simp
  apply (drule capAligned_capUntypedPtr [OF capAligned_c'])
  apply (frule valid_capAligned [OF valid_capI'])
  apply (drule(1) capAligned_capUntypedPtr)
  apply auto
  done

lemma reply_masters_rvk_fb_m:
  "reply_masters_rvk_fb m"
  using valid by auto

lemma reply_masters_rvk_fb_n[simp]:
  "reply_masters_rvk_fb n'"
  using reply_masters_rvk_fb_m
  apply (simp add: reply_masters_rvk_fb_def n'_def ball_ran_modify_map_eq
                   n_def fun_upd_def[symmetric])
  apply (rule ball_ran_fun_updI, assumption)
  apply clarsimp
  done

lemma valid_n':
  "untypedRange c' \<inter> usableUntypedRange parent_cap = {} \<Longrightarrow> valid_mdb_ctes n'"
  by (simp add: valid_mdb_ctes_def)
end

lemma caps_overlap_reserved'_D:
  "\<lbrakk>caps_overlap_reserved' S s; ctes_of s p = Some cte;isUntypedCap (cteCap cte)\<rbrakk> \<Longrightarrow> usableUntypedRange (cteCap cte) \<inter> S = {}"
  apply (simp add:caps_overlap_reserved'_def)
  apply (erule ballE)
   apply (erule(2) impE)
  apply fastforce
  done

lemma insertNewCap_valid_mdb:
  "\<lbrace>valid_mdb' and valid_objs' and K (slot \<noteq> p) and
    caps_overlap_reserved' (untypedRange cap) and
    cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                      sameRegionAs (cteCap cte) cap) p and
    K (\<not>isZombie cap) and valid_cap' cap and
    (\<lambda>s. descendants_range' cap p (ctes_of s))\<rbrace>
  insertNewCap p slot cap
  \<lbrace>\<lambda>rv. valid_mdb'\<rbrace>"
  apply (clarsimp simp: insertNewCap_def valid_mdb'_def)
  apply (wp getCTE_ctes_of | simp add: o_def)+
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (rule conjI)
   apply (clarsimp simp: no_0_def valid_mdb_ctes_def)
  apply (case_tac cte)
  apply (rename_tac p_cap p_node)
  apply (clarsimp cong: if_cong)
  apply (case_tac ya)
  apply (rename_tac node)
  apply (clarsimp simp: nullPointer_def)
  apply (rule mdb_insert_again_all.valid_n')
   apply unfold_locales[1]
                apply (assumption|rule refl)+
        apply (frule sameRegionAs_classes, clarsimp simp: isCap_simps)
       apply (erule (1) ctes_of_valid_cap')
      apply (simp add: valid_mdb_ctes_def)
     apply simp
    apply (clarsimp simp: isMDBParentOf_CTE)
    apply (clarsimp simp: isCap_simps valid_mdb_ctes_def ut_revocable'_def)
   apply assumption
  apply (drule(1) caps_overlap_reserved'_D)
    apply simp
  apply (simp add:Int_ac)
  done

(* FIXME: Move to top *)
lemma no_default_zombie:
  "cap_relation (default_cap tp p sz) cap \<Longrightarrow> \<not>isZombie cap"
  by (cases tp, auto simp: isCap_simps)

lemma insertNewCap_valid_objs [wp]:
  "\<lbrace> valid_objs' and valid_cap' cap and pspace_aligned' and pspace_distinct'\<rbrace>
  insertNewCap parent slot cap
  \<lbrace>\<lambda>_. valid_objs'\<rbrace>"
  apply (simp add: insertNewCap_def)
  apply (wp setCTE_valid_objs getCTE_wp')
  apply clarsimp
  done

lemma insertNewCap_valid_cap [wp]:
  "\<lbrace> valid_cap' c \<rbrace>
  insertNewCap parent slot cap
  \<lbrace>\<lambda>_. valid_cap' c\<rbrace>"
  apply (simp add: insertNewCap_def)
  apply (wp getCTE_wp')
  apply clarsimp
  done

lemma descendants_of'_mdbPrev:
  "descendants_of' p (modify_map m p' (cteMDBNode_update (mdbPrev_update f))) =
   descendants_of' p m"
  by (simp add: descendants_of'_def)

lemma insertNewCap_ranges:
  "\<lbrace>\<lambda>s. descendants_range' c p (ctes_of s) \<and>
   descendants_range' cap p (ctes_of s) \<and>
   capRange c \<inter> capRange cap = {} \<and>
   cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                     sameRegionAs (cteCap cte) cap) p s \<and>
   valid_mdb' s \<and> valid_objs' s\<rbrace>
  insertNewCap p slot cap
  \<lbrace>\<lambda>_ s. descendants_range' c p (ctes_of s)\<rbrace>"
  apply (simp add: insertNewCap_def)
  apply (wp getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (rule conjI)
   apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def no_0_def)
  apply (case_tac ctea)
  apply (case_tac cteb)
  apply (clarsimp simp: nullPointer_def cong: if_cong)
  apply (simp (no_asm) add: descendants_range'_def descendants_of'_mdbPrev)
  apply (subst mdb_insert_again_child.descendants)
   apply unfold_locales[1]
               apply (simp add: valid_mdb'_def)
              apply (assumption|rule refl)+
       apply (frule sameRegionAs_classes, clarsimp simp: isCap_simps)
      apply (erule (1) ctes_of_valid_cap')
     apply (simp add: valid_mdb'_def valid_mdb_ctes_def)
    apply clarsimp
   apply (clarsimp simp: isMDBParentOf_def)
   apply (clarsimp simp: isCap_simps valid_mdb'_def
                         valid_mdb_ctes_def ut_revocable'_def)
  apply clarsimp
  apply (rule context_conjI, blast)
  apply (clarsimp simp: descendants_range'_def)
  done

lemma insertNewCap_overlap_reserved'[wp]:
  "\<lbrace>\<lambda>s. caps_overlap_reserved' (capRange c) s\<and>
   capRange c \<inter> capRange cap = {} \<and> capAligned cap \<and>
   cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                     sameRegionAs (cteCap cte) cap) p s \<and>
   valid_mdb' s \<and> valid_objs' s\<rbrace>
  insertNewCap p slot cap
  \<lbrace>\<lambda>_ s. caps_overlap_reserved' (capRange c) s\<rbrace>"
  apply (simp add: insertNewCap_def caps_overlap_reserved'_def)
  apply (wp getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (rule conjI)
   apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def no_0_def)
  apply (case_tac ctea)
  apply (case_tac cteb)
  apply (clarsimp simp: nullPointer_def ball_ran_modify_map_eq
    caps_overlap_reserved'_def[symmetric])
  apply (clarsimp simp:ran_def split:if_splits)
  apply (case_tac "slot = a")
    apply clarsimp
    apply (rule disjoint_subset)
     apply (erule(1) usableRange_subseteq)
    apply (simp add:untypedCapRange Int_ac)+
  apply (subst Int_commute)
  apply (erule(2) caps_overlap_reserved'_D)
  done

crunch typ_at'[wp]: insertNewCap "\<lambda>s. P (typ_at' T p s)"
  (wp: crunch_wps)
crunch ksArch[wp]: insertNewCap "\<lambda>s. P (ksArchState s)"
  (wp: crunch_wps)

lemma inv_untyped_corres_helper1:
  "list_all2 cap_relation (map (\<lambda>ref. default_cap tp ref sz) orefs) cps
   \<Longrightarrow>
   corres dc
      (\<lambda>s. pspace_aligned s \<and> pspace_distinct s
          \<and> valid_objs s \<and> valid_mdb s \<and> valid_list s
          \<and> cte_wp_at is_untyped_cap p s
          \<and> (\<forall>tup \<in> set (zip crefs orefs).
              cte_wp_at (\<lambda>c. cap_range (default_cap tp (snd tup) sz) \<subseteq> untyped_range c) p s)
          \<and> (\<forall>tup \<in> set (zip crefs orefs).
              descendants_range (default_cap tp (snd tup) sz) p s)
          \<and> (\<forall>tup \<in> set (zip crefs orefs).
              caps_overlap_reserved (untyped_range (default_cap tp (snd tup) sz)) s)
          \<and> (\<forall>tup \<in> set (zip crefs orefs). real_cte_at (fst tup) s)
          \<and> (\<forall>tup \<in> set (zip crefs orefs).
              cte_wp_at (op = cap.NullCap) (fst tup) s)
          \<and> distinct (p # (map fst (zip crefs orefs)))
          \<and> distinct_sets (map (\<lambda>tup. cap_range (default_cap tp (snd tup) sz)) (zip crefs orefs))
          \<and> (\<forall>tup \<in> set (zip crefs orefs).
              valid_cap (default_cap tp (snd tup) sz) s))
      (\<lambda>s. (\<forall>tup \<in> set (zip (map cte_map crefs) cps). valid_cap' (snd tup) s)
         \<and> (\<forall>tup \<in> set (zip (map cte_map crefs) cps). cte_wp_at' (\<lambda>c. cteCap c = NullCap) (fst tup) s)
         \<and> cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                         (\<forall>tup \<in> set (zip (map cte_map crefs) cps).
                               sameRegionAs (cteCap cte) (snd tup)))
              (cte_map p) s
         \<and> distinct ((cte_map p) # (map fst (zip (map cte_map crefs) cps)))
         \<and> valid_mdb' s \<and> valid_objs' s \<and> pspace_aligned' s \<and> pspace_distinct' s
         \<and> (\<forall>tup \<in> set (zip (map cte_map crefs) cps). descendants_range' (snd tup) (cte_map p) (ctes_of s))
         \<and> (\<forall>tup \<in> set (zip (map cte_map crefs) cps).
              caps_overlap_reserved' (capRange (snd tup)) s)
         \<and> distinct_sets (map capRange (map snd (zip (map cte_map crefs) cps))))
      (sequence_x (map (create_cap tp sz p) (zip crefs orefs)))
      (zipWithM_x (insertNewCap (cte_map p))
             ((map cte_map crefs)) cps)"
  apply (simp add: zipWithM_x_def zipWith_def split_def)
  apply (fold mapM_x_def)
  apply (rule corres_list_all2_mapM_)
     apply (rule corres_guard_imp)
       apply (erule create_cap_corres)
      apply (clarsimp simp: cte_wp_at_def is_cap_simps)
     apply (clarsimp simp: cteCaps_of_ran_Ball_upd fun_upd_def cte_wp_at_ctes_of)
    apply clarsimp
    apply (rule hoare_pre, wp hoare_vcg_const_Ball_lift)
    apply clarsimp
    apply (rule conjI)
     apply (clarsimp simp: cte_wp_at_caps_of_state
                           cap_range_def[where c="default_cap a b c", standard])
     apply (drule(2) caps_overlap_reservedD[rotated])
     apply (simp add:Int_ac)
    apply (rule conjI)
     apply (clarsimp simp: valid_cap_def)
    apply (rule conjI)
     apply (clarsimp simp: cte_wp_at_caps_of_state)
    apply (rule conjI)
     apply (clarsimp simp:Int_ac)
     apply (erule disjoint_subset2[rotated])
     apply fastforce
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (rule conjI)
      apply fastforce
     apply (clarsimp simp: cte_wp_at_caps_of_state is_cap_simps valid_cap_def)
    apply (fastforce simp: image_def)
   apply (rule hoare_pre)
    apply (wp
              hoare_vcg_const_Ball_lift hoare_vcg_const_imp_lift [OF insertNewCap_mdbNext]
              insertNewCap_valid_mdb hoare_vcg_all_lift insertNewCap_ranges
               | subst cte_wp_at_cteCaps_of)+
   apply (subst(asm) cte_wp_at_cteCaps_of)+
   apply (clarsimp simp only:)
   apply simp
   apply (rule conjI)
    apply clarsimp
    apply (thin_tac "cte_map p \<notin> ?S")
    apply (erule notE, erule rev_image_eqI)
    apply simp
   apply (rule conjI,clarsimp+)
   apply (rule conjI,erule caps_overlap_reserved'_subseteq)
   apply (rule untypedRange_in_capRange)
   apply (rule conjI,erule no_default_zombie)
   apply (rule conjI, clarsimp simp:Int_ac)
    apply fastforce
   apply (clarsimp simp:Int_ac valid_capAligned )
    apply fastforce
  apply (rule list_all2_zip_split)
   apply (simp add: list_all2_map2 list_all2_refl)
  apply (simp add: list_all2_map1)
  done

lemma createNewCaps_valid_pspace_extras:
  "\<lbrace>(\<lambda>s.    n \<noteq> 0 \<and> ptr \<noteq> 0 \<and> range_cover ptr sz (APIType_capBits ty us) n
          \<and> pspace_no_overlap' ptr sz s
          \<and> valid_pspace' s \<and> caps_no_overlap'' ptr sz s
          \<and> caps_overlap_reserved' {ptr .. ptr + of_nat n * 2 ^ APIType_capBits ty us - 1} s
          \<and> ksCurDomain s \<le> maxDomain
   )\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. pspace_aligned'\<rbrace>"
  "\<lbrace>(\<lambda>s.    n \<noteq> 0 \<and> ptr \<noteq> 0 \<and> range_cover ptr sz (APIType_capBits ty us) n
          \<and> pspace_no_overlap' ptr sz s
          \<and> valid_pspace' s \<and> caps_no_overlap'' ptr sz s
          \<and> caps_overlap_reserved' {ptr .. ptr + of_nat n * 2 ^ APIType_capBits ty us - 1} s
          \<and> ksCurDomain s \<le> maxDomain
   )\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. pspace_distinct'\<rbrace>"
  "\<lbrace>(\<lambda>s.    n \<noteq> 0 \<and> ptr \<noteq> 0 \<and> range_cover ptr sz (APIType_capBits ty us) n
          \<and> pspace_no_overlap' ptr sz s
          \<and> valid_pspace' s \<and> caps_no_overlap'' ptr sz s
          \<and> caps_overlap_reserved' {ptr .. ptr + of_nat n * 2 ^ APIType_capBits ty us - 1} s
          \<and> ksCurDomain s \<le> maxDomain
   )\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. valid_mdb'\<rbrace>"
  "\<lbrace>(\<lambda>s.    n \<noteq> 0 \<and> ptr \<noteq> 0 \<and> range_cover ptr sz (APIType_capBits ty us) n
          \<and> pspace_no_overlap' ptr sz s
          \<and> valid_pspace' s \<and> caps_no_overlap'' ptr sz s
          \<and> caps_overlap_reserved' {ptr .. ptr + of_nat n * 2 ^ APIType_capBits ty us - 1} s
          \<and> ksCurDomain s \<le> maxDomain
   )\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. valid_objs'\<rbrace>"
  apply (rule hoare_grab_asm)+
    apply (rule hoare_pre,rule hoare_strengthen_post[OF createNewCaps_valid_pspace])
    apply (simp add:valid_pspace'_def)+
  apply (rule hoare_grab_asm)+
    apply (rule hoare_pre,rule hoare_strengthen_post[OF createNewCaps_valid_pspace])
    apply (simp add:valid_pspace'_def)+
  apply (rule hoare_grab_asm)+
    apply (rule hoare_pre,rule hoare_strengthen_post[OF createNewCaps_valid_pspace])
    apply (simp add:valid_pspace'_def)+
  apply (rule hoare_grab_asm)+
    apply (rule hoare_pre,rule hoare_strengthen_post[OF createNewCaps_valid_pspace])
    apply (simp add:valid_pspace'_def)+
  done

(* Annotation added by Simon Winwood (Thu Jul  1 21:42:33 2010) using taint-mode *)
declare map_fst_zip_prefix[simp]

(* Annotation added by Simon Winwood (Thu Jul  1 21:42:33 2010) using taint-mode *)
declare map_snd_zip_prefix[simp]

declare word_unat_power [symmetric, simp del]

lemma createWordObjects_ret2:
  "\<lbrace>(\<lambda>s. P (map (\<lambda>p. ptr_add y (p * 2 ^ (pageBits + us)))
                         [0 ..< n]))
      and K ( n < 2 ^ word_bits \<and> n \<noteq> 0)\<rbrace>
     createWordObjects y n us
   \<lbrace>\<lambda>rv s. P rv\<rbrace>"
  apply (simp add: createWordObjects_def split del: split_if)
  apply (rule hoare_pre, wp)
   apply (wp createObjects_ret2)
  apply (simp add: objBits_simps)
  done

lemma createNewCaps_range_helper:
  "\<lbrace>\<lambda>s. range_cover ptr sz (APIType_capBits tp us) n \<and> 0 < n\<rbrace>
     createNewCaps tp ptr n us
   \<lbrace>\<lambda>rv s. \<exists>capfn.
        rv = map capfn (map (\<lambda>p. ptr_add ptr (p * 2 ^ (APIType_capBits tp us)))
                               [0 ..< n])
          \<and> (\<forall>p. capClass (capfn p) = PhysicalClass
                 \<and> capUntypedPtr (capfn p) = p
                 \<and> capBits (capfn p) = (APIType_capBits tp us))\<rbrace>"
  apply (simp add: createNewCaps_def toAPIType_def
                   ArchTypes_H.toAPIType_def
                   createNewCaps_def Arch_createNewCaps_def
               split del: split_if cong: option.case_cong)
  apply (rule hoare_grab_asm)+
  apply (frule range_cover.range_cover_n_less)
  apply (frule range_cover.unat_of_nat_n)
  apply (cases tp, simp_all split del: split_if)
          apply (case_tac apiobject_type, simp_all split del: split_if)
              apply (rule hoare_pre, wp)
              apply (frule range_cover_not_zero[rotated -1],simp)
              apply (clarsimp simp: APIType_capBits_def
                objBits_simps archObjSize_def ptr_add_def o_def)
              apply (subst upto_enum_red')
               apply unat_arith
              apply (clarsimp simp:map_map o_def fromIntegral_def toInteger_nat fromInteger_nat)
              apply fastforce
             apply (rule hoare_pre,wp createObjects_ret2)
             apply (clarsimp simp: APIType_capBits_def word_bits_def
                objBits_simps archObjSize_def ptr_add_def o_def)
             apply (fastforce simp:capBits.simps objBitsKO_def  objBits_def)
            apply (rule hoare_pre,wp createObjects_ret2)
            apply (clarsimp simp: APIType_capBits_def word_bits_def
               objBits_simps archObjSize_def ptr_add_def o_def)
            apply (fastforce simp:capBits.simps objBitsKO_def  objBits_def)
           apply (rule hoare_pre,wp createObjects_ret2)
           apply (clarsimp simp:  APIType_capBits_def word_bits_def
              objBits_simps archObjSize_def ptr_add_def o_def)
           apply (fastforce simp:capBits.simps objBitsKO_def  objBits_def)
          apply (rule hoare_pre,wp createObjects_ret2)
          apply (clarsimp simp: APIType_capBits_def word_bits_def
             objBits_simps archObjSize_def ptr_add_def o_def)
          apply (fastforce simp:capBits.simps objBitsKO_def  objBits_def)
        apply (wp createWordObjects_ret2 createObjects_ret2,
          clarsimp simp: APIType_capBits_def objBits_simps archObjSize_def
                        word_bits_def pdBits_def pageBits_def ptBits_def
          ,rule exI,fastforce)+
  done

lemma createNewCaps_range_helper2:
  "\<lbrace>\<lambda>s. range_cover ptr sz (APIType_capBits tp us) n \<and> 0 < n\<rbrace>
     createNewCaps tp ptr n us
   \<lbrace>\<lambda>rv s. \<forall>cp \<in> set rv. capRange cp \<noteq> {} \<and> capRange cp \<subseteq> {ptr .. (ptr && ~~ mask sz) + 2 ^ sz - 1}\<rbrace>"
  apply (rule hoare_assume_pre)
  apply (rule hoare_strengthen_post)
   apply (rule createNewCaps_range_helper)
  apply (clarsimp simp: capRange_def interval_empty ptr_add_def
                        word_unat_power[symmetric]
                  simp del: atLeastatMost_subset_iff
                 dest!: less_two_pow_divD)
  apply (rule conjI)
   apply (rule is_aligned_no_overflow)
   apply (rule is_aligned_add_multI [OF _ _ refl])
    apply (fastforce simp:range_cover_def)
   apply simp
  apply (rule range_subsetI)
   apply (rule word32_plus_mono_right_split[OF range_cover.range_cover_compare])
     apply (assumption)+
   apply (simp add:range_cover_def word_bits_def)
  apply (frule range_cover_cell_subset)
   apply (erule of_nat_mono_maybe[rotated])
   apply (drule (1) range_cover.range_cover_n_less )
  apply (clarsimp)
  apply (erule impE)
    apply (simp add:range_cover_def)
    apply (rule is_aligned_no_overflow)
    apply (rule is_aligned_add_multI[OF _ le_refl refl])
    apply (fastforce simp:range_cover_def)
   apply simp
  done

lemma createNewCaps_children:
  "\<lbrace>\<lambda>s. cap = UntypedCap (ptr && ~~ mask sz) sz idx
     \<and> range_cover ptr sz (APIType_capBits tp us) n \<and> 0 < n\<rbrace>
     createNewCaps tp ptr n us
   \<lbrace>\<lambda>rv s. \<forall>y \<in> set rv. sameRegionAs cap y\<rbrace>"
  apply (rule hoare_assume_pre)
  apply (rule hoare_chain [OF createNewCaps_range_helper2])
   apply fastforce
  apply clarsimp
  apply (drule(1) bspec)
  apply (clarsimp simp: sameRegionAs_def3 isCap_simps)
  apply (drule(1) subsetD)
  apply clarsimp
  apply (erule order_trans[rotated])
  apply (rule word_and_le2)
  done

lemma createObjects_null_filter':
  "\<lbrace>\<lambda>s. P (null_filter' (ctes_of s)) \<and> makeObjectKO ty = Some val \<and>
        range_cover ptr sz (objBitsKO val + gbits) n \<and> n \<noteq> 0 \<and>
        pspace_aligned' s \<and> pspace_distinct' s \<and> pspace_no_overlap' ptr sz s\<rbrace>
   createObjects' ptr n val gbits
   \<lbrace>\<lambda>addrs a. P (null_filter' (ctes_of a))\<rbrace>"
   apply (clarsimp simp: createObjects'_def split_def)
   apply (wp hoare_unless_wp|wpc
          | clarsimp simp:haskell_assert_def alignError_def
            split del: if_splits simp del:fun_upd_apply)+
   apply (subst new_cap_addrs_fold')
     apply (simp add:unat_1_0 unat_gt_0)
     apply (rule range_cover_not_zero_shift)
     apply fastforce+
   apply (subst new_cap_addrs_fold')
    apply (simp add:unat_1_0 unat_gt_0)
    apply (rule range_cover_not_zero_shift)
      apply simp
     apply assumption
    apply simp
   apply (subst data_map_insert_def[symmetric])+
   apply (frule(2) retype_aligned_distinct'[where ko = val])
    apply (erule range_cover_rel)
     apply simp+
   apply (frule(2) retype_aligned_distinct'(2)[where ko = val])
    apply (erule range_cover_rel)
     apply simp+
   apply (frule null_filter_ctes_retype
     [where addrs = "(new_cap_addrs (unat (((of_nat n)::word32) << gbits)) ptr val)"])
          apply assumption+
     apply (clarsimp simp:field_simps foldr_upd_app_if[folded data_map_insert_def] shiftl_t2n range_cover.unat_of_nat_shift)+
    apply (rule new_cap_addrs_aligned[THEN bspec])
    apply (erule range_cover.aligned[OF range_cover_rel])
     apply simp+
   apply (clarsimp simp:shiftl_t2n field_simps range_cover.unat_of_nat_shift)
   apply (drule subsetD[OF new_cap_addrs_subset,rotated])
    apply (erule range_cover_rel)
     apply simp
    apply simp
   apply (rule ccontr)
   apply clarify
   apply (frule(1) pspace_no_overlapD')
   apply (erule_tac B = "{x..x+2^objBitsKO y - 1}" in in_empty_interE[rotated])
    apply (drule(1) pspace_alignedD')
    apply (clarsimp)
    apply (erule is_aligned_no_overflow)
    apply (simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
        Int_atLeastAtMost atLeastatMost_empty_iff add:Int_ac ptr_add_def p_assoc_help)
  apply (simp add:field_simps foldr_upd_app_if[folded data_map_insert_def] shiftl_t2n)
  apply auto
  done

lemma createNewCaps_null_filter':
  "\<lbrace>(\<lambda>s. P (null_filter' (ctes_of s)))
      and pspace_aligned' and pspace_distinct' and pspace_no_overlap' ptr sz
      and K (range_cover ptr sz (APIType_capBits ty us) n \<and> n \<noteq> 0) \<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>_ s. P (null_filter' (ctes_of s))\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: createNewCaps_def toAPIType_def
                   ArchTypes_H.toAPIType_def
                   createNewCaps_def Arch_createNewCaps_def
               split del: split_if cong: option.case_cong)
  apply (cases ty, simp_all split del: split_if)
          apply (case_tac apiobject_type, simp_all split del: split_if)
              apply (rule hoare_pre, wp,simp)
             apply (simp add: createWordObjects_def createObjects_def
                              objBitsKO_def makeObjectKO_def
                              APIType_capBits_def objBits_def pageBits_def
                              archObjSize_def ptBits_def pdBits_def curDomain_def
                    | wp createObjects_null_filter'[where ty = "Inr ty" and sz = sz]
                         copyGlobalMappings_ctes_of threadSet_ctes_of mapM_x_wp'
                    | fastforce)+
  done

lemma createNewCaps_descendants_range':
  "\<lbrace>\<lambda>s. descendants_range' p q (ctes_of s) \<and>
        range_cover ptr sz (APIType_capBits ty us) n \<and> n \<noteq> 0 \<and>
        pspace_aligned' s \<and> pspace_distinct' s \<and> pspace_no_overlap' ptr sz s\<rbrace>
   createNewCaps ty ptr n us
   \<lbrace> \<lambda>rv s. descendants_range' p q (ctes_of s)\<rbrace>"
  apply (clarsimp simp:descendants_range'_def2 descendants_range_in'_def2)
  apply (wp createNewCaps_null_filter')
  apply fastforce
  done

lemma caps_overlap_reserved'_def2:
  "caps_overlap_reserved' S =
   (\<lambda>s. (\<forall>cte \<in> ran (null_filter' (ctes_of s)).
        isUntypedCap (cteCap cte) \<longrightarrow>
        usableUntypedRange (cteCap cte) \<inter> S = {}))"
  apply (rule ext)
  apply (clarsimp simp:caps_overlap_reserved'_def)
  apply (intro iffI ballI impI)
    apply (elim ballE impE)
      apply simp
     apply simp
    apply (simp add:ran_def null_filter'_def split:split_if_asm option.splits)
  apply (elim ballE impE)
    apply simp
   apply simp
  apply (clarsimp simp:ran_def null_filter'_def is_cap_simps
    simp del:split_paired_All split_paired_Ex split:if_splits)
  apply (drule_tac x = a in spec)
  apply simp
  done

lemma createNewCaps_caps_overlap_reserved':
  "\<lbrace>\<lambda>s. caps_overlap_reserved' S s \<and> pspace_aligned' s \<and> pspace_distinct' s \<and>
        pspace_no_overlap' ptr sz s \<and> 0 < n \<and>
        range_cover ptr sz (APIType_capBits ty us) n\<rbrace>
   createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv s. caps_overlap_reserved' S s\<rbrace>"
   apply (clarsimp simp: caps_overlap_reserved'_def2)
   apply (wp createNewCaps_null_filter')
   apply fastforce
   done

lemma createNewCaps_caps_overlap_reserved_ret':
  "\<lbrace>\<lambda>s. caps_overlap_reserved'
          {ptr..ptr + of_nat n * 2 ^ APIType_capBits ty us - 1} s \<and>
        pspace_aligned' s \<and> pspace_distinct' s \<and> pspace_no_overlap' ptr sz s \<and>
        0 < n \<and> range_cover ptr sz (APIType_capBits ty us) n\<rbrace>
   createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv s. \<forall>y\<in>set rv. caps_overlap_reserved' (capRange y) s\<rbrace>"
   apply (rule hoare_name_pre_state)
   apply (clarsimp simp:valid_def)
  apply (frule use_valid[OF _ createNewCaps_range_helper])
   apply fastforce
  apply clarsimp
  apply (erule use_valid[OF _ createNewCaps_caps_overlap_reserved'])
  apply (intro conjI,simp_all)
  apply (erule caps_overlap_reserved'_subseteq)
  apply (drule(1) range_cover_subset)
   apply simp
  apply (clarsimp simp:ptr_add_def capRange_def
        simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
        Int_atLeastAtMost atLeastatMost_empty_iff)
  done

lemma createNewCaps_descendants_range_ret':
 "\<lbrace>\<lambda>s.  (range_cover ptr sz (APIType_capBits ty us) n \<and> 0 < n)
        \<and> pspace_aligned' s \<and> pspace_distinct' s
        \<and> pspace_no_overlap' ptr sz s
        \<and> descendants_range_in' {ptr..ptr + of_nat n * 2^(APIType_capBits ty us) - 1} cref (ctes_of s)\<rbrace>
   createNewCaps ty ptr n us
  \<lbrace> \<lambda>rv s. \<forall>y\<in>set rv. descendants_range' y cref (ctes_of s)\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (clarsimp simp:valid_def)
  apply (frule use_valid[OF _ createNewCaps_range_helper])
    apply simp
  apply (erule use_valid[OF _ createNewCaps_descendants_range'])
  apply (intro conjI,simp_all)
  apply (clarsimp simp:descendants_range'_def descendants_range_in'_def)
  apply (drule(1) bspec)+
  apply (clarsimp simp:cte_wp_at_ctes_of)
  apply (erule disjoint_subset2[rotated])
  apply (drule(1) range_cover_subset)
    apply simp
  apply (simp add:capRange_def ptr_add_def)
  done

lemma createNewCaps_not_parents:
  "\<lbrace>\<lambda>s. (\<forall>cap \<in> ran (cteCaps_of s). \<not> sameRegionAs (UntypedCap ptr_base sz idx) cap)
      \<and> pspace_no_overlap' ptr sz s \<and> pspace_aligned' s \<and> pspace_distinct' s
      \<and> 0 < n \<and> range_cover ptr sz (APIType_capBits ty us) n \<and> ptr_base = ptr && ~~ mask sz\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv s. \<forall>cap \<in> ran (cteCaps_of s). \<forall>tup \<in> set (zip xs rv). \<not> sameRegionAs (snd tup) cap\<rbrace>"
  apply (rule_tac Q="\<lambda>rv s. (\<forall>y\<in>set rv. sameRegionAs (UntypedCap ptr_base sz idx) y)
                          \<and> (\<forall>p. \<not> cte_wp_at' (sameRegionAs (UntypedCap ptr_base sz idx) \<circ> cteCap) p s)"
                 in hoare_post_imp)
   apply (clarsimp dest!: set_zip_helper)
   apply (drule(1) bspec)+
   apply (drule(1) sameRegionAs_trans)
   apply (erule ranE)
   apply (clarsimp simp: tree_cte_cteCap_eq)
   apply (erule_tac x=x in allE)
   apply simp
  apply (wp createNewCaps_children hoare_vcg_all_lift createNewCaps_cte_wp_at2)
   apply (clarsimp simp: tree_cte_cteCap_eq simp del: o_apply)
   apply (rule conjI)
    apply (clarsimp split: option.splits)
    apply (erule notE[rotated], erule bspec, erule ranI)
   apply (simp add: makeObject_cte)
   apply fastforce
  apply fastforce
  done

lemma createObjects_distinct:
  "\<lbrace>\<lambda>s. 0<n \<and> range_cover ptr sz ((objBitsKO (injectKO obj)) + us) n\<rbrace> createObjects ptr n obj us \<lbrace>\<lambda>rv s. distinct_prop op \<noteq> rv\<rbrace>"
  apply (simp add: createObjects_def unless_def alignError_def split_def
                   lookupAround2_pspace_no createObjects'_def
             cong: if_cong split del: split_if)
  apply (wp | simp only: o_def del: data_map_insert_def)+
  apply (clarsimp simp: upto_enum_def distinct_prop_map
              simp del: upt_Suc)
  apply (rule distinct_prop_distinct)
   apply simp
  apply (clarsimp simp: unat_minus_one)
  apply (subgoal_tac "x<2^word_bits")
   prefer 2
   apply (rule range_cover.range_cover_le_n_less(1)
     [where 'a=32, folded word_bits_def], assumption)
   apply (drule unat_of_nat_minus_1[OF range_cover.range_cover_n_less(1),where 'a=32, folded word_bits_def])
     apply simp
    apply arith
   apply (subgoal_tac "y< 2^word_bits")
    prefer 2
    apply (rule range_cover.range_cover_le_n_less(1)
      [where 'a=32, folded word_bits_def],assumption)
    apply (drule unat_of_nat_minus_1[OF range_cover.range_cover_n_less(1)])
     apply simp
    apply arith
   apply (subst(asm) toEnum_of_nat)
    apply (simp add:word_bits_def)
   apply (subst(asm) toEnum_of_nat)
    apply (simp add:word_bits_def)
   apply (drule_tac f = "\<lambda>x. x >> (objBitsKO (injectKOS obj) + us)" and x= "?x << ?l" in arg_cong)
   apply (subst (asm) shiftl_shiftr_id)
      apply (simp add:range_cover_def)
     apply (rule of_nat_power[OF range_cover.range_cover_le_n_less(2)])
      apply assumption
     apply (drule unat_of_nat_minus_1[OF range_cover.range_cover_n_less(1)])
      apply simp
     apply arith
     apply (simp add:word_bits_def objBitsKO_bounded_low)
  apply (subst (asm) shiftl_shiftr_id)
     apply (simp add:range_cover_def)
    apply (rule of_nat_power[OF range_cover.range_cover_le_n_less(2)])
     apply assumption
    apply (drule unat_of_nat_minus_1[OF range_cover.range_cover_n_less(1)])
     apply simp
    apply arith
    apply (simp add:word_bits_def objBitsKO_bounded_low)
  apply (simp add:of_nat_inj32)
  done

lemma createNewCaps_distinct:
  "\<lbrace>K (range_cover ptr sz (APIType_capBits ty us) n \<and> 0 < n)\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv s. distinct_prop (\<lambda>x y. \<not> RetypeDecls_H.sameRegionAs x y \<and> \<not> RetypeDecls_H.sameRegionAs y x)
                  (map snd (zip xs rv))\<rbrace>"
  apply (rule hoare_gen_asm[where P'=\<top>, simplified pred_and_true_var])
  apply (rule hoare_strengthen_post)
   apply (rule hoare_pre)
    apply (rule hoare_vcg_conj_lift)
     apply (rule createNewCaps_range_helper)
    apply (rule createNewCaps_children)
   apply fastforce
  apply clarsimp
  apply (rule distinct_prop_prefixE [OF _ map_snd_zip_prefix [unfolded less_eq_list_def]])
  apply (simp add: distinct_prop_map)
  apply (rule distinct_prop_distinct)
   apply simp
  apply clarsimp
  apply (subgoal_tac "capRange (capfn (ptr_add ptr (x * 2^APIType_capBits ty us)))
                       \<inter> capRange (capfn (ptr_add ptr (y * 2 ^ APIType_capBits ty us))) = {}")
   apply (subgoal_tac "\<forall>x < n. capAligned (capfn (ptr_add ptr (x * 2 ^ APIType_capBits ty us)))")
    apply (rule conjI)
     apply (rule notI, drule sameRegionAs_capRange_Int, simp+)
     apply (simp add: Int_commute)
    apply (rule notI, drule sameRegionAs_capRange_Int, simp+)
   apply (clarsimp simp: capAligned_def ptr_add_def word_unat_power[symmetric]
                  dest!: less_two_pow_divD)
   apply (intro conjI)
    apply (rule is_aligned_add_multI [OF _ le_refl refl])
      apply ((simp add:range_cover_def word_bits_def)+)[2]
  apply (simp add: capRange_def del: Int_atLeastAtMost)
  apply (rule aligned_neq_into_no_overlap[simplified field_simps])
     apply (rule notI)
     apply (erule(3) ptr_add_distinct_helper)
      apply (simp add:range_cover_def word_bits_def)
     apply (erule range_cover.range_cover_n_le(1)
       [where 'a=32, folded word_bits_def])
    apply (clarsimp simp: ptr_add_def word_unat_power[symmetric])
    apply (rule is_aligned_add_multI[OF _ le_refl refl])
     apply (simp add:range_cover_def)
    apply (simp add:range_cover_def)
   apply (clarsimp simp: ptr_add_def word_unat_power[symmetric])
   apply (rule is_aligned_add_multI[OF _ le_refl refl])
  apply (simp add:range_cover_def)+
  done

lemma getCTE_Ex_valid:
  "\<lbrace>valid_pspace'\<rbrace> getCTE p \<lbrace>\<lambda>rv s. \<exists>s'. s' \<turnstile>' cteCap rv\<rbrace>"
  apply (rule hoare_pre)
   apply (rule hoare_strengthen_post [OF getCTE_valid_cap'])
   apply fastforce
  apply (clarsimp simp: valid_pspace'_def)
  done

lemma createNewCaps_parent_helper:
  "\<lbrace>\<lambda>s. cte_wp_at' (\<lambda>cte. cteCap cte = UntypedCap ptr_base sz idx) p s
      \<and> pspace_aligned' s \<and> pspace_distinct' s
      \<and> pspace_no_overlap' ptr sz s
      \<and> (ty = APIObjectType ArchTypes_H.CapTableObject \<longrightarrow> 0 < us)
      \<and> range_cover ptr sz (APIType_capBits ty us) n \<and> 0 < n \<and> ptr_base = ptr && ~~ mask sz \<rbrace>
    createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                       (\<forall>tup\<in>set (zip (xs rv) rv).
                                sameRegionAs (cteCap cte) (snd tup)))
    p\<rbrace>"
  apply (rule hoare_post_imp [where Q="\<lambda>rv s. \<exists>cte. cte_wp_at' (op = cte) p s
                                           \<and> isUntypedCap (cteCap cte)
                                           \<and> (\<forall>tup\<in>set (zip (xs rv) rv).
                                sameRegionAs (cteCap cte) (snd tup))"])
   apply (clarsimp elim!: cte_wp_at_weakenE')
  apply (rule hoare_pre)
  apply (wp hoare_vcg_ex_lift createNewCaps_cte_wp_at'
            set_tuple_pick createNewCaps_children)
  apply (auto simp:cte_wp_at'_def isCap_simps)
  done

lemma createNewCaps_valid_cap':
  "\<lbrace>\<lambda>s. pspace_no_overlap' ptr sz s \<and>
        valid_pspace' s \<and> n \<noteq> 0 \<and>
        range_cover ptr sz (APIType_capBits ty us) n \<and>
        (ty = APIObjectType ArchTypes_H.CapTableObject \<longrightarrow> 0 < us) \<and>
        (ty = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> 4\<le> us \<and> us \<le> 30) \<and>
       ptr \<noteq> 0 \<rbrace>
    createNewCaps ty ptr n us
  \<lbrace>\<lambda>r s. \<forall>cap\<in>set r. s \<turnstile>' cap\<rbrace>"
  apply (rule hoare_assume_pre)
  apply clarsimp
  apply (erule createNewCaps_valid_cap)
  apply simp+
  done

lemma dmo_ctes_of[wp]:
  "\<lbrace>\<lambda>s. P (ctes_of s)\<rbrace> doMachineOp mop \<lbrace>\<lambda>rv s. P (ctes_of s)\<rbrace>"
  by (simp add: doMachineOp_def split_def | wp select_wp)+

lemma createNewCaps_ranges:
  "\<lbrace>\<lambda>s. range_cover ptr sz (APIType_capBits ty us) n \<and> 0<n \<rbrace>
  createNewCaps ty ptr n us
  \<lbrace>\<lambda>rv s. distinct_sets (map capRange rv)\<rbrace>"
  apply (rule hoare_assume_pre)
  apply (rule hoare_chain)
    apply (rule createNewCaps_range_helper)
   apply fastforce
  apply (clarsimp simp: distinct_sets_prop distinct_prop_map)
  apply (rule distinct_prop_distinct)
   apply simp
  apply (clarsimp simp: capRange_def simp del: Int_atLeastAtMost
                  dest!: less_two_pow_divD)
  apply (rule aligned_neq_into_no_overlap[simplified field_simps])
     apply (rule notI)
     apply (erule(3) ptr_add_distinct_helper)
      apply (simp add:range_cover_def word_bits_def)
     apply (erule range_cover.range_cover_n_le(1)
       [where 'a=32, folded word_bits_def])
    apply (clarsimp simp: ptr_add_def word_unat_power[symmetric])
    apply (rule is_aligned_add_multI[OF _ le_refl refl])
     apply (simp add:range_cover_def)+
   apply (clarsimp simp: ptr_add_def word_unat_power[symmetric])
   apply (rule is_aligned_add_multI[OF _ le_refl refl])
  apply (simp add:range_cover_def)+
  done

lemma createNewCaps_ranges':
  "\<lbrace>\<lambda>s. range_cover ptr sz (APIType_capBits ty us) n \<and> 0 < n\<rbrace>
  createNewCaps ty ptr n us
  \<lbrace>\<lambda>rv s. distinct_sets (map capRange (map snd (zip xs rv)))\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (rule createNewCaps_ranges)
  apply (simp add: distinct_sets_prop del: map_map)
  apply (erule distinct_prop_prefixE)
  apply (rule map_prefixeqI)
  apply (rule map_snd_zip_prefix [unfolded less_eq_list_def])
  done

lemmas corres_split_retype_createNewCaps
   = corres_split [OF _ corres_retype_region_createNewCaps,
                   simplified bind_assoc, simplified]

crunch cte_wp_at[wp]: do_machine_op "\<lambda>s. P (cte_wp_at P' p s)"

lemma retype_region_caps_overlap_reserved:
  "\<lbrace>valid_pspace and valid_mdb and
    pspace_no_overlap ptr sz and caps_no_overlap ptr sz and
    caps_overlap_reserved
      {ptr..ptr + of_nat n * 2^obj_bits_api (APIType_map2 (Inr ao')) us - 1} and
    K (APIType_map2 (Inr ao') = Invariants_AI.CapTableObject \<longrightarrow> 0 < us) and
    K (range_cover ptr sz (obj_bits_api (APIType_map2 (Inr ao')) us) n) and
    K (S \<subseteq> {ptr..ptr + of_nat n *
                  2 ^ obj_bits_api (APIType_map2 (Inr ao')) us - 1})\<rbrace>
   retype_region ptr n us (APIType_map2 (Inr ao'))
   \<lbrace>\<lambda>rv s. caps_overlap_reserved S s\<rbrace>"
  apply (rule hoare_gen_asm)+
  apply (simp (no_asm) add:caps_overlap_reserved_def2)
  apply (rule hoare_pre)
  apply (wp retype_region_caps_of)
   apply simp+
  apply (simp add:caps_overlap_reserved_def2)
  apply (intro conjI,simp+)
  apply clarsimp
  apply (drule bspec)
   apply simp+
  apply (erule(1) disjoint_subset2)
  done

lemma retype_region_caps_overlap_reserved_ret:
  "\<lbrace>valid_pspace and valid_mdb and caps_no_overlap ptr sz and
    pspace_no_overlap ptr sz and
    caps_overlap_reserved
      {ptr..ptr + of_nat n * 2^obj_bits_api (APIType_map2 (Inr ao')) us - 1} and
    K (APIType_map2 (Inr ao') = Invariants_AI.CapTableObject \<longrightarrow> 0 < us) and
    K (range_cover ptr sz (obj_bits_api (APIType_map2 (Inr ao')) us) n)\<rbrace>
   retype_region ptr n us (APIType_map2 (Inr ao'))
   \<lbrace>\<lambda>rv s. \<forall>y\<in>set rv. caps_overlap_reserved (untyped_range (default_cap
                            (APIType_map2 (Inr ao')) y us)) s\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (clarsimp simp:valid_def)
  apply (frule retype_region_ret[unfolded valid_def,simplified,THEN spec,THEN bspec])
  apply clarsimp
  apply (erule use_valid[OF _ retype_region_caps_overlap_reserved])
  apply clarsimp
  apply (intro conjI,simp_all)
  apply (case_tac ao')
    apply (simp_all add:APIType_map2_def)
  apply (case_tac apiobject_type)
    apply (simp_all add:obj_bits_api_def ptr_add_def)
  apply (drule(1) range_cover_subset)
  apply clarsimp+
  done

lemma getObjectSize_def_eq:
  "Types_H.getObjectSize va us = obj_bits_api (APIType_map2 (Inr va)) us"
  apply (case_tac va)
    apply (case_tac apiobject_type)
  apply (clarsimp simp:getObjectSize_def apiGetObjectSize_def APIType_map2_def
    ArchTypes_H.getObjectSize_def obj_bits_api_def tcbBlockSizeBits_def epSizeBits_def
    aepSizeBits_def cteSizeBits_def slot_bits_def arch_kobj_size_def
    default_arch_object_def ptBits_def pageBits_def pdBits_def)+
  done

lemma updateFreeIndex_pspace_no_overlap':
  "\<lbrace>\<lambda>s. pspace_no_overlap' ptr sz s \<and>
        valid_pspace' s \<and> cte_wp_at' (\<lambda>c. cteCap c = cap) src s\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. pspace_no_overlap' ptr sz s\<rbrace>"
  apply (rule hoare_pre)
  apply (wp pspace_no_overlap'_lift)
  apply (clarsimp simp:valid_pspace'_def)
  done

lemma updateFreeIndex_caps_overlap_reserved':
  "\<lbrace>\<lambda>s. invs' s \<and> S \<subseteq> untypedRange cap \<and>
        usableUntypedRange (capFreeIndex_update (\<lambda>_. index) cap) \<inter> S = {} \<and>
        isUntypedCap cap \<and> descendants_range_in' S src (ctes_of s) \<and>
        cte_wp_at' (\<lambda>c. cteCap c = cap) src s\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. caps_overlap_reserved' S s\<rbrace>"
  apply (clarsimp simp:caps_overlap_reserved'_def)
  apply (wp updateCap_ctes_of_wp)
  apply (clarsimp simp:modify_map_def cte_wp_at_ctes_of)
  apply (erule ranE)
  apply (frule invs_mdb')
  apply (clarsimp split:split_if_asm simp:valid_mdb'_def valid_mdb_ctes_def)
  apply (case_tac cte)
  apply (case_tac ctea)
  apply simp
  apply (drule untyped_incD')
   apply (simp+)[4]
  apply clarify
  apply (erule subset_splitE)
     apply (simp del:usable_untyped_range.simps)
     apply (thin_tac "?P \<longrightarrow> ?Q")+
     apply (elim conjE)
     apply blast
    apply (simp)
    apply (thin_tac "?P\<longrightarrow>?Q")+
    apply (elim conjE)
    apply (drule(2) descendants_range_inD')
    apply simp
    apply (rule disjoint_subset[OF usableRange_subseteq])
       apply (rule valid_capAligned)
        apply (erule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
      apply (simp add:untypedCapRange)+
   apply (elim disjE)
     apply clarsimp
     apply (drule(2) descendants_range_inD')
     apply simp
     apply (rule disjoint_subset[OF usableRange_subseteq])
       apply (rule valid_capAligned)
        apply (erule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
      apply (simp add:untypedCapRange)+
  apply (thin_tac "?P\<longrightarrow>?Q")+
  apply (rule disjoint_subset[OF usableRange_subseteq])
     apply (rule valid_capAligned)
    apply (erule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
   apply simp+
  apply blast
  done

lemma updateFreeIndex_caps_no_overlap'':
  "\<lbrace>\<lambda>s. isUntypedCap cap \<and> caps_no_overlap'' ptr sz s \<and>
        cte_wp_at' (\<lambda>c. cteCap c = cap) src s\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. caps_no_overlap'' ptr sz s\<rbrace>"
  apply (clarsimp simp:caps_no_overlap''_def)
  apply (wp updateCap_ctes_of_wp)
  apply (clarsimp simp: modify_map_def ran_def cte_wp_at_ctes_of
              simp del: atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
                        Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex)
  apply (case_tac "a = src")
   apply (clarsimp simp del: atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
     Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex)
   apply (erule subsetD[rotated])
   apply (elim allE impE)
     apply fastforce
    apply (clarsimp simp:isCap_simps)
   apply (erule subset_trans)
   apply (clarsimp simp:isCap_simps)
  apply (clarsimp simp del: atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
     Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex)
   apply (erule subsetD[rotated])
  apply (elim allE impE)
   prefer 2
    apply assumption
  apply fastforce+
  done

lemma updateCap_ct_active':
  "\<lbrace>ct_active'\<rbrace> updateCap slot newCap \<lbrace>\<lambda>_. ct_active'\<rbrace>"
apply (simp add: updateCap_def ct_in_state'_def)
apply wp
apply (wps setCTE_ct)
apply (wp setCTE_st_tcb_at')
done

(* FIXME: move to CSpace_R *)
lemma mdb_preserve_refl: "mdb_inv_preserve m m"
  by (simp add:mdb_inv_preserve_def)

(* FIXME: move to CSpace_R *)
lemma mdb_preserve_sym: "mdb_inv_preserve m m' \<Longrightarrow> mdb_inv_preserve m' m"
  by (simp add:mdb_inv_preserve_def)

lemma updateFreeIndex_descendants_of':
  "\<lbrace>\<lambda>s. cte_wp_at' (\<lambda>c. cteCap c = cap) ptr s \<and> isUntypedCap cap \<and>
        P ((swp descendants_of') (null_filter' (ctes_of s)))\<rbrace>
   updateCap ptr (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. P ((swp descendants_of') (null_filter' (ctes_of s)))\<rbrace>"
  apply (wp updateCap_ctes_of_wp)
  apply clarsimp
  apply (erule subst[rotated,where P = P])
  apply (rule ext)
  apply (clarsimp simp:null_filter_descendants_of'[OF null_filter_simp'])
  apply (rule mdb_inv_preserve.descendants_of)
  apply (clarsimp simp:cte_wp_at_ctes_of)
  apply (erule(1) mdb_inv_preserve_updateCap)
  done

lemma updateFreeIndex_descendants_range_in':
  "\<lbrace>\<lambda>s. cte_wp_at' (\<lambda>c. cteCap c = cap) slot s \<and> isUntypedCap cap \<and>
        descendants_range_in' S slot (ctes_of s)\<rbrace>
   updateCap slot (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. descendants_range_in' S slot (ctes_of s)\<rbrace>"
  apply (rule hoare_pre)
   apply (wp descendants_range_in_lift'
     [where Q'="\<lambda>s. cte_wp_at' (\<lambda>c. cteCap c = cap) slot s \<and> isUntypedCap cap" and
       Q = "\<lambda>s. cte_wp_at' (\<lambda>c. cteCap c = cap) slot s \<and> isUntypedCap cap "] )
    apply (wp updateFreeIndex_descendants_of')
    apply (elim conjE)
   apply (intro conjI,assumption+)
   apply clarsimp
  apply (simp add:updateCap_def)
  apply (wp setCTE_weak_cte_wp_at getCTE_wp)
   apply (fastforce simp:cte_wp_at_ctes_of isCap_simps)
  apply (clarsimp)
  done

lemma caps_no_overlap''_def2:
  "caps_no_overlap'' ptr sz =
   (\<lambda>s. \<forall>cte\<in>ran (null_filter' (ctes_of s)).
            untypedRange (cteCap cte) \<inter>
            {ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1} \<noteq> {} \<longrightarrow>
            {ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1} \<subseteq>
            untypedRange (cteCap cte))"
  apply (intro ext iffI)
    apply (clarsimp simp:caps_no_overlap''_def null_filter'_def ran_def)
    apply (drule_tac x = cte in spec)
    apply fastforce
  apply (clarsimp simp:caps_no_overlap''_def null_filter'_def)
  apply (case_tac "cte = CTE capability.NullCap nullMDBNode")
   apply clarsimp
  apply (drule_tac x = cte in  bspec)
   apply (clarsimp simp:ran_def)
   apply (rule_tac x= a in exI)
   apply clarsimp
  apply clarsimp
  apply (erule subsetD)
  apply simp
  done

lemma caps_no_overlapI'':
  "\<lbrakk>cte_wp_at' (\<lambda>c. cteCap c = capability.UntypedCap ptr_base sz idx) slot s;
    valid_pspace' s;idx < 2^sz;ptr = ptr_base + of_nat idx\<rbrakk>
   \<Longrightarrow> caps_no_overlap'' ptr sz s"
  apply (unfold caps_no_overlap''_def)
  apply (intro ballI impI)
  apply (erule ranE)
  apply (subgoal_tac "isUntypedCap (cteCap cte)")
   apply (clarsimp simp:cte_wp_at_ctes_of
          simp del: atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff )
   apply (case_tac cte,case_tac ctea)
   apply clarify
   apply (drule untyped_incD')
      apply (simp add:isCap_simps)+
    apply (clarsimp simp:valid_pspace'_def valid_mdb'_def valid_mdb_ctes_def)
   apply (clarsimp simp:cte_wp_at_ctes_of valid_pspace'_def valid_cap'_def capAligned_def
                        of_nat_less_pow is_aligned_add_helper
          simp del: atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff
          dest!:ctes_of_valid_cap')
   apply (erule subset_splitE)
       apply (simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff)+
     apply (erule subsetD[OF psubset_imp_subset])
     apply (erule subsetD[rotated])
     apply clarsimp
     apply (erule is_aligned_no_wrap')
     apply (simp add:of_nat_less_pow)
    apply (simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
        Int_atLeastAtMost atLeastatMost_empty_iff)+
    apply (erule subsetD[rotated])
    apply clarsimp
    apply (erule is_aligned_no_wrap')
    apply (simp add:of_nat_less_pow)
   apply (thin_tac "?P \<longrightarrow>?Q")+
   apply (drule disjoint_subset2[rotated,where B'="{ptr_base + of_nat idx..ptr_base + 2 ^ sz - 1}"])
    apply clarsimp
    apply (erule is_aligned_no_wrap')
    apply (simp add:of_nat_less_pow)
   apply simp
  apply (case_tac "cteCap cte")
  apply (simp_all add:isCap_simps)
  done

lemma caps_no_overlap'_def2:
  "caps_no_overlap' =
   (\<lambda>ms S. \<forall>p c. (\<exists>n. (null_filter' ms) p = Some (CTE c n)) \<longrightarrow>
                 capRange c \<inter> S = {})"
  apply (intro iffI ext allI)
  apply (clarsimp simp:caps_no_overlap'_def null_filter'_def
    dest!:bspec split:if_splits)+
  apply (drule_tac x = p in spec)
  apply auto
  done

lemma deleteObjects_caps_no_overlap'':
  "\<lbrace>\<lambda>s. invs' s \<and> ct_active' s \<and> sch_act_simple s \<and>
        cte_wp_at' (\<lambda>c. cteCap c = capability.UntypedCap ptr sz idx) slot s \<and>
        caps_no_overlap'' ptr sz s \<and>
        descendants_range' (capability.UntypedCap ptr sz idx) slot (ctes_of s)\<rbrace>
   deleteObjects ptr sz
   \<lbrace>\<lambda>rv s. caps_no_overlap'' ptr sz s\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (clarsimp split:if_splits)
  apply (clarsimp simp:caps_no_overlap''_def2 deleteObjects_def2 capAligned_def valid_cap'_def
    dest!:ctes_of_valid_cap')
  apply (wp deleteObjects_null_filter[where idx = idx and p = slot])
  apply (clarsimp simp:cte_wp_at_ctes_of invs_def)
  apply (case_tac cte)
  apply clarsimp
  apply (frule ctes_of_valid_cap')
   apply (simp add:invs_valid_objs')
  apply (simp add:valid_cap'_def capAligned_def)
  done

lemma descendants_range_in_subseteq':
  "\<lbrakk>descendants_range_in' A p ms ;B\<subseteq> A\<rbrakk> \<Longrightarrow> descendants_range_in' B p ms"
  by (auto simp:descendants_range_in'_def cte_wp_at_ctes_of dest!:bspec)

lemma deleteObjects_caps_overlap_reserved':
  "\<lbrace>\<lambda>s. valid_pspace' s \<and>
        cte_wp_at' (\<lambda>c. cteCap c = capability.UntypedCap ptr sz idx) slot s \<and>
        caps_overlap_reserved' S s\<rbrace>
   deleteObjects ptr sz
   \<lbrace>\<lambda>rv s. caps_overlap_reserved' S s\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (clarsimp simp:cte_wp_at_ctes_of valid_pspace'_def isCap_simps capAligned_def)
  apply (case_tac cte)
  apply (clarsimp simp:caps_no_overlap''_def deleteObjects_def2 capAligned_def valid_cap'_def
    dest!:ctes_of_valid_cap')
  apply (wp hoare_drop_imps)+
   apply (rule_tac Q = "\<lambda>r. caps_overlap_reserved' S and pspace_distinct' and ?Q" in  hoare_strengthen_post)
    prefer 2
    apply (cut_tac s = sa in  map_to_ctes_delete[where base = ptr and magnitude = sz and idx = idx])
      apply clarsimp
      apply assumption
     apply simp
    apply (simp add:valid_cap'_def capAligned_def p_assoc_help caps_overlap_reserved'_def)+
    apply (intro ballI)
    apply (erule ranE)
    apply (fastforce split:if_splits)
   apply (clarsimp simp:caps_overlap_reserved'_def2)
   apply wp
    apply (clarsimp simp:caps_overlap_reserved'_def2 valid_cap'_def capAligned_def)+
  done

lemma updateFreeIndex_mdb_simple':
  "\<lbrace>\<lambda>s. descendants_range_in' (capRange cap) src (ctes_of s) \<and>
        pspace_no_overlap' (capPtr cap) (capBlockSize cap) s \<and>
        valid_pspace' s \<and> cte_wp_at' (\<lambda>c. cteCap c = cap) src s \<and>
        isUntypedCap cap\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. idx) cap)
   \<lbrace>\<lambda>rv. valid_mdb'\<rbrace>"
  apply (clarsimp simp:valid_mdb'_def updateCap_def valid_pspace'_def)
  apply (wp getCTE_wp)
  apply (clarsimp simp:cte_wp_at_ctes_of simp del:fun_upd_apply)
  apply (subgoal_tac
    "mdb_inv_preserve (ctes_of s)
    (ctes_of s(src \<mapsto> cteCap_update (\<lambda>_. capFreeIndex_update (\<lambda>_. idx) (cteCap cte)) cte))")
  prefer 2
    apply (frule mdb_inv_preserve_updateCap)
     apply (simp add: modify_map_apply)+
    apply (clarsimp simp:valid_mdb_ctes_def
      mdb_inv_preserve.preserve_stuff mdb_inv_preserve.by_products)
  apply (clarsimp simp:isCap_simps)
  proof -
  fix s cte v0 v1 f
  assume descendants_range: "descendants_range_in' {v0..v0 + 2 ^ v1 - 1} src (ctes_of s)"
  and    cte_wp_at' :"ctes_of s src = Some cte" "cteCap cte = capability.UntypedCap v0 v1 f"
  and      unt_inc' :"untyped_inc' (ctes_of s)"
  and   valid_objs' :"valid_objs' s"
  have descendants_of_simp:
    "\<And>p. descendants_of' p  (ctes_of s(src \<mapsto> cteCap_update (\<lambda>_. capability.UntypedCap v0 v1 idx) cte))
    = descendants_of' p (ctes_of s)"
    using cte_wp_at'
    apply -
    apply (drule updateUntypedCap_descendants_of)
      apply (clarsimp simp:isCap_simps)+
    apply simp
    done
  note drangeD = descendants_range_inD'[OF descendants_range]
  note valid_capD = ctes_of_valid_cap'[OF _ valid_objs']
  note blah[simp del] = usableUntypedRange.simps atLeastAtMost_iff
          atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          order_class.Icc_eq_Icc
  show  "untyped_inc' (ctes_of s(src \<mapsto> cteCap_update (\<lambda>_. capability.UntypedCap v0 v1 idx) cte))"
  using unt_inc' cte_wp_at'
  apply (clarsimp simp:untyped_inc'_def descendants_of_simp)
  apply (case_tac cte)
  apply clarsimp
  apply (intro conjI)
    apply clarsimp
    apply (drule_tac x = src in spec)
    apply (drule_tac x = p' in spec)
    apply (clarsimp simp: isCap_simps)
    apply (intro conjI impI)
       apply simp
       apply (elim conjE)
       apply (thin_tac "?P\<longrightarrow>?Q")+
       apply (drule(1) drangeD)
       apply (drule valid_capAligned[OF valid_capD])+
       apply (drule aligned_untypedRange_non_empty,simp add:isCap_simps)+
       apply simp
       apply blast
    apply clarsimp
    apply (drule(1) drangeD)
    apply (drule valid_capAligned[OF valid_capD])+
    apply (drule aligned_untypedRange_non_empty,simp add:isCap_simps)+
    apply simp
  apply clarsimp
  apply (drule_tac x = src in spec)
  apply (drule_tac x = p in spec)
  apply (clarsimp simp:isCap_simps)
  apply (intro conjI impI)
    apply (elim disjE)
      apply (simp add:Int_ac)+
   apply (thin_tac "?P\<longrightarrow>?Q")+
   apply (elim conjE)
   apply (drule(1) drangeD)
   apply (drule valid_capAligned[OF valid_capD])+
   apply (drule aligned_untypedRange_non_empty,simp add:isCap_simps)+
   apply simp
   apply blast
  apply simp
  apply (elim disjE conjE,simp_all)
  apply (drule(1) drangeD)
  apply (drule valid_capAligned[OF valid_capD])+
  apply (drule aligned_untypedRange_non_empty,simp add:isCap_simps)+
  apply simp
  done
qed

lemma updateFreeIndex_pspace_simple':
  "\<lbrace>\<lambda>s. descendants_range_in' (capRange cap) src (ctes_of s) \<and>
        pspace_no_overlap' (capPtr cap) (capBlockSize cap) s \<and>
        valid_pspace' s \<and> cte_wp_at' (\<lambda>c. cteCap c = cap) src s \<and>
        isUntypedCap cap \<and> is_aligned (of_nat idx :: word32) 4 \<and>
        idx \<le> 2 ^ (capBlockSize cap)\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. idx) cap)
   \<lbrace>\<lambda>r s. valid_pspace' s\<rbrace>"
   apply (clarsimp simp:valid_pspace'_def)
   apply (rule hoare_pre)
    apply (rule hoare_vcg_conj_lift)
     apply (clarsimp simp:updateCap_def)
     apply (wp getCTE_wp)
    apply (wp updateFreeIndex_mdb_simple')
    apply (simp)+
  apply (clarsimp simp:cte_wp_at_ctes_of valid_pspace'_def)
  apply (case_tac cte,simp add:isCap_simps)
  apply (frule(1) ctes_of_valid_cap')
  apply (clarsimp simp:valid_cap'_def capAligned_def valid_untyped'_def
          simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff usableUntypedRange.simps
          split del:if_splits)
  apply (drule_tac x = ptr' in spec)
  apply (clarsimp simp:ko_wp_at'_def valid_mdb'_def obj_range'_def valid_mdb_ctes_def
          simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff usableUntypedRange.simps
          split del:if_splits)
  apply (drule(1) pspace_no_overlapD')
  apply (cut_tac c' = "capability.UntypedCap v0 v1 idx" in usableRange_subseteq)
    apply (simp add:capAligned_def)
   apply (simp add:isCap_simps)
  apply (clarsimp simp:ko_wp_at'_def valid_mdb'_def is_aligned_neg_mask is_aligned_neg_mask_eq
          simp del:atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff usableUntypedRange.simps)
  apply blast
  done

lemma updateCap_vms'[wp]:
  "\<lbrace>valid_machine_state'\<rbrace> updateCap src cap' \<lbrace>\<lambda>rv s. valid_machine_state' s\<rbrace>"
  by (clarsimp simp:updateCap_def,wp)

(* FIXME: move *)
lemma setCTE_tcbDomain_inv[wp]:
  "\<lbrace>obj_at' (\<lambda>tcb. P (tcbState tcb)) t\<rbrace> setCTE ptr v \<lbrace>\<lambda>_. obj_at' (\<lambda>tcb. P (tcbState tcb)) t\<rbrace>"
  apply (simp add: setCTE_def)
  apply (rule setObject_cte_obj_at_tcb', simp_all)
  done

(* FIXME: move *)
crunch tcbState_inv[wp]: cteInsert "obj_at' (\<lambda>tcb. P (tcbState tcb)) t"
  (wp: crunch_simps hoare_drop_imps)

lemma updateCap_ct_idle_or_in_cur_domain'[wp]:
  "\<lbrace>ct_idle_or_in_cur_domain' and ct_active'\<rbrace> updateCap src cap \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain'\<rbrace>"
apply (wp ct_idle_or_in_cur_domain'_lift_futz[where Q=\<top>])
apply (rule_tac Q="\<lambda>_. obj_at' (\<lambda>tcb. tcbState tcb \<noteq> Structures_H.thread_state.Inactive) t and obj_at' (\<lambda>tcb. d = tcbDomain tcb) t"
             in hoare_strengthen_post)
apply (wp | clarsimp elim: obj_at'_weakenE)+
apply (auto simp: obj_at'_def)
done

lemma updateFreeIndex_invs_simple':
  "\<lbrace>\<lambda>s. ct_active' s \<and> descendants_range_in' (capRange cap) src (ctes_of s) \<and>
        pspace_no_overlap' (capPtr cap) (capBlockSize cap) s \<and> invs' s \<and>
        cte_wp_at' (\<lambda>c. cteCap c = cap) src s \<and> isUntypedCap cap \<and>
        is_aligned (of_nat index :: word32) 4 \<and> index \<le> 2 ^ capBlockSize cap\<rbrace>
   updateCap src (capFreeIndex_update (\<lambda>_. index) cap)
   \<lbrace>\<lambda>r s. invs' s\<rbrace>"
   apply (clarsimp simp:invs'_def valid_state'_def )
   apply (wp updateFreeIndex_pspace_simple' sch_act_wf_lift valid_queues_lift updateCap_iflive' tcb_in_cur_domain'_lift)
        apply (rule hoare_pre)
         apply (rule hoare_vcg_conj_lift)
         apply (simp add: ifunsafe'_def3 cteInsert_def setUntypedCapAsFull_def
               split del: split_if)
         apply (wp getCTE_wp)
       apply (rule hoare_vcg_conj_lift)
        apply (simp add:updateCap_def)
        apply wp
       apply (wp valid_irq_node_lift)
       apply (rule hoare_vcg_conj_lift)
        apply (simp add:updateCap_def)
        apply (wp setCTE_irq_handlers' getCTE_wp)
       apply (wp irqs_masked_lift valid_queues_lift' cur_tcb_lift)
      apply (clarsimp simp:cte_wp_at_ctes_of)
      apply (intro conjI allI impI)
         apply (clarsimp simp: modify_map_def cteCaps_of_def ifunsafe'_def3 split:if_splits)
          apply (drule_tac x=src in spec)
          apply (clarsimp simp:isCap_simps)
          apply (rule_tac x = cref' in exI)
          apply clarsimp
         apply (drule_tac x = cref in spec)
         apply clarsimp
         apply (rule_tac x = cref' in exI)
         apply clarsimp
        apply (drule(1) valid_global_refsD')
  apply (clarsimp simp:isCap_simps cte_wp_at_ctes_of)+
  done

lemma cte_wp_at_pspace_no_overlapI':
  "\<lbrakk>invs' s; cte_wp_at' (\<lambda>c. cteCap c = capability.UntypedCap
                                          (ptr && ~~ mask sz) sz idx) cref s;
    idx \<le> unat (ptr && mask sz); sz < word_bits\<rbrakk>
   \<Longrightarrow> pspace_no_overlap' ptr sz s"
  apply (clarsimp simp:cte_wp_at_ctes_of)
  apply (case_tac cte,clarsimp)
  apply (frule ctes_of_valid_cap')
    apply (simp add:invs_valid_objs')
  apply (clarsimp simp:valid_cap'_def invs'_def valid_state'_def valid_pspace'_def
    valid_untyped'_def simp del:usableUntypedRange.simps)
  apply (unfold pspace_no_overlap'_def)
  apply (intro allI impI)
  apply (unfold ko_wp_at'_def)
  apply (clarsimp simp del: atLeastAtMost_iff
          atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff  usableUntypedRange.simps)
  apply (drule spec)+
  apply (frule(1) pspace_distinctD')
  apply (frule(1) pspace_alignedD')
  apply (erule(1) impE)+
  apply (clarsimp simp: obj_range'_def simp del: atLeastAtMost_iff
          atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff  usableUntypedRange.simps)
  apply (erule disjoint_subset2[rotated])
  apply (frule(1) le_mask_le_2p)
  apply (clarsimp simp:p_assoc_help)
  apply (rule le_plus'[OF word_and_le2])
  apply simp
  apply (erule word_of_nat_le)
  done

lemma descendants_range_caps_no_overlapI':
  "\<lbrakk>invs' s; cte_wp_at' (\<lambda>c. cteCap c = capability.UntypedCap
                                          (ptr && ~~ mask sz) sz idx) cref s;
    descendants_range_in' {ptr .. (ptr && ~~ mask sz) +2^sz - 1} cref
                          (ctes_of s)\<rbrakk>
   \<Longrightarrow> caps_no_overlap'' ptr sz s"
  apply (frule invs_mdb')
  apply (clarsimp simp:valid_mdb'_def valid_mdb_ctes_def cte_wp_at_ctes_of
         simp del:usableUntypedRange.simps untypedRange.simps)
  apply (unfold caps_no_overlap''_def)
  apply (intro ballI impI)
  apply (erule ranE)
  apply (subgoal_tac "isUntypedCap (cteCap ctea)")
  prefer 2
   apply (rule untypedRange_not_emptyD)
    apply blast
  apply (case_tac ctea,case_tac cte)
  apply simp
  apply (drule untyped_incD')
     apply ((simp add:isCap_simps del:usableUntypedRange.simps untypedRange.simps)+)[4]
  apply (elim conjE subset_splitE)
     apply (erule subset_trans[OF _ psubset_imp_subset,rotated])
     apply (clarsimp simp:word_and_le2)
    apply simp
    apply (elim conjE)
    apply (thin_tac "?P\<longrightarrow>?Q")+
    apply (drule(2) descendants_range_inD')
    apply (simp add:untypedCapRange)+
   apply (erule subset_trans[OF _  equalityD1,rotated])
   apply (clarsimp simp:word_and_le2)
  apply (thin_tac "?P\<longrightarrow>?Q")+
  apply (drule disjoint_subset[rotated,
       where A' = "{ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1}"])
  apply (clarsimp simp:word_and_le2 Int_ac)+
  done

lemma cte_wp_at_caps_no_overlapI':
  "\<lbrakk>invs' s; cte_wp_at' (\<lambda>c. (cteCap c) = capability.UntypedCap
                                            (ptr && ~~ mask sz) sz idx) cref s;
    idx \<le> unat (ptr && mask sz); sz < word_bits\<rbrakk>
   \<Longrightarrow> caps_no_overlap'' ptr sz s"
  apply (frule invs_mdb')
  apply (frule(1) le_mask_le_2p)
  apply (clarsimp simp:valid_mdb'_def valid_mdb_ctes_def cte_wp_at_ctes_of)
  apply (case_tac cte)
  apply simp
  apply (frule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
  apply (unfold caps_no_overlap''_def)
  apply (intro ballI impI)
  apply (erule ranE)
  apply (subgoal_tac "isUntypedCap (cteCap ctea)")
  prefer 2
   apply (rule untypedRange_not_emptyD)
   apply blast
  apply (case_tac ctea)
  apply simp
  apply (drule untyped_incD')
     apply (simp add:isCap_simps)+
  apply (elim conjE)
  apply (erule subset_splitE)
      apply (erule subset_trans[OF _ psubset_imp_subset,rotated])
       apply (clarsimp simp: word_and_le2)
     apply simp
     apply (thin_tac "?P\<longrightarrow>?Q")+
     apply (elim conjE)
     apply (drule disjoint_subset2[rotated,
       where B' = "{ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1}"])
      apply clarsimp
      apply (rule le_plus'[OF word_and_le2])
      apply simp
      apply (erule word_of_nat_le)
     apply simp
    apply simp
   apply (erule subset_trans[OF _  equalityD1,rotated])
   apply (clarsimp simp:word_and_le2)
  apply (thin_tac "?P\<longrightarrow>?Q")+
  apply (drule disjoint_subset[rotated,
       where A' = "{ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1}"])
  apply (clarsimp simp:word_and_le2 Int_ac)+
  done


lemma descendants_range_ex_cte':
  "\<lbrakk>descendants_range_in' S p (ctes_of s');ex_cte_cap_wp_to' P q s'; S \<subseteq> capRange (cteCap cte);
    invs' s';ctes_of s' p = Some cte;isUntypedCap (cteCap cte)\<rbrakk> \<Longrightarrow> q \<notin> S"
   apply (frule invs_valid_objs')
   apply (frule invs_mdb')
   apply (clarsimp simp:invs'_def valid_state'_def)
   apply (clarsimp simp: ex_cte_cap_to'_def cte_wp_at_ctes_of)
    apply (frule_tac cte = "cte" in  valid_global_refsD')
    apply simp
   apply (case_tac "\<exists>irq. cteCap ctea = IRQHandlerCap irq")
     apply clarsimp
   apply (erule(1) in_empty_interE[OF _ _ subsetD,rotated -1])
     apply (clarsimp simp:global_refs'_def)
     apply (erule_tac A = "range ?P" in subsetD)
     apply (simp add:range_eqI field_simps)
   apply (case_tac ctea)
   apply clarsimp
  apply (case_tac ctea)
  apply (drule_tac cte = "cte" and cte' = ctea in untyped_mdbD')
       apply assumption
      apply (clarsimp simp:isCap_simps)
     apply (drule_tac B = "untypedRange (cteCap cte)" in subsetD[rotated])
      apply (clarsimp simp:untypedCapRange)
     apply clarsimp
     apply (drule_tac x = " (irq_node' s')" in cte_refs_capRange[rotated])
      apply (erule(1) ctes_of_valid_cap')
     apply blast
   apply (clarsimp simp:isCap_simps)
  apply (simp add:valid_mdb'_def valid_mdb_ctes_def)
  apply (drule(2) descendants_range_inD')
  apply clarsimp
  apply (drule_tac x = " (irq_node' s')" in cte_refs_capRange[rotated])
   apply (erule(1) ctes_of_valid_cap')
  apply blast
  done

lemma update_untyped_cap_corres:
  "\<lbrakk>is_untyped_cap cap; isUntypedCap cap'; cap_relation cap cap'\<rbrakk>
   \<Longrightarrow> corres dc
         (cte_wp_at (\<lambda>c. is_untyped_cap c \<and> obj_ref_of c = obj_ref_of cap \<and>
          cap_bits c = cap_bits cap) src and valid_objs and
          pspace_aligned and pspace_distinct)
         (cte_at' (cte_map src) and pspace_distinct' and pspace_aligned')
         (set_cap cap src) (updateCap (cte_map src) cap')"
  apply (rule corres_name_pre)
  apply (simp add:updateCap_def)
  apply (frule state_relation_pspace_relation)
  apply (clarsimp simp:cte_wp_at_ctes_of)
  apply (frule CSpace_R.pspace_relation_cte_wp_atI)
    apply (fastforce simp:cte_wp_at_ctes_of)
   apply simp
  apply clarify
  apply (frule cte_map_inj_eq)
    apply (fastforce simp:cte_wp_at_ctes_of cte_wp_at_caps_of_state)+
  apply (clarsimp simp:isCap_simps is_cap_simps)
  apply (rule corres_guard_imp)
    apply (rule corres_symb_exec_r)
      apply (rule_tac F = "cteCap_update (\<lambda>_. capability.UntypedCap r bits f) ctea
        = cteCap_update (\<lambda>cap. capFreeIndex_update (\<lambda>_. f) (cteCap cte)) cte" in corres_gen_asm2)
      apply (rule_tac F = " (cap.UntypedCap r bits f) = free_index_update (\<lambda>_. f) c"
        in corres_gen_asm)
      apply simp
      apply (rule set_untyped_cap_corres)
        apply (clarsimp simp:cte_wp_at_caps_of_state cte_wp_at_ctes_of)+
      apply (subst identity_eq)
     apply (wp getCTE_sp getCTE_get)
    apply (rule no_fail_pre[OF no_fail_getCTE])
  apply (clarsimp simp:cte_wp_at_ctes_of cte_wp_at_caps_of_state)+
  done


locale invokeUntyped_proofs =
 fixes s cref ptr tp us slots sz idx
    assumes cte_wp_at': "cte_wp_at' (\<lambda>cte. cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sz idx) cref s"
    assumes cover     : "range_cover ptr sz (APIType_capBits tp us) (length (slots::word32 list))"
    assumes  misc     : "distinct slots" "idx \<le> unat (ptr && mask sz) \<or> ptr = ptr && ~~ mask sz"
      "invs' s" "slots \<noteq> []"
      "\<forall>slot\<in>set slots. cte_wp_at' (\<lambda>c. cteCap c = capability.NullCap) slot s"
      "\<forall>x\<in>set slots. ex_cte_cap_wp_to' (\<lambda>_. True) x s"
    assumes desc_range: "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in' {ptr..ptr + 2 ^ sz - 1} (cref) (ctes_of s)"
begin

abbreviation(input)
  "retype_range == {ptr..ptr + of_nat (length slots) * 2 ^ APIType_capBits tp us - 1}"

abbreviation(input)
  "usable_range ==  {ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1}"

   lemma not_0_ptr[simp]: "ptr\<noteq> 0"
      using misc cte_wp_at'
      apply (clarsimp simp:cte_wp_at_ctes_of)
      apply (case_tac cte)
      apply clarsimp
      apply (drule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
      apply (simp add:valid_cap'_def)
      done

   lemma subset_stuff[simp]:
      "retype_range \<subseteq> usable_range"
      apply (rule range_cover_subset'[OF cover])
      apply (simp add:misc)
      done

    lemma descendants_range[simp]:
      "descendants_range_in' usable_range cref (ctes_of s)"
      "descendants_range_in' retype_range cref (ctes_of s)"
      proof -
        have "descendants_range_in' usable_range cref (ctes_of s)"
          using misc cte_wp_at' cover
          apply -
          apply (erule disjE)
           apply (erule cte_wp_at_caps_descendants_range_inI'
             [OF _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
           apply simp+
          using desc_range
          apply simp
          done
        thus "descendants_range_in' usable_range cref (ctes_of s)"
           by simp
        thus "descendants_range_in' retype_range cref (ctes_of s)"
           by (rule descendants_range_in_subseteq'[OF _ subset_stuff])
        qed

    lemma vc'[simp] : "s \<turnstile>' capability.UntypedCap (ptr && ~~ mask sz) sz idx"
      using misc cte_wp_at'
      apply (clarsimp simp:cte_wp_at_ctes_of)
      apply (case_tac cte)
      apply clarsimp
      apply (erule ctes_of_valid_cap')
      apply (simp add:invs_valid_objs')
      done

    lemma ps_no_overlap'[simp]: "ptr && ~~ mask sz \<noteq> ptr \<Longrightarrow> pspace_no_overlap' ptr sz s"
      using misc cte_wp_at' cover
      apply clarsimp
      apply (erule(3) cte_wp_at_pspace_no_overlapI'
        [OF  _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
      done

    lemma caps_no_overlap'[simp]: "caps_no_overlap'' ptr sz s"
      using cte_wp_at' misc cover desc_range
      apply -
      apply (erule disjE)
       apply (erule cte_wp_at_caps_no_overlapI'
         [OF  _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
        apply simp+
      apply (erule descendants_range_caps_no_overlapI')
       apply simp+
      done

    lemma idx_compare'[simp]:"unat ((ptr && mask sz) + (of_nat (length slots)<< (APIType_capBits tp us))) \<le> 2 ^ sz"
      apply (rule le_trans[OF unat_plus_gt])
      apply (simp add:range_cover.unat_of_nat_n_shift[OF cover] range_cover_unat)
      apply (insert range_cover.range_cover_compare_bound[OF cover])
      apply simp
      done

    lemma ex_cte_no_overlap': "\<And>P p. ex_cte_cap_wp_to' P p s \<Longrightarrow> p \<notin> usable_range"
      using cte_wp_at' misc
      apply (clarsimp simp:cte_wp_at_ctes_of)
        apply (drule_tac cte = cte in descendants_range_ex_cte'[OF descendants_range(1)])
        apply (clarsimp simp:word_and_le2 isCap_simps)+
      done

    lemma cref_inv: "cref \<notin> usable_range"
      apply (insert misc cte_wp_at')
      apply (drule if_unsafe_then_capD')
        apply (simp add:invs'_def valid_state'_def)
       apply simp
      apply (erule ex_cte_no_overlap')
      done

    lemma slots_invD: "\<And>x. x \<in> set slots \<Longrightarrow>
      x \<noteq> cref \<and> x \<notin> usable_range \<and>  ex_cte_cap_wp_to' (\<lambda>_. True) x s"
      using misc cte_wp_at'
      apply -
      apply simp
      apply (drule(1) bspec)+
      apply (drule ex_cte_no_overlap')
       apply simp
      apply (clarsimp simp:cte_wp_at_ctes_of)
      done

    lemma usableRange_disjoint:
      "usableUntypedRange (capability.UntypedCap (ptr && ~~ mask sz) sz
       (unat ((ptr && mask sz) + of_nat (length slots) * 2 ^ APIType_capBits tp us))) \<inter>
       {ptr..ptr + of_nat (length slots) * 2 ^ APIType_capBits tp us - 1} = {}"
      proof -
      have idx_compare''[simp]:
       "unat ((ptr && mask sz) + (of_nat (length slots) * (2::word32) ^ APIType_capBits tp us)) < 2 ^ sz
        \<Longrightarrow> ptr + of_nat (length slots) * 2 ^ APIType_capBits tp us - 1
        < ptr + of_nat (length slots) * 2 ^ APIType_capBits tp us"
      apply (rule minus_one_helper,simp)
      apply (rule neq_0_no_wrap)
      apply (rule word32_plus_mono_right_split)
      apply (simp add:shiftl_t2n range_cover_unat[OF cover] field_simps)
      apply (simp add:range_cover.sz(1)
        [where 'a=32, folded word_bits_def, OF cover])+
      done
      show ?thesis
       apply (clarsimp simp:mask_out_sub_mask)
       apply (drule idx_compare'')
       apply simp
       done
     qed
end

lemma and_distrib:
  "(P and (\<lambda>x. Q x)) = (\<lambda>x. P x \<and> Q x)"
  by (rule ext,simp)

lemma valid_sched_etcbs[elim!]: "valid_sched_2 queues ekh sa cdom kh ct it \<Longrightarrow> valid_etcbs_2 ekh kh"
  by (simp add: valid_sched_def)

lemma valid_etcbs_detype: "valid_etcbs s \<Longrightarrow> valid_etcbs (detype S s)"
  by (clarsimp simp add: detype_def detype_ext_def valid_etcbs_def
                            st_tcb_at_kh_def is_etcb_at_def obj_at_kh_def
                            obj_at_def)

crunch ksIdleThread[wp]: deleteObjects "\<lambda>s. P (ksIdleThread s)"
  (simp: crunch_simps wp: hoare_drop_imps hoare_unless_wp ignore:freeMemory)
crunch ksCurDomain[wp]: deleteObjects "\<lambda>s. P (ksCurDomain s)"
  (simp: crunch_simps wp: hoare_drop_imps hoare_unless_wp ignore:freeMemory)
crunch irq_node[wp]: deleteObjects "\<lambda>s. P (irq_node' s)"
  (simp: crunch_simps wp: hoare_drop_imps hoare_unless_wp ignore:freeMemory)

lemma deleteObjects_ksCurThread[wp]:
  "\<lbrace>\<lambda>s. P (ksCurThread s)\<rbrace> deleteObjects ptr sz \<lbrace>\<lambda>_ s. P (ksCurThread s)\<rbrace>"
apply (simp add: deleteObjects_def3)
apply (wp | simp add: doMachineOp_def split_def)+
done

lemma deleteObjects_ct_active':
  "\<lbrace>invs' and sch_act_simple and ct_active'
      and cte_wp_at' (\<lambda>c. cteCap c = UntypedCap ptr sz idx) cref
      and (\<lambda>s. descendants_range' (UntypedCap ptr sz idx) cref (ctes_of s))
      and K (sz < word_bits \<and> is_aligned ptr sz)\<rbrace>
     deleteObjects ptr sz
   \<lbrace>\<lambda>_. ct_active'\<rbrace>"
  apply (simp add: ct_in_state'_def)
  apply (rule hoare_pre)
  apply wps
  apply (wp deleteObjects_st_tcb_at')
  apply (auto simp: ct_in_state'_def elim: st_tcb'_weakenE)
done



lemma inv_untyped_corres':
  "\<lbrakk> ui = (Invocations_A.Retype cref ptr_base ptr tp us slots);
     untypinv_relation ui ui' \<rbrakk> \<Longrightarrow>
   corres (op =)
     (einvs and valid_untyped_inv ui and ct_active)
     (invs' and valid_untyped_inv' ui' and ct_active')
     (invoke_untyped ui) (invokeUntyped ui')"
  apply (rule corres_name_pre)
  apply (clarsimp simp del:invoke_untyped.simps)
  proof -
    fix s s' ao' sz idx sza idxa
    assume cte_wp_at : "cte_wp_at (\<lambda>c. c = cap.UntypedCap (ptr && ~~ mask sz) sz idx) cref (s::det_state)"
     have cte_at: "cte_wp_at (op = (cap.UntypedCap (ptr && ~~ mask sz) sz idx)) cref s" (is "?cte_cond s")
       using cte_wp_at by (simp add:cte_wp_at_caps_of_state)
    assume cte_wp_at': "cte_wp_at' (\<lambda>cte. cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sza idxa) (cte_map cref) s'"
    assume cover     : "range_cover ptr sz (obj_bits_api (APIType_map2 (Inr ao')) us) (length slots)"
    assume vslot     : "slots \<noteq> []"
    assume cap_table : "\<forall>slot\<in>set slots. cte_wp_at (op = cap.NullCap) slot s
                         \<and> ex_cte_cap_wp_to is_cnode_cap slot s \<and> real_cte_at slot s"
    assume desc_range: "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in {ptr..ptr + 2 ^ sz - 1} cref s"
                       "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in' {ptr..ptr + 2 ^ sza - 1} (cte_map cref) (ctes_of s')"
    assume  misc     : "distinct slots" "cte_map cref \<notin> cte_map ` set slots" "cref \<notin> set slots" "distinct (map cte_map slots)"
      " ao' = APIObjectType ArchTypes_H.apiobject_type.CapTableObject \<longrightarrow> 0 < us" "idx \<le> unat (ptr && mask sz) \<or> ptr = ptr && ~~ mask sz"
      " ao' = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> 4 \<le> us"
      " ao' = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> us \<le> 30" "invs s" "invs' s'"  "valid_list s" "valid_sched s"
      " APIType_map2 (Inr ao') \<noteq> ArchObject ASIDPoolObj "
      " \<forall>slot\<in>set slots. ex_cte_cap_wp_to' (\<lambda>_. True) (cte_map slot) s'"
      " \<forall>slot\<in>set slots. cte_wp_at' (\<lambda>c. cteCap c = capability.NullCap) (cte_map slot) s'"
      " \<forall>slot\<in>set slots. cte_wp_at (op = cap.NullCap) slot s \<and> ex_cte_cap_wp_to is_cnode_cap slot s \<and> real_cte_at slot s"
      " ct_active s" "ct_active' s'" "(s, s') \<in> state_relation" "sch_act_simple s'"
    have sz_simp[simp]: "sza = sz \<and> idxa = idx \<and> 2 \<le> sz"
       using misc cte_at cte_wp_at'
       apply -
       apply (clarsimp simp:cte_wp_at_ctes_of)
       apply (drule pspace_relation_cte_wp_atI'[OF state_relation_pspace_relation])
         apply (simp add:cte_wp_at_ctes_of)
        apply (simp add:invs_valid_objs)
       apply (clarsimp simp:is_cap_simps isCap_simps)
       apply (frule cte_map_inj_eq)
        apply ((fastforce simp:cte_wp_at_caps_of_state cte_wp_at_ctes_of)+)[5]
       apply (clarsimp simp:cte_wp_at_caps_of_state cte_wp_at_ctes_of)
       apply (drule caps_of_state_valid_cap,fastforce)
       apply (clarsimp simp:valid_cap_def)
       done

    have obj_bits_low_bound[simp]:
      "4 \<le> obj_bits_api (APIType_map2 (Inr ao')) us"
       using misc
       apply (case_tac ao')
       apply (simp_all add:obj_bits_api_def slot_bits_def arch_kobj_size_def default_arch_object_def
         APIType_map2_def split: ArchTypes_H.apiobject_type.splits)
       done

    have intvl_eq[simp]:
    "ptr && ~~ mask sz = ptr \<Longrightarrow> {ptr + of_nat k |k. k < 2 ^ sz} = {ptr..ptr + 2 ^ sz - 1}"
      using cover
      apply (subgoal_tac "is_aligned (ptr &&~~ mask sz) sz")
       apply (rule intvl_range_conv)
        apply (simp)
       apply (drule range_cover.sz)
       apply simp
      apply (rule is_aligned_neg_mask,simp)
      done

    have delete_objects_rewrite:
      "ptr && ~~ mask sz = ptr \<Longrightarrow> delete_objects ptr sz =
      do y \<leftarrow> modify (clear_um {ptr + of_nat k |k. k < 2 ^ sz});
              modify (detype {ptr && ~~ mask sz..ptr + 2 ^ sz - 1})
      od"
      using cover
      apply (clarsimp simp:delete_objects_def freeMemory_def word_size_def)
      apply (subgoal_tac "is_aligned (ptr &&~~ mask sz) sz")
       apply (subst mapM_storeWord_clear_um)
          apply (simp)
         apply simp
        apply (simp add:range_cover_def word_bits_def)
       apply clarsimp
      apply (rule is_aligned_neg_mask)
      apply simp
      done

    have of_nat_length: "(of_nat (length slots)::word32) - (1::word32) < (of_nat (length slots)::word32)"
       using vslot
       using range_cover.range_cover_le_n_less(1)[OF cover,where p = "length slots"]
       apply -
       apply (case_tac slots)
       apply clarsimp+
       apply (subst add_commute)
       apply (subst word_le_make_less[symmetric])
       apply (rule less_imp_neq)
       apply (simp add:word_bits_def minus_one_norm)
       apply (rule word_of_nat_less)
       apply auto
       done
    have not_0_ptr[simp]: "ptr\<noteq> 0"
      using misc cte_wp_at'
      apply (clarsimp simp:cte_wp_at_ctes_of)
      apply (case_tac cte)
      apply clarsimp
      apply (drule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
      apply (simp add:valid_cap'_def)
      done
    have size_eq[simp]: "APIType_capBits ao' us = obj_bits_api (APIType_map2 (Inr ao')) us"
      apply (case_tac ao')
        apply (case_tac apiobject_type)
        apply (clarsimp simp: APIType_capBits_def objBits_def arch_kobj_size_def default_arch_object_def
          obj_bits_api_def APIType_map2_def objBitsKO_def slot_bits_def pageBitsForSize_def)+
      done

   have subset_stuff[simp]:
       "{ptr..ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us - 1}
       \<subseteq> {ptr..(ptr && ~~ mask sz) + 2 ^ sz - 1}" (is "?retype_range \<subseteq> ?usable_range")
      apply (rule range_cover_subset'[OF cover])
      apply (simp add:vslot)
      done

    have non_detype_idx_le[simp]: "ptr \<noteq>  ptr && ~~ mask sz \<Longrightarrow> idx < 2^sz"
       using misc
       apply clarsimp
       apply (erule le_less_trans)
       apply (rule unat_less_helper)
       apply simp
       apply (rule le_less_trans)
       apply (rule word_and_le1)
       apply (simp add:mask_def)
       apply (rule minus_one_helper)
       apply simp
       using cover
       apply (clarsimp simp:range_cover_def)
       done

    note blah[simp del] = untyped_range.simps usable_untyped_range.simps atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex usableUntypedRange.simps

    have descendants_range[simp]:
      "descendants_range_in ?usable_range cref s"
      "descendants_range_in ?retype_range cref s"
      "descendants_range_in' ?usable_range (cte_map cref) (ctes_of s')"
      "descendants_range_in' ?retype_range (cte_map cref) (ctes_of s')"
      proof -
        have "descendants_range_in ?usable_range cref s"
          using misc cte_at cover cte_wp_at
          apply -
          apply (erule disjE)
           apply (erule cte_wp_at_caps_descendants_range_inI
             [OF _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
           apply simp+
          using desc_range
          apply simp
          done
        thus
          "descendants_range_in ?usable_range cref s"
           by simp
        thus "descendants_range_in ?retype_range cref s"
           by (rule descendants_range_in_subseteq[OF _ subset_stuff])
        have "descendants_range_in' ?usable_range (cte_map cref) (ctes_of s')"
          using misc cte_wp_at' cover
          apply -
          apply (erule disjE)
           apply (erule cte_wp_at_caps_descendants_range_inI'
             [OF _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
           apply simp+
          using desc_range
          apply simp
          done
        thus "descendants_range_in' ?usable_range (cte_map cref) (ctes_of s')"
           by simp
        thus "descendants_range_in' ?retype_range (cte_map cref) (ctes_of s')"
           by (rule descendants_range_in_subseteq'[OF _ subset_stuff])
        qed

    have vc'[simp] : "s' \<turnstile>' capability.UntypedCap (ptr && ~~ mask sz) sz idx"
      using misc cte_wp_at'
      apply (clarsimp simp:cte_wp_at_ctes_of)
      apply (case_tac cte)
      apply clarsimp
      apply (erule ctes_of_valid_cap')
      apply (simp add:invs_valid_objs')
      done

-- "pspace_no_overlap on both side :"
    have ps_no_overlap[simp]: "ptr && ~~ mask sz \<noteq> ptr \<Longrightarrow> pspace_no_overlap ptr sz s"
      using misc cte_wp_at cover
      apply clarsimp
      apply (erule(3) cte_wp_at_pspace_no_overlapI
        [OF _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
      done

    have ps_no_overlap'[simp]: "ptr && ~~ mask sz \<noteq> ptr \<Longrightarrow> pspace_no_overlap' ptr sz s'"
      using misc cte_wp_at' cover
      apply clarsimp
      apply (erule(3) cte_wp_at_pspace_no_overlapI'
        [OF  _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
      done


-- "caps_no_overlap on both side :"
    have caps_no_overlap[simp]: "caps_no_overlap ptr sz s"
      using cte_wp_at misc cover desc_range cte_at
      apply -
      apply (erule disjE)
       apply (erule(3) cte_wp_at_caps_no_overlapI
         [OF _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
      apply clarsimp
      apply (erule descendants_range_caps_no_overlapI)
       apply simp
      apply simp
      done

    have caps_no_overlap'[simp]: "caps_no_overlap'' ptr sz s'"
      using cte_wp_at' misc cover desc_range
      apply -
      apply (erule disjE)
       apply (erule cte_wp_at_caps_no_overlapI'
         [OF  _ _ _ range_cover.sz(1)[where 'a=32, folded word_bits_def]])
        apply simp+
      apply (erule descendants_range_caps_no_overlapI')
       apply simp+
      done

    have ex_cte_no_overlap:
      "\<And>P slot. ex_cte_cap_wp_to P slot s \<Longrightarrow> fst slot \<notin> ?usable_range"
       using cte_at
       apply clarsimp
       apply (drule ex_cte_cap_to_obj_ref_disj,erule disjE)
        using misc
        apply clarsimp
        apply (rule_tac ptr' = "(aa,b)" in untyped_children_in_mdbEE[OF invs_untyped_children])
             apply simp+
         apply (clarsimp simp:untyped_range.simps)
         apply (drule_tac B'="?usable_range" in disjoint_subset2[rotated])
           apply (clarsimp simp:blah word_and_le2)
         apply blast
        apply (clarsimp simp:cte_wp_at_caps_of_state)
        apply (drule(1) descendants_range_inD[OF descendants_range(1)])
        apply (clarsimp simp:cap_range_def)
        apply blast
       apply clarsimp
       apply (drule_tac irq = irq in valid_globals_irq_node[rotated])
        using misc
        apply (clarsimp simp: invs_def valid_state_def )
       apply (clarsimp simp:untyped_range.simps)
       apply (drule_tac B = "{ptr && ~~ mask sz..(ptr && ~~ mask sz) + 2 ^ sz - 1}" in subsetD[rotated])
        apply (clarsimp simp:blah word_and_le2)
       apply simp
       done

    have ex_cte_no_overlap': "\<And>P p. ex_cte_cap_wp_to' P p s' \<Longrightarrow> p \<notin> ?usable_range"
      using cte_wp_at' misc
      apply (clarsimp simp:cte_wp_at_ctes_of)
        apply (drule_tac cte = cte in descendants_range_ex_cte'[OF descendants_range(3)])
        apply (clarsimp simp:blah word_and_le2 isCap_simps)+
      done

    have cref_inv: "fst cref \<notin> ?usable_range" "cte_map cref \<notin> ?usable_range"
      apply (insert misc cte_wp_at cte_wp_at')
       apply (drule if_unsafe_then_capD)
         apply (simp add:invs_def valid_state_def)
        apply simp
       apply (erule ex_cte_no_overlap)
      apply (drule if_unsafe_then_capD')
        apply (simp add:invs'_def valid_state'_def)
       apply simp
      apply (erule ex_cte_no_overlap')
      done

    have slots_invD: "\<And>x. x \<in> set slots
      \<Longrightarrow> fst x \<notin> ?usable_range \<and> caps_of_state s x = Some cap.NullCap
          \<and> ex_cte_cap_wp_to is_cnode_cap x s
          \<and> real_cte_at x s
          \<and> cte_map x \<noteq> cte_map cref
          \<and> cte_map x \<notin> ?usable_range"
      using cte_at misc cte_wp_at'
      apply -
      apply (drule(1) bspec)+
      apply (frule_tac p = cref and p' = x in cte_map_inj_ps[rotated -1,OF invs_valid_pspace])
       apply (clarsimp simp: cte_wp_at_caps_of_state)+
      apply (drule ex_cte_no_overlap)
       apply simp
      apply (drule ex_cte_no_overlap')
       apply simp
      done

    have kernel_window_inv[simp]: "\<forall>x\<in>?usable_range.
      arm_kernel_vspace (arch_state s) x = ArmVSpaceKernelWindow"
      using cte_at misc
      apply (clarsimp simp:cte_wp_at_caps_of_state invs_def valid_state_def)
      apply (erule(1) cap_refs_in_kernel_windowD[THEN bspec])
      apply (simp add:blah cap_range_def)
      apply clarsimp
      apply (erule order_trans[OF word_and_le2])
      done

    have nidx[simp]: "ptr + (of_nat (length slots) * 2^obj_bits_api (APIType_map2 (Inr ao')) us) - (ptr && ~~ mask sz)
      = (ptr && mask sz) + (of_nat (length slots) * 2^obj_bits_api (APIType_map2 (Inr ao')) us)"
       apply (subst word_plus_and_or_coroll2[symmetric,where w = "mask sz" and t = ptr])
       apply simp
       done

    have idx_compare:
      "\<lbrakk>unat ((ptr && mask sz) + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us) < 2^ sz;
        ptr \<noteq> ptr && ~~ mask sz \<rbrakk>
      \<Longrightarrow> (ptr && ~~ mask sz) + of_nat idx
      \<le> ptr + (of_nat (length slots) << obj_bits_api (APIType_map2 (Inr ao')) us)"
       apply (rule range_cover_idx_compare[OF cover ])
         apply assumption+
       apply (frule non_detype_idx_le)
       apply (erule less_imp_le)
       using misc
       apply simp
       done
    have idx_compare'[simp]:"unat ((ptr && mask sz) + (of_nat (length slots)<< obj_bits_api (APIType_map2 (Inr ao')) us)) \<le> 2 ^ sz"
      apply (rule le_trans[OF unat_plus_gt])
      apply (simp add:range_cover.unat_of_nat_n_shift[OF cover] range_cover_unat)
      apply (insert range_cover.range_cover_compare_bound[OF cover])
      apply simp
      done

    have usable_range_subset:
      "ptr && ~~ mask sz \<noteq> ptr
      \<Longrightarrow> usableUntypedRange (capability.UntypedCap (ptr &&~~ mask sz) sz
                       (getFreeIndex (ptr &&~~ mask sz) (ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us)))
                      \<subseteq> usableUntypedRange (capability.UntypedCap (ptr&&~~ mask sz) sz idx)"
      "ptr && ~~ mask sz \<noteq> ptr
      \<Longrightarrow>usable_untyped_range
                     (cap.UntypedCap (ptr && ~~ mask sz) sz
                       (unat (ptr + (of_nat (length slots) << obj_bits_api (APIType_map2 (Inr ao')) us) - (ptr && ~~ mask sz))))
                    \<subseteq> usable_untyped_range (cap.UntypedCap (ptr && ~~ mask sz) sz idx)"
      apply (simp_all add:blah getFreeIndex_def field_simps nidx)
      apply (clarsimp)
       apply (subst add_commute)
       apply (erule order_trans[OF idx_compare])
        apply simp
       apply (subst word_plus_and_or_coroll2[symmetric,where w = "mask sz"])
       apply (simp add:shiftl_t2n field_simps)
      apply (clarsimp simp:shiftl_t2n nidx field_simps)
       apply (subst add_commute)
       apply (erule order_trans[OF idx_compare])
        apply simp
       apply (simp add:shiftl_t2n field_simps)
      done

    have idx_compare''[simp]:
       "unat ((ptr && mask sz) + (of_nat (length slots) * (2::word32) ^ obj_bits_api (APIType_map2 (Inr ao')) us)) < 2 ^ sz
        \<Longrightarrow> ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us - 1
        < ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us"
      apply (rule minus_one_helper,simp)
      apply (rule neq_0_no_wrap)
      apply (rule word32_plus_mono_right_split)
      apply (simp add:shiftl_t2n range_cover_unat[OF cover] field_simps)
      apply (simp add:range_cover.sz[where 'a=32, folded word_bits_def, OF cover])+
      done

    note neg_mask_add_mask = word_plus_and_or_coroll2[symmetric,where w = "mask sz" and t = ptr,symmetric]

    have idx_compare'''[simp]:
      "\<lbrakk>unat (of_nat (length slots) * (2::word32) ^ obj_bits_api (APIType_map2 (Inr ao')) us) < 2 ^ sz;
       ptr && ~~ mask sz = ptr\<rbrakk>
      \<Longrightarrow> ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us - 1
      < ptr + of_nat (length slots) * 2 ^ obj_bits_api (APIType_map2 (Inr ao')) us "
      apply (rule minus_one_helper,simp)
      apply (simp add:is_aligned_neg_mask_eq'[symmetric])
      apply (rule neq_0_no_wrap)
      apply (rule word32_plus_mono_right_split[where sz = sz])
       apply (simp add:is_aligned_mask)+
      apply (simp add:range_cover.sz[where 'a=32, folded word_bits_def, OF cover])+
      done

    have detype_locale:"ptr && ~~ mask sz = ptr \<Longrightarrow> detype_locale (cap.UntypedCap (ptr && ~~ mask sz) sz idx) cref s"
      using cte_at descendants_range misc
      by (simp add:detype_locale_def cte_at descendants_range_def2 blah invs_untyped_children)

    have detype_descendants_range_in:
      "ptr && ~~ mask sz = ptr \<Longrightarrow> descendants_range_in ?usable_range cref
      (detype ?usable_range (clear_um ?usable_range s))"
      using misc cte_at
      apply -
      apply (frule detype_invariants)
          apply (simp add:isCap_simps)
         using descendants_range
         apply (clarsimp simp:blah descendants_range_def2)
         apply ((simp add:isCap_simps invs_untyped_children blah
               invs_valid_reply_caps invs_valid_reply_masters)+)[5]
      apply (subst valid_mdb_descendants_range_in)
       apply (clarsimp dest!: invs_mdb simp: untyped_range.simps)
      apply (frule detype_locale)
      apply (drule detype_locale.non_filter_detype[symmetric])
      using descendants_range(1)
      apply -
      apply (subst (asm) valid_mdb_descendants_range_in)
        apply (clarsimp simp: invs_mdb untyped_range.simps)
      apply (clarsimp simp:descendants_range_in_def untyped_range.simps clear_um_def
        cong:if_cong)
      done

    have maxDomain:"ksCurDomain s' \<le> maxDomain"
      using misc
      by (simp add:invs'_def valid_state'_def)
      
    note set_cap_free_index_invs_spec = set_free_index_invs[where cap = "cap.UntypedCap (ptr && ~~ mask sz) sz idx"
      ,unfolded free_index_update_def free_index_of_def,simplified]

    note msimp[simp add] =  misc getObjectSize_def_eq neg_mask_add_mask
    show " corres op = (op = s) (op = s')
           (invoke_untyped (Invocations_A.untyped_invocation.Retype cref (ptr && ~~ mask sz) ptr (APIType_map2 (Inr ao')) us slots))
           (invokeUntyped (Invocations_H.untyped_invocation.Retype (cte_map cref) (ptr && ~~ mask sz) ptr ao' us (map cte_map slots)))"

  apply (case_tac "ptr && ~~ mask sz \<noteq> ptr")
   using misc
   apply (clarsimp simp:invokeUntyped_def getSlotCap_def bind_assoc)
       apply (case_tac ui')
       apply (clarsimp simp: insertNewCaps_def split_def
                          bind_assoc
               split del: split_if)
       apply (insert cover)
       apply (rule corres_guard_imp)
         apply (rule corres_split[OF _ get_cap_corres])
           apply (rule_tac F = "cap = cap.UntypedCap (ptr && ~~ mask sz) sz idx" in corres_gen_asm)
           apply (rule corres_split[OF _ update_untyped_cap_corres,rotated])
                apply (simp add:isCap_simps)+
              apply (clarsimp simp:getFreeIndex_def bits_of_def shiftL_nat shiftl_t2n)
             prefer 3
             apply (insert range_cover.range_cover_n_less[OF cover] vslot)
             apply (rule createNewObjects_corres_helper)
                  apply simp+
              apply (simp add: insertNewCaps_def)
              apply (rule corres_split_retype_createNewCaps[where sz = sz,OF corres_rel_imp])
                 apply (rule inv_untyped_corres_helper1)
                 apply simp
                apply simp
               apply ((wp retype_region_invs_extras[where sz = sz]
                   retype_region_plain_invs [where sz = sz]
                   retype_region_descendants_range_ret[where sz = sz]
                   retype_region_caps_overlap_reserved_ret[where sz = sz]
                   retype_region_cte_at_other[where sz = sz]
                   retype_region_distinct_sets[where sz = sz]
                 (* retype_region_ranges[where p=cref and sz = sz] *)
                   retype_region_ranges[where ptr=ptr and sz=sz' and
                      ptr_base="ptr && ~~mask sz'", standard, where p=cref and sz' = sz]
                   retype_ret_valid_caps [where sz = sz]
                   retype_region_arch_objs [where sza = sz]
                   hoare_vcg_const_Ball_lift
                   set_tuple_pick distinct_tuple_helper
                   retype_region_obj_at_other3[where sz = sz]
                 | assumption)+)[1]
              apply (wp set_tuple_pick createNewCaps_cte_wp_at'[where sz= sz]
                 hoare_vcg_ex_lift distinct_tuple_helper
                 createNewCaps_parent_helper [where p="cte_map cref" and sz = sz]
                 createNewCaps_valid_pspace_extras [where ptr=ptr and sz = sz]
                 createNewCaps_not_parents[where sz = sz] createNewCaps_distinct[where sz = sz]
                 createNewCaps_ranges'[where sz = sz]
                 hoare_vcg_const_Ball_lift createNewCaps_valid_cap'[where sz = sz]
                 createNewCaps_descendants_range_ret'[where sz = sz]
                 createNewCaps_caps_overlap_reserved_ret'[where sz = sz])
             apply clarsimp
             apply (erule cte_wp_at_weakenE')
             apply (case_tac c,clarsimp simp:isCap_simps)
            apply (clarsimp simp: getObjectSize_def_eq
               getFreeIndex_def is_cap_simps bits_of_def shiftL_nat shiftl_t2n)
            apply (clarsimp simp:conj_ac)
            apply (strengthen impI[OF invs_mdb] impI[OF invs_valid_objs]
              impI[OF invs_valid_pspace] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
            apply (clarsimp simp:conj_ac bits_of_def region_in_kernel_window_def)
            apply (wp set_cap_free_index_invs_spec set_cap_caps_no_overlap set_cap_no_overlap)
            apply (rule hoare_vcg_conj_lift)
             apply (rule hoare_strengthen_post[OF set_cap_sets])
             apply (clarsimp simp:cte_wp_at_caps_of_state)
            apply (wp set_cap_no_overlap hoare_vcg_ball_lift
              set_cap_free_index_invs_spec
              set_cap_cte_wp_at set_cap_descendants_range_in
              set_untyped_cap_caps_overlap_reserved)
           apply (clarsimp simp:conj_ac ball_conj_distrib simp del:capFreeIndex_update.simps)
           apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
               impI[OF invs_valid_pspace'] impI[OF invs_arch_state']
               imp_consequent[where Q = "(\<exists>x. x \<in> cte_map ` set slots)"]
             | clarsimp simp:conj_ac not_0_ptr simp del:capFreeIndex_update.simps)+
           apply (wp updateFreeIndex_invs' updateFreeIndex_caps_overlap_reserved'
             updateFreeIndex_caps_no_overlap'' updateFreeIndex_pspace_no_overlap')
           apply (rule hoare_vcg_conj_lift[OF hoare_vcg_ball_lift])
            apply (simp add:updateCap_def)
            apply (wp setCTE_weak_cte_wp_at getCTE_wp)
           apply (wp updateFreeIndex_caps_overlap_reserved' updateFreeIndex_descendants_range_in' )
           apply (simp add:updateCap_def)
           apply (wp setCTE_weak_cte_wp_at,simp)
           apply (rule hoare_strengthen_post[OF hoare_TrueI[where P = \<top>]])
           apply fastforce
          apply (clarsimp simp:conj_ac ball_conj_distrib and_distrib)
          apply (strengthen impI[OF invs_mdb] impI[OF invs_valid_objs] imp_consequent
                impI[OF invs_valid_pspace] impI[OF invs_arch_state] impI[OF invs_psp_aligned]
                impI[OF invs_distinct])
          apply (clarsimp simp:conj_ac)
          apply (wp get_cap_wp)[1]
         apply (clarsimp simp:conj_ac and_distrib split del:if_splits)
         apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_valid_pspace'] imp_consequent
           impI[OF invs_pspace_distinct'] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
         apply (clarsimp simp:conj_ac not_0_ptr isCap_simps
           shiftL_nat field_simps range_cover.unat_of_nat_shift[OF cover le_refl,simplified])
         apply (wp get_cap_wp)
        using kernel_window_inv cte_at ps_no_overlap caps_no_overlap caps_no_overlap_detype
        apply (clarsimp simp:cte_wp_at_caps_of_state cap_master_cap_def bits_of_def
                             is_cap_simps shiftl_t2n untyped_range.simps valid_sched_etcbs[OF misc(12)])
        apply (intro conjI impI)
             apply clarsimp
             apply (drule slots_invD)
             apply (clarsimp simp: cte_wp_at_caps_of_state ex_cte_cap_wp_to_def)
            apply (clarsimp dest!:slots_invD)
           apply (clarsimp simp:field_simps range_cover_unat[OF cover]
             range_cover.unat_of_nat_shift[OF cover le_refl le_refl])+
          apply (subst add_commute)
          apply (rule range_cover.range_cover_compare_bound[OF cover])
         apply (rule subset_trans[OF subset_stuff])
         apply (clarsimp simp:blah word_and_le2)
        apply (clarsimp simp:usable_untyped_range.simps blah add_assoc[symmetric] add_commute
                        dest!:idx_compare'')
        apply (metis idx_compare'' nat_mult_commute nidx word_arith_nat_mult word_not_le)
       apply (clarsimp simp:invs_pspace_aligned' invs_pspace_distinct' 
         invs_valid_pspace' maxDomain)
       apply (insert cte_wp_at')
       apply (intro conjI impI)
              apply (clarsimp simp:cte_wp_at_ctes_of isCap_simps dest!:usable_range_subset(1))+
            apply (clarsimp simp:getFreeIndex_def field_simps range_cover_unat[OF cover]
              range_cover.unat_of_nat_shift[OF cover le_refl le_refl])+
           apply (subst add_commute)
           apply (rule range_cover.range_cover_compare_bound[OF cover])
          apply (simp add:getFreeIndex_def field_simps)
          apply (rule aligned_add_aligned[OF aligned_after_mask])
            apply (erule range_cover.aligned)
           apply (rule is_aligned_weaken)
            apply (subst mult_commute)
            apply (rule is_aligned_shiftl_self[unfolded shiftl_t2n])
           apply (simp)
          apply (simp add: range_cover_def)
         apply clarsimp+
         apply (drule slots_invD,clarsimp simp:cte_wp_at_ctes_of)
        apply (rule subset_trans[OF subset_stuff])
        apply (clarsimp simp:blah word_and_le2)
       apply simp
       apply (clarsimp simp:usable_untyped_range.simps add_assoc[symmetric] getFreeIndex_def
           blah add_commute dest!:idx_compare'')
       apply simp
      apply (clarsimp simp:invokeUntyped_def getSlotCap_def bind_assoc)
      apply (case_tac ui')
      apply (clarsimp simp: insertNewCaps_def split_def
                            bind_assoc
                 split del: split_if)
      apply (rule corres_guard_imp)
        apply (rule corres_split[OF _ get_cap_corres])
          apply (rule_tac F = "cap = cap.UntypedCap (ptr && ~~ mask sz) sz idx" in corres_gen_asm)
          apply (clarsimp simp:bits_of_def simp del:capFreeIndex_update.simps)
          apply (rule corres_split[OF _ detype_corres])
              apply (rule corres_split[OF _ update_untyped_cap_corres,rotated])
                   apply (simp add:isCap_simps)+
                 apply (clarsimp simp:shiftl_t2n shiftL_nat getFreeIndex_def)
                prefer 3
                apply (insert range_cover.range_cover_n_less[OF cover] vslot)
                apply (rule createNewObjects_corres_helper)
                     apply simp+
                 apply (simp add: insertNewCaps_def)
                 apply (rule corres_split_retype_createNewCaps[where sz = sz,OF corres_rel_imp])
                    apply (rule inv_untyped_corres_helper1)
                    apply simp
                   apply simp
                  apply ((wp retype_region_invs_extras[where sz = sz]
                       retype_region_plain_invs [where sz = sz]
                       retype_region_descendants_range_ret[where sz = sz]
                       retype_region_caps_overlap_reserved_ret[where sz = sz]
                       retype_region_cte_at_other[where sz = sz]
                       retype_region_distinct_sets[where sz = sz]
                       retype_region_ranges[where p=cref and sz = sz]
                       retype_ret_valid_caps [where sz = sz]
                       retype_region_arch_objs [where sza = sz]
                      hoare_vcg_const_Ball_lift
                       set_tuple_pick distinct_tuple_helper
                       retype_region_obj_at_other3[where sz = sz]
                     | assumption)+)[1]
                 apply (wp set_tuple_pick createNewCaps_cte_wp_at'[where sz= sz]
                    hoare_vcg_ex_lift distinct_tuple_helper
                    createNewCaps_parent_helper [where p="cte_map cref"
                       and sz = sz and ptr_base = "ptr && ~~ mask sz"]
                    createNewCaps_valid_pspace_extras [where ptr=ptr and sz = sz]
                    createNewCaps_not_parents[where sz = sz] createNewCaps_distinct[where sz = sz]
                    createNewCaps_ranges'[where sz = sz]
                    hoare_vcg_const_Ball_lift createNewCaps_valid_cap'[where sz = sz]
                    createNewCaps_descendants_range_ret'[where sz = sz]
                    createNewCaps_caps_overlap_reserved_ret'[where sz = sz])
                apply clarsimp
                apply (erule cte_wp_at_weakenE')
                apply (case_tac c,clarsimp simp:cte_wp_at_ctes_of isCap_simps)
               apply (clarsimp simp:
                  getFreeIndex_def is_cap_simps bits_of_def shiftL_nat shiftl_t2n)
               apply (clarsimp simp:conj_ac)
               apply (strengthen impI[OF invs_mdb] impI[OF invs_valid_objs]
                 impI[OF invs_valid_pspace] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
               apply (clarsimp simp:conj_ac bits_of_def region_in_kernel_window_def)
               apply (wp set_cap_caps_no_overlap set_untyped_cap_invs_simple set_cap_no_overlap)
               apply (rule hoare_vcg_conj_lift)
                apply (rule hoare_strengthen_post[OF set_cap_sets])
                apply (clarsimp simp:cte_wp_at_caps_of_state)
               apply (wp set_cap_no_overlap hoare_vcg_ball_lift
                        set_untyped_cap_invs_simple
                        set_cap_cte_wp_at
                        set_cap_descendants_range_in
                        set_untyped_cap_caps_overlap_reserved)
              apply (clarsimp simp:conj_ac ball_conj_distrib simp del:capFreeIndex_update.simps)
              apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
                  impI[OF invs_valid_pspace'] impI[OF invs_arch_state']
                  imp_consequent[where Q = "(\<exists>x. x \<in> cte_map ` set slots)"]
                | clarsimp simp:conj_ac not_0_ptr simp del:capFreeIndex_update.simps)+
              apply (wp updateFreeIndex_invs_simple' updateFreeIndex_caps_overlap_reserved'
                updateFreeIndex_caps_no_overlap'' updateFreeIndex_pspace_no_overlap')
              apply (rule hoare_vcg_conj_lift[OF hoare_vcg_ball_lift])
               apply (simp add:updateCap_def)
               apply (wp setCTE_weak_cte_wp_at getCTE_wp)
              apply (rule hoare_vcg_conj_lift)
               apply (simp add:updateCap_def)
               apply (wp setCTE_weak_cte_wp_at getCTE_wp)
              apply (wp updateFreeIndex_caps_overlap_reserved' updateFreeIndex_descendants_range_in' )
             apply (simp add:is_aligned_neg_mask_eq')
            apply (simp add:sz_simp)
           apply (simp add:delete_objects_rewrite)
           apply wp
          apply (clarsimp simp:conj_ac split del:if_splits)
          apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_valid_pspace'] imp_consequent
             impI[OF invs_pspace_distinct'] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
          apply (clarsimp simp:conj_ac not_0_ptr isCap_simps
            shiftL_nat field_simps range_cover.unat_of_nat_shift[OF cover le_refl,simplified])
          apply (wp deleteObjects_invs'[where idx = idx and p = "cte_map cref"]
                 deleteObjects_caps_no_overlap''[where idx = idx and slot = "cte_map cref"]
                 deleteObject_no_overlap[where idx = idx]
                 deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz]
                 deleteObjects_caps_overlap_reserved'[where idx = idx and slot = "cte_map cref"]
                 deleteObjects_descendants[where idx = idx and p = "cte_map cref"]
                 hoare_vcg_ball_lift hoare_drop_imp hoare_vcg_ex_lift
                 deleteObjects_ct_active'[where sz = sz and ptr = ptr and idx = idx and cref = "cte_map cref"]
                 deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz])[1]
         apply (clarsimp simp:conj_ac ball_conj_distrib)
         apply (strengthen impI[OF invs_mdb] impI[OF invs_valid_objs] imp_consequent
                  impI[OF invs_valid_pspace] impI[OF invs_arch_state] impI[OF invs_psp_aligned]
                  impI[OF invs_distinct] | clarsimp simp:conj_ac)+
         apply (wp get_cap_wp)
       using kernel_window_inv cte_at ps_no_overlap caps_no_overlap
            caps_no_overlap_detype descendants_range
       apply (clarsimp simp:cte_wp_at_caps_of_state cap_master_cap_def descendants_range_def2
         invs_mdb valid_state_def invs_untyped_children bits_of_def is_cap_simps untyped_range.simps)
       apply (frule detype_descendants_range_in)
       apply (subgoal_tac "pspace_no_overlap ptr sz (detype {ptr..ptr + 2 ^ sz - 1} s)")
        prefer 2
        apply (cut_tac misc cte_at)
        apply (erule pspace_no_overlap_detype[OF caps_of_state_valid])
          apply (simp add:invs_psp_aligned invs_valid_objs cte_wp_at_caps_of_state)+
       apply (subgoal_tac "invs (detype {ptr..ptr + 2 ^ sz - 1} (clear_um {ptr..ptr + 2 ^ sz - 1} s))")
        prefer 2
        apply (cut_tac misc cte_at)
        apply (frule detype_invariants)
               apply (simp add:isCap_simps)
              apply (clarsimp simp:blah descendants_range_def2)
             apply ((simp add:isCap_simps invs_untyped_children blah
                    invs_valid_reply_caps invs_valid_reply_masters)+)[6]
       apply (clarsimp simp: detype_clear_um_independent)
       apply (intro conjI impI)
                        apply (insert misc cte_at cref_inv)
                        apply ((clarsimp simp:invs_def valid_state_def)+)[2]
                      apply (erule caps_of_state_valid,simp)
                     apply simp+
                   apply (clarsimp dest!:slots_invD)
                  apply simp
                  apply (rule_tac x = cref in exI,simp)
                 apply simp
                apply (clarsimp dest!:slots_invD)
               apply (clarsimp simp:field_simps
                range_cover.unat_of_nat_shift[OF cover le_refl le_refl])
               apply (subst mult_commute)
               apply (rule nat_le_power_trans)
                apply (rule range_cover.range_cover_n_le(2)[OF cover])
               apply (erule range_cover.sz)
              apply (simp add:caps_no_overlap_detype)
             apply (simp add:range_cover.unat_of_nat_n_shift[OF cover] field_simps)
             apply (rule subset_trans[OF subset_stuff],simp)
            apply (cut_tac kernel_window_inv)
            apply (simp add:detype_def clear_um_def)
           apply (clarsimp simp:blah field_simps dest!:idx_compare''')
           apply (simp)
          apply (simp add:clear_um_def detype_def detype_ext_def)
         apply (erule descendants_range_in_subseteq)
         apply (rule subset_trans[OF subset_stuff],simp)
        apply (simp add: clear_um_def)
        apply (rule valid_etcbs_detype[OF valid_sched_etcbs[OF misc(12)]])
       apply (clarsimp,drule slots_invD,simp)
       apply (clarsimp simp:field_simps range_cover.unat_of_nat_shift[OF cover le_refl le_refl])
       apply (subst mult_commute)
       apply (rule nat_le_power_trans)
        apply (rule range_cover.range_cover_n_le(2)[OF cover])
       apply (erule range_cover.sz)
      apply (clarsimp simp:conj_ac invs_pspace_aligned' invs_pspace_distinct' invs_valid_pspace')
      apply (insert cte_wp_at' vc' descendants_range)
      apply (intro conjI impI)
                  apply (simp add: is_aligned_neg_mask_eq' range_cover.sz
                      [where 'a=32, folded word_bits_def, OF cover])+
                apply (clarsimp simp:cte_wp_at_ctes_of isCap_simps maxDomain)+
             apply (clarsimp simp:descendants_range'_def2)
            apply simp
           apply (simp add:getFreeIndex_def)+
          apply (clarsimp simp:range_cover.unat_of_nat_shift field_simps)
          apply (subst mult_commute)
          apply (rule nat_le_power_trans[OF range_cover.range_cover_n_le(2)[OF cover]])
          apply (rule range_cover.sz(2)[OF cover])
         apply (simp add:getFreeIndex_def)
         apply (rule is_aligned_weaken)
          apply (subst mult_commute)
          apply (rule is_aligned_shiftl_self[unfolded shiftl_t2n])
         apply simp
        apply (rule subset_trans[OF subset_stuff],simp)
       apply (clarsimp simp:cte_wp_at_ctes_of)
       apply (drule slots_invD)
       apply simp
      apply (clarsimp simp:blah getFreeIndex_def dest!:idx_compare''')
      apply simp
  done
qed

lemma inv_untyped_corres:
  "untypinv_relation ui ui' \<Longrightarrow>
   corres (op=)
     (einvs and valid_untyped_inv ui and ct_active)
     (invs' and valid_untyped_inv' ui' and ct_active')
     (invoke_untyped ui) (invokeUntyped ui')"
  by (case_tac ui, erule(1) inv_untyped_corres')

crunch st_tcb_at'[wp]: insertNewCap "st_tcb_at' P t"
  (wp: crunch_wps)

crunch st_tcb_at'[wp]: doMachineOp "st_tcb_at' P t"
  (wp: crunch_wps)


(* FIXME: move *)
lemma deleteObjects_real_cte_at':
  "\<lbrace>\<lambda>s. real_cte_at' p s \<and> p \<notin> {ptr .. ptr + 2 ^ bits - 1}
         \<and> s \<turnstile>' (UntypedCap ptr bits idx) \<and> valid_pspace' s\<rbrace>
     deleteObjects ptr bits
   \<lbrace>\<lambda>_. real_cte_at' p\<rbrace>"
  apply (simp add: deleteObjects_def3 doMachineOp_def split_def)
  apply wp
  apply (clarsimp simp: valid_pspace'_def cong:if_cong)
  apply (subgoal_tac
     "s\<lparr>ksMachineState := b,
        ksPSpace := \<lambda>x. if ptr \<le> x \<and> x \<le> ptr + 2 ^ bits - 1 then None
                        else ksPSpace s x\<rparr> =
      ksMachineState_update (\<lambda>_. b)
      (s\<lparr>ksPSpace := \<lambda>x. if ptr \<le> x \<and> x \<le> ptr + 2 ^ bits - 1 then None
                         else ksPSpace s x\<rparr>)", erule ssubst)
   apply (simp add: obj_at_delete' x_power_minus_1)
  apply (case_tac s, simp)
  done

lemma inv_untyp_st_tcb_at'[wp]:
  "\<lbrace>invs' and st_tcb_at' (P and (op \<noteq> Inactive) and (op \<noteq> IdleThreadState)) tptr
         and valid_untyped_inv' ui and ct_active'\<rbrace>
     invokeUntyped ui
   \<lbrace>\<lambda>rv. st_tcb_at' P tptr\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (cases ui)
  apply (clarsimp)
  apply (rename_tac s cref ptr tp us slots sz idx)
proof -
 fix s cref ptr tp us slots sz idx
    assume cte_wp_at': "cte_wp_at' (\<lambda>cte. cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sz idx) cref s"
    assume cover     : "range_cover ptr sz (APIType_capBits tp us) (length (slots::word32 list))"
    assume  misc     : "distinct slots" "idx \<le> unat (ptr && mask sz) \<or> ptr = ptr && ~~ mask sz"
      "invs' s" "slots \<noteq> []" "sch_act_simple s"
      "\<forall>slot\<in>set slots. cte_wp_at' (\<lambda>c. cteCap c = capability.NullCap) slot s"
      "\<forall>x\<in>set slots. ex_cte_cap_wp_to' (\<lambda>_. True) x s" "ct_active' s"
      "tp = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> 4 \<le> us \<and> us \<le> 30"
    assume desc_range: "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in' {ptr..ptr + 2 ^ sz - 1} (cref) (ctes_of s)"

    assume st_tcb:
      "st_tcb_at' (P and op \<noteq> Structures_H.thread_state.Inactive and op \<noteq> Structures_H.thread_state.IdleThreadState) tptr s"

  have pf: "invokeUntyped_proofs s cref ptr tp us slots sz idx"
    using cte_wp_at' cover misc desc_range
    by (simp add:invokeUntyped_proofs_def)

  have us_align[simp]: "is_aligned ((ptr && mask sz) + of_nat (length slots) * 2 ^ APIType_capBits tp us) 4"
    using misc cover
    apply -
    apply (rule aligned_add_aligned[OF aligned_after_mask])
       apply (rule range_cover.aligned[OF cover])
      apply (subst mult_commute)
      apply (rule is_aligned_weaken)
       apply (rule is_aligned_shiftl_self[unfolded shiftl_t2n])
      apply (case_tac tp,(clarsimp simp:APIType_capBits_def objBits_simps
         split: ArchTypes_H.apiobject_type.splits)+)[1]
     apply (simp add:range_cover_def)
    apply (case_tac tp,(clarsimp simp:APIType_capBits_def objBits_simps
      split: ArchTypes_H.apiobject_type.splits)+)[1]
    done

  note nidx[simp] = add_minus_neg_mask[where ptr = ptr]
  note blah[simp del] = untyped_range.simps usable_untyped_range.simps atLeastAtMost_iff
          atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex usableUntypedRange.simps

  note if_cong[cong del] if_weak_cong[cong]
  show "\<lbrace>op = s\<rbrace> invokeUntyped (Invocations_H.untyped_invocation.Retype cref (ptr && ~~ mask sz) ptr tp us slots)
          \<lbrace>\<lambda>rv. st_tcb_at' P tptr\<rbrace>"
    using misc cover cte_wp_at' invokeUntyped_proofs.not_0_ptr[OF pf]
          invokeUntyped_proofs.caps_no_overlap'[OF pf]
          invokeUntyped_proofs.descendants_range[OF pf]
          invokeUntyped_proofs.idx_compare'[OF pf]
    
  apply (simp add:invokeUntyped_def)
  apply (case_tac "\<not> ptr && ~~ mask sz = ptr")
   apply (frule invokeUntyped_proofs.ps_no_overlap'[OF pf])
   apply (rule hoare_pre)
    apply wp
       apply (rule createNewObjects_wp_helper)
           apply simp+
       apply (simp add: insertNewCaps_def split_def bind_assoc zipWithM_x_mapM
             cong: capability.case_cong)
       apply (wp mapM_wp' createNewCaps_st_tcb_at'
        deleteObjects_st_tcb_at' createNewObjects_wp_helper
        updateFreeIndex_pspace_no_overlap'[where sz = sz] | wpc)+
      apply (rule hoare_vcg_conj_lift)
       apply (simp add:updateCap_def)
       apply (wp setCTE_weak_cte_wp_at getCTE_wp)
      apply (wp hoare_vcg_const_Ball_lift)
       apply (simp add:updateCap_def)
       apply (wp setCTE_weak_cte_wp_at getCTE_wp)
      apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
          impI[OF invs_valid_pspace'] impI[OF invs_arch_state'])
      apply (clarsimp simp:conj_ac)
      apply (wp updateFreeIndex_invs' updateFreeIndex_caps_overlap_reserved'
         updateFreeIndex_caps_no_overlap''[where sz = sz]
         updateFreeIndex_pspace_no_overlap'[where sz = sz]
         hoare_vcg_const_Ball_lift)
     apply simp
    apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
           impI[OF invs_valid_pspace'])
    apply (clarsimp simp:conj_ac isCap_simps getFreeIndex_def split del:if_splits)
    apply (wp getSlotCap_wp)
   apply (clarsimp simp:invs_pspace_aligned' invs_pspace_distinct' invs_valid_pspace'
       cte_wp_at_ctes_of conj_ac field_simps shiftl_t2n shiftL_nat invs_ksCurDomain_maxDomain')
   apply (intro conjI)
       apply (rule st_tcb'_weakenE[OF st_tcb])
       apply simp
      apply (clarsimp dest!:invokeUntyped_proofs.slots_invD[OF pf])
     apply (simp add:range_cover_unat[OF cover]
         range_cover.unat_of_nat_shift field_simps)
    apply (rule subset_trans[OF invokeUntyped_proofs.subset_stuff[OF pf]])
    apply (clarsimp simp:blah word_and_le2)
   apply (rule invokeUntyped_proofs.usableRange_disjoint[OF pf])
  apply (rule hoare_pre)
   apply wp
      apply (rule createNewObjects_wp_helper)
          apply simp+
      apply (simp add: insertNewCaps_def split_def bind_assoc zipWithM_x_mapM
             cong: capability.case_cong)
      apply (wp mapM_wp' createNewCaps_st_tcb_at'
        deleteObjects_st_tcb_at' createNewObjects_wp_helper
        updateFreeIndex_pspace_no_overlap'[where sz = sz] | wpc)+
     apply (rule hoare_vcg_conj_lift)
      apply (simp add:updateCap_def)
      apply (wp setCTE_weak_cte_wp_at getCTE_wp)
     apply (wp hoare_vcg_const_Ball_lift)
      apply (simp add:updateCap_def)
      apply (wp setCTE_weak_cte_wp_at getCTE_wp)
     apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
         impI[OF invs_valid_pspace'] impI[OF invs_arch_state'])
     apply (clarsimp simp:conj_ac)
     apply (wp updateFreeIndex_invs_simple'  updateFreeIndex_caps_overlap_reserved'
         updateFreeIndex_caps_no_overlap''[where sz = sz]
         updateFreeIndex_pspace_no_overlap'[where sz = sz]
         hoare_vcg_const_Ball_lift)
    apply (clarsimp simp:conj_ac split del:if_splits)
    apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_valid_pspace'] imp_consequent
          impI[OF invs_pspace_distinct'] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
    apply (clarsimp simp:conj_ac isCap_simps
         shiftL_nat field_simps range_cover.unat_of_nat_shift[OF cover le_refl,simplified])
    apply (rule_tac P = "cap = capability.UntypedCap (ptr && ~~ mask sz) sz idx"
       in hoare_gen_asm)
    apply (clarsimp simp: conj_ac)
    apply (wp deleteObjects_invs'[where idx = idx and p = "cref"]
              deleteObjects_caps_no_overlap''[where idx = idx and slot = "cref"]
              deleteObject_no_overlap[where idx = idx]
              deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_caps_overlap_reserved'[where idx = idx and slot = "cref"]
              deleteObjects_descendants[where idx = idx and p = "cref"]
              hoare_vcg_ball_lift hoare_drop_imp hoare_vcg_ex_lift
              deleteObjects_st_tcb_at'[where p = cref]
              deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_real_cte_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_ct_active'[where cref=cref and idx=idx])
  apply (clarsimp simp:conj_ac ball_conj_distrib descendants_range'_def2 is_aligned_neg_mask_eq)
  apply (strengthen impI[OF invs_mdb'] impI[OF invs_valid_objs'] imp_consequent
                impI[OF invs_valid_pspace'] impI[OF invs_arch_state'] impI[OF invs_pspace_aligned']
                impI[OF invs_pspace_distinct'])
  apply (wp getSlotCap_wp)
  apply (rule_tac x = "capability.UntypedCap ptr sz idx" in exI)
  apply (clarsimp simp:invs_pspace_aligned' invs_pspace_distinct' invs_valid_pspace'
       cte_wp_at_ctes_of conj_ac field_simps shiftl_t2n shiftL_nat invs_ksCurDomain_maxDomain')
  apply (rule conjI)
   apply (erule range_cover.sz(1)[where 'a=32, folded word_bits_def])
   using invokeUntyped_proofs.usableRange_disjoint[OF pf]
         invokeUntyped_proofs.vc'[OF pf]
         invokeUntyped_proofs.cref_inv[OF pf]
         invokeUntyped_proofs.subset_stuff[OF pf]
         us_align
   apply (simp add: is_aligned_neg_mask_eq'[symmetric] st_tcb
     is_aligned_neg_mask_eq is_aligned_mask getFreeIndex_def)
   apply (rule conjI)
   apply (clarsimp dest!:invokeUntyped_proofs.slots_invD[OF pf]
       simp:is_aligned_mask[symmetric] is_aligned_neg_mask_eq)+
   done
qed

lemma inv_untyp_tcb'[wp]:
  "\<lbrace>invs' and st_tcb_at' active' tptr
         and valid_untyped_inv' ui and ct_active'\<rbrace>
     invokeUntyped ui
   \<lbrace>\<lambda>rv. tcb_at' tptr\<rbrace>"
  apply (rule hoare_chain [OF inv_untyp_st_tcb_at'[where tptr=tptr and P="\<top>"]])
   apply (clarsimp elim!: st_tcb'_weakenE)
   apply fastforce
  apply (clarsimp simp: st_tcb_at'_def)
  done

crunch irq_node[wp]: set_thread_state "\<lambda>s. P (interrupt_irq_node s)"
crunch ctes_of [wp]: setQueue "\<lambda>s. P (ctes_of s)"
crunch cte_wp_at [wp]: setQueue "cte_wp_at' P p"
  (simp: cte_wp_at_ctes_of)

lemma sts_valid_untyped_inv':
  "\<lbrace>valid_untyped_inv' ui\<rbrace> setThreadState st t \<lbrace>\<lambda>rv. valid_untyped_inv' ui\<rbrace>"
  apply (cases ui, simp add: ex_cte_cap_to'_def)
  apply (rule hoare_pre)
   apply (rule hoare_use_eq_irq_node' [OF setThreadState_ksInterruptState])
   apply (wp hoare_vcg_const_Ball_lift hoare_vcg_ex_lift | simp)+
  done

crunch nosch[wp]: insertNewCaps "\<lambda>s. P (ksSchedulerAction s)"
  (simp: crunch_simps zipWithM_x_mapM wp: crunch_wps)

crunch nosch[wp]: createNewObjects "\<lambda>s. P (ksSchedulerAction s)"
  (simp: crunch_simps zipWithM_x_mapM wp: crunch_wps hoare_unless_wp)

lemma invokeUntyped_nosch[wp]:
  "\<lbrace>\<lambda>s. P (ksSchedulerAction s)\<rbrace>
     invokeUntyped invok
   \<lbrace>\<lambda>rv s. P (ksSchedulerAction s)\<rbrace>"
  apply (cases invok, simp add: invokeUntyped_def)
  apply (wp deleteObjects_nosch zipWithM_x_inv)
  apply clarsimp
  done

crunch no_0_obj'[wp]: insertNewCap no_0_obj'
  (wp: crunch_wps)

lemma insertNewCap_valid_pspace':
  "\<lbrace>\<lambda>s. valid_pspace' s \<and> s \<turnstile>' cap
          \<and> slot \<noteq> parent \<and> caps_overlap_reserved' (untypedRange cap) s
          \<and> cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                              sameRegionAs (cteCap cte) cap) parent s
          \<and> \<not> isZombie cap \<and> descendants_range' cap parent (ctes_of s)\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv. valid_pspace'\<rbrace>"
  apply (simp add: valid_pspace'_def)
  apply (wp insertNewCap_valid_mdb)
     apply simp_all
  done

crunch tcb'[wp]: insertNewCap "tcb_at' t"
  (wp: crunch_wps)
crunch inQ[wp]: insertNewCap "obj_at' (inQ d p) t"
  (wp: crunch_wps)
crunch norq[wp]: insertNewCap "\<lambda>s. P (ksReadyQueues s)"
  (wp: crunch_wps)
crunch ct[wp]: insertNewCap "\<lambda>s. P (ksCurThread s)"
  (wp: crunch_wps)
crunch state_refs_of'[wp]: insertNewCap "\<lambda>s. P (state_refs_of' s)"
  (wp: crunch_wps)

lemma insertNewCap_ifunsafe'[wp]:
  "\<lbrace>if_unsafe_then_cap' and ex_cte_cap_to' slot\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv s. if_unsafe_then_cap' s\<rbrace>"
  apply (simp add: ifunsafe'_def3 insertNewCap_def)
  apply (wp getCTE_wp')
  apply (clarsimp simp: ex_cte_cap_to'_def cte_wp_at_ctes_of cteCaps_of_def)
  apply (drule_tac x=crefa in spec)
  apply (rule conjI)
   apply clarsimp
   apply (rule_tac x=cref in exI, fastforce)
  apply clarsimp
  apply (rule_tac x=cref' in exI, fastforce)
  done

lemma insertNewCap_iflive'[wp]:
  "\<lbrace>if_live_then_nonz_cap'\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv. if_live_then_nonz_cap'\<rbrace>"
  apply (simp add: insertNewCap_def)
  apply (wp setCTE_iflive' getCTE_wp')
  apply (clarsimp elim!: cte_wp_at_weakenE')
  done

lemma insertNewCap_cte_wp_at'':
  "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) p and K (\<not> P NullCap)\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv s. cte_wp_at' (P \<circ> cteCap) p s\<rbrace>"
  apply (simp add: insertNewCap_def tree_cte_cteCap_eq)
  apply (wp getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def)
  done

lemmas insertNewCap_cte_wp_at' = insertNewCap_cte_wp_at''[unfolded o_def]

crunch irq_node'[wp]: insertNewCap "\<lambda>s. P (irq_node' s)"
  (wp: crunch_wps)

lemma insertNewCap_cap_to'[wp]:
  "\<lbrace>ex_cte_cap_to' p\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv. ex_cte_cap_to' p\<rbrace>"
  apply (simp add: ex_cte_cap_to'_def)
  apply (rule hoare_pre)
   apply (rule hoare_use_eq_irq_node'[OF insertNewCap_irq_node'])
   apply (wp hoare_vcg_ex_lift insertNewCap_cte_wp_at')
  apply clarsimp
  done

lemma insertNewCap_nullcap:
  "\<lbrace>P and cte_wp_at' (\<lambda>cte. cteCap cte = NullCap) slot\<rbrace> insertNewCap parent slot cap \<lbrace>Q\<rbrace>
    \<Longrightarrow> \<lbrace>P\<rbrace> insertNewCap parent slot cap \<lbrace>Q\<rbrace>"
  apply (clarsimp simp: valid_def)
  apply (subgoal_tac "cte_wp_at' (\<lambda>cte. cteCap cte = NullCap) slot s")
   apply fastforce
  apply (clarsimp simp: insertNewCap_def in_monad cte_wp_at_ctes_of liftM_def
                 dest!: use_valid [OF _ getCTE_sp[where P="op = s",standard], OF _ refl])
  done

crunch idle'[wp]: getCTE "valid_idle'"

lemma insertNewCap_idle'[wp]:
  "\<lbrace>valid_idle' and (\<lambda>s. ksIdleThread s \<notin> capRange cap)\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv. valid_idle'\<rbrace>"
  apply (simp add: insertNewCap_def)
  apply (wp getCTE_no_idle_cap
          | simp add: o_def
          | rule hoare_drop_imp)+
  done

crunch global_refs': insertNewCap "\<lambda>s. P (global_refs' s)"
  (wp: crunch_wps simp: crunch_simps)

lemma insertNewCap_valid_global_refs':
  "\<lbrace>valid_global_refs' and
        cte_wp_at' (\<lambda>cte. capRange cap \<subseteq> capRange (cteCap cte)) parent\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv. valid_global_refs'\<rbrace>"
  apply (simp add: valid_global_refs'_def valid_refs'_cteCaps)
  apply (rule hoare_pre)
   apply (rule hoare_use_eq [where f=global_refs', OF insertNewCap_global_refs'])
   apply wp
  apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def)
  apply (clarsimp elim!: ranE split: split_if_asm)
   apply fastforce
  apply fastforce
  done


lemma insertNewCap_valid_irq_handlers:
  "\<lbrace>valid_irq_handlers' and (\<lambda>s. \<forall>irq. cap = IRQHandlerCap irq \<longrightarrow> irq_issued' irq s)\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv. valid_irq_handlers'\<rbrace>"
  apply (simp add: insertNewCap_def valid_irq_handlers'_def irq_issued'_def)
  apply wp
     apply (simp add: cteCaps_of_def)
     apply (wp hoare_use_eq[where f=ksInterruptState, OF setCTE_ksInterruptState setCTE_ctes_of_wp]
               getCTE_wp)
  apply (clarsimp simp: cteCaps_of_def cte_wp_at_ctes_of ran_def)
  apply auto
  done

crunch irq_states' [wp]: insertNewCap valid_irq_states'
  (wp: getCTE_wp')

crunch pde_mappings' [wp]: insertNewCap valid_pde_mappings'
  (wp: getCTE_wp')

crunch vq'[wp]: insertNewCap valid_queues'
  (wp: crunch_wps)

crunch irqs_masked' [wp]: insertNewCap irqs_masked'
  (wp: crunch_wps lift: irqs_masked_lift)

crunch valid_machine_state'[wp]: insertNewCap valid_machine_state'
  (wp: crunch_wps)

crunch pspace_domain_valid[wp]: insertNewCap pspace_domain_valid
  (wp: crunch_wps)

crunch ct_not_inQ[wp]: insertNewCap "ct_not_inQ"
  (wp: crunch_wps)

crunch ksCurDomain[wp]: insertNewCap "\<lambda>s. P (ksCurDomain s)"
  (wp: crunch_wps)
crunch ksCurThread[wp]: insertNewCap "\<lambda>s. P (ksCurThread s)"
  (wp: crunch_wps)

crunch tcbState_inv[wp]: insertNewCap "obj_at' (\<lambda>tcb. P (tcbState tcb)) t"
  (wp: crunch_simps hoare_drop_imps)
crunch tcbDomain_inv[wp]: insertNewCap "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t"
  (wp: crunch_simps hoare_drop_imps)
crunch tcbPriority_inv[wp]: insertNewCap "obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t"
  (wp: crunch_simps hoare_drop_imps)
crunch ksIdleThread[wp]: insertNewCap "\<lambda>s. P (ksIdleThread s)"
  (wp: crunch_simps hoare_drop_imps)
crunch ksDomSchedule[wp]: insertNewCap "\<lambda>s. P (ksDomSchedule s)"
  (wp: crunch_simps hoare_drop_imps)
crunch ksInterrupt[wp]: insertNewCap "\<lambda>s. P (ksInterruptState s)"
  (wp: crunch_wps)

lemma insertNewCap_ct_idle_or_in_cur_domain'[wp]:
  "\<lbrace>ct_idle_or_in_cur_domain' and ct_active'\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain'\<rbrace>"
apply (wp ct_idle_or_in_cur_domain'_lift_futz[where Q=\<top>])
apply (rule_tac Q="\<lambda>_. obj_at' (\<lambda>tcb. tcbState tcb \<noteq> Structures_H.thread_state.Inactive) t and obj_at' (\<lambda>tcb. d = tcbDomain tcb) t"
             in hoare_strengthen_post)
apply (wp | clarsimp elim: obj_at'_weakenE)+
apply (auto simp: obj_at'_def)
done

lemma insertNewCap_ct_active'[wp]:
  "\<lbrace>ct_active'\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>_. ct_active'\<rbrace>"
apply (simp add: ct_in_state'_def)
apply (rule hoare_pre)
apply (wps insertNewCap_ksCurThread)
apply (wp insertNewCap_st_tcb_at')
apply simp
done

crunch ksDomScheduleIdx[wp]: insertNewCap "\<lambda>s. P (ksDomScheduleIdx s)"
  (wp: crunch_simps hoare_drop_imps)

lemma insertNewCap_invs':
  "\<lbrace>invs' and ct_active'
          and valid_cap' cap
          and cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                              sameRegionAs (cteCap cte) cap) parent
          and K (\<not> isZombie cap) and (\<lambda>s. descendants_range' cap parent (ctes_of s))
          and caps_overlap_reserved' (untypedRange cap)
          and ex_cte_cap_to' slot
          and (\<lambda>s. ksIdleThread s \<notin> capRange cap)
          and (\<lambda>s. \<forall>irq. cap = IRQHandlerCap irq \<longrightarrow> irq_issued' irq s)\<rbrace>
     insertNewCap parent slot cap
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (rule insertNewCap_nullcap)
  apply (simp add: invs'_def valid_state'_def)
  apply (rule hoare_pre)
   apply (wp insertNewCap_valid_pspace' sch_act_wf_lift
             valid_queues_lift cur_tcb_lift tcb_in_cur_domain'_lift
             insertNewCap_valid_global_refs'
             valid_arch_state_lift'
             valid_irq_node_lift insertNewCap_valid_irq_handlers)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (rule conjI, clarsimp)
  apply (auto simp: isCap_simps sameRegionAs_def3)
  done

lemma insertNewCap_irq_issued'[wp]:
  "\<lbrace>\<lambda>s. P (irq_issued' irq s)\<rbrace> insertNewCap parent slot cap \<lbrace>\<lambda>rv s. P (irq_issued' irq s)\<rbrace>"
  by (simp add: irq_issued'_def, wp)

lemma zipWithM_x_insertNewCap_invs'':
  "\<lbrace>\<lambda>s. invs' s \<and> ct_active' s \<and> (\<forall>tup \<in> set ls. s \<turnstile>' snd tup)
        \<and> cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                            (\<forall>tup \<in> set ls. sameRegionAs (cteCap cte) (snd tup))) parent s
        \<and> (\<forall>tup \<in> set ls. \<not> isZombie (snd tup))
        \<and> (\<forall>tup \<in> set ls. ex_cte_cap_to' (fst tup) s)
        \<and> (\<forall>tup \<in> set ls. descendants_range' (snd tup) parent (ctes_of s))
        \<and> (\<forall>tup \<in> set ls. ksIdleThread s \<notin> capRange (snd tup))
        \<and> (\<forall>tup \<in> set ls. caps_overlap_reserved' (capRange (snd tup)) s)
        \<and> distinct_sets (map capRange (map snd ls))
        \<and> (\<forall>irq. IRQHandlerCap irq \<in> set (map snd ls) \<longrightarrow> irq_issued' irq s)
        \<and> distinct (map fst ls)\<rbrace>
    mapM (\<lambda>(x, y). insertNewCap parent x y) ls
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (induct ls)
   apply (simp add: mapM_def sequence_def)
   apply (wp, simp)
  apply (simp add: mapM_Cons)
  apply wp
   apply assumption
  apply (thin_tac "valid ?P ?f ?Q")
  apply clarsimp
  apply (rule hoare_pre)
   apply (wp insertNewCap_invs'
             hoare_vcg_const_Ball_lift
             insertNewCap_cte_wp_at' insertNewCap_ranges
             hoare_vcg_all_lift)
  apply (clarsimp simp: cte_wp_at_ctes_of invs_mdb' invs_valid_objs' dest!:valid_capAligned)
  apply (drule caps_overlap_reserved'_subseteq[OF _ untypedRange_in_capRange])
  apply (auto simp:comp_def)
  done

lemma zipWithM_x_insertNewCap_invs':
  "\<lbrace>\<lambda>s. invs' s \<and> ct_active' s \<and> (\<forall>cap \<in> set cps. s \<turnstile>' cap)
        \<and> cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte) \<and>
                            (\<forall>tup \<in> set (zip slots cps). sameRegionAs (cteCap cte) (snd tup))) parent s
        \<and> (\<forall>cap \<in> set cps. \<not> isZombie cap)
        \<and> (\<forall>slot \<in> set slots. ex_cte_cap_to' slot s)
        \<and> (\<forall>cap \<in> set cps. ksIdleThread s \<notin> capRange cap)
        \<and> (\<forall>tup \<in> set (zip slots cps). caps_overlap_reserved' (capRange (snd tup)) s)
        \<and> (\<forall>irq. IRQHandlerCap irq \<in> set cps \<longrightarrow> irq_issued' irq s)
        \<and> distinct slots
        \<and> descendants_of' parent (ctes_of s) = {}
        \<and> distinct_sets (map capRange cps)\<rbrace>
     zipWithM_x (insertNewCap parent) slots cps
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (rule hoare_pre)
   apply (simp add:zipWithM_x_mapM)
   apply wp
   apply (rule zipWithM_x_insertNewCap_invs'')
  apply (clarsimp simp: descendants_range'_def cte_wp_at_ctes_of
                        distinct_prefix [OF _ map_fst_zip_prefix]
                        distinct_sets_prop
                  simp del: map_map)
  apply (auto simp: map_snd_zip_prefix [unfolded less_eq_list_def]
              dest!: set_zip_helper
              elim!: distinct_prop_prefixE
              intro!: map_prefixeqI
              simp del: map_map)
  done

lemma createNewCaps_not_isZombie[wp]:
  "\<lbrace>\<top>\<rbrace> createNewCaps ty ptr bits sz \<lbrace>\<lambda>rv s. (\<forall>cap \<in> set rv. \<not> isZombie cap)\<rbrace>"
  apply (simp add: createNewCaps_def toAPIType_def ArchTypes_H.toAPIType_def
                   createNewCaps_def
              split del: split_if cong: option.case_cong if_cong
                                        ArchTypes_H.apiobject_type.case_cong
                                        ArchTypes_H.object_type.case_cong)
  apply (rule hoare_pre)
   apply (wp undefined_valid | wpc
            | simp add: isCap_simps)+
  apply auto?
  done

lemma createNewCaps_cap_to':
  "\<lbrace>\<lambda>s. ex_cte_cap_to' p s \<and> 0 < n
      \<and> range_cover ptr sz (APIType_capBits ty us) n
      \<and> pspace_aligned' s \<and> pspace_distinct' s
      \<and> pspace_no_overlap' ptr sz s\<rbrace>
     createNewCaps ty ptr n us
   \<lbrace>\<lambda>rv. ex_cte_cap_to' p\<rbrace>"
  apply (simp add: ex_cte_cap_to'_def)
  apply (wp hoare_vcg_ex_lift
            hoare_use_eq_irq_node' [OF createNewCaps_ksInterrupt
                                       createNewCaps_cte_wp_at'])
  apply fastforce
  done

lemma storePDE_it[wp]:
  "\<lbrace>\<lambda>s. P (ksIdleThread s)\<rbrace> storePDE ptr val \<lbrace>\<lambda>rv s. P (ksIdleThread s)\<rbrace>"
  by (simp add: storePDE_def | wp updateObject_default_inv)+

crunch it[wp]: copyGlobalMappings "\<lambda>s. P (ksIdleThread s)"
  (wp: mapM_x_wp' ignore: clearMemory forM_x getObject)

crunch it[wp]: createWordObjects "\<lambda>s. P (ksIdleThread s)"
  (wp: mapM_x_wp' ignore: clearMemory forM_x getObject)

lemma createNewCaps_idlethread[wp]:
  "\<lbrace>\<lambda>s. P (ksIdleThread s)\<rbrace> createNewCaps tp ptr sz us \<lbrace>\<lambda>rv s. P (ksIdleThread s)\<rbrace>"
  apply (simp add: createNewCaps_def toAPIType_def ArchTypes_H.toAPIType_def
                   createNewCaps_def
            split: ArchTypes_H.object_type.split
                   ArchTypes_H.apiobject_type.split)
  apply safe
          apply (wp mapM_x_wp' | simp)+
  done

lemma createNewCaps_idlethread_ranges[wp]:
  "\<lbrace>\<lambda>s. 0 < n \<and> range_cover ptr sz (APIType_capBits tp us) n
           \<and> ksIdleThread s \<notin> {ptr .. (ptr && ~~ mask sz) + 2 ^ sz - 1}\<rbrace>
     createNewCaps tp ptr n us
   \<lbrace>\<lambda>rv s. \<forall>cap\<in>set rv. ksIdleThread s \<notin> capRange cap\<rbrace>"
  apply (rule hoare_as_subst [OF createNewCaps_idlethread])
  apply (rule hoare_assume_pre)
  apply (rule hoare_chain, rule createNewCaps_range_helper2)
   apply fastforce
  apply blast
  done

lemma createNewCaps_IRQHandler[wp]:
  "\<lbrace>\<top>\<rbrace>
     createNewCaps tp ptr sz us
   \<lbrace>\<lambda>rv s. IRQHandlerCap irq \<in> set rv \<longrightarrow> P rv s\<rbrace>"
  apply (simp add: createNewCaps_def split del: split_if)
  apply (rule hoare_pre)
   apply (wp | wpc | simp add: image_def | rule hoare_pre_cont)+
  done

crunch ksIdleThread[wp]: updateCap "\<lambda>s. P (ksIdleThread s)"

lemma size_eq: "APIType_capBits ao' us = obj_bits_api (APIType_map2 (Inr ao')) us"
    apply (case_tac ao')
      apply (case_tac apiobject_type)
      apply (clarsimp simp: APIType_capBits_def objBits_def arch_kobj_size_def default_arch_object_def
        obj_bits_api_def APIType_map2_def objBitsKO_def slot_bits_def pageBitsForSize_def)+
    done

lemma obj_at_in_obj_range':
  "\<lbrakk>ksPSpace s p = Some ko; pspace_aligned' s\<rbrakk>
   \<Longrightarrow> p \<in> {p.. p + 2 ^ objBitsKO ko - 1}"
  apply (drule(1) pspace_alignedD')
  apply (clarsimp)
  apply (erule is_aligned_no_overflow)
  done

lemma updateCap_weak_cte_wp_at:
  "\<lbrace>\<lambda>s. if p = ptr then P (cteCap (cteCap_update (\<lambda>_. cap) cte))
        else cte_wp_at' (\<lambda>c. P (cteCap c)) p s\<rbrace>
   updateCap ptr cap
   \<lbrace>\<lambda>uu. cte_wp_at' (\<lambda>c. P (cteCap c)) p\<rbrace>"
   apply (simp add:updateCap_def)
   apply (wp setCTE_weak_cte_wp_at getCTE_wp)
   apply (clarsimp simp:cte_wp_at'_def)
   done

lemma createNewCaps_ct_active':
  "\<lbrace>ct_active' and pspace_aligned' and pspace_distinct' and pspace_no_overlap' ptr sz and K (range_cover ptr sz (APIType_capBits ty us) n \<and> 0 < n)\<rbrace>
    createNewCaps ty ptr n us
   \<lbrace>\<lambda>_. ct_active'\<rbrace>"
apply (simp add: ct_in_state'_def)
apply (rule hoare_pre)
apply wps
apply (wp createNewCaps_st_tcb_at'[where sz=sz])
apply simp
done

lemma invokeUntyped_invs'':
   "ui = Retype cref ptr_base ptr tp us slots \<Longrightarrow>
   \<lbrace>invs' and valid_untyped_inv' ui and ct_active'\<rbrace>
     invokeUntyped ui
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (cases ui, simp)
  apply (rule hoare_name_pre_state)
  apply (clarsimp simp del: split_paired_All split_paired_Ex split_paired_Ball invokeUntyped_def)
  apply (rename_tac s sz idx)
  proof -
    fix s sz idx
    assume cte_wp_at': "cte_wp_at' (\<lambda>cte. cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sz idx) cref s"
    assume cover     : "range_cover ptr sz (APIType_capBits tp us) (length slots)"
    assume vslot     : "slots \<noteq> []"
    assume desc_range: "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in' {ptr..ptr + 2 ^ sz - 1} (cref) (ctes_of s)"
    assume misc      : "distinct slots" "cref \<notin> set slots" "ct_active' s"
      "tp = APIObjectType ArchTypes_H.apiobject_type.CapTableObject \<longrightarrow> 0 < us"
      "tp = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> 4 \<le> us \<and> us \<le> 30"
      "idx \<le> unat (ptr && mask sz) \<or> ptr = ptr && ~~ mask sz"
      "invs' s"
      "\<forall>slot\<in>set slots. ex_cte_cap_wp_to' (\<lambda>_. True) slot s"
      "\<forall>slot\<in>set slots. cte_wp_at' (\<lambda>c. cteCap c = capability.NullCap) slot s"
      "ct_active' s" "sch_act_simple s"
    have pf: "invokeUntyped_proofs s cref ptr tp us slots sz idx"
       using cte_wp_at' cover vslot desc_range misc
       by (simp add:invokeUntyped_proofs_def)
    have of_nat_length: "(of_nat (length slots)::word32) - (1::word32) < (of_nat (length slots)::word32)"
       using vslot
       using range_cover.range_cover_le_n_less(1)[OF cover,where p = "length slots"]
       apply -
       apply (case_tac slots)
        apply clarsimp+
       apply (subst add_commute)
       apply (subst word_le_make_less[symmetric])
       apply (rule less_imp_neq)
       apply (simp add:word_bits_def minus_one_norm)
       apply (rule word_of_nat_less)
       apply auto
       done

    have us_align[simp]:"is_aligned ((ptr && mask sz) + 2 ^ APIType_capBits tp us * of_nat (length slots)) 4"
    using misc cover
    apply -
    apply (rule aligned_add_aligned[OF aligned_after_mask])
       apply (rule range_cover.aligned[OF cover])
      apply (rule is_aligned_weaken)
       apply (rule is_aligned_shiftl_self[unfolded shiftl_t2n])
      apply (case_tac tp,(clarsimp simp:APIType_capBits_def objBits_simps
         split: ArchTypes_H.apiobject_type.splits)+)[1]
     apply (simp add:range_cover_def)
    apply (case_tac tp,(clarsimp simp:APIType_capBits_def objBits_simps
      split: ArchTypes_H.apiobject_type.splits)+)[1]
    done

    note not_0_ptr[simp] = invokeUntyped_proofs.not_0_ptr [OF pf]
    note subset_stuff[simp] = invokeUntyped_proofs.subset_stuff[OF pf]

    have non_detype_idx_le[simp]: "ptr \<noteq>  ptr && ~~ mask sz \<Longrightarrow> idx < 2^sz"
       using misc
       apply clarsimp
       apply (erule le_less_trans)
       apply (rule unat_less_helper)
       apply simp
       apply (rule le_less_trans)
       apply (rule word_and_le1)
       apply (simp add:mask_def)
       apply (rule minus_one_helper)
       apply simp
       using cover
       apply (clarsimp simp:range_cover_def)
       done

    note blah[simp del] = untyped_range.simps usable_untyped_range.simps atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex usableUntypedRange.simps
    note descendants_range[simp] = invokeUntyped_proofs.descendants_range[OF pf]
    note vc'[simp] = invokeUntyped_proofs.vc'[OF pf]
    note ps_no_overlap'[simp] = invokeUntyped_proofs.ps_no_overlap'[OF pf]
    note caps_no_overlap'[simp] = invokeUntyped_proofs.caps_no_overlap'[OF pf]
    note ex_cte_no_overlap' = invokeUntyped_proofs.ex_cte_no_overlap'[OF pf]
    note cref_inv = invokeUntyped_proofs.cref_inv[OF pf]
    note slots_invD = invokeUntyped_proofs.slots_invD[OF pf]
    note nidx[simp] = add_minus_neg_mask[where ptr = ptr]
    note idx_compare' = invokeUntyped_proofs.idx_compare'[OF pf]

    have idx_compare :
       "\<lbrakk>unat ((ptr && mask sz) + of_nat (length slots) * 2 ^ APIType_capBits tp us) < 2 ^ sz;ptr \<noteq> ptr && ~~ mask sz\<rbrakk>
       \<Longrightarrow> (ptr && ~~ mask sz) + of_nat idx \<le> ptr + (of_nat (length slots) << APIType_capBits tp us)"
       apply (rule range_cover_idx_compare[OF cover ])
         apply assumption+
       apply (frule non_detype_idx_le)
       apply (erule less_imp_le)
       using misc
       apply simp
       done

    have usable_range_subset:
      "ptr && ~~ mask sz \<noteq> ptr
      \<Longrightarrow> usableUntypedRange (capability.UntypedCap (ptr &&~~ mask sz) sz
                       (getFreeIndex (ptr &&~~ mask sz) (ptr + of_nat (length slots) * 2 ^ APIType_capBits tp us)))
                      \<subseteq> usableUntypedRange (capability.UntypedCap (ptr&&~~ mask sz) sz idx)"
      "ptr && ~~ mask sz \<noteq> ptr
      \<Longrightarrow>usable_untyped_range
                     (cap.UntypedCap (ptr && ~~ mask sz) sz
                       (unat ((ptr && mask sz) + (of_nat (length slots) << (APIType_capBits tp us)))))
                    \<subseteq> usable_untyped_range (cap.UntypedCap (ptr && ~~ mask sz) sz idx)"
      apply (simp_all add:blah getFreeIndex_def field_simps nidx)
      apply (clarsimp)
       apply (subst add_commute)
       apply (erule order_trans[OF idx_compare])
        apply simp
       apply (subst word_plus_and_or_coroll2[symmetric,where w = "mask sz"])
       apply (simp add:shiftl_t2n field_simps)
      apply (clarsimp simp:shiftl_t2n nidx field_simps)
       apply (subst add_commute)
       apply (erule order_trans[OF idx_compare])
        apply simp
       apply (clarsimp simp:shiftl_t2n add_assoc[symmetric]
         word_plus_and_or_coroll2[where w = "mask sz"] field_simps)
      done

    have valid_global_refs': "valid_global_refs' s"
      using misc by auto

    have kernel_data_refs[simp]:
        "\<And>p2. p2 = ptr && ~~ mask sz
            \<Longrightarrow> {ptr .. p2 + 2 ^ sz - 1} \<inter> kernel_data_refs = {}"
      using cte_wp_at' valid_global_refs'
      apply (clarsimp simp: cte_wp_at_ctes_of valid_global_refs'_def
                            valid_refs'_def)
      apply (drule bspec, erule ranI)
      apply (subst Int_commute, erule disjoint_subset2[rotated])
      apply (simp add: atLeastatMost_subset_iff word_and_le2)
      done

    note neg_mask_add_mask = word_plus_and_or_coroll2
    [symmetric,where w = "mask sz" and t = ptr,symmetric]
    note msimp[simp add] =  misc getObjectSize_def_eq neg_mask_add_mask
    show "\<lbrace>op = s\<rbrace> invokeUntyped
      (Invocations_H.untyped_invocation.Retype cref (ptr && ~~ mask sz) ptr tp us slots)
      \<lbrace>\<lambda>rv. invs'\<rbrace>"
    apply (clarsimp simp:invokeUntyped_def getSlotCap_def)
    apply (case_tac "ptr && ~~ mask sz \<noteq> ptr")
      apply (wp createNewObjects_wp_helper[where sz = sz])
            apply simp+
           apply (rule cover)
          apply simp
         using vslot
         apply simp
      apply (clarsimp simp:insertNewCaps_def)
      apply (insert misc cover vslot)
      apply (wp zipWithM_x_insertNewCap_invs''
                set_tuple_pick distinct_tuple_helper
                hoare_vcg_const_Ball_lift
                createNewCaps_invs'[where sz = sz]
                createNewCaps_valid_cap[where sz = sz,OF cover]
                createNewCaps_parent_helper[where sz = sz and ptr_base = "ptr && ~~ mask sz"]
                createNewCaps_cap_to'[where sz = sz]
                createNewCaps_descendants_range_ret'[where sz = sz]
                createNewCaps_caps_overlap_reserved_ret'[where sz = sz]
                createNewCaps_ranges[where sz = sz]
                createNewCaps_ranges'[where sz = sz]
                createNewCaps_IRQHandler
                createNewCaps_ct_active'[where sz=sz]
      | simp add: zipWithM_x_mapM)+
      apply (wp hoare_vcg_all_lift)
      apply (wp hoare_strengthen_post[OF createNewCaps_IRQHandler])
      apply (intro impI)
       apply (erule impE)
       apply (erule(1) snd_set_zip_in_set)
      apply (wp hoare_strengthen_post[OF createNewCaps_range_helper[where sz = sz]])
       apply clarsimp
     apply (clarsimp simp:conj_ac ball_conj_distrib simp del:capFreeIndex_update.simps)
     apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
                impI[OF invs_valid_pspace'] impI[OF invs_arch_state']
                imp_consequent[where Q = "(\<exists>x. x \<in> set slots)"]
              | clarsimp simp:conj_ac not_0_ptr simp del:capFreeIndex_update.simps)+
     apply (wp updateFreeIndex_invs' updateFreeIndex_caps_overlap_reserved'
       updateFreeIndex_caps_no_overlap'' updateFreeIndex_pspace_no_overlap'
       hoare_vcg_const_Ball_lift updateCap_weak_cte_wp_at updateCap_ct_active')
      apply (simp add:ex_cte_cap_wp_to'_def)
      apply wps
      apply (rule hoare_vcg_ex_lift)
      apply (wp updateCap_weak_cte_wp_at updateCap_ct_active' getCTE_wp hoare_vcg_ball_lift)
     apply (wp updateFreeIndex_caps_overlap_reserved'
               updateFreeIndex_descendants_range_in' getCTE_wp | simp)+
    using cte_wp_at'
    apply (clarsimp simp: cte_wp_at_ctes_of isCap_simps getFreeIndex_def shiftL_nat shiftl_t2n)
     apply (intro conjI)
             apply (simp add: range_cover_unat[OF cover,unfolded size_eq]
                              range_cover.unat_of_nat_shift size_eq field_simps)+
            apply (clarsimp dest!: range_cover.range_cover_compare_bound)
           apply (simp add: invs_valid_pspace')
           using `invs' s`
           apply (simp add: invs'_def valid_state'_def)
          apply (clarsimp dest!: slots_invD
                           simp: ex_cte_cap_wp_to'_def cte_wp_at_ctes_of)
          apply (rule_tac x = crefa in exI)
          apply clarsimp
         apply simp+
     apply (rule subset_trans[OF subset_stuff])
     apply (clarsimp simp:blah word_and_le2)
    apply (simp add:field_simps)
    apply (rule invokeUntyped_proofs.usableRange_disjoint[OF pf])
   apply (drule ps_no_overlap')
   using misc
   apply -
   apply (frule invs_valid_idle')
   apply (clarsimp simp:valid_idle'_def st_tcb_at'_def obj_at'_def)
   apply (frule obj_at_in_obj_range')
     apply (simp add:invs_pspace_aligned')
   apply (drule(1) pspace_no_overlapD')
   apply blast
  apply (clarsimp simp:insertNewCaps_def)
  apply (insert misc cover vslot)
  apply (wp createNewObjects_wp_helper[where sz = sz])
      apply simp+
     apply (clarsimp simp:insertNewCaps_def)
     apply (wp zipWithM_x_insertNewCap_invs''
      set_tuple_pick distinct_tuple_helper
      hoare_vcg_const_Ball_lift
      createNewCaps_invs'[where sz = sz]
      createNewCaps_valid_cap[where sz = sz,OF cover]
      createNewCaps_parent_helper[where sz = sz]
      createNewCaps_cap_to'[where sz = sz]
      createNewCaps_descendants_range_ret'[where sz = sz]
      createNewCaps_caps_overlap_reserved_ret'[where sz = sz]
      createNewCaps_ranges[where sz = sz]
      createNewCaps_ranges'[where sz = sz]
      createNewCaps_IRQHandler
      createNewCaps_ct_active'
      | simp add:zipWithM_x_mapM)+
     apply (wp hoare_vcg_all_lift)
     apply (wp hoare_strengthen_post[OF createNewCaps_IRQHandler])
     apply (intro impI)
     apply (erule impE)
      apply (erule(1) snd_set_zip_in_set)
     apply (wp hoare_strengthen_post[OF createNewCaps_range_helper[where sz = sz]])
     apply clarsimp
    apply (clarsimp simp:conj_ac ball_conj_distrib simp del:capFreeIndex_update.simps)
    apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_pspace_distinct']
                impI[OF invs_valid_pspace'] impI[OF invs_arch_state']
                imp_consequent[where Q = "(\<exists>x. x \<in> set slots)"]
              | clarsimp simp:conj_ac not_0_ptr simp del:capFreeIndex_update.simps)+
     apply (wp updateFreeIndex_invs_simple'
       updateFreeIndex_caps_overlap_reserved'
       updateFreeIndex_caps_no_overlap''[where sz = sz]
       updateFreeIndex_pspace_no_overlap'[where sz = sz]
       hoare_vcg_const_Ball_lift updateCap_weak_cte_wp_at)
      apply (simp add:ex_cte_cap_wp_to'_def)
      apply wps
      apply (rule hoare_vcg_ex_lift)
      apply (wp updateCap_weak_cte_wp_at getCTE_wp updateCap_ct_active' hoare_vcg_ball_lift)
     apply (wp updateFreeIndex_caps_overlap_reserved'
       updateFreeIndex_descendants_range_in' getCTE_wp)
    apply (clarsimp simp:conj_ac split del:if_splits)
    apply (strengthen impI[OF invs_pspace_aligned'] impI[OF invs_valid_pspace'] imp_consequent
          impI[OF invs_pspace_distinct'] impI[OF invs_arch_state] impI[OF invs_psp_aligned])
    apply (clarsimp simp:conj_ac not_0_ptr isCap_simps
         shiftL_nat field_simps range_cover.unat_of_nat_shift[OF cover le_refl,simplified])
    apply (rule_tac P = "cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sz idx"
      in hoare_gen_asm)
    apply simp
    apply (wp deleteObjects_invs'[where idx = idx and p = "cref"]
              deleteObjects_caps_no_overlap''[where idx = idx and slot = "cref"]
              deleteObject_no_overlap[where idx = idx]
              deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_caps_overlap_reserved'[where idx = idx and slot = "cref"]
              deleteObjects_descendants[where idx = idx and p = "cref"]
              hoare_vcg_ball_lift hoare_drop_imp hoare_vcg_ex_lift
              deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_real_cte_at'[where idx = idx and ptr = ptr and bits = sz]
              deleteObjects_ct_active')
    apply wps
    apply (wp deleteObjects_cte_wp_at'[where idx = idx and ptr = ptr and bits = sz])[2]
  using vc'
  apply (clarsimp simp:conj_ac ball_conj_distrib descendants_range'_def2 is_aligned_neg_mask_eq)
  apply (strengthen impI[OF invs_mdb] impI[OF invs_valid_objs] imp_consequent
                impI[OF invs_valid_pspace] impI[OF invs_arch_state] impI[OF invs_psp_aligned]
                impI[OF invs_distinct])
  apply (wp getCTE_wp)
  using cte_wp_at' cref_inv misc us_align descendants_range
  apply (clarsimp simp: is_aligned_neg_mask_eq' invs_valid_pspace' invs_ksCurDomain_maxDomain'
       cte_wp_at_ctes_of isCap_simps getFreeIndex_def shiftL_nat shiftl_t2n)
  apply (intro conjI)
               apply (rule range_cover.sz
                 [where 'a=32, folded word_bits_def, OF cover])
               using `invs' s` apply (simp add: invs'_def valid_state'_def)
              apply fastforce+
         apply (clarsimp dest!: slots_invD)
        apply (simp add:range_cover.unat_of_nat_shift[OF cover] size_eq field_simps)+
       apply (subst mult_commute)
       apply (rule nat_le_power_trans)
        apply (rule range_cover.range_cover_n_le[OF cover,unfolded size_eq])
       apply (rule range_cover.sz[OF cover,unfolded size_eq])
      apply (clarsimp simp: mask_out_sub_mask field_simps)
     using misc
     apply -
     apply (frule invs_valid_global')
     apply (clarsimp simp:valid_global_refs'_def valid_refs'_def)
     apply (thin_tac "\<forall>x\<in> ?A. ?P x")
     apply (drule bspec)
      apply fastforce
     apply (erule(1) in_empty_interE[OF  _ subsetD])
      prefer 2
      apply simp
     apply (clarsimp simp:global_refs'_def)
    apply (cut_tac subset_stuff,simp)
   using invokeUntyped_proofs.usableRange_disjoint[OF pf]
   apply (simp add: is_aligned_neg_mask_eq'[symmetric]
     is_aligned_neg_mask_eq is_aligned_mask getFreeIndex_def)
  apply (rule ballI)
  apply (drule(1) bspec)+
  apply (clarsimp simp: ex_cte_cap_wp_to'_def cte_wp_at_ctes_of )
  apply (rule_tac x = crefa in exI,clarsimp)
  apply (intro conjI,clarsimp)
  apply (subgoal_tac "ex_cte_cap_wp_to' (\<lambda>_. True) ?p ?s")
   apply (drule ex_cte_no_overlap')
   apply simp
  apply (rule if_unsafe_then_capD')
    apply (auto simp:cte_wp_at_ctes_of invs_unsafe_then_cap')
  done
qed

lemma invokeUntyped_invs'[wp]:
  "\<lbrace>invs' and valid_untyped_inv' ui and ct_active'\<rbrace>
     invokeUntyped ui
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  by (cases ui, erule invokeUntyped_invs'')

end