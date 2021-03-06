module Effective
  module Concerns
    module Purchase
      extend ActiveSupport::Concern

      protected

      def order_purchased(provider:, card: 'none', details: 'none', email: true, skip_buyer_validations: false, purchased_url: nil, declined_url: nil)
        begin
          @order.purchase!(provider: provider, card: card, details: details, email: email, skip_buyer_validations: skip_buyer_validations)

          Effective::Cart.where(user_id: @order.user_id).destroy_all

          if EffectiveOrders.mailer[:send_order_receipt_to_buyer] && email
            flash[:success] = "Payment successful! A receipt has been sent to #{@order.user.email}"
          elsif @order.free?
            # Nothing
          else
            flash[:success] = 'Payment successful! An email receipt has not been sent.'
          end

          redirect_to (purchased_url.presence || effective_orders.purchased_order_path(':id')).gsub(':id', @order.to_param.to_s)
        rescue => e
          flash[:danger] = "An error occurred while processing your payment: #{e.message}. Please try again."
          redirect_to(declined_url.presence || effective_orders.cart_path).gsub(':id', @order.to_param.to_s)
        end
      end

      def order_declined(provider:, card: 'none', details: 'none', message: nil, declined_url: nil)
        @order.decline!(provider: provider, card: card, details: details) rescue nil

        flash[:danger] = message.presence || 'Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.'

        redirect_to(declined_url.presence || effective_orders.declined_order_path(@order)).gsub(':id', @order.to_param.to_s)
      end

    end
  end
end
