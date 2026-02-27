SELECT 
    * REPLACE (
        REPLACE(ticket_description, '{product_purchased}', product_purchased) AS ticket_description
    )
FROM {{ ref('bronze_customer_support_tickets') }}
