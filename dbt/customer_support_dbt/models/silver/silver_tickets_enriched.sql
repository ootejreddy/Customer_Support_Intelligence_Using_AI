{{
    config(
        materialized='incremental',
        unique_key='ticket_id',
        incremental_strategy='merge'
    )
}}

{% set translate_func = 'SNOWFLAKE.CORTEX.TRANSLATE' %}
{% set sentiment_func = 'SNOWFLAKE.CORTEX.SENTIMENT' %}
{% set classify_func = 'SNOWFLAKE.CORTEX.CLASSIFY_TEXT' %}
{% set complete_func = 'SNOWFLAKE.CORTEX.COMPLETE' %}

with bronze_tickets as (
    select *
    from {{ ref('bronze_tickets_extracted') }}
    where body is not null and trim(body) != ''
    {% if is_incremental() %}
    and created_at > (
        select coalesce(max(created_at), '1900-01-01'::timestamp_ntz) from {{ this }}
    )
    {% endif %}
),

translated as (
    select
        ticket_id,
        subject,
        body,
        language,
        case 
            when lower(language) != 'en' and subject is not null and trim(subject) != '' then 
                {{ translate_func }}(subject, language, 'en')
            else subject
        end as subject_english,
        case 
            when lower(language) != 'en' and body is not null and trim(body) != '' then 
                {{ translate_func }}(body, language, 'en')
            else body
        end as body_english,
        ticket_type,
        queue,
        original_priority,
        answer,
        tag_1,
        tag_2,
        tag_3,
        tag_4,
        tag_5,
        kafka_partition,
        kafka_offset,
        kafka_topic,
        created_at,
        ingested_at
    from bronze_tickets
),

categorized as (
    select
        *,
        case 
            when body_english is not null and trim(body_english) != '' then
                {{ classify_func }}(
                    body_english,
                    ['Billing Issue', 'Technical Support', 'Product Inquiry', 'Complaint', 'Feature Request', 'Account Issue', 'General Question']
                ):label::string
            else 'Unknown'
        end as ai_category
    from translated
),

with_sentiment as (
    select
        *,
        case 
            when body_english is not null and trim(body_english) != '' then
                {{ sentiment_func }}(body_english)
            else 0
        end as sentiment_score
    from categorized
),

with_sentiment_label as (
    select
        *,
        case
            when sentiment_score >= 0.3 then 'positive'
            when sentiment_score <= -0.3 then 'negative'
            else 'neutral'
        end as sentiment_label
    from with_sentiment
),

with_priority as (
    select
        *,
        case 
            when body_english is not null and trim(body_english) != '' then
                {{ complete_func }}(
                    'mistral-7b',
                    'Based on the following customer support ticket, determine the priority level. Respond with ONLY one word: critical, high, medium, or low. Ticket: ' || left(body_english, 500)
                )::string
            else 'medium'
        end as ai_priority_raw
    from with_sentiment_label
),

final as (
    select
        ticket_id,
        subject,
        subject_english,
        body,
        body_english,
        language,
        ticket_type,
        ai_category,
        queue,
        original_priority,
        trim(lower(regexp_replace(ai_priority_raw, '[^a-zA-Z]', ''))) as ai_priority,
        sentiment_score,
        sentiment_label,
        answer,
        tag_1,
        tag_2,
        tag_3,
        tag_4,
        tag_5,
        kafka_partition,
        kafka_offset,
        kafka_topic,
        created_at,
        ingested_at,
        current_timestamp() as processed_at
    from with_priority
)

select * from final
