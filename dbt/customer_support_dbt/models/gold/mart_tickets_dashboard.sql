{{
    config(
        materialized='table'
    )
}}

with enriched_tickets as (
    select * from {{ ref('silver_tickets_enriched') }}
),

final as (
    select
        ticket_id,
        subject,
        subject_english,
        body_english,
        language,
        ticket_type,
        ai_category,
        queue,
        original_priority,
        ai_priority,
        sentiment_score,
        sentiment_label,
        case
            when ai_priority in ('critical') then 1
            when ai_priority in ('high') then 2
            when ai_priority in ('medium') then 3
            when ai_priority in ('low') then 4
            else 5
        end as priority_rank,
        case
            when sentiment_label = 'negative' then 'red'
            when sentiment_label = 'positive' then 'green'
            else 'gray'
        end as sentiment_color,
        created_at,
        processed_at
    from enriched_tickets
)

select * from final
order by priority_rank, sentiment_score asc
