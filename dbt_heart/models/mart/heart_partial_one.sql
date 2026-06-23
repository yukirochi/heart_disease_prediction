WITH staging_data AS (
    SELECT * FROM {{ source('heart_staging_data','heart_staging')}}
)

SELECT * FROM staging_data LIMIT 2500 OFFSET 5000