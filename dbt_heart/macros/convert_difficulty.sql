{% macro convert_difficulty(column_name, partition_cols="age, gender") %}

    CASE 
        WHEN {{column_name}} = 'low' THEN 1 
        WHEN {{column_name}} = 'medium' THEN 2
        WHEN {{column_name}} = 'high' THEN 3
        ELSE (
            CASE 
                WHEN (MODE({{column_name}}) OVER (PARTITION BY {{ partition_cols }} ))  = 'low' THEN 1 
                WHEN (MODE({{column_name}}) OVER (PARTITION BY {{ partition_cols }} )) = 'medium' THEN 2
                WHEN (MODE({{column_name}}) OVER (PARTITION BY {{ partition_cols }} ))  = 'high' THEN 3
                ELSE 2
                END
                )
    END

{% endmacro %}