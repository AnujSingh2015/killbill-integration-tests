$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementAddOn < Base

    def setup
      @user = "EntitlementAddOn"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_simple

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(1, bps.size)
      assert_equal(bp.subscription_id, bps[0].subscription_id)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(1, aos.size)
      assert_equal(ao_entitlement.subscription_id, aos[0].subscription_id)
    end

    def test_cancel_bp_default_policy_in_trial

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options) # "2013-08-16"

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock before cancellation (BP still in trial)
      kb_clock_add_days(5, nil, @options) # "2013-08-21"

      # All default, system will cancel immediately since we are still in trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(1, bps.size)
      check_subscription(bps[0], 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-21", DEFAULT_KB_INIT_DATE, "2013-08-21")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                    {:type => "START_BILLING", :date => "2013-08-01"},
                    {:type => "STOP_ENTITLEMENT", :date => "2013-08-21"},
                    {:type => "STOP_BILLING", :date => "2013-08-21"}], bps[0].events)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(1, aos.size)
      assert_equal(ao_entitlement.subscription_id, aos[0].subscription_id)
      check_subscription(aos[0], 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", "2013-08-21", "2013-08-16", "2013-08-21")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-16"},
                                   {:type => "START_BILLING", :date => "2013-08-16"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-08-21"},
                                   {:type => "STOP_BILLING", :date => "2013-08-21"}], aos[0].events)
    end


    def test_cancel_bp_default_policy_after_trial

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options) # 16/08/2013

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock after trial before cancellation
      kb_clock_add_days(16, nil, @options) # 01/09/2013

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(1, bps.size)

      check_subscription(bps[0], 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-01", DEFAULT_KB_INIT_DATE, "2013-09-30")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                                   {:type => "START_BILLING", :date => "2013-08-01"},
                                   {:type => "PHASE", :date => "2013-08-31"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-09-01"},
                                   {:type => "STOP_BILLING", :date => "2013-09-30"}], bps[0].events)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)

      check_subscription(aos[0], 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", "2013-09-01", "2013-08-16", "2013-09-30")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-16"},
                                   {:type => "START_BILLING", :date => "2013-08-16"},
                                   {:type => "PHASE", :date => "2013-09-01"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-09-01"},
                                   {:type => "STOP_BILLING", :date => "2013-09-30"}], aos[0].events)
    end


    def test_cancel_bp_with_cancel_date_and_uncancel

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days(BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      requested_date = '2013-08-06'
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = true

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-06", "2013-08-01", "2013-08-06")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-06", "2013-08-01", "2013-08-06")

      bp.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
    end


    def test_cancel_bp_with_ent_eot_bill_imm

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days(BP after TRIAL)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'IMMEDIATE'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-09-30", "2013-08-01", "2013-08-31")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-09-30", "2013-08-01", "2013-08-31")

    end

    def test_cancel_bp_with_ent_imm_bill_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days(BP after TRIAL)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      requested_date = nil
      entitlement_policy = 'IMMEDIATE'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-31", "2013-08-01", "2013-09-30")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-31", "2013-08-01", "2013-09-30")

    end


    def test_uncancel_ao_ent_eot_bill_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-31", "2013-08-01", "2013-08-31")

      ao1.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)

    end

    def test_uncancel_ao_ent_eot_bill_imm

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days(BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'IMMEDIATE'
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-31", "2013-08-01", "2013-08-05")

      # Base subscription already reached cancellation, we should not be able to uncancel
      assert_raise do
        ao1.uncancel(@user, nil, nil, @options)
      end
    end

    def test_uncancel_ao_ent_imm_bill_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      requested_date = nil
      entitlement_policy = 'IMMEDIATE'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-05", "2013-08-01", "2013-08-31")

      # We allow to uncancel a subscription as long as the billing cancellation date is in the future.
      ao1.uncancel(@user, nil, nil, @options)
    end

    def test_uncancel_ao_with_cancel_date

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock and by a few days(BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      requested_date = '2013-08-06'
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = true

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-06", "2013-08-01", "2013-08-06")

      ao1.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
    end


    def test_change_bp_with_included_ao_eot

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)


      # Change Plan for BP (future cancel date = 30/09/2013)  => AO1 is now included in new plan, so should be cancelled
      requested_date = nil
      billing_policy = "END_OF_TERM"
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")
    end

    def test_change_bp_with_included_ao_imm

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013

      # Change Plan for BP immediately => AO1 is now included in new plan, so should be cancelled immediately
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")
    end


    def test_cancel_ao_prior_future_bp_cancel_date

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      #
      # Will future cancel BP on  2013-09-30 (and AO should reflect that as well)
      #
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      #
      # Will cancel AO immediatly
      #
      requested_date = nil
      entitlement_policy = 'IMMEDIATE'
      billing_policy = 'IMMEDIATE'
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      #  Retrieves subscription and check AO cancellation date should now be 2013-09-01
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

      # Uncancel BP
      bp.uncancel(@user, nil, nil, @options)

      # Retrieves subscription and check cancellation date for AO1 reverted back to BP CTD, 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      # ADD-ON should still be cancelled on 8/31/2013
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

    end

    def test_future_cancel_ao_prior_future_bp_cancel_date

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      #
      # Will future cancel BP on  2013-09-30 (and AO should reflect that as well)
      #
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      #
      # Will future cancel AO on its CTD 2013-09-01
      #
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      #  Retrieves subscription and check AO cancellation date should now be 2013-09-01
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-01", "2013-08-05", "2013-09-01")

      # Uncancel AO
      ao1.uncancel(@user, nil, nil, @options)

      # Retrieves subscription and check cancellation date for AO1 reverted back to BP CTD, 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

    end

    def test_future_cancel_ao_after_future_bp_cancel_date_and_uncancel_bp

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013
      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      # Move clock to pass AO PHASE
      kb_clock_add_days(1, nil, @options) # 01/09/2013
      wait_for_expected_clause(4, @account, &@proc_account_invoices_nb)

      #
      # Will future cancel BP on  2013-09-30 (and AO should reflect that as well)
      #
      #
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      #
      # Will future cancel AO after BP cancellation date, call should fail as this is already cancelled prior
      # Default ADD_ON cancellation policy is IMMEDIATE hence the "2013-09-01" expected for billing_end_date
      requested_date = "2013-10-01"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is still 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-01")

      # Uncancel BP and check AO cancellation is not honored
      bp.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-10-01", "2013-08-05", "2013-09-01")

    end


    def test_future_cancel_ao_after_future_bp_cancel_date_and_reach_bp_cancellation

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock on BP Phase (BP not in trial)
      kb_clock_add_days(26, nil, @options) # 31/08/2013

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)

      # Move clock to pass AO PHASE
      kb_clock_add_days(1, nil, @options) # 01/09/2013
      wait_for_expected_clause(4, @account, &@proc_account_invoices_nb)

      #
      # Will future cancel BP on  2013-09-30 (and AO should reflect that as well)
      #
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      #
      # Will future cancel AO after BP cancellation date
      # Note that default catalog policy for ADD_ON cancellation is IMMEDIATE and not EOT
      #
      requested_date = "2013-10-01"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is still 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-01")

      # Move clock right after BP cancellation effective date
      kb_clock_add_days(30, nil, @options) # 30/09/2013

      # Retrieves subscription and check cancellation date for AO1 is still 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")

      # ADD-ON should be reflected as being cancelled on the CTD of the the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-01")

      # Double check we don't have double cancellation, that is the ao is not anymore cancelled at its own cancellation date
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                    {:type => "START_BILLING", :date => "2013-08-05"},
                    {:type => "PHASE", :date => "2013-09-01"},
                    {:type => "STOP_BILLING", :date => "2013-09-01"},
                    {:type => "STOP_ENTITLEMENT", :date => "2013-09-30"}], ao1.events)


    end


    def test_cancel_bp_prior_future_ao_cancel_date

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-08-31", ao1.charged_through_date)

      # Future cancel AO
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

      # Cancel BP Immediately
      requested_date = nil
      entitlement_policy = 'IMMEDIATE'
      billing_policy = 'IMMEDIATE'
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-05", DEFAULT_KB_INIT_DATE, "2013-08-05")

      # ADD-ON should be reflected as being cancelled the same as the BP
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-05", "2013-08-05", "2013-08-05")

    end

    def test_future_cancel_bp_prior_future_ao_cancel_date

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-08-31", ao1.charged_through_date)

      # Future cancel AO
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

      # Cancel BP slightly in the future
      requested_date = "2013-08-07"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-07", DEFAULT_KB_INIT_DATE, "2013-08-07")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-07", "2013-08-05", "2013-08-07")

      bp.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

    end


    def test_future_cancel_bp_after_future_ao_cancel_date

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      #
      # Let's verify invoice completed its work correctly and set the CTD correctly on both subscription
      # That date will be used below for cancellation at the entitlement level
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-08-31", ao1.charged_through_date)

      # Future cancel AO
      requested_date = nil
      entitlement_policy = 'END_OF_TERM'
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = true
      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

      # Cancel BP after AO cancellation
      requested_date = "2013-09-02"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = true
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-02", DEFAULT_KB_INIT_DATE, "2013-09-02")

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

      bp.uncancel(@user, nil, nil, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-08-31", "2013-08-05", "2013-08-31")

    end

    def test_cancel_with_two_similar_ao

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move clock after before cancellation (BP still in trial)
      kb_clock_add_days(3, nil, @options) # 04/08/2013

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-04", "2013-08-01", "2013-08-04")

      # Create Add-on 2
      ao2 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-04", nil)
      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)

      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      ao2.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(3, subscriptions.size)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-04", "2013-08-01", "2013-08-04")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-04", "2013-08-31", "2013-08-04", "2013-08-31")

    end


    def test_complex_ao

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)


      # Move clock and create Add-on 2 (BP still in trial)
      kb_clock_add_days(10, nil, @options) # 15/08/2013

      # Third invoice  15/08/2013 ->  31/08/2013
      ao2 = create_entitlement_ao(bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options) # (Subscription Aligned)
      check_entitlement(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", nil)
      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)

      # Fourth invoice
      # BP : 31/08/2013 ->  30/09/2013
      # AO1 : 31/08/2013 ->  01/09/2013  (end of discount)
      # AO2 : 31/08/2013 ->  15/09/2013   (end of discount)
      kb_clock_add_days(16, nil, @options) # 31/08/2013
      wait_for_expected_clause(4, @account, &@proc_account_invoices_nb)

      # Check on CTD after invoices
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-01", ao1.charged_through_date)
      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      assert_equal("2013-09-15", ao2.charged_through_date)


      # Fifth invoice AO1 01/09/2013 -> 30/09/2013 (Recurring Phase)
      kb_clock_add_days(1, nil, @options) # 01/09/2013
      wait_for_expected_clause(5, @account, &@proc_account_invoices_nb)

      # Check on CTD after invoices
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      assert_equal("2013-09-30", bp.charged_through_date)
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal("2013-09-30", ao1.charged_through_date)
      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      assert_equal("2013-09-15", ao2.charged_through_date)


      # Change Plan for BP (future cancel date = 30/09/2013)  => AO1 is now included in new plan
      requested_date = nil
      billing_policy = "END_OF_TERM"
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", nil, "2013-08-15", nil)

      # Sixth invoice AO2 15/09/2013 -> 30/09/2013 (Recurring Phase, aligns to BCD)
      kb_clock_add_days(14, nil, @options) # 15/09/2013
      wait_for_expected_clause(6, @account, &@proc_account_invoices_nb)

      # Seventh invoice AO2
      # BP : 30/09/2013 ->  31/10/2013
      # AO1 : (CANCELLED)
      # AO2 : 30/09/2013 ->  31/10/2013
      kb_clock_add_days(15, nil, @options) # 30/09/2013
      wait_for_expected_clause(7, @account, &@proc_account_invoices_nb)


      # Future cancel BP  (and therefore ADD_ON)

      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(3, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-10-31", DEFAULT_KB_INIT_DATE, "2013-10-31")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", "2013-10-31", "2013-08-15", "2013-10-31")

      # MORE TO COME ... when basic tests pass

    end

  end
end

