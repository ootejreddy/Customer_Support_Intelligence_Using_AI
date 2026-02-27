WITH base_staged_data AS (
    SELECT 
        ticket_id,
        customer_name,
        product_purchased,
        ticket_description AS semi_clean_description 
    FROM {{ ref('stg_customer_support_tickets') }}
)

SELECT
    *,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2', 
        CONCAT(
            'You are an expert support analyst. The following ticket contains template noise ',
            'and random unrelated sentences (like billing info or browser comments). ',
            'Your task: Extract ONLY the unique customer problem statement. ',
            'Ignore the introductory phrase "I am having an issue with...". ',
            'Ignore zip codes, URLs, logs, system logs, browser comments and generic filler. ',
            'If the customer describes a specific action or failure, keep only that. ',
            'Return ONLY the cleaned text. ',
            'Text: ', 
            semi_clean_description
        )
    ) AS ai_generated_ticket_description
FROM base_staged_data

