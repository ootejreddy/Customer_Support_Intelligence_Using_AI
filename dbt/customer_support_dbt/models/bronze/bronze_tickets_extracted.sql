{{
    config(
        materialized='incremental',
        unique_key='ticket_id',
        incremental_strategy='merge'
    )
}}

with source_data as (
    select
        record_metadata,
        parse_json(record_content) as record_content
    from {{ source('raw', 'CUSTOMER_SUPPORT_TICKETS') }}
    {% if is_incremental() %}
    where try_to_timestamp(parse_json(record_metadata):CreateTime::string)::timestamp_ntz > (
        select coalesce(max(created_at), '1900-01-01'::timestamp_ntz) from {{ this }}
    )
    {% endif %}
),

extracted as (
    select
        md5(
            record_metadata:partition::string || '-' || 
            record_metadata:offset::string || '-' || 
            record_metadata:topic::string
        ) as ticket_id,
        record_content:subject::string as subject,
        record_content:body::string as body,
        record_content:language::string as language,
        record_content:type::string as ticket_type,
        record_content:queue::string as queue,
        record_content:priority::string as original_priority,
        record_content:answer::string as answer,
        record_content:tag_1::string as tag_1,
        record_content:tag_2::string as tag_2,
        record_content:tag_3::string as tag_3,
        record_content:tag_4::string as tag_4,
        record_content:tag_5::string as tag_5,
        record_metadata:partition::int as kafka_partition,
        record_metadata:offset::int as kafka_offset,
        record_metadata:topic::string as kafka_topic,
        to_timestamp(record_metadata:CreateTime::number / 1000) as created_at,
        to_timestamp(record_metadata:SnowflakeConnectorPushTime::number / 1000) as ingested_at
    from source_data
)

select * from extracted
where subject is not null and trim(subject) != ''
