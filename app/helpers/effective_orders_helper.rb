module EffectiveOrdersHelper
  def price_to_currency(price)
    price = price || 0
    raise 'price_to_currency expects an Integer representing the number of cents' unless price.kind_of?(Integer)
    number_to_currency(price / 100.0)
  end

  def tax_rate_to_percentage(tax_rate, options = {})
    options[:strip_insignificant_zeros] = true if options[:strip_insignificant_zeros].nil?
    number_to_percentage(tax_rate, strip_insignificant_zeros: true)
  end

  def order_summary(order)
    order_item_list = content_tag(:ul) do
      order.order_items.map do |item|
        content_tag(:li) do
          title = item.title.split('<br>')
          "#{item.quantity}x #{title.first} for #{price_to_currency(item.price)}".tap do |output|
            title[1..-1].each { |line| output << "<br>#{line}" }
          end.html_safe
        end
      end.join.html_safe
    end
    content_tag(:p, "#{price_to_currency(order.total)} total for #{pluralize(order.num_items, 'item')}:") + order_item_list
  end

  def order_item_summary(order_item)
    if order_item.quantity > 1
      content_tag(:p, "#{price_to_currency(order_item.total)} total for #{pluralize(order_item.quantity, 'item')}")
    else
      content_tag(:p, "#{price_to_currency(order_item.total)} total")
    end
  end

  def order_checkout_label(processor = nil)
    return 'Checkout' if (EffectiveOrders.single_payment_processor? && ![:pretend, :mark_as_paid, :free, :refund].include?(processor))

    case processor
    when :mark_as_paid
      'Mark as paid'
    when :free
      'Checkout free'
    when :refund
      'Complete refund'
    when :moneris, :stripe, :ccbill
      'Checkout with credit card'
    when :paypal
      'Checkout with PayPal'
    when :pretend
      EffectiveOrders.allow_pretend_purchase_in_production ? 'Purchase Order' : 'Purchase Order (development only)'
    when :cheque
      'Pay by cheque'
    when :app_checkout
      EffectiveOrders.app_checkout[:checkout_label].presence || 'Checkout'
    else
      'Checkout'
    end
  end

  # This is called on the My Sales Page and is intended to be overridden in the app if needed
  def acts_as_purchasable_path(purchasable, action = :show)
    polymorphic_path(purchasable)
  end

  def order_payment_to_html(order)
    payment = order.payment

    if order.purchased?(:stripe_connect) && order.payment.kind_of?(Hash)
      payment = Hash[
        order.payment.map do |seller_id, v|
          if (user = Effective::Customer.find(seller_id).try(:user))
            [link_to(user, admin_user_path(user)), order.payment[seller_id]]
          else
            [seller_id, order.payment[seller_id]]
          end
        end
      ]
    end

    content_tag(:pre) do
      raw JSON.pretty_generate(payment).html_safe
        .gsub('\"', '')
        .gsub("[\n\n    ]", '[]')
        .gsub("{\n    }", '{}')
    end
  end

  def render_order(order)
    render(partial: 'effective/orders/order', locals: { order: order })
  end

  def render_checkout_step1(order, namespace: nil, purchased_url: nil, declined_url: nil)
    raise 'unable to checkout an order without a user' unless order && order.user

    locals = { order: order, purchased_url: purchased_url, declined_url: declined_url, namespace: namespace }

    render partial: 'effective/orders/checkout_step1', locals: locals
  end
  alias_method :render_checkout, :render_checkout_step1

  def render_checkout_step2(order, namespace: nil, purchased_url: nil, declined_url: nil)
    raise 'unable to checkout an order without a user' unless order && order.user

    locals = { order: order, purchased_url: purchased_url, declined_url: declined_url, namespace: namespace }

    if order.new_record? || !order.valid?
      render(partial: 'effective/orders/checkout_step1', locals: locals)
    else
      render(partial: 'effective/orders/checkout_step2', locals: locals)
    end
  end

  def checkout_step1_form_url(order, namespace = nil)
    raise 'expected an order' unless order
    raise 'invalid namespace, expecting nil or :admin' unless [nil, :admin].include?(namespace)

    if order.new_record?
      namespace == nil ? effective_orders.orders_path : effective_orders.admin_orders_path
    else
      namespace == nil ? effective_orders.order_path(order) : effective_orders.checkout_admin_order_path(order)
    end
  end

  def link_to_my_purchases(opts = {})
    options = {
      label: 'My Purchases',
      class: 'btn btn-default',
      rel: :nofollow
    }.merge(opts)

    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-my-purchases')

    link_to(label, effective_orders.my_purchases_orders_path, options)
  end
  alias_method :link_to_order_history, :link_to_my_purchases


  def render_orders(obj, opts = {})
    orders = Array(obj.kind_of?(User) ? Effective::Order.purchased_by(obj) : obj)

    if orders.any? { |order| order.kind_of?(Effective::Order) == false }
      raise 'expected a User or Effective::Order'
    end

    render(partial: 'effective/orders/orders_table', locals: { orders: orders }.merge(opts))
  end

  alias_method :render_purchases, :render_orders
  alias_method :render_my_purchases, :render_orders
  alias_method :render_order_history, :render_orders

  def payment_card_label(card)
    card = card.to_s.downcase.gsub(' ', '').strip

    case card
    when ''
      'None'
    when 'v', 'visa'
      'Visa'
    when 'm', 'mc', 'master', 'mastercard'
      'MasterCard'
    when 'a', 'ax', 'american', 'americanexpress'
      'American Express'
    when 'd', 'discover'
      'Discover'
    else
      card.to_s
    end
  end

end
