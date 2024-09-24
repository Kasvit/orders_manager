Here is my solution for a short test task

## My proposes:
1. Add index:
  - add_index :refunds, :order_id (Increase the speed of searching for order refunds)
  - add_index :orders, :status (Increase the speed of filtering and searching only by status)
2. Add transactions:
  - When we create the orders refund
    ```
    def refund!(amount = available_amount_for_refunding)
      transaction do 
        refunds.create!(amount_in_cents: amount)
      end
    end
    ```
    Allow us to follow ACID properties
3. Denormalize DB table `orders` and add `refunded_amount_in_cents` field and update it during the `refund!` or as a collback inside `Refund`.
    ```
    add_column :orders, :refunded_amount_in_cents, :integer, default: 0, null: false
    ```
    It will increase the speed of getting this number without the query to DB.

