# frozen_string_literal: true

# Objective
# The goal of this task is to implement the necessary code in the "TASK #"
# sections so that all provided test cases pass successfully.
#
# Guidelines
# Do Not Modify Existing Code: The code that's already in place should remain unchanged.
# Do Not Alter Test Cases: Test cases should not be modified in any way.
# Optional: You may add additional test cases to further improve test coverage, but this is not required.
#
# Bonus Requirement (Optional)
# In addition to completing the task, you may also propose and implement
# schema or code changes that would lead to performance improvements.
# Please document your reasoning and the expected benefits of these changes.
#
# To run the tests use:
# $ ruby ./task.rb
#
# or, using Docker:
# $ docker run -it --rm -v ${PWD}:/usr/src/project ruby:3.3.4 ruby /usr/src/project/taks.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails", branch: "main"
  gem "sqlite3"
end

require "active_record"
require "minitest/autorun"
require "logger"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.string :status, null: false
    t.integer :total_in_cents, null: false

    t.timestamps
  end

  create_table :refunds, force: true do |t|
    t.references :order, null: false, foreign_key: true
    t.integer :amount_in_cents, null: false

    t.timestamps
  end
end

class Order < ActiveRecord::Base
  enum :status, { paid: 'paid', refunded: 'refunded' }

  has_many :refunds

  before_create :set_default_status

  def refund!(amount = available_amount_for_refunding)
    refunds.create!(amount_in_cents: amount)
  end

  def refunded_amount_in_cents
    (refunds && refunds.pluck(:amount_in_cents).inject(:+)).to_i
  end

  def can_refund?(amount = 0)
    return false if available_amount_for_refunding == amount && amount == 0
    
    available_amount_for_refunding >= amount
  end

  def available_amount_for_refunding
    @available_amount_for_refunding = total_in_cents - refunded_amount_in_cents
  end

  private

  def set_default_status
    self.status ||= :paid
  end
end

class Refund < ActiveRecord::Base
  belongs_to :order

  validates :order, presence: true
  validate :validate_available_amount

  after_save :set_refunded_status_to_orders

  private

  def validate_available_amount
    return false unless order
    
    if amount_in_cents > order.available_amount_for_refunding
      errors.add(:amount_in_cents, "is invalid")
    end
  end

  def set_refunded_status_to_orders
    order.status = :refunded
    order.save
  end
end

class RefundTest < Minitest::Test
  def test_paid_status
    order = Order.create! total_in_cents: 16000

    assert order.paid?
  end

  def test_refunded_status
    order = Order.create! total_in_cents: 16000

    order.refund! 400
    order.reload

    assert order.refunded?
  end

  def test_full_refund
    order = Order.create! total_in_cents: 16000

    order.refund!

    assert_equal order.total_in_cents, order.refunded_amount_in_cents
  end

  def test_invalid_amount
    order = Order.create! total_in_cents: 16000

    exception = assert_raises ActiveRecord::RecordInvalid do
      order.refund! 17000
    end

    assert_equal 'Validation failed: Amount in cents is invalid', exception.message
  end

  def test_refund_amount
    order = Order.create! total_in_cents: 16000

    order.refund! 4000
    order.refund! 3000

    assert_equal 7000, order.refunded_amount_in_cents
  end

  def test_can_refund_new_order
    order = Order.create! total_in_cents: 16000

    assert order.can_refund?
  end

  def test_can_refund_refunded_order
    order = Order.create! total_in_cents: 16000

    order.refund!

    assert_equal false, order.can_refund?
  end

  def test_can_refund_invalid_amount
    order = Order.create! total_in_cents: 16000

    assert_equal false, order.can_refund?(17000)
  end

  def test_can_refund_for_amount
    order = Order.create! total_in_cents: 16000

    assert order.can_refund? 16000

    order.refund! 4000

    assert_equal false, order.can_refund?(14000)

    order.refund!

    assert_equal false, order.can_refund?
  end

  def test_refund_without_order
    exception = assert_raises ActiveRecord::RecordInvalid do
      Refund.create! amount_in_cents: 1000
    end

    assert_equal 'Validation failed: Order can\'t be blank', exception.message
  end

  def test_refund_directly
    order = Order.create! total_in_cents: 16000
    refund = Refund.create! amount_in_cents: 1000, order: order

    assert order.refunded?
    assert_equal refund.amount_in_cents, order.refunded_amount_in_cents
  end

  def test_invalid_refund_directly
    order = Order.create! total_in_cents: 16000

    assert_raises ActiveRecord::RecordInvalid do
      Refund.create! amount_in_cents: 17000, order: order
    end
  end
end
