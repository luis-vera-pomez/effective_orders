module Admin
  class CustomersController < ApplicationController
    before_action :authenticate_user!

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_customers] : EffectiveOrders.layout)

    def index
      @datatable = EffectiveCustomersDatatable.new(self)

      @page_title = 'Customers'

      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, :index, Effective::Customer)
    end

    def show
      @customer = Effective::Customer.find(params[:id])

      @page_title ||= @customer.to_s
      EffectiveOrders.authorized?(self, :show, Effective::Customer)
    end

  end
end
