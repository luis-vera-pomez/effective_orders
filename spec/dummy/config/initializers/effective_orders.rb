# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  # Configure Database Tables
  config.orders_table_name = :orders
  config.order_items_table_name = :order_items
  config.carts_table_name = :carts
  config.cart_items_table_name = :cart_items
  config.customers_table_name = :customers
  config.subscriptions_table_name = :subscriptions
  config.products_table_name = :custom_products

  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If the method returns false, an Effective::AccessDenied Error will be raised (see README.md for complete info)
  #
  # Use via Proc (and with CanCan):
  # config.authorization_method = Proc.new { |controller, action, resource| can?(action, resource) }
  #
  # Use via custom method:
  # config.authorization_method = :my_authorization_method
  #
  # And then in your application_controller.rb:
  #
  # def my_authorization_method(action, resource)
  #   current_user.is?(:admin)
  # end
  #
  # Or disable the check completely:
  # config.authorization_method = false
  config.authorization_method = Proc.new { |controller, action, resource| true }

  # Use effective_obfuscation gem to change order.id into a seemingly random 10-digit number
  config.obfuscate_order_ids = true

  # Require these addresses when creating a new Order.  Works with effective_addresses gem
  config.require_billing_address = true
  config.require_shipping_address = true

  # Use billing/shipping address full name in checkout process. Address full name will be validated.
  # Works with effective_addresses gem
  config.use_address_full_name = true

  # If set, the orders#new screen will render effective/orders/user_fields partial and capture this User Info
  # The partial can be overridden to customize the form, but the following fields are also fed into strong_paramters
  config.collect_user_fields = [:first_name, :last_name]
  #config.collect_user_fields = [:salutation, :first_name, :last_name] # Must be valid fields on the User object

  # Don't validate_associated :user when saving an Order
  config.skip_user_validation = false

  config.collect_note = true
  config.collect_note_message = 'please enter a note'

  # Minimum Charge
  # Prevent orders less than this value from being purchased
  # Stripe doesn't allow orders less than $0.50
  # Set to nil for no minimum charge
  # Default value is 50 cents, or $0.50
  config.minimum_charge = 50

  # Free Orders
  # Allow orders with a total of 0.00 to be purchased (regardless of the minimum charge setting)
  # When enabled, the checkout process will skip the paypal/stripe/purchasing step
  # and just display the 'Thank You' after checkout is clicked
  config.allow_free_orders = true

  # Allow Pretend Purchase in Production
  # WARNING: Setting this option to true will allow users to purchase! an Order without entering a credit card
  # WARNING: When true, users can purchase! anything without paying money
  #
  # This should basically always be false, but sometimes you want to make a Beta/Demo site
  # where users may test the purchase workflow without actually paying money
  #
  # When true, there will be a 'Process Order' button on the Checkout screen.
  # Clicking this button will mark an Order purchased and redirect the user to the
  # Thank You page just as if they had successfully Checked Out through a payment processor
  config.allow_pretend_purchase_in_production = false
  config.allow_pretend_purchase_in_production_message = '* payment information is not required to process this order at this time.'

  # Pay by Cheque
  # Allow user to create pending orders in order to pay for it by cheque offline. Pending orders are not
  # considered purchased and have 'pending' purchase state
  #
  # When true, there will be a 'Pay by Cheque' button on the Checkout screen.
  # Clicking this button will mark an Order pending and redirect the user to the
  # pending order page.
  config.cheque_enabled = true

  config.cheque = {
    confirm: 'Your order will not be considered purchased until we receive your cheque. Proceed with pay by cheque?',
    success_message: 'Thank you! You have indicated that this order will be purchased by cheque. Please send us a cheque and a copy of this invoice at your earliest convenience. We will mark this order purchased upon receiving payment.'
  }

  # Show/hide the 'Order History' button on the 'Cart Page'
  config.show_order_history_button = true

  # Layout Settings
  # Configure the Layout per controller, or all at once

  # config.layout = 'application'   # All EffectiveOrders controllers will use this layout
  config.layout = {
    carts: 'application',
    orders: 'application',
    subscriptions: 'application',
    admin_customers: 'application',
    admin_orders: 'application'
  }

  # SimpleForm Options
  # This Hash of options will be passed into any simple_form_for() calls
  config.simple_form_options = {}

  # config.simple_form_options = {
  #   html: {class: 'form-horizontal'},
  #   wrapper: :horizontal_form,
  #   wrapper_mappings: {
  #     boolean: :horizontal_boolean,
  #     check_boxes: :horizontal_radio_and_checkboxes,
  #     radio_buttons: :horizontal_radio_and_checkboxes
  #   }
  # }

  # Mailer Settings
  # effective_orders will send out receipts to the buyer, seller and admins.
  # For all the emails, the same :subject_prefix will be prefixed.  Leave as nil / empty string if you don't want any prefix
  #
  # The subject_for_admin_receipt, subject_for_buyer_receipt, subject_for_payment_request and
  # subject_for_seller_receipt can be one of:
  # - nil / empty string to use the built in defaults
  # - A string with the full subject line for this email
  # - A Proc to create the subject line based on the email
  # In all three of these cases, the subject_prefix will still be used.

  # The Procs are the same for admin & buyer receipt, the seller Proc is different
  # subject_for_admin_receipt: Proc.new { |order| "Order #{order.to_param} has been purchased"}
  # subject_for_buyer_receipt: Proc.new { |order| "Order #{order.to_param} has been purchased"}
  # subject_for_payment_request: Proc.new { |order| "Pending Order #{order.to_param}"}
  # subject_for_seller_receipt: Proc.new { |order, order_items, seller| "Order #{order.to_param} has been purchased"}

  config.mailer = {
    send_order_receipt_to_admin: true,
    send_order_receipt_to_buyer: true,
    send_payment_request_to_buyer: true,
    send_order_receipts_when_marked_paid_by_admin: false,
    send_order_receipt_to_seller: true,   # Only applies to StripeConnect
    layout: 'effective_orders_mailer_layout',
    admin_email: 'admin@example.com',
    default_from: 'info@example.com',
    subject_prefix: '[example]',
    subject_for_admin_receipt: '',
    subject_for_buyer_receipt: '',
    subject_for_payment_request: '',
    subject_for_seller_receipt: '',
    deliver_method: nil,
    delayed_job_deliver: false
  }

  # Moneris configuration
  config.moneris_enabled = true

  if Rails.env.production?
    config.moneris = {
      ps_store_id: '',
      hpp_key: '',
      hpp_url: 'https://www3.moneris.com/HPPDP/index.php',
      verify_url: 'https://www3.moneris.com/HPPDP/verifyTxn.php'
    }
  else
    config.moneris = {
      ps_store_id: 'foo',
      hpp_key: 'bar',
      hpp_url: 'https://esqa.moneris.com/HPPDP/index.php',
      verify_url: 'https://esqa.moneris.com/HPPDP/verifyTxn.php'
    }
  end

  # Paypal configuration
  config.paypal_enabled = true

  if Rails.env.production?
    config.paypal = {
      seller_email: '',
      secret: '',
      cert_id: '',
      paypal_url: 'https://www.paypal.com/cgi-bin/webscr',
      currency: 'CAD',
      paypal_cert: "#{Rails.root}/config/paypalcerts/production/paypal_cert.pem",
      app_cert: "#{Rails.root}/config/paypalcerts/production/app_cert.pem",
      app_key: "#{Rails.root}/config/paypalcerts/production/app_key.pem"
    }
  else
    config.paypal = {
      seller_email: 'seller@mail.com',
      secret: 'foo',
      cert_id: 'bar',
      paypal_url: 'https://www.sandbox.paypal.com/cgi-bin/webscr',
      currency: 'CAD',
      paypal_cert: "#{Rails.root}/config/paypalcerts/#{Rails.env}/paypal_cert.pem",
      app_cert: "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_cert.pem",
      app_key: "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_key.pem"
    }
  end

  # Stripe configuration
  config.stripe_enabled = true
  config.subscriptions_enabled = true # https://stripe.com/docs/subscriptions
  config.stripe_connect_enabled = false # https://stripe.com/docs/connect
  config.stripe_connect_application_fee_method = Proc.new { |order_item| order_item.total * 0.10 } # 10 percent

  if Rails.env.production?
    config.stripe = {
      secret_key: '',
      publishable_key: '',
      currency: 'usd',
      site_title: 'My Site',
      site_image: '', # A relative URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
      connect_client_id: ''
    }
  else
    config.stripe = {
      secret_key: 'foo',
      publishable_key: 'bar',
      currency: 'usd',
      site_title: 'My Development Site',  # Displayed on the Embedded Stripe Form
      site_image: 'foo', # A relative URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
      connect_client_id: 'bar'
    }
  end

  # CCBill configuration
  config.ccbill_enabled = true

  # CCBill Dynamic Pricing documentation describes these variables:
  # https://www.ccbill.com/cs/wiki/tiki-index.php?page=Dynamic+Pricing+User+Guide
  if Rails.env.production?
    config.ccbill = {
      client_accnum: '',
      client_subacc: '',
      # Get this from CCBill Admin dashboard after setting up a form
      form_name: '',
      form_period: '',
      # https://www.ccbill.com/cs/wiki/tiki-index.php?page=Webhooks+User+Guide#Appendix_A:_Currency_Codes
      currency_code: '',
      # You'll get this salt value from CCBill tech support
      # https://www.ccbill.com/cs/wiki/tiki-index.php?page=Dynamic+Pricing+User+Guide#Generating_the_MD5_Hash
      dynamic_pricing_salt: ''
    }
  else
    config.ccbill = {
      client_accnum: 'foo',
      client_subacc: 'bar',
      form_name: 'foo',
      form_period: 'bar',
      currency_code: 'foo',
      dynamic_pricing_salt: 'bar'
    }
  end

  # App checkout configuration
  config.app_checkout_enabled = false

  config.app_checkout = {
    checkout_label: '', # Checkout button to finalize the order
    service: nil, # an EffectiveOrders::AppCheckout type object
    declined_flash: "Payment was unsuccessful. Please try again."
  }
end
