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
        'mistral-7b', 
        CONCAT(
            '### TASK\n',
            'Act as a Senior Support Triage Lead. Analyze the following messy support ticket and extract two specific elements: the core technical problem and the customer’s specific experience or sentiment.\n\n',
            '### RULES\n',
            '1. CORE PROBLEM: Identify the specific failure or question. Ignore the intro "I am having an issue with...".\n',
            '2. EXPERIENCE: Note what the customer did (e.g., troubleshooting), how they feel, or the effort they made to reach support.\n',
            '3. NOISE REMOVAL: Strictly strip out zip codes, URLs, browser metadata, logs, and generic template filler.\n\n',
            '### OUTPUT FORMAT\n',
            'Return only one sentence in this format: [Problem Statement]. Customer experienced [Experience/Action].\n\n',
            '### INPUT TEXT\n', 
            semi_clean_description
        )
    ) AS ai_generated_ticket_description
FROM base_staged_data

