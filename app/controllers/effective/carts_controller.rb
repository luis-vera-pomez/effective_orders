module Effective
  class CartsController < ApplicationController
    include EffectiveCartsHelper

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:carts] : EffectiveOrders.layout)

    def show
      @cart = current_cart
      @pending_orders = Effective::Order.pending.where(user: current_user) if current_user.present?

      @page_title ||= 'My Cart'
      EffectiveOrders.authorized?(self, :show, @cart)
    end

    def destroy
      @cart = current_cart

      EffectiveOrders.authorized?(self, :destroy, @cart)

      if @cart.destroy
        flash[:success] = 'Successfully emptied cart.'
      else
        flash[:danger] = 'Unable to destroy cart.'
      end

      redirect_back_or_to_cart
    end

    def add_to_cart
      @purchasable = (add_to_cart_params[:purchasable_type].constantize.find(add_to_cart_params[:purchasable_id].to_i) rescue nil)

      EffectiveOrders.authorized?(self, :update, current_cart)

      begin
        raise "Please select a valid #{add_to_cart_params[:purchasable_type] || 'item' }." unless @purchasable

        current_cart.add(@purchasable, quantity: [add_to_cart_params[:quantity].to_i, 1].max)
        flash[:success] = 'Successfully added item to cart.'
      rescue EffectiveOrders::SoldOutException
        flash[:warning] = 'This item is sold out.'
      rescue => e
        flash[:danger] = 'Unable to add item to cart: ' + e.message
      end

      redirect_back_or_to_cart
    end

    def remove_from_cart
      @cart_item = current_cart.cart_items.find(remove_from_cart_params[:id])

      EffectiveOrders.authorized?(self, :update, current_cart)

      if @cart_item.destroy
        flash[:success] = 'Successfully removed item from cart.'
      else
        flash[:danger] = 'Unable to remove item from cart.'
      end

      redirect_back_or_to_cart
    end

    private

    def add_to_cart_params
      params.permit(:purchasable_type, :purchasable_id, :quantity)
    end

    def remove_from_cart_params
      params.permit(:id)
    end

    def redirect_back_or_to_cart
      if respond_to?(:redirect_back)
        redirect_back(fallback_location: effective_orders.cart_path)
      elsif request.referrer.present?
        redirect_to(:back)
      else
        redirect_to(effective_orders.cart_path)
      end
    end

  end
end
