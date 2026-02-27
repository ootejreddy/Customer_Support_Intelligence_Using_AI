select * from {{ ref('stg_denoised_tickets') }}

select * from {{ ref('stg_denoised_tickets_using_small_model') }}


