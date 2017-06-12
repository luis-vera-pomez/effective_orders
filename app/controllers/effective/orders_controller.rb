module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Providers::Admin if EffectiveOrders.admin_enabled
    include Providers::Cheque if EffectiveOrders.cheque_enabled
    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled
    include Providers::Ccbill if EffectiveOrders.ccbill_enabled
    include Providers::AppCheckout if EffectiveOrders.app_checkout_enabled

    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_development && !Rails.env.production?
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_production && Rails.env.production?

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_action :authenticate_user!, except: [:paypal_postback, :ccbill_postback]
    before_action :set_page_title, except: [:show]

    # This is the entry point for the "Checkout" buttons
    def new
      @order ||= Effective::Order.new(current_cart, user: current_user)

      EffectiveOrders.authorized?(self, :new, @order)

      # We're only going to check for a subset of errors on this step,
      # with the idea that we don't want to create an Order object if the Order is totally invalid
      @order.valid?

      if @order.errors[:order_items].present?
        flash[:danger] = @order.errors[:order_items].first
        redirect_to(effective_orders.cart_path)
        return
      elsif @order.errors[:total].present?
        flash[:danger] = @order.errors[:total].first
        redirect_to(effective_orders.cart_path)
        return
      end

      @order.errors.clear
      @order.billing_address.try(:errors).try(:clear)
      @order.shipping_address.try(:errors).try(:clear)
    end

    def edit
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :edit, @order)
    end

    def create
      @order ||= Effective::Order.new(current_cart, user: current_user)
      EffectiveOrders.authorized?(self, :create, @order)

      save_order_and_redirect_to_step2 || render(:new)
    end

    # If there is an existing order, it will be posted to the /update action, instead of /create
    def update
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :update, @order)

      save_order_and_redirect_to_step2 || render(:edit)
    end

    def save_order_and_redirect_to_step2
      raise 'expected @order to be present' unless @order

      @order.attributes = order_params
      @order.user_id = current_user.id

      @order.valid?  # This makes sure the correct shipping_address is copied from billing_address if shipping_address_same_as_billing

      Effective::Order.transaction do
        begin
          if @order.save_billing_address? && @order.user.respond_to?(:billing_address=) && @order.billing_address.present?
            @order.user.billing_address = @order.billing_address
          end

          if @order.save_shipping_address? && @order.user.respond_to?(:shipping_address=) && @order.shipping_address.present?
            @order.user.shipping_address = @order.shipping_address
          end

          @order.save!

          if @order.total == 0 && EffectiveOrders.allow_free_orders
            order_purchased(details: 'automatic purchase of free order', provider: 'free', card: 'none')
          else
            redirect_to(effective_orders.order_path(@order))  # This goes to checkout_step2
          end

          return true
        rescue => e
          Rails.logger.info e.message
          flash.now[:danger] = "Unable to save order: #{@order.errors.full_messages.to_sentence}. Please try again."
          raise ActiveRecord::Rollback
        end
      end

      false
    end

    def show
      @order = Effective::Order.find(params[:id])
      set_page_title

      EffectiveOrders.authorized?(self, :show, @order)
    end

    def index
      @orders = Effective::Order.purchased_by(current_user)
      @pending_orders = Effective::Order.pending.where(user: current_user)

      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Basically an index page.
    # Purchases is an Order History page.  List of purchased orders
    def my_purchases
      @orders = Effective::Order.purchased_by(current_user)

      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Sales is a list of what products beign sold by me have been purchased
    def my_sales
      @order_items = Effective::OrderItem.sold_by(current_user)
      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Thank you for Purchasing this Order.  This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = if params[:id].present?
        Effective::Order.find(params[:id])
      elsif current_user.present?
        Effective::Order.purchased_by(current_user).first
      end

      if @order.blank?
        redirect_to(effective_orders.my_purchases_path) and return
      end

      EffectiveOrders.authorized?(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.purchased?
    end

    # An error has occurred, please try again
    def declined # An error occurred!
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.declined?
    end

    def resend_buyer_receipt
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if @order.send_order_receipt_to_buyer!
        flash[:success] = "Successfully sent receipt to #{@order.user.email}"
      else
        flash[:danger] = "Unable to send receipt."
      end

      if respond_to?(:redirect_back)
        redirect_back(fallback_location: effective_orders.order_path(@order))
      elsif request.referrer.present?
        redirect_to :back
      else
        redirect_to effective_orders.order_path(@order)
      end
    end

    protected

    def order_purchased(details: 'none', provider:, card: 'none', purchased_url: nil, declined_url: nil)
      begin
        @order.purchase!(details: details, provider: provider, card: card)

        Effective::Cart.where(user_id: @order.user_id).destroy_all

        if EffectiveOrders.mailer[:send_order_receipt_to_buyer] && @order.user == current_user
          flash[:success] = "Payment successful! Please check your email for a receipt."
        else
          flash[:success] = "Payment successful!"
        end

        redirect_to (purchased_url.presence || effective_orders.order_purchased_path(':id')).gsub(':id', @order.to_param.to_s)
      rescue => e
        flash[:danger] = "An error occurred while processing your payment: #{e.message}.  Please try again."
        redirect_to(declined_url.presence || effective_orders.cart_path).gsub(':id', @order.to_param.to_s)
      end
    end

    def order_declined(details: 'none', provider:, card: 'none', declined_url: nil, message: nil)
      @order.decline!(details: details, provider: provider, card: card) rescue nil

      flash[:danger] = message.presence || 'Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.'

      redirect_to(declined_url.presence || effective_orders.order_declined_path(@order)).gsub(':id', @order.id.to_s)
    end

    private

    # StrongParameters
    def order_params
      params.require(:effective_order).permit(EffectiveOrders.permitted_params)
    end

    def set_page_title
      @page_title ||= case params[:action]
        when 'index'        ; 'Orders'
        when 'show'
          if @order.purchased?
            'Receipt'
          elsif @order.user != current_user
            @order.pending? ? "Pending Order ##{@order.to_param}" : "Order ##{@order.to_param}"
          else
            'Checkout'
          end
        when 'my_purchases' ; 'Order History'
        when 'my_sales'     ; 'Sales History'
        when 'purchased'    ; 'Thank You'
        when 'declined'     ; 'Payment Declined'
        else 'Checkout'
      end
    end

  end
end
