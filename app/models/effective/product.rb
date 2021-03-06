module Effective
  class Product < ActiveRecord::Base
    self.table_name = EffectiveOrders.products_table_name.to_s

    acts_as_purchasable

    # Attributes
    # title         :string
    # price         :integer, default: 0
    # tax_exempt    :boolean, default: false
    #
    # timestamps

    validates :title, presence: true
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    def to_s
      self[:title] || 'New Product'
    end

  end
end
