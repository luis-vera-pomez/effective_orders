# rake effective_orders:overwrite_order_item_titles

namespace :effective_orders do
  desc 'Overwrite all order item titles with current acts_as_purchasable object title'
  task overwrite_order_item_titles: :environment do
    puts 'WARNING: this task will overwrite all existing order items with new titles. Proceed? (y/n)'
    (puts 'Aborted' and exit) unless STDIN.gets.chomp.downcase == 'y'

    Effective::OrderItem.transaction do
      begin

        Effective::OrderItem.includes(:purchasable).find_each do |order_item|
          new_title = order_item.purchasable.title

          unless new_title
            raise "acts_as_purchasable object #{order_item.purchasable_type.try(:classify)}<#{order_item.purchasable_id}>.title() from Effective::OrderItem<#{order_item.id}> cannot be nil."
          end

          order_item.update_column(:title, new_title) # This intentionally skips validation
        end

        puts 'Successfully updated all order item titles.'
      rescue => e
        puts "An error has occurred: #{e.message}"
        puts "(effective_orders) Rollback. No order item titles have been changed."
        raise ActiveRecord::Rollback
      end
    end
  end

  desc 'Sends trial expiring and expired emails to each subscribable. Schedule me to run once per day.'
  task send_trial_expiring_emails: :environment do
    trial_remind_at = Array(EffectiveOrders.subscription[:trial_remind_at]).compact
    exit unless trial_remind_at.present? && trial_remind_at.all? { |x| x.present? }

    Rails.application.eager_load!

    today = Time.zone.now.beginning_of_day
    reminders = trial_remind_at.select { |remind_at| remind_at.kind_of?(ActiveSupport::Duration) }

    begin
      ActsAsSubscribable.descendants.each do |klass|
        klass.trialing.find_each do |subscribable|
          if subscribable.trial_expires_at == today
            puts "sending trial expired to #{subscribable}"
            Effective::OrdersMailer.subscription_trial_expired(subscribable).deliver_now
          end

          next if subscribable.trial_expired? # We already notified them

          reminders.each do |remind_at|
            next unless subscribable.trial_expires_at == (today + remind_at)

            puts "sending trial expiring to #{subscribable}. expires in #{(subscribable.trial_expires_at - today) / 1.day.to_i} days."
            Effective::OrdersMailer.subscription_trial_expiring(subscribable).deliver_now
          end
        end
      end

      puts 'send_trial_expiring_emails completed'
      EffectiveLogger.success('scheduled task send_trial_expiring_emails completed') if defined?(EffectiveLogger)
    rescue => e
      ExceptionNotifier.notify_exception(e) if defined?(ExceptionNotifier)
      raise e
    end

    true
  end

end
