require 'effective_addresses'
require "effective_orders/engine"
require 'migrant'     # Required for rspec to run properly

module EffectiveOrders
  PURCHASED = 'purchased'
  DECLINED = 'declined'

  # The following are all valid config keys
  mattr_accessor :orders_table_name
  mattr_accessor :order_items_table_name
  mattr_accessor :carts_table_name
  mattr_accessor :cart_items_table_name
  mattr_accessor :customers_table_name

  mattr_accessor :authorization_method
  mattr_accessor :tax_rate_method

  mattr_accessor :require_billing_address
  mattr_accessor :require_shipping_address
  mattr_accessor :order_id_nudge

  mattr_accessor :paypal_enabled
  mattr_accessor :moneris_enabled

  # application fee  is required if stripe_connect_enabled is true
  mattr_accessor :stripe_enabled

  mattr_accessor :stripe_subscriptions_enabled
  mattr_accessor :stripe_connect_enabled
  mattr_accessor :stripe_connect_application_fee_method

  # These are hashes of configs
  mattr_accessor :mailer
  mattr_accessor :paypal
  mattr_accessor :moneris
  mattr_accessor :stripe

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &EffectiveOrders.authorization_method)
    true
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
  class AlreadyDeclinedException < Exception; end

end
